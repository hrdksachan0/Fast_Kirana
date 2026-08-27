---
name: canvasui
description: >-
  Canvas UI design system, WebGL/Canvas shaders, Flutter CustomPainter components,
  liquid glass surfaces, particle animations, and high-performance interactive UI modules.
---

# Canvas UI Plugin & Design System

## Overview
Canvas UI provides high-performance, canvas-driven UI components, custom painters, and GPU-accelerated motion surfaces across Flutter Mobile and Web applications.

## Core Capabilities

### 1. Flutter CustomPainter & Canvas Optimization
- **Hardware Acceleration**: Utilize `CustomPainter` with `shouldRepaint` optimization to render zero-jank 60/120fps UI components.
- **Glassmorphism & Frosted Glass**: Seamless backdrop filters and translucent borders using custom paths and radial shader masks.
- **Dynamic Wave & Liquid Badges**: Fluid, spring-physics-driven loaders, pulsing tags, and progress indicators.
- **Particle & Glow Effects**: Subtle celebratory particle bursts for add-to-cart, delivery unlock, and success states.

### 2. High-Performance Mobile UI Guidelines
- Avoid heavy re-renders by wrapping canvas animations in `RepaintBoundary`.
- Utilize pre-computed paths (`Path.combine`) and linear shader gradients for badge surfaces.
- Support responsive bounds and vector-scale math across all phone aspect ratios.

### 3. Usage Patterns
- **Product Image Overlays**: Shimmering discount badges, live stock countdowns, and gradient glow outlines.
- **Cart & Stepper Controls**: Elastic scale transitions and haptic-responsive touch ripples.
- **Route & Tracker Cards**: Custom canvas drawing of live delivery paths and pulse animations.
