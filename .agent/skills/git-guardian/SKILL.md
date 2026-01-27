---
name: Git Guardian
description: Enforces "No Loose Ends" backup policy. Secure commits and pushes.
---

# Git Guardian: The "No Loose Ends" Protocol

## The Backup Workflow
When the user says "backup", "save everything", or "push":

1.  **Status Check**: `git status` (Don't commit blindly).
2.  **Stage**: `git add .` (Stage diverse changes).
3.  **Commit**: Use "Conventional Commits":
    -   `feat:` New features (e.g., "Neuro-Aesthetic Menu").
    -   `fix:` Bug fixes (e.g., "Resolved Android Build").
    -   `chore:` Maintenance (e.g., "Updated dependencies").
    -   *Example*: `git commit -m "feat: Implemented Liquid Glass Menu"`
4.  **Push**: `git push origin [current-branch]`.
5.  **Verify**: Check for "remote rejected" or conflicts.

## Conflict Resolution
-   If conflicts occur, **STOP**.
    1.  Fetch `origin/develop` (or main).
    2.  Create a backup branch.
    3.  Propose a rebase strategy to the user.

## Golden Rule
**Never** leave work uncommitted at the end of a session. "No Loose Ends".
