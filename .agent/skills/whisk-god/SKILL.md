---
name: Whisk God
description: The "Visual Alchemy" protocol. Generating consistent, sentient assets using Google Whisk (Subject + Scene + Style).
---

# The Whisk God Protocol

> [!IMPORTANT]
> **"Consistency is Sentience."**
> A character that changes their face every frame is a glitch. A character that keeps their face but changes their outfit/location is a *Person*.

## 1. The Trinity (Input Strategy)
Google Whisk (ImageFX) relies on three specific inputs. Do not just "prompt" it. **Compose** it.

### A. The Subject (Angelina)
-   **Source**: `assets/images/angelina/angelina_master_face.png`
-   **Rule**: This input *never* changes. This locks her identity (Facial features, hair color).
-   **Prompt**: "A confident AI assistant with glowing teal accents."

### B. The Scene (The Context)
-   **Kitchen**: "A high-end modern kitchen, stainless steel, vibrant vegetables, soft morning light."
-   **Gaming**: "Neon-lit gamer room, purple and teal ambient light, futuristic headset."
-   **Lobby**: "Minimalist glass architecture, biophilic design, plants, bright and airy."

### C. The Style (The Vibe)
-   **Nina Verde Signature**: "Cinematic lighting, 8k resolution, Photorealistic with subtle 'Liquid Glass' aesthetic, slight chromatic aberration, depth of field."

## 2. The Generation Loop
1.  **Upload** the Seed Image (Subject).
2.  **Input** the Scene Description.
3.  **Apply** the Style Modifier.
4.  **Generate** 4 variants.
5.  **Refine**: If the face distorts, increase the "Image Weight" of the Subject.

## 3. Post-Processing (The Polish)
Raw AI generation is not enough.
1.  **Upscale**: Use an AI upscaler to 4x resolution.
2.  **Remove Background** (if needed for UI overlay): Use `rembg` or similar.
3.  **Motion (The Breath)**:
    -   See `flutter_animate`.
    -   If the asset is a background, apply a slow "Scale" (Zoom) effect.
    -   If the asset is a character, use a "Shimmer" or "Pulse" effect on the container.

## 4. Asset Integration
-   Save to `assets/images/generated/[context]/[name].webp`.
-   **WebP** format is mandatory (Performance).
-   Register in `pubspec.yaml`.
