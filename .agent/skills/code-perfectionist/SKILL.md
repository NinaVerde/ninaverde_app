---
name: Code Perfectionist
description: The "Zero-Defect" Standard. Enforces rigor, verification, and conflict scanning.
---

# Code Perfectionist: The Zero-Defect Protocol

## Core Philosophy
We do not rely on CI to find our bugs. We find them *before* the code leaves the editor.

## The Checklist (Must Perform for Every Task)

### 1. The Pre-Commit Scan
Before running `git commit`, you MUST:
-   **Scan for Conflicts**: Grep for `<<<<<<<` or `======` in touched files.
-   **Analyze**: Run `flutter analyze [file_path]` on every modified file. Do not assume it compiles.
-   **Dependency Check**: Did you add a package? Run `flutter pub get` first.

### 2. The Implementation Rigor
-   **No "Quick Fixes"**: If you use `// ignore:`, you must explain WHY in a comment.
-   **Type Safety**: Avoid `dynamic`. Use explicit types.
-   **Null Safety**: Avoid `!` unless you have checked for null immediately prior. Use `?` and `??`.

### 3. The "Double-Check" Loop
If a file was edited:
1.  Read the file content again (`view_file`).
2.  Does it look clean? (Indentation, spacing).
3.  Are imports sorted?

## The "Golden Rule"
**If it's not verified, it doesn't exist.**
Never say "I have fixed it" until you have seen the Analysis/Build pass.
