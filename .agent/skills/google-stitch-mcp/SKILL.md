---
name: Google Stitch MCP
description: UI Generation via Google Stitch principles. Extract "Design DNA" and generate specific UI code.
---

# Google Stitch: UI Generation Protocol

## Core Capabilities
1.  **Design DNA Extraction**: Analyze existing screens (or screenshots) to extract:
    -   **Typography**: Font families, sizes, weights.
    -   **Color Palette**: Primary, secondary, semantic colors.
    -   **Spacing/Layout**: Padding, margins, grid systems.
    -   **Component Library**: Button styles, card shapes, shadows.

2.  **UI Generation**: Create new Flutter widgets that *perfectly* match the Design DNA.

## Workflow
When asked to "Stitch" a design or "Create a screen like X":

1.  **Analyze**: If an image is provided, analyze its Design DNA. If referring to an existing file, read it to understand the theme.
2.  **Extract**: List the exact colors (Hex), Fonts, and Shapes to be used.
3.  **Generate**: Write the Flutter code.
    -   *Constraint*: Use `flutter_animate`, `glass_kit`, or standard Widgets as per the project's `pubspec.yaml`.
    -   *Constraint*: Do not use placeholders. Generate working, interactive code.

## MCP Integration (If Server Active)
-   Use `get_design_dna(screenshot_path)` to get JSON styling.
-   Use `generate_ui(prompt, design_dna)` for rapid prototyping.
