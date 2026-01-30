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

# 1. Check and install UV (Official Method)
Write-Host "1. Checking UV installation..." -ForegroundColor Green

if (Get-Command "uv" -ErrorAction SilentlyContinue) {
    $ver = uv --version
    Write-Host "   UV found: $ver" -ForegroundColor Green
} else {
    Write-Host "   UV not found. Installing..." -ForegroundColor Yellow
    try {
        powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
        Write-Host "   UV installed successfully." -ForegroundColor Green
        # Refresh path for this session so we can use it immediately if needed
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","User") + ";" + [System.Environment]::GetEnvironmentVariable("Path","Machine")
    } catch {
        Write-Host "   Failed to install UV automatically." -ForegroundColor Red
        Write-Host "   Please install manually: https://github.com/astral-sh/uv" -ForegroundColor Yellow
        return
    }
}

# 2. Create installation directory
Write-Host "`n2. Setting up installation directory..." -ForegroundColor Green

if (Test-Path $InstallDir) {
    if ($Force) {
        Remove-Item -Path $InstallDir -Recurse -Force
        Write-Host "   Removed existing directory." -ForegroundColor Yellow
    } else {
        Write-Host "   Directory already exists: $InstallDir" -ForegroundColor Yellow
        $choice = Read-Host "   Overwrite? (y/N)"
        if ($choice -eq 'y') {
            Remove-Item -Path $InstallDir -Recurse -Force
            Write-Host "   Removed existing directory." -ForegroundColor Yellow
        }
    }
}

if (-not (Test-Path $InstallDir)) {
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
    Write-Host "   Created directory: $InstallDir" -ForegroundColor Green
}

# 3. Download scripts from GitHub
Write-Host "`n3. Downloading scripts..." -ForegroundColor Green

$scripts = @{
    "uv-manager.ps1" = "https://raw.githubusercontent.com/superchargez/power_shelling/main/uv-manager.ps1"
    "uv-extras.ps1"  = "https://raw.githubusercontent.com/superchargez/power_shelling/main/uv-extras.ps1"
}

foreach ($key in $scripts.Keys) {
    $url = $scripts[$key]
    $out = Join-Path $InstallDir $key
    try {
        Invoke-WebRequest -Uri $url -OutFile $out -UseBasicParsing
        Write-Host "   ✓ $key" -ForegroundColor Green
    } catch {
        Write-Host "   ✗ Failed to download $key" -ForegroundColor Red
    }
}

# 4. Configure PowerShell profile
if (-not $NoProfile) {
    Write-Host "`n4. Configuring PowerShell profile..." -ForegroundColor Green
    
    $profilePath = $PROFILE.CurrentUserAllHosts
    if (-not (Test-Path $profilePath)) {
        New-Item -ItemType File -Path $profilePath -Force | Out-Null
    }

    # Backup existing
    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    Copy-Item -Path $profilePath -Destination "$profilePath.backup.$timestamp"
    Write-Host "   Backup created: $profilePath.backup.$timestamp" -ForegroundColor Gray

    # Clean existing block (Updates logic)
    $content = Get-Content -Path $profilePath -Raw -ErrorAction SilentlyContinue
    if ($content) {
        $cleanContent = $content -replace "(?ms)# >> UV MANAGER START.*?# >> UV MANAGER END\r?\n?", ""
        if ($cleanContent -ne $content) {
            Write-Host "   Removed old configuration." -ForegroundColor Yellow
            $content = $cleanContent
        }
    } else {
        $content = ""
    }

    # Define new block (Simplified - No Tab Completion here, logic is in the script)
    $newBlock = @"

# >> UV MANAGER START
`$uvManagerScript = "$InstallDir\uv-manager.ps1"
if (Test-Path `$uvManagerScript) {
    . `$uvManagerScript
    
    # Auto-activate project environments
    function Global:Enter-ProjectWithVenv {
        if (Test-Path ".venv") {
            # Assuming standard .venv/Scripts/Activate.ps1 structure
            if (Test-Path ".venv/Scripts/Activate.ps1") {
                . ".venv/Scripts/Activate.ps1"
            } 
            # Fallback to managed named env if .venv contains a name
            elseif (Get-Command "Enter-UvEnv" -ErrorAction SilentlyContinue) {
                `$envName = Get-Content .venv -First 1 -ErrorAction SilentlyContinue
                if (`$envName) { Enter-UvEnv `$envName }
            }
        }
    }
}
# >> UV MANAGER END
"@

    Set-Content -Path $profilePath -Value ($content.Trim() + "`n" + $newBlock)
    Write-Host "   Profile updated successfully." -ForegroundColor Green
}

# 5. Create registry entry
$regPath = "HKCU:\Software\UVManager"
if (-not (Test-Path $regPath)) { New-Item -Path $regPath -Force | Out-Null }
Set-ItemProperty -Path $regPath -Name "InstallDir" -Value $InstallDir
Set-ItemProperty -Path $regPath -Name "Version" -Value "3.2.0"

# 6. Create uninstall script (Fixed Regex Logic)
Write-Host "`n6. Creating uninstall script..." -ForegroundColor Green
$uninstallScript = @"
# UV Manager Uninstall
`$profilePath = `$PROFILE.CurrentUserAllHosts
Write-Host "Removing configuration from profile..." -ForegroundColor Cyan
if (Test-Path `$profilePath) {
    `$c = Get-Content `$profilePath -Raw
    `$new = `$c -replace "(?ms)# >> UV MANAGER START.*?# >> UV MANAGER END\r?\n?", ""
    Set-Content `$profilePath -Value `$new
}
Remove-Item -Path "HKCU:\Software\UVManager" -Recurse -ErrorAction SilentlyContinue
Remove-Item -Path "$InstallDir" -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "Uninstall complete." -ForegroundColor Green
"@
Set-Content -Path (Join-Path $InstallDir "uninstall-uv-manager.ps1") -Value $uninstallScript
Write-Host "   Uninstall script created." -ForegroundColor Green

# 7. Final Test
Write-Host "`n7. Verifying..." -ForegroundColor Green
if (Test-Path "$InstallDir\uv-manager.ps1") {
    . "$InstallDir\uv-manager.ps1"
    Write-Host "   UV Manager loaded successfully." -ForegroundColor Green
} else {
    Write-Host "   Warning: Main script not found." -ForegroundColor Red
}

Write-Host "`n" + "="*50 -ForegroundColor Cyan
Write-Host "INSTALLATION COMPLETE!" -ForegroundColor Green
Write-Host "="*50 -ForegroundColor Cyan
Write-Host "Restart PowerShell to begin." -ForegroundColor Yellow
Write-Host "Try: 'uvc my-ai -Python 3.12'" -ForegroundColor White