// ===----------------------------------------------------------------------===
//
// This source file is part of the MeridianCore open source project
//
// Copyright (c) 2026 Apple Inc. and the MeridianCore project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// ===----------------------------------------------------------------------===

import Foundation

/// Easing functions based on Robert Penner's equations.
public enum EasingType: String, Sendable, Hashable, Equatable, CaseIterable, Codable {
    case linear

    // Quadratic
    case quadraticIn
    case quadraticOut
    case quadraticInOut

    // Cubic
    case cubicIn
    case cubicOut
    case cubicInOut

    // Quartic
    case quarticIn
    case quarticOut
    case quarticInOut

    // Quintic
    case quinticIn
    case quinticOut
    case quinticInOut

    // Sinusoidal
    case sinusoidalIn
    case sinusoidalOut
    case sinusoidalInOut

    // Exponential
    case exponentialIn
    case exponentialOut
    case exponentialInOut

    // Circular
    case circularIn
    case circularOut
    case circularInOut

    // Elastic
    case elasticIn
    case elasticOut
    case elasticInOut

    // Back
    case backIn
    case backOut
    case backInOut

    // Bounce
    case bounceIn
    case bounceOut
    case bounceInOut

    /// Evaluates the easing function at normalized elapsed time $t \in [0, 1]$.
    ///
    /// - Parameter t: Normalized time parameter in $[0, 1]$.
    /// - Returns: Eased value, typically in $[0, 1]$ (except for elastic and back overshoots).
    /// - Complexity: $O(1)$ constant time.
    @inlinable
    public func evaluate(at t: Double) -> Double {
        Easing.evaluate(type: self, progress: t)
    }

    /// Resolves an easing type from a case-insensitive string, defaulting to `.cubicOut` (canonical default).
    ///
    /// - Parameter name: The name of the easing equation (e.g. `"easeInOutCubic"`, `"bounceOut"`).
    /// - Returns: The matched `EasingType`, or `.cubicOut` if unmatched or nil.
    /// - Complexity: $O(K)$ where $K = 31$ cases.
    public static func from(name: String?) -> EasingType {
        guard let n = name?.trimmingCharacters(in: .whitespacesAndNewlines), !n.isEmpty else {
            return .cubicOut
        }
        let lower = n.lowercased()
        for c in EasingType.allCases {
            if c.rawValue.lowercased() == lower {
                return c
            }
        }
        return .cubicOut
    }
}

/// Rich timing curve representation supporting parametric spring ODE dynamics and functional combinators.
public enum TimingCurve: Sendable, Equatable, Hashable {
    case linear
    case quadIn
    case quadOut
    case quadInOut
    case cubicIn
    case cubicOut
    case cubicInOut
    case exponential
    case backIn(overshoot: Double = AnimationConstants.defaultBackOvershoot)
    case backOut(overshoot: Double = AnimationConstants.defaultBackOvershoot)
    case backInOut(overshoot: Double = AnimationConstants.defaultBackOvershoot)
    case bounceIn
    case bounceOut
    case bounceInOut
    case elasticIn(amplitude: Double = AnimationConstants.defaultElasticAmplitude, period: Double = AnimationConstants.defaultElasticPeriod)
    case elasticOut(amplitude: Double = AnimationConstants.defaultElasticAmplitude, period: Double = AnimationConstants.defaultElasticPeriod)
    case elasticInOut(amplitude: Double = AnimationConstants.defaultElasticAmplitude, period: Double = AnimationConstants.defaultElasticInOutPeriod)
    case spring(
        mass: Double = AnimationConstants.defaultSpringMass,
        stiffness: Double = AnimationConstants.defaultSpringStiffness,
        damping: Double = AnimationConstants.defaultSpringDamping,
        initialVelocity: Double = AnimationConstants.defaultSpringInitialVelocity
    )

    /// Evaluates the timing curve or spring ODE at normalized elapsed time $t \in [0, 1]$.
    ///
    /// For `.spring`, this evaluates the exact closed-form analytical solution of the
    /// continuous Mass-Spring-Damper ODE:
    /// $$m \ddot{x} + c \dot{x} + k x = 0$$
    ///
    /// - Parameter t: Normalized time parameter $t \in [0, 1]$.
    /// - Returns: The evaluated animation progress factor.
    /// - Complexity: $O(1)$ constant time with zero numerical drift.
    public func evaluate(at t: Double) -> Double {
        let clampedT = max(0.0, min(1.0, t))
        switch self {
        case .linear:
            return clampedT

        case .quadIn:
            return clampedT * clampedT

        case .quadOut:
            return 1.0 - (1.0 - clampedT) * (1.0 - clampedT)

        case .quadInOut:
            if clampedT < 0.5 {
                return 2.0 * clampedT * clampedT
            } else {
                let p = -2.0 * clampedT + 2.0
                return 1.0 - (p * p) * 0.5
            }

        case .cubicIn:
            return clampedT * clampedT * clampedT

        case .cubicOut:
            let inv = 1.0 - clampedT
            return 1.0 - inv * inv * inv

        case .cubicInOut:
            if clampedT < 0.5 {
                return 4.0 * clampedT * clampedT * clampedT
            } else {
                let p = -2.0 * clampedT + 2.0
                return 1.0 - (p * p * p) * 0.5
            }

        case .exponential:
            if clampedT <= 0.0 { return 0.0 }
            if clampedT >= 1.0 { return 1.0 }
            return pow(2.0, 10.0 * (clampedT - 1.0))

        case .backIn(let s):
            return clampedT * clampedT * ((s + 1.0) * clampedT - s)

        case .backOut(let s):
            let inv = clampedT - 1.0
            return 1.0 + inv * inv * ((s + 1.0) * inv + s)

        case .backInOut(let s):
            let c2 = s * AnimationConstants.backInOutOvershootMultiplier
            if clampedT < 0.5 {
                let p = 2.0 * clampedT
                return (p * p * ((c2 + 1.0) * p - c2)) * 0.5
            } else {
                let p = 2.0 * clampedT - 2.0
                return (p * p * ((c2 + 1.0) * p + c2) + 2.0) * 0.5
            }

        case .bounceOut:
            return Easing.bounceOut(clampedT)

        case .bounceIn:
            return 1.0 - Easing.bounceOut(1.0 - clampedT)

        case .bounceInOut:
            if clampedT < 0.5 {
                return (1.0 - Easing.bounceOut(1.0 - 2.0 * clampedT)) * 0.5
            } else {
                return (1.0 + Easing.bounceOut(2.0 * clampedT - 1.0)) * 0.5
            }

        case .elasticIn(let a, let p):
            if clampedT <= 0.0 { return 0.0 }
            if clampedT >= 1.0 { return 1.0 }
            let period = (p == 0.0) ? AnimationConstants.defaultElasticPeriod : p
            let s: Double
            if a < 1.0 {
                s = period * 0.25
            } else {
                s = period / (2.0 * .pi) * asin(min(1.0, 1.0 / max(AnimationConstants.minimumSingularityGuard, a)))
            }
            let decay = pow(2.0, 10.0 * (clampedT - 1.0))
            return -a * decay * sin((clampedT - 1.0 - s) * (2.0 * .pi) / period)

        case .elasticOut(let a, let p):
            if clampedT <= 0.0 { return 0.0 }
            if clampedT >= 1.0 { return 1.0 }
            let period = (p == 0.0) ? AnimationConstants.defaultElasticPeriod : p
            let s: Double
            if a < 1.0 {
                s = period * 0.25
            } else {
                s = period / (2.0 * .pi) * asin(min(1.0, 1.0 / max(AnimationConstants.minimumSingularityGuard, a)))
            }
            let decay = pow(2.0, -10.0 * clampedT)
            return a * decay * sin((clampedT - s) * (2.0 * .pi) / period) + 1.0

        case .elasticInOut(let a, let p):
            if clampedT <= 0.0 { return 0.0 }
            if clampedT >= 1.0 { return 1.0 }
            let period = (p == 0.0) ? AnimationConstants.defaultElasticInOutPeriod : p
            let s: Double
            if a < 1.0 {
                s = period * 0.25
            } else {
                s = period / (2.0 * .pi) * asin(min(1.0, 1.0 / max(AnimationConstants.minimumSingularityGuard, a)))
            }
            if clampedT < 0.5 {
                let decay = pow(2.0, 10.0 * (2.0 * clampedT - 1.0))
                return -0.5 * (a * decay * sin((2.0 * clampedT - 1.0 - s) * (2.0 * .pi) / period))
            } else {
                let decay = pow(2.0, -10.0 * (2.0 * clampedT - 1.0))
                return 0.5 * (a * decay * sin((2.0 * clampedT - 1.0 - s) * (2.0 * .pi) / period)) + 1.0
            }

        case .spring(let m, let k, let c, let v0):
            return evaluateSpring(t: clampedT, mass: m, stiffness: k, damping: c, initialVelocity: v0)
        }
    }

    private func evaluateSpring(
        t: Double,
        mass: Double,
        stiffness: Double,
        damping: Double,
        initialVelocity: Double
    ) -> Double {
        let m = max(AnimationConstants.minimumSingularityGuard, mass)
        let k = max(AnimationConstants.minimumSingularityGuard, stiffness)
        let c = max(0.0, damping)

        let omega0 = sqrt(k / m)
        let zeta = c / (2.0 * sqrt(m * k))
        let eps = AnimationConstants.precisionEpsilon

        if zeta < 1.0 - eps {
            let omegaD = omega0 * sqrt(1.0 - zeta * zeta)
            let decay = exp(-zeta * omega0 * t)
            let coefficientB = (zeta * omega0 - initialVelocity) / max(eps, omegaD)
            return 1.0 - decay * (cos(omegaD * t) + coefficientB * sin(omegaD * t))
        } else if abs(zeta - 1.0) <= eps {
            let decay = exp(-omega0 * t)
            return 1.0 - decay * (1.0 + (omega0 - initialVelocity) * t)
        } else {
            let discriminant = sqrt(zeta * zeta - 1.0)
            let r1 = omega0 * (-zeta + discriminant)
            let r2 = omega0 * (-zeta - discriminant)
            let denom = r2 - r1
            if abs(denom) < eps {
                let decay = exp(-omega0 * t)
                return 1.0 - decay * (1.0 + (omega0 - initialVelocity) * t)
            }
            let c1 = (r2 - initialVelocity) / denom
            let c2 = (initialVelocity - r1) / denom
            return 1.0 - (c1 * exp(r1 * t) + c2 * exp(r2 * t))
        }
    }

    // MARK: - Combinators

    /// Reverses the timing curve: $f_{\text{rev}}(t) = 1 - f(1 - t)$.
    ///
    /// - Returns: A closure mapping normalized progress $t$ to its time-reversed value.
    /// - Complexity: $O(1)$ constant time.
    public func reversed() -> @Sendable (Double) -> Double {
        return { t in
            1.0 - self.evaluate(at: 1.0 - t)
        }
    }

    /// Reflects the timing curve symmetrically around $t = 0.5$.
    ///
    /// Creates a symmetric ping-pong curve where the first half scales $f(2t)$
    /// and the second half reverses back smoothly.
    ///
    /// - Returns: A closure evaluating the symmetrically reflected curve.
    /// - Complexity: $O(1)$ constant time.
    public func reflected() -> @Sendable (Double) -> Double {
        return { t in
            if t < 0.5 {
                return 0.5 * self.evaluate(at: 2.0 * t)
            } else {
                return 1.0 - 0.5 * self.evaluate(at: 2.0 - 2.0 * t)
            }
        }
    }

    /// Clamps output between custom bounds $[min, max]$.
    ///
    /// Prevents overshoot values from exceeding prescribed visual limits.
    ///
    /// - Parameters:
    ///   - min: Lower bounding limit (default `0.0`).
    ///   - max: Upper bounding limit (default `1.0`).
    /// - Returns: A closure evaluating the clamped curve.
    /// - Complexity: $O(1)$ constant time.
    public func clamped(min: Double = 0.0, max: Double = 1.0) -> @Sendable (Double) -> Double {
        return { t in
            Swift.min(max, Swift.max(min, self.evaluate(at: t)))
        }
    }
}
