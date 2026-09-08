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
    public var startValue: Value {
        get { from }
        set { from = newValue }
    }

    @inlinable
    public var endValue: Value {
        get { to }
        set { to = newValue }
    }

    @inlinable
    public init(
        from startValue: Value,
        to endValue: Value,
        duration: Double = 1000.0,
        delay: Double = 0.0,
        easing: EasingType = .linear,
        startTime: Double = 0.0
    ) {
        self.from = startValue
        self.to = endValue
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

    /// Evaluates the property value at the specified elapsed time in milliseconds.
    @inlinable
    public func sample(at elapsedMs: Double) -> Value {
        value(at: elapsedMs)
    }
}

/// An individual keyframe for property interpolation.
public struct Keyframe<Value: Interpolatable>: Sendable {
    public var timeFraction: Double
    public var value: Value
    public var easing: EasingType

    @inlinable
    public var time: Double {
        get { timeFraction }
        set { timeFraction = newValue }
    }

    public init(timeFraction: Double, value: Value, easing: EasingType = .linear) {
        self.timeFraction = min(1.0, max(0.0, timeFraction))
        self.value = value
        self.easing = easing
    }

    public init(time: Double, value: Value, easing: EasingType = .linear) {
        self.timeFraction = time
        self.value = value
        self.easing = easing
    }
}

/// A keyframe track for multi-segment property interpolation over time.
public struct KeyframeTrack<Value: Interpolatable>: Sendable {
    public typealias Keyframe = VectorAnimation.Keyframe<Value>

    public var keyframes: [Keyframe]

    public init(keyframes: [Keyframe]) {
        self.keyframes = keyframes.sorted { $0.timeFraction < $1.timeFraction }
    }

    /// Evaluates the track at a given timestamp or progress fraction.
    public func sample(at time: Double) -> Value? {
        guard !keyframes.isEmpty else { return nil }
        guard keyframes.count > 1 else { return keyframes[0].value }

        if time <= keyframes.first!.timeFraction {
            return keyframes.first!.value
        }
        if time >= keyframes.last!.timeFraction {
            return keyframes.last!.value
        }

        for i in 0..<(keyframes.count - 1) {
            let k0 = keyframes[i]
            let k1 = keyframes[i + 1]

            if time >= k0.timeFraction && time <= k1.timeFraction {
                let duration = k1.timeFraction - k0.timeFraction
                guard duration > 1e-9 else { return k0.value }
                let progress = (time - k0.timeFraction) / duration
                let eased = k0.easing.evaluate(at: progress)
                return k0.value.interpolated(to: k1.value, progress: eased)
            }
        }
        return keyframes.last!.value
    }
}

/// Calculates staggered delays for sequential visual element presentation.
public enum AnimationStagger: Sendable {
    public static func calculateDelay(
        index: Int,
        totalCount: Int,
        baseDelay: Double = 0.0,
        staggerStep: Double = 50.0
    ) -> Double {
        guard totalCount > 0 else { return baseDelay }
        return baseDelay + Double(index) * staggerStep
    }
}
