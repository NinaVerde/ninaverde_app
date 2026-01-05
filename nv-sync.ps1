param(
  [string]$Message = "Auto-sync: hourly",
  [string]$RepoPath = "C:\Users\Matt\Desktop\Nina Verde\ninaverde_app"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Run([string]$cmd) {
  iex $cmd
  if ($LASTEXITCODE -ne 0) { throw "Command failed: $cmd" }
}

Set-Location -LiteralPath $RepoPath
if (-not (Test-Path ".git")) { exit 0 }

# Never auto-commit. If working tree is dirty, skip.
$dirty = (git status --porcelain)
if ($dirty) { exit 0 }

# Keep repo in sync (safe)
Run "git fetch --prune"
Run "git pull --rebase"
Run "git push"

# OPTIONAL: If you want the hourly job to also keep deps consistent, enable this block.
# This will ONLY run when the tree is clean and it will NOT commit anything.
# It may change pubspec.lock; if it does, the next run will skip until YOU commit.
#
# Uncomment if you want it:
#
# if (Test-Path ".fvmrc") {
#   try {
#     Run "fvm flutter --version"
#     Run "fvm flutter pub get"
#   } catch {
#     # If FVM or Flutter isn't available in PATH for the scheduler context, ignore.
#   }
# }
