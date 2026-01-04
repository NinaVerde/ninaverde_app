param(
  [string]$RepoPath = "C:\Users\Matt\Desktop\Nina Verde\ninaverde_app"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Run($cmd) {
  Write-Host "> $cmd"
  iex $cmd
  if ($LASTEXITCODE -ne 0) { throw "Command failed: $cmd" }
}

Set-Location -LiteralPath $RepoPath

if (-not (Test-Path ".git")) {
  throw "Not a git repo: $RepoPath"
}

Write-Host "`n=== Prep2Vibe ==="
Run "git rev-parse --show-toplevel"
Run "git status -sb"

Run "git fetch --prune"

$dirty = (git status --porcelain)
if ($dirty) {
  Write-Host "`nWARNING: Working tree has uncommitted changes. I will NOT pull/rebase automatically."
  Write-Host "Options:"
  Write-Host " - Commit changes:   .\Commit2Vibe.ps1 -Message '...'"
  Write-Host " - Stash changes:    git stash push -u -m 'wip'"
  Write-Host " - Discard changes:  git restore ."
  exit 0
}

Run "git pull --rebase"

Write-Host "`nOK: Prep2Vibe complete."
Run "git status -sb"