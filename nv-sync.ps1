param(
  [string]$Message = "Auto-sync",
  [string]$Branch = ""
)

$ErrorActionPreference = "Stop"

function Log($text) {
  $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
  $line = "[$ts] $text"
  Write-Output $line
  Add-Content -Path "$PSScriptRoot\.nv-sync\nv-sync.log" -Value $line
}

try {
  Set-Location -LiteralPath $PSScriptRoot
  Log "=== nv-sync start: $Message ==="
  Log "Repo: $PSScriptRoot"

  if (-not (Test-Path ".git")) {
    Log "ERROR: This folder is not a git repo (no .git)."
    exit 2
  }

  # Ensure git is available
  $git = (Get-Command git -ErrorAction Stop).Source
  Log "git: $git"

  # Quick status
  $status = git status --porcelain
  if ($status) {
    Log "Changes detected. Staging..."
    git add -A

    # If after add there's still nothing, skip commit (rare)
    $status2 = git status --porcelain
    if (-not $status2) {
      Log "No staged changes after add. Skipping commit."
    } else {
      $stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
      $msg = "$Message ($stamp)"
      Log "Committing: $msg"
      git commit -m $msg
    }
  } else {
    Log "No local changes detected."
  }

  # Determine branch
  if ($Branch -and $Branch.Trim().Length -gt 0) {
    $useBranch = $Branch.Trim()
  } else {
    $useBranch = (git rev-parse --abbrev-ref HEAD).Trim()
  }
  Log "Branch: $useBranch"

  # Pull (rebase) first to avoid diverging histories when other tools push
  Log "Pulling (rebase) from origin/$useBranch..."
  git pull --rebase origin $useBranch

  # Push
  Log "Pushing to origin/$useBranch..."
  git push origin $useBranch

  Log "SUCCESS: nv-sync completed."
  exit 0
}
catch {
  Log ("FAILED: " + $_.Exception.Message)
  Log "Tip: open .nv-sync\nv-sync.log for details."
  exit 1
}
