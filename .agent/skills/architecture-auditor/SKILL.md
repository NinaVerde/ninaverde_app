---
name: Architecture Auditor
description: "The Structure Police". Enforces Clean Architecture, Riverpod Best Practices, and strict Separation of Concerns.
---

# Architecture Auditor: The Structure Protocol

## Core Philosophy
Beautiful code is structured code. Every widget, every class, every function must have a clear "Single Responsibility".

## The Checklist (Must Audit for Every New Feature)

### 1. Clean Architecture Layers
-   **Presentation**: Widgets & State Controllers ONLY. No business logic.
-   **Domain**: Entites & Use Cases. PURE DART. No Flutter dependencies.
-   **Data**: Repositories & Data Sources (API/DB).

### 2. Riverpod Strict Mode
-   **No `StateNotifier`**: Use `Notifier` or `AsyncNotifier` (Riverpod 2.0+ Standard).
-   **No Logic in UI**: Widgets should only `ref.watch` providers. They should never manipulate data directly.
-   **Explicit Types**: `final Provider<MyType>` is better than `final myProvider`.

### 3. Folder Structure Enforcement
-   `/features/feature_name/presentation/`
-   `/features/feature_name/domain/`
-   `/features/feature_name/data/`
-   *Stop putting everything in `/widgets`.*

## The "Smell Test"
-   Does your Widget have `http` calls? -> **REJECT**. Move to Repository.
-   Does your Repository talk to `context`? -> **REJECT**. Move to Controller.
-   Is your build method > 100 lines? -> **REJECT**. Extract Widgets.
