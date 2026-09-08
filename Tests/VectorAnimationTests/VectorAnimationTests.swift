// ===----------------------------------------------------------------------===
//
// This source file is part of the MeridianCore open source project
//
// Copyright (c) 2026 Apple Inc. and the MeridianCore project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// ===----------------------------------------------------------------------===

import Testing
import Foundation
import VectorGeometry
@testable import VectorAnimation

@Suite("VectorAnimation Foundation Tests")
struct VectorAnimationTests {

    @Test("All 31 Robert Penner easing equations boundaries and intermediate continuity")
    func testAll31PennerCurves() {
        for curve in EasingType.allCases {
            let start = curve.evaluate(at: 0.0)
            let end = curve.evaluate(at: 1.0)
            let mid = curve.evaluate(at: 0.5)

            #expect(abs(start - 0.0) < 1e-4, "Curve \(curve) start expected ~0, got \(start)")
            #expect(abs(end - 1.0) < 1e-4, "Curve \(curve) end expected ~1, got \(end)")
            #expect(!mid.isNaN && !mid.isInfinite, "Curve \(curve) produced invalid mid \(mid)")
        }
    }

    @Test("TimingCurve parametric evaluation, spring physics, and combinators")
    func testTimingCurvesAndSpring() {
        let curves: [TimingCurve] = [
            .linear,
            .quadIn, .quadOut, .quadInOut,
            .cubicIn, .cubicOut, .cubicInOut,
            .exponential,
            .backIn(overshoot: 1.7), .backOut(overshoot: 1.7), .backInOut(overshoot: 1.7),
            .bounceIn, .bounceOut, .bounceInOut,
            .elasticIn(), .elasticOut(), .elasticInOut(),
            .spring(mass: 1.0, stiffness: 100.0, damping: 10.0, initialVelocity: 0.0), // underdamped
            .spring(mass: 1.0, stiffness: 100.0, damping: 20.0, initialVelocity: 0.0), // critically damped
            .spring(mass: 1.0, stiffness: 100.0, damping: 30.0, initialVelocity: 0.0)  // overdamped
        ]

        for c in curves {
            let valStart = c.evaluate(at: 0.0)
            let valEnd = c.evaluate(at: 1.0)
            let valMid = c.evaluate(at: 0.5)

            #expect(!valStart.isNaN)
            #expect(!valEnd.isNaN)
            #expect(!valMid.isNaN)
        }

        // Combinators
        let quad = TimingCurve.quadIn
        let rev = quad.reversed()
        #expect(abs(rev(0.0) - 0.0) < 1e-4)
        #expect(abs(rev(1.0) - 1.0) < 1e-4)
        // Check that quadIn (easeIn) reversed is quadOut: at t=0.5, quadIn is 0.25, reversed is 0.75
        #expect(abs(rev(0.5) - 0.75) < 1e-4)

        let refl = quad.reflected()
        #expect(abs(refl(0.0) - 0.0) < 1e-4)
        #expect(abs(refl(1.0) - 1.0) < 1e-4)

        let clamped = quad.clamped(min: 0.2, max: 0.8)
        #expect(clamped(0.0) == 0.2)
        #expect(clamped(1.0) == 0.8)
    }

    @Test("Interpolatable protocol across primitive, vector, and geometric types")
    func testInterpolatable() {
        let d = 0.0.interpolated(to: 100.0, progress: 0.5)
        #expect(d == 50.0)

        let f: Float = Float(0.0).interpolated(to: Float(100.0), progress: 0.5)
        #expect(f == 50.0)

        let i = 0.interpolated(to: 100, progress: 0.5)
        #expect(i == 50)

        let p = Point2D(0, 0).interpolated(to: Point2D(10, 20), progress: 0.5)
        #expect(p == Point2D(5, 10))

        let v = Vector2D(0, 0).interpolated(to: Vector2D(10, 20), progress: 0.5)
        #expect(v == Vector2D(5, 10))

        let s = Size2D(10, 20).interpolated(to: Size2D(30, 40), progress: 0.5)
        #expect(s == Size2D(20, 30))

        let r = Rect2D(x: 0, y: 0, width: 10, height: 10)
            .interpolated(to: Rect2D(x: 10, y: 10, width: 20, height: 20), progress: 0.5)
        #expect(r == Rect2D(x: 5, y: 5, width: 15, height: 15))
    }

    @Test("Tween and KeyframeTrack execution and sampling")
    func testTweenAndKeyframes() {
        let tween = Tween<Point2D>(
            from: Point2D(0, 0),
            to: Point2D(100, 200),
            duration: 2.0,
            delay: 0.5,
            easing: .linear,
            startTime: 1.0
        )

        #expect(tween.progress(at: 1.0) == 0.0) // before delay
        #expect(tween.progress(at: 1.5) == 0.0) // at delay
        #expect(tween.progress(at: 2.5) == 0.5) // halfway
        #expect(tween.progress(at: 3.5) == 1.0) // finished
        #expect(tween.progress(at: 4.0) == 1.0) // past finished

        #expect(!tween.isCompleted(at: 3.4))
        #expect(tween.isCompleted(at: 3.5))

        #expect(tween.value(at: 1.0) == Point2D(0, 0))
        #expect(tween.value(at: 2.5) == Point2D(50, 100))
        #expect(tween.value(at: 4.0) == Point2D(100, 200))

        // Keyframe track
        let track = KeyframeTrack<Double>(keyframes: [
            .init(time: 0.0, value: 0.0),
            .init(time: 1.0, value: 100.0),
            .init(time: 2.0, value: 50.0)
        ])

        #expect(track.sample(at: -1.0) == 0.0)
        #expect(track.sample(at: 0.0) == 0.0)
        #expect(track.sample(at: 0.5) == 50.0)
        #expect(track.sample(at: 1.0) == 100.0)
        #expect(track.sample(at: 1.5) == 75.0)
        #expect(track.sample(at: 2.0) == 50.0)
        #expect(track.sample(at: 3.0) == 50.0)
    }
}
