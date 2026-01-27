---
name: Production Guardrails
description: "Ironclad Reliability". Security (OWASP) and Stability (Constant Loop) protocols.
---

# Production Guardrails: Security & Stability

## 1. Security First (OWASP Top 10)
Before ANY code is committed:
-   **Injection**: Sanitize all SQL/NoSQL queries. Use parameterized inputs.
-   **Auth**: Never hardcode API keys or secrets. Use `flutter_dotenv` or secure storage.
-   **Data**: Encrypt sensitive data in strict local storage (`flutter_secure_storage`).
-   **Dependencies**: Check `pubspec.yaml` for known vulnerable packages.

## 2. The Stability Loop (Break -> Fix -> Verify)
We do not fear breaking things; we fear *not knowing* they are broken.
1.  **Break**: Stress test the new feature. (e.g., "What happens if I tap this button 50 times rapidly?", "What if the network drops midway?").
2.  **Fix**: Patch the edge cases immediately.
3.  **Verify**: Run the build. If it fails, **STOP**. Fix the build before moving on.

## 3. Definition of Done (DoD)
A task is *only* complete when:
-   [ ] Code compiles without errors (Red screen).
-   [ ] No new Lint warnings introduced.
-   [ ] Logic handles standard "Happy Path" AND "Error States" (Network fail, Empty data).
-   [ ] UI is responsive on the target device (Pixel/iPhone).
