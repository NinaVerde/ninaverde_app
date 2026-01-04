param(
  [string]$Message = "Auto-sync: hourly",
  [string]$RepoPath = "C:\Users\Matt\Desktop\Nina Verde\ninaverde_app"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Run($cmd) {
  iex $cmd
  if ($LASTEXITCODE -ne 0) { throw "Command failed: $cmd" }
}

Set-Location -LiteralPath $RepoPath
if (-not (Test-Path ".git")) { exit 0 }

$dirty = (git status --porcelain)
if ($dirty) { exit 0 }

Run "git fetch --prune"
Run "git pull --rebase"
Run "git push"