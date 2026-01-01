# fix-splash-swooshes-safe.ps1
# Safe surgical patch for splash_to_login.dart

$target = "lib\screens\splash_to_login.dart"
$backupDir = "backup"
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

if (-not (Test-Path $target)) {
    Write-Host "ERROR: $target not found"
    exit 1
}

# Create backup
if (-not (Test-Path $backupDir)) {
    New-Item -ItemType Directory -Path $backupDir | Out-Null
}
Copy-Item $target "$backupDir\splash_to_login_$timestamp.dart" -Force
Write-Host "Backup saved at $backupDir\splash_to_login_$timestamp.dart"

$content = Get-Content -Raw -Encoding UTF8 $target

# 1) Remove existing _playWhoosh definition (catch/unawaited junk)
$content = $content -replace '(?s)Future<void>\s*_playWhoosh\(.+?\{.+?\}', ''

# 2) Insert new field declaration (if missing)
if ($content -notmatch 'AudioPlayer\?\s*_sfxPlayer;') {
    $content = $content -replace '(Timer\?\s*_videoWatchdog;\s*)', '$1
    AudioPlayer? _sfxPlayer;
'
}

# 3) In initState(), after controllers setup but before _runSequence, insert pre-warm code
$patternInit = '(?s)(_finalReveal\s*=\s*AnimationController.*?;\s*)(\s*_runSequence\(\);)'
$replacementInit = '$1
    _sfxPlayer = AudioPlayer()
      ..setReleaseMode(ReleaseMode.stop)
      ..setPlayerMode(PlayerMode.lowLatency);
$2'
$content = [regex]::Replace($content, $patternInit, $replacementInit)

# 4) Insert clean _playWhoosh definition after class start or near top
$insertPlay = @'
  Future<void> _playWhoosh([double volume = 1.0]) async {
    try {
      await _sfxPlayer?.stop();
      await _sfxPlayer?.play(
        AssetSource('audio/648538__audiopapkin__cinematic-woosh-sfx-001.wav'),
        volume: volume.clamp(0.0, 1.0),
      );
    } catch (_) {}
  }
'@
# Insert it just after first method or after initState signature
$content = $content -replace '(class _SplashToLoginScreenState.*?\{)', "`$1`r`n$insertPlay"

# 5) Add swoosh triggers before each flash phase if missing

# flash0
$patternFlash0 = 'setState\(\(\)\s*=>\s*_phase\s*=\s*_Phase\.flash0\);'
$replFlash0 = 'await _playWhoosh(1.0);
    setState(() => _phase = _Phase.flash0);'
$content = [regex]::Replace($content, $patternFlash0, $replFlash0)

# flash1
$patternFlash1 = 'setState\(\(\)\s*=>\s*_phase\s*=\s*_Phase\.flash1\);'
$replFlash1 = 'await _playWhoosh(1.0);
    setState(() => _phase = _Phase.flash1);'
$content = [regex]::Replace($content, $patternFlash1, $replFlash1)

# flash2
$patternFlash2 = 'setState\(\(\)\s*=>\s*_phase\s*=\s*_Phase\.flash2\);'
$replFlash2 = 'await _playWhoosh(1.0);
    setState(() => _phase = _Phase.flash2);'
$content = [regex]::Replace($content, $patternFlash2, $replFlash2)

# 6) Update final reveal to delay then swoosh, if not already
$patternFinal = 'await\s*_finalReveal\.forward\(\);\s*_finalReveal\.reset\(\);\s*_goToLogin\(\);'
$replFinal = @"
await _finalReveal.forward();
    await Future.delayed(const Duration(milliseconds: 250));
    await _playWhoosh(1.0);
    _finalReveal.reset();
    _goToLogin();
"@
$content = [regex]::Replace($content, $patternFinal, $replFinal)

# 7) Dispose _sfxPlayer in dispose()
$patternDispose = '(_video\.dispose\(\);\s*\r?\n\s*)super\.dispose\(\);'
$replDispose = '$1    _sfxPlayer?.dispose();
    super.dispose();'
$content = [regex]::Replace($content, $patternDispose, $replDispose)

# Write back
Set-Content -Path $target -Value $content -Encoding UTF8
Write-Host "Patch applied to $target"
