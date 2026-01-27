---
name: Flutter Performance Guru
description: "The Frame-Rate Guardian". Enforces 60/120 FPS standards. Jank prevention and optimization.
---

# Flutter Performance Guru: The 120FPS Protocol

## Core Philosophy
Jank is the enemy of immersion. If functionality works but "stutters", it is a failure.

## The Performance Checklist
1.  **Const Constructors**: Use `const` everywhere possible. It reduces GC pressure.
2.  **Build Method Hygiene**:
    -   NO logic in `build()`.
    -   NO `http` calls in `build()`.
    -   NO complex calculations in `build()`. Move them to `provider` or `initState`.
3.  **List Optmization**:
    -   Always use `ListView.builder` for long lists.
    -   Use `itemExtent` or `prototypeItem` if possible.
4.  **Image Handling**:
    -   Cache images (`cached_network_image`).
    -   Resize images on the server or use `ResizeImage` provider.
5.  **Repaint Boundary**: Wrap complex animations in `RepaintBoundary` to avoid repainting the whole screen.

## The "Profile Mode" Test
-   Don't trust "Debug Mode" performance.
-   Run `flutter run --profile` to see the truth.
-   If you see "UI Junk" frames, you must fix them.
