//
//  ResilientOutbox.swift
//  Resilience
//
//  Created on 2026-09-06.
//

import Foundation

/// Operational state of the Outbox dispatcher.
public enum OutboxState: String, Sendable {
    case idle
    case flushing
    case retrying
    case paused
}

/// Asynchronous, fault-tolerant mutation buffer isolating critical application transactions
/// from network latency, temporary connection timeouts, or peer service unavailability.
///
/// Mutations are enqueued in constant $O(1)$ time into a bounded FIFO queue, guaranteeing
/// that upstream caller threads will never block when external network systems fail.
public actor ResilientOutbox<Item: Sendable>: Sendable {
    public typealias Dispatcher = @Sendable (Item) async throws -> Bool

    private var queue: [Item] = []
    public let capacity: Int
    public private(set) var state: OutboxState = .idle
    private var backoffDuration: TimeInterval
    private let minBackoff: TimeInterval
    private let maxBackoff: TimeInterval
    private var isFlushing: Bool = false

    /// Dispatch handler invoked to transmit individual mutations over network RPC/REST.
    private var dispatcher: Dispatcher?

    /// Initializes a ResilientOutbox with bounded capacity and configurable retry backoffs.
    ///
    /// - Parameters:
    ///   - capacity: Maximum number of queued items before oldest eviction occurs (default: 5,000).
    ///   - minBackoff: Minimum retry backoff delay in seconds (default: 0.25s).
    ///   - maxBackoff: Maximum retry backoff cap in seconds (default: 10.0s).
    public init(
        capacity: Int = 5_000,
        minBackoff: TimeInterval = 0.25,
        maxBackoff: TimeInterval = 10.0
    ) {
        precondition(capacity > 0, "Capacity must be strictly positive")
        self.capacity = capacity
        self.minBackoff = minBackoff
        self.maxBackoff = maxBackoff
        self.backoffDuration = minBackoff
    }

    /// Sets the active network dispatcher.
    public func setDispatcher(_ dispatcher: Dispatcher?) {
        self.dispatcher = dispatcher
    }

    /// Non-blocking mutation enqueue called from application workflows.
    ///
    /// - Parameter item: The item to buffer.
    /// - Returns: `true` if enqueued successfully.
    @discardableResult
    public func enqueue(_ item: Item) -> Bool {
        if queue.count >= capacity {
            // Bounded ring buffer: drop oldest mutation to prevent memory exhaustion
            queue.removeFirst()
        }
        queue.append(item)

        // Trigger asynchronous background flush if dispatcher is attached
        if dispatcher != nil && !isFlushing {
            Task { [weak self] in
                await self?.flush()
            }
        }

        return true
    }

    /// Number of pending mutations in the outbox.
    public var pendingCount: Int {
        queue.count
    }

    /// Returns `true` if the outbox queue is currently empty.
    public var isEmpty: Bool {
        queue.isEmpty
    }

    /// Clears all queued mutations and resets retry backoff.
    public func clear() {
        queue.removeAll()
        state = .idle
        backoffDuration = minBackoff
    }

    /// Attempts to drain and dispatch all queued mutations in FIFO order.
    public func flush() async {
        guard !isFlushing else { return }
        guard let dispatcher = self.dispatcher else {
            state = .paused
            return
        }

        isFlushing = true
        state = .flushing
        defer { isFlushing = false }

        while !queue.isEmpty {
            let item = queue[0]
            do {
                let success = try await dispatcher(item)
                if success {
                    queue.removeFirst()
                    // Reset backoff on successful send
                    backoffDuration = minBackoff
                    state = .flushing
                } else {
                    // Dispatcher returned failure without throwing: enter retry loop
                    state = .retrying
                    try? await Task.sleep(nanoseconds: UInt64(backoffDuration * 1_000_000_000))
                    applyExponentialBackoff()
                    break
                }
            } catch {
                // Network failure or disconnection: apply exponential backoff with jitter
                state = .retrying
                try? await Task.sleep(nanoseconds: UInt64(backoffDuration * 1_000_000_000))
                applyExponentialBackoff()
                break
            }
        }

        if queue.isEmpty {
            state = .idle
            backoffDuration = minBackoff
        }
    }

    private func applyExponentialBackoff() {
        // Exponential backoff with ±20% randomized jitter
        let jitter = Double.random(in: 0.8...1.2)
        backoffDuration = min(backoffDuration * 2.0 * jitter, maxBackoff)
    }
}
