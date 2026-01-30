# ================================================
# UV MANAGER INSTALLATION SCRIPT
# ================================================

param(
    [switch]$Force,
    [switch]$NoProfile,
    [string]$InstallDir = "$env:USERPROFILE\.uv-manager"
)

Write-Host "`n=========================================" -ForegroundColor Cyan
Write-Host "   UV ENVIRONMENT MANAGER SETUP" -ForegroundColor Cyan
Write-Host "=========================================`n" -ForegroundColor Cyan

# 1. Check UV
Write-Host "1. Checking UV installation..." -ForegroundColor Green
if (Get-Command "uv" -ErrorAction SilentlyContinue) {
    Write-Host "   UV found: $(uv --version)" -ForegroundColor Green
} else {
    Write-Host "   UV not found. Installing..." -ForegroundColor Yellow
    powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","User") + ";" + [System.Environment]::GetEnvironmentVariable("Path","Machine")
}

# 2. Setup Directory
if (-not (Test-Path $InstallDir)) {
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
}

# 3. Handle Scripts (Local First)
Write-Host "`n3. Installing scripts..." -ForegroundColor Green
$requiredScripts = @("uv-manager.ps1") # Removed uv-extras.ps1 as it doesn't exist

foreach ($scriptName in $requiredScripts) {
    $localPath = Join-Path $PSScriptRoot $scriptName
    $destPath = Join-Path $InstallDir $scriptName
    
    if (Test-Path $localPath) {
        Write-Host "   Copying local $scriptName..." -ForegroundColor Green
        Copy-Item $localPath $destPath -Force
    } else {
        Write-Host "   Downloading $scriptName from GitHub dev branch..." -ForegroundColor Yellow
        $url = "https://raw.githubusercontent.com/superchargez/power_shelling/dev/$scriptName"
        try {
            Invoke-WebRequest -Uri $url -OutFile $destPath -UseBasicParsing
            Write-Host "   ✓ $scriptName downloaded" -ForegroundColor Green
        } catch {
            Write-Host "   ✗ Failed to acquire $scriptName" -ForegroundColor Red
        }
    }
}

# 4. Configure PowerShell profile
if (-not $NoProfile) {
    Write-Host "`n4. Configuring PowerShell profile..." -ForegroundColor Green
    $profilePath = $PROFILE.CurrentUserAllHosts
    if (-not (Test-Path $profilePath)) { New-Item -ItemType File -Path $profilePath -Force | Out-Null }

    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    Copy-Item -Path $profilePath -Destination "$profilePath.backup.$timestamp"

    $content = Get-Content -Path $profilePath -Raw -ErrorAction SilentlyContinue
    if ($content) {
        $content = $content -replace "(?ms)# >> UV MANAGER START.*?# >> UV MANAGER END\r?\n?", ""
    }

    $newBlock = @"
# >> UV MANAGER START
`$uvManagerScript = "$InstallDir\uv-manager.ps1"
if (Test-Path `$uvManagerScript) {
    . `$uvManagerScript
}
# >> UV MANAGER END
"@
    Set-Content -Path $profilePath -Value ($content.Trim() + "`n" + $newBlock)
    Write-Host "   Profile updated: $profilePath" -ForegroundColor Green
}

# 6. Create uninstall script
$uninstallScript = @"
`$profilePath = `$PROFILE.CurrentUserAllHosts
if (Test-Path `$profilePath) {
    `$c = Get-Content `$profilePath -Raw
    `$new = `$c -replace "(?ms)# >> UV MANAGER START.*?# >> UV MANAGER END\r?\n?", ""
    Set-Content `$profilePath -Value `$new
}
Remove-Item -Path "$InstallDir" -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "Uninstall complete." -ForegroundColor Green
"@
Set-Content -Path (Join-Path $InstallDir "uninstall-uv-manager.ps1") -Value $uninstallScript

# 7. Verification
if (Test-Path (Join-Path $InstallDir "uv-manager.ps1")) {
    Write-Host "`nINSTALLATION COMPLETE!" -ForegroundColor Green
    Write-Host "Restart PowerShell or run: . `$PROFILE.CurrentUserAllHosts" -ForegroundColor Yellow
} else {
    Write-Host "`nInstallation failed: Main script not found in $InstallDir" -ForegroundColor Red
}