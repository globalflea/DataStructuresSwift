// ===----------------------------------------------------------------------===
//
// This source file is part of the MeridianCore open source project
//
// Copyright (c) 2026 Apple Inc. and the MeridianCore project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// ===----------------------------------------------------------------------===

import Foundation

/// Centralized mathematical, physical, and algorithmic constants for `VectorAnimation`.
///
/// Consolidates all domain-specific constants to prevent duplicate magic numbers across
/// easing equations, spring ODE numerical solvers, and keyframe interpolators.
public enum AnimationConstants: Sendable {

    // MARK: - Robert Penner Back Curves

    /// Canonical Robert Penner overshoot constant $s \approx 1.70158$ producing a ~10% overshoot.
    public static let defaultBackOvershoot: Double = 1.70158

    /// Scaling multiplier applied to overshoot constant $s$ for `.backInOut` curves ($1.525$).
    public static let backInOutOvershootMultiplier: Double = 1.525

    /// Precomputed composite overshoot coefficient for `.backInOut` ($1.70158 \times 1.525 \approx 2.59238875$).
    public static let compositeBackInOutOvershoot: Double = defaultBackOvershoot * backInOutOvershootMultiplier

    // MARK: - Robert Penner Bounce Curves

    /// Gravitational acceleration multiplier for piecewise quadratic bounce equations ($7.5625$).
    public static let bounceQuadraticFactor: Double = 7.5625

    /// Canonical time partition divisor for the Robert Penner bounce curve stages ($2.75$).
    public static let bounceTimeDivisor: Double = 2.75

    /// Bounce stage 1 threshold numerator: $1.0 / 2.75$.
    public static let bounceStage1Numerator: Double = 1.0

    /// Bounce stage 2 threshold numerator: $2.0 / 2.75$.
    public static let bounceStage2Numerator: Double = 2.0

    /// Bounce stage 3 threshold numerator: $2.5 / 2.75$.
    public static let bounceStage3Numerator: Double = 2.5

    /// Bounce stage 2 time shift numerator: $1.5 / 2.75$.
    public static let bounceShiftStage2Numerator: Double = 1.5

    /// Bounce stage 3 time shift numerator: $2.25 / 2.75$.
    public static let bounceShiftStage3Numerator: Double = 2.25

    /// Bounce stage 4 time shift numerator: $2.625 / 2.75$.
    public static let bounceShiftStage4Numerator: Double = 2.625

    /// Bounce stage 2 vertical baseline offset ($0.75$).
    public static let bounceOffsetStage2: Double = 0.75

    /// Bounce stage 3 vertical baseline offset ($0.9375$).
    public static let bounceOffsetStage3: Double = 0.9375

    /// Bounce stage 4 vertical baseline offset ($0.984375$).
    public static let bounceOffsetStage4: Double = 0.984375

    // MARK: - Elastic Dynamics

    /// Default baseline amplitude for damped sinusoidal elastic curves ($1.0$).
    public static let defaultElasticAmplitude: Double = 1.0

    /// Default oscillation period for unilateral elastic curves (`elasticIn`, `elasticOut`) ($0.3$).
    public static let defaultElasticPeriod: Double = 0.3

    /// Default oscillation period for bilateral elastic curves (`elasticInOut`) ($0.45$).
    public static let defaultElasticInOutPeriod: Double = 0.45

    // MARK: - Spring Physics Defaults

    /// Default particle mass in kilograms ($1.0$).
    public static let defaultSpringMass: Double = 1.0

    /// Default spring stiffness $k$ in Newtons per meter ($100.0$).
    public static let defaultSpringStiffness: Double = 100.0

    /// Default viscous damping coefficient $c$ in Newton-seconds per meter ($10.0$).
    public static let defaultSpringDamping: Double = 10.0

    /// Default initial velocity in units per second ($0.0$).
    public static let defaultSpringInitialVelocity: Double = 0.0

    // MARK: - Numerical Tolerances & Thresholds

    /// Precision epsilon threshold for singularity avoidance and critical damping root checks ($10^{-5}$).
    public static let precisionEpsilon: Double = 1e-5

    /// Minimum mass or stiffness clamp to avoid divide-by-zero singularities ($10^{-4}$).
    public static let minimumSingularityGuard: Double = 1e-4

    /// Threshold for keyframe duration validity check ($10^{-9}$).
    public static let keyframeDurationEpsilon: Double = 1e-9
}
