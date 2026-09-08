// ===----------------------------------------------------------------------===
//
// This source file is part of the MeridianCore open source project
//
// Copyright (c) 2026 Apple Inc. and the MeridianCore project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// ===----------------------------------------------------------------------===

import Foundation
import VectorGeometry

/// Generic parameter tweening between an initial and target value over time.
public struct Tween<Value: Interpolatable>: Sendable {
    public var from: Value
    public var to: Value
    public var duration: Double
    public var delay: Double
    public var easing: EasingType
    public var startTime: Double

    @inlinable
    public init(
        from: Value,
        to: Value,
        duration: Double,
        delay: Double = 0.0,
        easing: EasingType = .linear,
        startTime: Double = 0.0
    ) {
        self.from = from
        self.to = to
        self.duration = max(1e-6, duration)
        self.delay = max(0.0, delay)
        self.easing = easing
        self.startTime = startTime
    }

    /// Evaluates the normalized progress $p \in [0, 1]$ at a given absolute timestamp.
    @inlinable
    public func progress(at time: Double) -> Double {
        let elapsed = time - startTime - delay
        if elapsed <= 0.0 { return 0.0 }
        if elapsed >= duration { return 1.0 }
        return elapsed / duration
    }

    /// Checks if the tween animation has finished.
    @inlinable
    public func isCompleted(at time: Double) -> Bool {
        time >= (startTime + delay + duration)
    }

    /// Evaluates the interpolated value at a given absolute timestamp.
    public func value(at time: Double) -> Value {
        let rawProgress = progress(at: time)
        let easedProgress = easing.evaluate(at: rawProgress)
        return from.interpolated(to: to, progress: easedProgress)
    }
}

/// A keyframe track for multi-segment property interpolation over time.
public struct KeyframeTrack<Value: Interpolatable>: Sendable {
    public struct Keyframe: Sendable {
        public var time: Double
        public var value: Value
        public var easing: EasingType

        public init(time: Double, value: Value, easing: EasingType = .linear) {
            self.time = time
            self.value = value
            self.easing = easing
        }
    }

    public var keyframes: [Keyframe]

    public init(keyframes: [Keyframe]) {
        self.keyframes = keyframes.sorted { $0.time < $1.time }
    }

    /// Evaluates the track at a given timestamp.
    public func sample(at time: Double) -> Value? {
        guard !keyframes.isEmpty else { return nil }
        guard keyframes.count > 1 else { return keyframes[0].value }

        if time <= keyframes.first!.time {
            return keyframes.first!.value
        }
        if time >= keyframes.last!.time {
            return keyframes.last!.value
        }

        for i in 0..<(keyframes.count - 1) {
            let k0 = keyframes[i]
            let k1 = keyframes[i + 1]

            if time >= k0.time && time <= k1.time {
                let duration = k1.time - k0.time
                guard duration > 1e-9 else { return k0.value }
                let progress = (time - k0.time) / duration
                let eased = k1.easing.evaluate(at: progress)
                return k0.value.interpolated(to: k1.value, progress: eased)
            }
        }
        return keyframes.last!.value
    }
}
