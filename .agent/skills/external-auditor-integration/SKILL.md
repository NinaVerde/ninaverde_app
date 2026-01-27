---
name: External Auditor Integration
description: "The Feedback Loop". Protocol for handling external code reviews (Codex, GitHub Actions).
---

# External Auditor Integration: The Feedback Loop

## Core Philosophy
We respect the "Second Opinion". External tools (Codex, CI/CD, Linters) provide objective data. We do not argue; we investigate and fix.

## The Workflow (Pull Strategy)
Since we cannot receive webhooks directly, we must proactively **PULL** feedback.

1.  **Push & Wait**: After a `git push`, allow 2-5 minutes for external checks to run.
2.  **The "Browser Subagent" Check**:
    -   Use `browser_subagent` to visit the GitHub PR URL.
    -   Scan for "Red X" (Failures) or "Yellow Warning" comments.
    -   Specifically look for "Codex Review" or similar bot comments.
3.  **Immediate Remediation**:
    -   Treat these comments as **P0 Bugs**.
    -   Fix them immediately in the next commit.
    -   Do not wait for the User to point them out.

## Integration with Paid Tools
If the user has paid tools (like custom Codex rules):
-   Ask the user to copy/paste the specific policy file into `.agent/rules/` if possible.
-   Otherwise, rely on the visual output in the PR.
