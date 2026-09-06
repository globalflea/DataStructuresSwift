//
//  DesiredStateReconciler.swift
//  Resilience
//
//  Created on 2026-09-06.
//

import Foundation

/// Protocol for idempotently converging local desired resources with a remote stateful service.
///
/// Implements the Kubernetes-style declarative reconciliation control loop:
/// `reconcile(desired:with:)` is invoked upon initial connection or recovery from process restart,
/// ensuring that required hooks, subscriptions, or registered entities exist on the remote peer.
public protocol DesiredStateReconciler: Sendable {
    associatedtype Resource: Sendable & Identifiable
    associatedtype Client: Sendable

    /// Idempotently reconciles desired in-memory resources against the remote service client.
    ///
    /// - Parameters:
    ///   - desired: The array of resources that must be active on the remote peer.
    ///   - client: The active connected communication client.
    func reconcile(desired: [Resource], with client: Client) async throws
}
