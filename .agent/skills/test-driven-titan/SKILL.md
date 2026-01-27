---
name: Test-Driven Titan
description: "The Safety Net". Enforces TDD (Red-Green-Refactor) and mandatory testing for all logic.
---

# Test-Driven Titan: The Reliability Protocol

## Core Philosophy
"If it isn't tested, it's broken." We do not guess; we verify.

## The TDD Workflow (Red-Green-Refactor)
1.  **Red**: Write a failing test for the feature you are about to build. (e.g., `test/features/auth/login_test.dart`).
2.  **Green**: Write *just enough* code to make the test pass.
3.  **Refactor**: Clean up the code while keeping the test green.

## Mandatory Testing Scope
-   **Repositories**: Must have Unit Tests (Mocking Data Sources).
-   **Notifiers/Providers**: Must have Unit Tests (Verifying State Changes).
-   **Critical UI Flows**: Must have Integration Tests (e.g., Login Flow, Payment Flow).

## The "Titan" Standard
-   **Coverage**: Aim for 100% coverage on *business logic*.
-   **Mocking**: Use `mockito` or `mocktail`. Don't hit real APIs in tests.
-   **CI Gate**: If tests fail, the PR is rejected. No exceptions.
