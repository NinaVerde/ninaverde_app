# Auto Backup Script for Nina Verde App
# Runs 3x daily via Task Scheduler

$SourcePath = "C:\Users\adsta\Desktop\Nina Verde\ninaverde_app"
$DestRoot = "C:\Users\adsta\OneDrive\Documents\Nina Verde\backups"
$DateStamp = Get-Date -Format "yyyy-MM-dd_HHmm"
$ZipName = "NinaVerde_Backup_$DateStamp.zip"
$ZipPath = Join-Path $DestRoot $ZipName

# Ensure destination exists
if (-not (Test-Path $DestRoot)) {
    New-Item -ItemType Directory -Path $DestRoot | Out-Null
}

# Define folders to exclude
$Exclusions = @(
    "build",
    ".dart_tool",
    ".pub-cache",
    ".git",
    ".idea",
    ".gradle",
    "Pods"
)

Write-Host "Starting backup of $SourcePath to $ZipPath..."

# Create a temporary list of files to zip
# We use Compress-Archive but it handles exclusions poorly on entire folders,
# so we'll use a slightly more manual approach or a temporary staging folder if needed.
# For simplicity and reliability in PowerShell 5+, we'll use a temporary folder approach.

$TempFolder = Join-Path $Env:TEMP "NinaVerde_Staging_$DateStamp"
New-Item -ItemType Directory -Path $TempFolder | Out-Null

try {
    # Copy files excluding the ignored folders
    # We use robocopy for speed and exclusion handling, but it's external.
    # Let's use Get-ChildItem with explicit exclusions for pure PowerShell.
    
    Get-ChildItem -Path $SourcePath -Recurse | Where-Object {
        $shouldSkip = $false
        foreach ($exclude in $Exclusions) {
            # Check if file path contains the exclusion folder name enclosed in slashes 
            # or creates a path starting with the exclusion
            if ($_.FullName -match "\\$exclude\\?" -or $_.FullName -match "\\$exclude$") {
                $shouldSkip = $true
                break
            }
        }
        return -not $shouldSkip
    } | ForEach-Object {
        $relativePath = $_.FullName.Substring($SourcePath.Length)
        if ($relativePath.StartsWith("\")) { $relativePath = $relativePath.Substring(1) }
        $targetFile = Join-Path $TempFolder $relativePath
        
        # Preserve directory structure
        if ($_.PSIsContainer) {
            if (-not (Test-Path $targetFile)) {
                New-Item -ItemType Directory -Path $targetFile | Out-Null
            }
        } else {
            $parentDir = Split-Path $targetFile
            if (-not (Test-Path $parentDir)) {
                New-Item -ItemType Directory -Path $parentDir | Out-Null
            }
            Copy-Item -LiteralPath $_.FullName -Destination $targetFile
        }
    }

    # Zip the staged folder
    Compress-Archive -Path "$TempFolder\*" -DestinationPath $ZipPath -CompressionLevel Optimal
    Write-Host "Backup created successfully."

} catch {
    Write-Error "Backup failed: $_"
} finally {
    # Cleanup temp
    Remove-Item -Path $TempFolder -Recurse -Force -ErrorAction SilentlyContinue
}

# Retention Policy: Delete files older than 7 days
Write-Host "Cleaning up old backups..."
$LimitDate = (Get-Date).AddDays(-7)
Get-ChildItem -Path $DestRoot -Filter "NinaVerde_Backup_*.zip" | Where-Object { $_.LastWriteTime -lt $LimitDate } | ForEach-Object {
    Write-Host "Deleting old backup: $($_.Name)"
    Remove-Item $_.FullName -Force
}

Write-Host "Backup process complete."
