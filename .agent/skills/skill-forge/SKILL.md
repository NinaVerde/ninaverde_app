---
name: Skill Forge
description: The "Antigravity" protocol for extracting and creating new skills from successful workflows.
---

# Skill Forge: The Self-Replicating Protocol

> [!IMPORTANT]
> **"Don't just solve it. Automate it."**
> When a complex task is completed successfully (and verified), use this skill to "crystallize" the workflow into a permanent Skill.

## 1. Candidate Identification
Trigger this skill when:
-   You have performed the same sequence of 3+ tool calls twice.
-   You resolved a complex error (e.g., "Merge Hell") using a specific strategy.
-   The USER explicitly says "Remember how we did this?" or "I want you to learn this."

## 2. The Extraction Process (Result: `SKILL.md`)
Create a new folder: `.agent/skills/[skill-name-kebab-case]/`
Create a file: `SKILL.md` with:

### YAML Frontmatter
```yaml
---
name: [Human Readable Name]
description: [Short, action-oriented summary]
---
```

### Body Structure
1.  **The Trigger**: When should this skill be used?
2.  **The Protocol**: Step-by-step instructions.
    -   Use imperative verbs ("Run...", "Check...", "Verify...").
    -   Include specific CLI commands or Tool parameters.
3.  **The Guardrails**:
    -   What could go wrong?
    -   Reference `excellence_protocol.md` (Security, 120FPS).
4.  **Verification**: How to know it worked.

## 3. Installation
1.  Save the file.
2.  Update `task.md` to track the "Learning" of this new skill.
3.  Notify the User: "I have forged a new skill: [Name]. I will now be faster/safer at [Task]."

## 4. Maintenance
-   If a Skill fails, **Update it**. Do not just retry. Patch the `SKILL.md`.
-   This is "Living Documentation".
