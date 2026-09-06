//
//  ConnectionSupervisor.swift
//  Resilience
//
//  Created on 2026-09-06.
//

import Foundation

/// Lifecycle status of a supervised connection.
public enum SupervisorState: String, Sendable {
    case disconnected
    case connecting
    case connected
    case reconnecting
    case closed
}

/// Configuration parameters for connection supervision, retry backoff, and heartbeats.
public struct SupervisorConfig: Sendable {
    public let reconnectMinBackoff: TimeInterval
    public let reconnectMaxBackoff: TimeInterval
    public let heartbeatInterval: TimeInterval
    public let heartbeatTimeout: TimeInterval

    public init(
        reconnectMinBackoff: TimeInterval = 0.5,
        reconnectMaxBackoff: TimeInterval = 30.0,
        heartbeatInterval: TimeInterval = 10.0,
        heartbeatTimeout: TimeInterval = 5.0
    ) {
        self.reconnectMinBackoff = reconnectMinBackoff
        self.reconnectMaxBackoff = reconnectMaxBackoff
        self.heartbeatInterval = heartbeatInterval
        self.heartbeatTimeout = heartbeatTimeout
    }
}

/// Long-running actor supervising resilient network connections with auto-reconnect,
/// exponential backoff with jitter, health probing, and lifecycle event hooks.
public actor ConnectionSupervisor<Client: Sendable>: Sendable {
    public typealias ConnectFactory = @Sendable () async throws -> Client
    public typealias HealthProbe = @Sendable (Client) async throws -> Bool
    public typealias LifecycleHook = @Sendable (Client) async -> Void
    public typealias DisconnectHook = @Sendable () async -> Void

    public let config: SupervisorConfig
    public private(set) var state: SupervisorState = .disconnected
    public private(set) var activeClient: Client?
    public private(set) var totalReconnects: Int = 0

    private var connectFactory: ConnectFactory?
    private var healthProbe: HealthProbe?
    private var onConnectedHooks: [LifecycleHook] = []
    private var onDisconnectedHooks: [DisconnectHook] = []

    private var supervisorTask: Task<Void, Never>?
    private var isRunning: Bool = false

    public init(config: SupervisorConfig = SupervisorConfig()) {
        self.config = config
    }

    /// Registers the connection factory that establishes the network client.
    public func setConnectFactory(_ factory: @escaping ConnectFactory) {
        self.connectFactory = factory
    }

    /// Registers a health probe invoked periodically to verify client liveliness.
    public func setHealthProbe(_ probe: @escaping HealthProbe) {
        self.healthProbe = probe
    }

    /// Appends a lifecycle callback executed whenever connection is successfully established.
    public func addOnConnected(_ hook: @escaping LifecycleHook) {
        onConnectedHooks.append(hook)
    }

    /// Appends a callback executed whenever connection is lost.
    public func addOnDisconnected(_ hook: @escaping DisconnectHook) {
        onDisconnectedHooks.append(hook)
    }

    /// Starts the supervisor loop.
    public func start() {
        guard !isRunning else { return }
        isRunning = true

        let supervisor = self
        supervisorTask = Task {
            await supervisor.runSupervisorLoop()
        }
    }

    /// Stops the supervisor loop and cleans up active connections.
    public func stop() async {
        isRunning = false
        supervisorTask?.cancel()
        supervisorTask = nil
        activeClient = nil
        state = .closed

        for hook in onDisconnectedHooks {
            await hook()
        }
    }

    private func runSupervisorLoop() async {
        var backoff = config.reconnectMinBackoff

        while isRunning && !Task.isCancelled {
            state = .connecting
            guard let factory = connectFactory else {
                state = .disconnected
                break
            }

            do {
                let client = try await factory()
                activeClient = client

                // Optional initial health probe
                if let probe = healthProbe {
                    let healthy = try await probe(client)
                    guard healthy else {
                        throw NSError(domain: "ConnectionSupervisor", code: -1, userInfo: [NSLocalizedDescriptionKey: "Initial health probe failed"])
                    }
                }

                state = .connected
                backoff = config.reconnectMinBackoff

                // Fire connection hooks (e.g. hook reconciliation, outbox flush)
                for hook in onConnectedHooks {
                    await hook(client)
                }

                // Liveliness monitoring loop
                while isRunning && !Task.isCancelled {
                    try await Task.sleep(nanoseconds: UInt64(config.heartbeatInterval * 1_000_000_000))
                    if let probe = healthProbe {
                        let ok = (try? await probe(client)) ?? false
                        if !ok {
                            break // Probe failed, trigger reconnect
                        }
                    }
                }
            } catch {
                // Connection or health check failed
            }

            activeClient = nil
            for hook in onDisconnectedHooks {
                await hook()
            }

            if isRunning && !Task.isCancelled {
                state = .reconnecting
                totalReconnects += 1
                let jitter = Double.random(in: 0.8...1.2)
                let sleepSecs = min(backoff * jitter, config.reconnectMaxBackoff)
                try? await Task.sleep(nanoseconds: UInt64(sleepSecs * 1_000_000_000))
                backoff = min(backoff * 2.0, config.reconnectMaxBackoff)
            }
        }

        state = .closed
    }
}
