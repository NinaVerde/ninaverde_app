param(
  [Parameter(Mandatory=$true)]
  [string]$Message,

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
if (-not (Test-Path ".git")) { throw "Not a git repo: $RepoPath" }

Write-Host "`n=== Commit2Vibe ==="
Run "git status -sb"

Run "git add -A"

$staged = (git diff --cached --name-only)
if (-not $staged) {
  Write-Host "`nINFO: Nothing to commit."
  exit 0
}

Run "git commit -m `"$Message`""
Run "git push"

Write-Host "`nOK: Commit2Vibe complete."
Run "git status -sb"