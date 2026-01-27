---
name: CI Sentinel
description: En forces GitHub CI/CD compliance, specifically PR titles and Flutter checks.
---

# CI Sentinel Protocol

> [!IMPORTANT]
> This skill MUST be consulted before creating any Git commits or Pull Requests.

## 1. PR & Commit Title Standards
The repository uses `amannn/action-semantic-pull-request` to enforce **Conventional Commits**.

**Format**: `<type>: <subject>`

**Allowed Types**:
- `feat`: A new feature
- `fix`: A bug fix
- `chore`: Maintenance, dependency updates, build scripts
- `docs`: Documentation only changes
- `refactor`: A code change that neither fixes a bug nor adds a feature
- `test`: Adding missing tests or correcting existing tests
- `ci`: Changes to our CI configuration files and scripts

**Examples**:
- ✅ `feat: add user profile screen`
- ✅ `fix: resolve null pointer in auth`
- ✅ `chore: update flutter_local_notifications`
- ❌ `Added user profile` (Missing type)
- ❌ `update: readme` (Invalid type)

**Rules**:
- Subject must be lowercase (per convention, though regex `.+` is permissive).
- No period at the end.
- Use imperative mood ("add" not "added").

## 2. CI Checks (Mandatory Pass)
The `flutter.yml` workflow enforces strict quality gates. You MUST run these locally before pushing.

### 2.1 Static Analysis
- **Command**: `flutter analyze`
- **Standard**: Zero issues (infos/warnings count as failures if strict, currently standard analysis).
- **Fix**: Resolve ALL errors before commit.

### 2.2 Testing
- **Command**: `flutter test`
- **Standard**: All unit/widget tests must pass.

## 3. Pre-Push Checklist
Before pushing any branch, run this sequence:

```bash
# 1. Format code
dart format .

# 2. Analyze
flutter analyze

# 3. Test
flutter test
```

## 4. Troubleshooting CI
If CI fails:
1.  **Read the Logs**: Don't guess. Look at the specific error line (e.g., `missing_required_argument`).
2.  **Replicate Locally**: Use `flutter clean` if local results disagree with CI.
3.  **Check Dependency Versions**: CI installs fresh packages. Your local cache might be stale.
