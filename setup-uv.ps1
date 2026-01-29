# ================================================
# ONE-CLICK UV SETUP SCRIPT
# ================================================

Write-Host "UV Environment Manager - One-Click Setup" -ForegroundColor Cyan
Write-Host "=======================================`n" -ForegroundColor Cyan

# Download and run the main installer
$tempFile = [System.IO.Path]::GetTempFileName() + ".ps1"
$installerUrl = "https://raw.githubusercontent.com/superchargez/power_shelling/main/install-uv-manager.ps1"

try {
    Write-Host "Downloading installer..." -ForegroundColor Yellow
    Invoke-WebRequest -Uri $installerUrl -OutFile $tempFile
    
    Write-Host "Running installer..." -ForegroundColor Green
    & $tempFile
    
    Write-Host "`nSetup complete!" -ForegroundColor Green
} catch {
    Write-Host "Error: Failed to download or run installer" -ForegroundColor Red
    Write-Host "Please check your internet connection and try again." -ForegroundColor Yellow
} finally {
    if (Test-Path $tempFile) {
        Remove-Item $tempFile -Force
    }
}

# Offer to restart PowerShell
$restart = Read-Host "`nRestart PowerShell now? (y/N)"
if ($restart -eq 'y') {
    Write-Host "Please close and reopen PowerShell to complete setup." -ForegroundColor Yellow
}