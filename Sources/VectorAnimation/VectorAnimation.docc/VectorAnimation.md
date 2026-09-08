# ``VectorAnimation``

Parametric curves, analytical Mass-Spring-Damper ODE dynamics, 31 Robert Penner easing equations, and keyframe interpolation pipelines.

## Overview

`VectorAnimation` provides physics-accurate kinematics and smooth temporal easing for high-performance vector graphics, motion design, and data visualization.

Rather than relying on frame-rate dependent discrete Euler integration, `VectorAnimation` evaluates continuous closed-form analytical solutions to the second-order Mass-Spring-Damper Ordinary Differential Equation (ODE), enabling $O(1)$ random-access time sampling without energy drift.

### Core Capabilities

- **Analytical Mass-Spring-Damper ODE**: Exact closed-form solutions for underdamped ($\zeta < 1$), critically damped ($\zeta = 1$), and overdamped ($\zeta > 1$) harmonic oscillator regimes.
- **31 Penner Easing Curves**: Complete mathematical suite of polynomial, sinusoidal, exponential, circular, elastic, back, and bounce curves.
- **Parametric Unit Bézier Timing**: Fast Newton-Raphson parameter inversion with interval bisection fallback for CSS timing functions.
- **Functional Combinators**: Reversal (`reversed()`), symmetric ping-pong reflection (`reflected()`), and range clamping (`clamped()`).
- **Type-Safe Interpolation (`Interpolatable`)**: First-class support for scalars, coordinates (`Point2D`), vectors (`Vector2D`), rectangles (`Rect2D`), and matrices (`Transform2D`).
- **Multi-Segment Keyframes**: Segment localization via binary search and progression easing.

## Topics

### Easing & Timing Dynamics
- ``Easing``
- ``EasingType``
- ``TimingCurve``
- ``AnimationConstants``

### Interpolation & Protocols
- ``Interpolatable``

### Animation & Keyframe Pipelines
- ``Tween``
- ``Keyframe``
- ``KeyframeTrack``
- ``AnimationStagger``

## See Also
- [03 Vector Animation & Spring Physics](file:///Users/globalflea/Xplore/MeridianCore/Docs/Design/03_VECTOR_ANIMATION_AND_SPRING_PHYSICS.md)
