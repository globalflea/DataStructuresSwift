//
//  ResilienceTests.swift
//  ResilienceTests
//
//  Created on 2026-09-06.
//

import Foundation
import Testing
@testable import MeridianCore
@testable import Resilience

final class SafeBox<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var val: T
    init(_ initial: T) { self.val = initial }
    var value: T {
        lock.lock()
        defer { lock.unlock() }
        return val
    }
    func withValue<R>(_ block: (inout T) -> R) -> R {
        lock.lock()
        defer { lock.unlock() }
        return block(&val)
    }
}

struct MockResource: Identifiable, Sendable {
    let id: String
    let name: String
}

final class MockClient: @unchecked Sendable {
    var isHealthy: Bool = true
    var reconciledResources: [MockResource] = []
}

struct MockReconciler: DesiredStateReconciler {
    func reconcile(desired: [MockResource], with client: MockClient) async throws {
        client.reconciledResources = desired
    }
}

struct TestDeduplicatableEvent: Deduplicatable {
    let traceId: String
    let payload: String

    var deduplicationKey: String {
        traceId
    }
}

@Suite("Resilience Primitives: Outbox, Deduplicator, Supervisor, Reconciler Tests")
struct ResilienceTests {

    // MARK: - 1. ResilientOutbox Tests

    @Test("ResilientOutbox Enqueue, FIFO Draining, and Idle Circuit State")
    func testOutboxFIFOAndDrain() async {
        let outbox = ResilientOutbox<String>(capacity: 10)
        #expect(await outbox.isEmpty)
        #expect(await outbox.pendingCount == 0)

        await outbox.enqueue("mutation-1")
        await outbox.enqueue("mutation-2")
        await outbox.enqueue("mutation-3")
        #expect(await outbox.pendingCount == 3)

        let received = SafeBox<[String]>([])
        await outbox.setDispatcher { item in
            received.withValue { $0.append(item) }
            return true
        }

        await outbox.flush()
        #expect(await outbox.pendingCount == 0)
        #expect(await outbox.state == .idle)
        #expect(received.value == ["mutation-1", "mutation-2", "mutation-3"])
    }

    @Test("ResilientOutbox Bounded Capacity Ring Eviction")
    func testOutboxCapacityEviction() async {
        let outbox = ResilientOutbox<Int>(capacity: 3)
        for i in 1...5 {
            await outbox.enqueue(i)
        }

        #expect(await outbox.pendingCount == 3)

        let dispatched = SafeBox<[Int]>([])
        await outbox.setDispatcher { item in
            dispatched.withValue { $0.append(item) }
            return true
        }

        await outbox.flush()
        #expect(dispatched.value == [3, 4, 5])
    }

    @Test("ResilientOutbox Retry on Dispatcher Error and Backoff Recovery")
    func testOutboxRetryAndRecovery() async {
        let outbox = ResilientOutbox<String>(capacity: 5, minBackoff: 0.05, maxBackoff: 0.2)
        await outbox.enqueue("retry-item")

        let attempts = SafeBox<Int>(0)
        await outbox.setDispatcher { _ in
            let count = attempts.withValue { val -> Int in
                val += 1
                return val
            }
            if count == 1 {
                // Return failure without throwing
                return false
            }
            return true
        }

        await outbox.flush()
        #expect(await outbox.pendingCount == 1)

        await outbox.flush()
        #expect(await outbox.pendingCount == 0)
        #expect(await outbox.state == .idle)

        await outbox.enqueue("item")
        await outbox.clear()
        #expect(await outbox.isEmpty)
    }

    // MARK: - 2. SlidingDeduplicator Tests

    @Test("SlidingDeduplicator Deduplication Window and Expiration Purge")
    func testSlidingDeduplicator() async {
        let deduplicator = SlidingDeduplicator<String>(ttl: 0.1, pruneInterval: 0.05)
        let t0 = Date()

        // 1. First check -> true
        #expect(await deduplicator.checkAndRecord(key: "event_1", now: t0) == true)
        #expect(await deduplicator.count == 1)

        // 2. Immediate duplicate -> false
        #expect(await deduplicator.checkAndRecord(key: "event_1", now: t0.addingTimeInterval(0.02)) == false)

        // 3. Different key -> true
        #expect(await deduplicator.checkAndRecord(key: "event_2", now: t0.addingTimeInterval(0.02)) == true)

        // 4. Conformance with Deduplicatable protocol
        let dedupItem = TestDeduplicatableEvent(traceId: "trace_abc", payload: "data")
        #expect(await deduplicator.checkAndRecord(item: dedupItem, now: t0) == true)
        #expect(await deduplicator.checkAndRecord(item: dedupItem, now: t0) == false)

        // 5. Expiration after TTL -> treated as new
        let tExpired = t0.addingTimeInterval(0.2)
        #expect(await deduplicator.checkAndRecord(key: "event_1", now: tExpired) == true)

        await deduplicator.clear()
        #expect(await deduplicator.isEmpty)
    }

    // MARK: - 3. ConnectionSupervisor & DesiredStateReconciler Tests

    @Test("ConnectionSupervisor Lifecycle, Reconciler Hook, and Health Probe")
    func testConnectionSupervisorLifecycle() async throws {
        let config = SupervisorConfig(
            reconnectMinBackoff: 0.05,
            reconnectMaxBackoff: 0.2,
            heartbeatInterval: 0.05,
            heartbeatTimeout: 0.05
        )
        let supervisor = ConnectionSupervisor<MockClient>(config: config)
        #expect(await supervisor.state == .disconnected)

        let mockClient = MockClient()
        await supervisor.setConnectFactory {
            mockClient
        }
        await supervisor.setHealthProbe { client in
            client.isHealthy
        }

        let connectedFired = SafeBox<Bool>(false)
        await supervisor.addOnConnected { client in
            connectedFired.withValue { $0 = true }
            // Run state reconciler
            let reconciler = MockReconciler()
            try? await reconciler.reconcile(desired: [MockResource(id: "r1", name: "Res1")], with: client)
        }

        let disconnectedFired = SafeBox<Bool>(false)
        await supervisor.addOnDisconnected {
            disconnectedFired.withValue { $0 = true }
        }

        await supervisor.start()

        // Wait for connection to establish
        for _ in 0..<50 {
            if await supervisor.state == .connected { break }
            try await Task.sleep(nanoseconds: 10_000_000)
        }

        #expect(await supervisor.state == .connected)
        #expect(connectedFired.value == true)
        #expect(mockClient.reconciledResources.count == 1)
        #expect(mockClient.reconciledResources[0].id == "r1")

        // Trigger health failure to test reconnect
        mockClient.isHealthy = false
        for _ in 0..<50 {
            if await supervisor.totalReconnects >= 1 { break }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        #expect(await supervisor.totalReconnects >= 1)

        await supervisor.stop()
        #expect(await supervisor.state == .closed)
        #expect(disconnectedFired.value == true)
    }
}
