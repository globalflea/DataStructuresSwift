// ===----------------------------------------------------------------------===
//
// This source file is part of the MeridianCore open source project
//
// Copyright (c) 2026 Apple Inc. and the MeridianCore project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// ===----------------------------------------------------------------------===

import Foundation

/// Mathematical easing function implementation supporting 31 Robert Penner equations.
public enum Easing: Sendable {

    /// Evaluates an easing curve at normalized progress parameter $t \in [0, 1]$.
    ///
    /// - Parameters:
    ///   - type: The `EasingType` curve to evaluate.
    ///   - t: The normalized time fraction, clamped between `0.0` and `1.0`.
    /// - Returns: The interpolated progress value in $[0, 1]$ (or outside for overshoot curves).
    /// - Complexity: $O(1)$ constant time with zero heap allocations.
    @inlinable
    public static func evaluate(_ type: EasingType, t: Double) -> Double {
        evaluate(type: type, progress: t)
    }

    /// Evaluates an easing curve at a given progress value in $[0, 1]$.
    ///
    /// Values outside $[0, 1]$ are clamped to boundary values $0.0$ and $1.0$.
    ///
    /// - Parameters:
    ///   - type: The `EasingType` equation specification.
    ///   - progress: The normalized elapsed progress fraction in $[0, 1]$.
    /// - Returns: The resulting eased acceleration factor.
    /// - Complexity: $O(1)$ constant time.
    public static func evaluate(type: EasingType, progress: Double) -> Double {
        if progress <= 0.0 { return 0.0 }
        if progress >= 1.0 { return 1.0 }
        let t = progress

        switch type {
        case .linear:
            return t

        case .quadraticIn:
            return t * t
        case .quadraticOut:
            return t * (2.0 - t)
        case .quadraticInOut:
            return t < 0.5 ? 2.0 * t * t : -1.0 + (4.0 - 2.0 * t) * t

        case .cubicIn:
            return t * t * t
        case .cubicOut:
            let f = t - 1.0
            return f * f * f + 1.0
        case .cubicInOut:
            return t < 0.5 ? 4.0 * t * t * t : (t - 1.0) * (2.0 * t - 2.0) * (2.0 * t - 2.0) + 1.0

        case .quarticIn:
            return t * t * t * t
        case .quarticOut:
            let f = t - 1.0
            return f * f * f * (1.0 - t) + 1.0
        case .quarticInOut:
            if t < 0.5 {
                return 8.0 * t * t * t * t
            } else {
                let f = t - 1.0
                return -8.0 * f * f * f * f + 1.0
            }

        case .quinticIn:
            return t * t * t * t * t
        case .quinticOut:
            let f = t - 1.0
            return f * f * f * f * f + 1.0
        case .quinticInOut:
            if t < 0.5 {
                return 16.0 * t * t * t * t * t
            } else {
                let f = 2.0 * t - 2.0
                return 0.5 * f * f * f * f * f + 1.0
            }

        case .sinusoidalIn:
            return 1.0 - cos(t * .pi * 0.5)
        case .sinusoidalOut:
            return sin(t * .pi * 0.5)
        case .sinusoidalInOut:
            return 0.5 * (1.0 - cos(.pi * t))

        case .exponentialIn:
            return t == 0.0 ? 0.0 : pow(2.0, 10.0 * (t - 1.0))
        case .exponentialOut:
            return t == 1.0 ? 1.0 : 1.0 - pow(2.0, -10.0 * t)
        case .exponentialInOut:
            if t == 0.0 { return 0.0 }
            if t == 1.0 { return 1.0 }
            if t < 0.5 {
                return 0.5 * pow(2.0, 20.0 * t - 10.0)
            } else {
                return 1.0 - 0.5 * pow(2.0, -20.0 * t + 10.0)
            }

        case .circularIn:
            return 1.0 - sqrt(max(0.0, 1.0 - t * t))
        case .circularOut:
            return sqrt(max(0.0, (2.0 - t) * t))
        case .circularInOut:
            if t < 0.5 {
                return 0.5 * (1.0 - sqrt(max(0.0, 1.0 - 4.0 * t * t)))
            } else {
                let f = 2.0 * t - 2.0
                return 0.5 * (sqrt(max(0.0, 1.0 - f * f)) + 1.0)
            }

        case .elasticIn:
            if t == 0.0 { return 0.0 }
            if t == 1.0 { return 1.0 }
            return -pow(2.0, 10.0 * (t - 1.0)) * sin((t - 1.1) * 5.0 * .pi)
        case .elasticOut:
            if t == 0.0 { return 0.0 }
            if t == 1.0 { return 1.0 }
            return pow(2.0, -10.0 * t) * sin((t - 0.1) * 5.0 * .pi) + 1.0
        case .elasticInOut:
            if t == 0.0 { return 0.0 }
            if t == 1.0 { return 1.0 }
            let scaled = t * 2.0
            if scaled < 1.0 {
                return -0.5 * pow(2.0, 10.0 * (scaled - 1.0)) * sin((scaled - 1.1) * 5.0 * .pi)
            } else {
                return 0.5 * pow(2.0, -10.0 * (scaled - 1.0)) * sin((scaled - 1.1) * 5.0 * .pi) + 1.0
            }

        case .backIn:
            // Robert Penner back overshoot formula: f(t) = t^2 * ((s + 1)t - s)
            // Constant s = 1.70158 produces a ~10% backward anticipation pullback.
            let s = 1.70158
            return t * t * ((s + 1.0) * t - s)

        case .backOut:
            // Robert Penner back overshoot formula: f(t) = (t - 1)^2 * ((s + 1)(t - 1) + s) + 1
            // Constant s = 1.70158 produces a ~10% forward overshoot past target.
            let s = 1.70158
            let f = t - 1.0
            return f * f * ((s + 1.0) * f + s) + 1.0

        case .backInOut:
            // Bilaterally scaled back overshoot: s * 1.525 ≈ 2.59238875 balances
            // ease-in anticipation with ease-out settling.
            let s = 1.70158 * 1.525
            let scaled = t * 2.0
            if scaled < 1.0 {
                return 0.5 * (scaled * scaled * ((s + 1.0) * scaled - s))
            } else {
                let f = scaled - 2.0
                return 0.5 * (f * f * ((s + 1.0) * f + s) + 2.0)
            }

        case .bounceIn:
            return 1.0 - bounceOut(1.0 - t)
        case .bounceOut:
            return bounceOut(t)
        case .bounceInOut:
            if t < 0.5 {
                return 0.5 * (1.0 - bounceOut(1.0 - 2.0 * t))
            } else {
                return 0.5 * bounceOut(2.0 * t - 1.0) + 0.5
            }
        }
    }

    /// Evaluates the Robert Penner bounce-out piecewise quadratic curve at time $t \in [0, 1]$.
    ///
    /// ### Mathematical Model & Algorithmic Derivation
    /// Models damped gravitational free-fall with an inelastic coefficient of restitution $e \approx 0.5$.
    /// The normalized time domain $[0, 1]$ is partitioned into 4 parabolic intervals using
    /// time divisor $d_1 = 2.75$ and acceleration factor $n_1 = 7.5625 = 121 / 16$:
    /// - Stage 1 ($t < 1 / d_1 \approx 0.3636$): Free-fall impact $n_1 \cdot t^2$
    /// - Stage 2 ($t < 2 / d_1 \approx 0.7273$): First bounce $n_1 \cdot (t - 1.5/d_1)^2 + 0.75$
    /// - Stage 3 ($t < 2.5 / d_1 \approx 0.9091$): Second bounce $n_1 \cdot (t - 2.25/d_1)^2 + 0.9375$
    /// - Stage 4 ($t \ge 2.5 / d_1$): Final micro-settle $n_1 \cdot (t - 2.625/d_1)^2 + 0.984375$
    ///
    /// - Parameter t: Normalized time parameter in $[0, 1]$.
    /// - Returns: The bounced progress value.
    /// - Complexity: $O(1)$ constant time.
    public static func bounceOut(_ t: Double) -> Double {
        let n1 = 7.5625
        let d1 = 2.75

        if t < 1.0 / d1 {
            return n1 * t * t
        } else if t < 2.0 / d1 {
            let p = t - 1.5 / d1
            return n1 * p * p + 0.75
        } else if t < 2.5 / d1 {
            let p = t - 2.25 / d1
            return n1 * p * p + 0.9375
        } else {
            let p = t - 2.625 / d1
            return n1 * p * p + 0.984375
        }
    }
}
