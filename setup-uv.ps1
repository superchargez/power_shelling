# ================================================
# ONE-CLICK UV SETUP SCRIPT
# ================================================

Write-Host "UV Environment Manager - One-Click Setup" -ForegroundColor Cyan
Write-Host "=======================================`n" -ForegroundColor Cyan

$localInstaller = Join-Path $PSScriptRoot "install-uv-manager.ps1"
$installerUrl = "https://raw.githubusercontent.com/superchargez/power_shelling/dev/install-uv-manager.ps1"

if (Test-Path $localInstaller) {
    Write-Host "Found local installer, running..." -ForegroundColor Green
    & $localInstaller
} else {
    $tempFile = [System.IO.Path]::GetTempFileName() + ".ps1"
    try {
        Write-Host "Downloading installer from GitHub (dev branch)..." -ForegroundColor Yellow
        Invoke-WebRequest -Uri $installerUrl -OutFile $tempFile -UseBasicParsing
        Write-Host "Running downloaded installer..." -ForegroundColor Green
        & $tempFile
    } catch {
        Write-Host "Error: Failed to download or run installer" -ForegroundColor Red
        Write-Host "Please check your internet connection or ensure the file exists." -ForegroundColor Yellow
    } finally {
        if (Test-Path $tempFile) { Remove-Item $tempFile -Force }
    }
}

$restart = Read-Host "`nRestart PowerShell now? (y/N)"
if ($restart -eq 'y') {
    # This launches a new window and closes the old one
    Start-Process powershell
    exit
}