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

# Check for admin privileges
function Test-Admin {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

$isAdmin = Test-Admin
if (-not $isAdmin) {
    Write-Host "Warning: Not running as administrator" -ForegroundColor Yellow
    Write-Host "Some features might require elevated privileges`n" -ForegroundColor Yellow
}

# 1. Check and install UV
Write-Host "1. Checking UV installation..." -ForegroundColor Green

$uvInstalled = $false
try {
    $uvVersion = uv --version
    $uvInstalled = $true
    Write-Host "   UV found: $uvVersion" -ForegroundColor Green
} catch {
    Write-Host "   UV not found." -ForegroundColor Yellow
    
    # Check if Python is available for pip installation
    try {
        $pythonVersion = python --version
        Write-Host "   Python found: $pythonVersion" -ForegroundColor Green
        
        $installChoice = Read-Host "   Install UV? (Y/n)"
        if ($installChoice -ne 'n') {
            Write-Host "   Installing UV via pip..." -ForegroundColor Cyan
            python -m pip install --user uv
            $uvInstalled = $true
            Write-Host "   UV installed successfully" -ForegroundColor Green
        } else {
            Write-Host "   UV installation skipped" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "   Python not found. Cannot install UV automatically." -ForegroundColor Red
        Write-Host "   Please install Python first, then run this script again." -ForegroundColor Yellow
        Write-Host "   Or install UV manually: https://github.com/astral-sh/uv" -ForegroundColor Yellow
        $installManually = Read-Host "   Continue with manual UV installation? (y/N)"
        if ($installManually -ne 'y') {
            return
        }
    }
}

# 2. Create installation directory
Write-Host "`n2. Setting up installation directory..." -ForegroundColor Green

if (Test-Path $InstallDir -PathType Container) {
    if ($Force) {
        Remove-Item -Path $InstallDir -Recurse -Force
        Write-Host "   Removed existing directory: $InstallDir" -ForegroundColor Yellow
    } else {
        Write-Host "   Directory already exists: $InstallDir" -ForegroundColor Yellow
        $overwrite = Read-Host "   Overwrite? (y/N)"
        if ($overwrite -ne 'y') {
            Write-Host "   Using existing directory." -ForegroundColor Green
        } else {
            Remove-Item -Path $InstallDir -Recurse -Force
            Write-Host "   Removed existing directory." -ForegroundColor Yellow
        }
    }
}

New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
Write-Host "   Created directory: $InstallDir" -ForegroundColor Green

# 3. Download scripts from GitHub
Write-Host "`n3. Downloading scripts from GitHub..." -ForegroundColor Green

$scripts = @{
    "uv-manager.ps1" = "https://raw.githubusercontent.com/superchargez/power_shelling/main/uv-manager.ps1"
    "uv-extras.ps1" = "https://raw.githubusercontent.com/superchargez/power_shelling/main/uv-extras.ps1"
    "setup-uv.ps1" = "https://raw.githubusercontent.com/superchargez/power_shelling/main/setup-uv.ps1"
}

foreach ($script in $scripts.Keys) {
    $url = $scripts[$script]
    $output = Join-Path $InstallDir $script
    
    try {
        Write-Host "   Downloading $script..." -ForegroundColor Gray
        Invoke-WebRequest -Uri $url -OutFile $output
        Write-Host "   ✓ $script" -ForegroundColor Green
    } catch {
        Write-Host "   ✗ Failed to download $script" -ForegroundColor Red
        Write-Host "   Error: $_" -ForegroundColor Red
    }
}

# 4. Configure PowerShell profile
if (-not $NoProfile) {
    Write-Host "`n4. Configuring PowerShell profile..." -ForegroundColor Green
    
    # We use CurrentUserAllHosts so it works in both ISE, VSCode, and Terminal
    $profilePath = $PROFILE.CurrentUserAllHosts
    $profileDir = Split-Path $profilePath -Parent
    
    # Create profile directory if it doesn't exist
    if (-not (Test-Path $profileDir)) {
        New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
    }

    # Define the content we want to add
    # Note: We use the Here-String to keep it clean
    $profileBlock = @"

# ================================================
# UV ENVIRONMENT MANAGER - Auto-loaded
# ================================================

# Set the installation directory
`$uvManagerDir = "$InstallDir"

# Load UV Manager
if (Test-Path "`$uvManagerDir\uv-manager.ps1") {
    . "`$uvManagerDir\uv-manager.ps1"
    Write-Host "UV Manager loaded from: `$uvManagerDir" -ForegroundColor Gray
}

# Optional: Load extras if available
if (Test-Path "`$uvManagerDir\uv-extras.ps1") {
    . "`$uvManagerDir\uv-extras.ps1"
}

# Auto-detect and activate project environments
function Enter-ProjectWithVenv {
    if (Test-Path ".venv") {
        `$envName = Get-Content .venv -First 1
        if (`$envName) {
            if (Get-Command uv-env-activate -ErrorAction SilentlyContinue) {
                uv-env-activate `$envName
            }
        }
    }
}

# Set up tab completion for uv-env-activate
Register-ArgumentCompleter -CommandName uv-env-activate -ScriptBlock {
    param(`$commandName, `$parameterName, `$wordToComplete)
    if (Test-Path "`$uvManagerDir\uv-manager.ps1") {
        # We dot-source to ensure we have the latest env list logic
        . "`$uvManagerDir\uv-manager.ps1"
        `$envsFile = Join-Path `$uvManagerDir "envs.json" # Assuming envs.json is in install dir or check global
        if (Test-Path `$global:UV_ENVS_FILE) {
             `$envs = Get-Content `$global:UV_ENVS_FILE | ConvertFrom-Json
             `$envs.PSObject.Properties.Name | Where-Object { `$_ -like "`$wordToComplete*" }
        }
    }
}

# Alias for quick access
Set-Alias uvm "`$uvManagerDir\uv-manager.ps1"

# ================================================
"@

    # 1. READ existing profile to check for duplicates
    $currentContent = ""
    if (Test-Path $profilePath) {
        $currentContent = Get-Content -Path $profilePath -Raw -ErrorAction SilentlyContinue
    }

    # 2. CHECK if our signature already exists
    if ($currentContent -match "UV ENVIRONMENT MANAGER - Auto-loaded") {
        Write-Host "   Profile is already configured. Skipping addition." -ForegroundColor Yellow
    } 
    else {
        # 3. BACKUP (Only if we are actually going to change it)
        if (Test-Path $profilePath) {
            $backupPath = "$profilePath.backup.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
            Copy-Item -Path $profilePath -Destination $backupPath
            Write-Host "   Backed up existing profile to: $backupPath" -ForegroundColor Green
        }
        
        # 4. APPEND the new block
        Add-Content -Path $profilePath -Value $profileBlock
        Write-Host "   Updated PowerShell profile: $profilePath" -ForegroundColor Green
    }
}

# 5. Create registry entry for easy updates
Write-Host "`n5. Creating system registry entry..." -ForegroundColor Green

$regPath = "HKCU:\Software\UVManager"
try {
    New-Item -Path $regPath -Force | Out-Null
    Set-ItemProperty -Path $regPath -Name "InstallDir" -Value $InstallDir
    Set-ItemProperty -Path $regPath -Name "Version" -Value "1.0.0"
    Set-ItemProperty -Path $regPath -Name "InstalledAt" -Value (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    Write-Host "   Registry entry created" -ForegroundColor Green
} catch {
    Write-Host "   Note: Could not create registry entry (non-critical)" -ForegroundColor Yellow
}

# 6. Create update script
Write-Host "`n6. Creating update script..." -ForegroundColor Green

$updateScript = @"
# UV Manager Update Script
`$managerDir = "$InstallDir"

Write-Host "Updating UV Manager..." -ForegroundColor Cyan

# Update uv-manager.ps1
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/superchargez/power_shelling/main/uv-manager.ps1" -OutFile "`$managerDir\uv-manager.ps1"

# Update uv-extras.ps1
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/superchargez/power_shelling/main/uv-extras.ps1" -OutFile "`$managerDir\uv-extras.ps1"

Write-Host "Update complete! Please restart PowerShell." -ForegroundColor Green
"@

$updateScriptPath = Join-Path $InstallDir "update-uv-manager.ps1"
Set-Content -Path $updateScriptPath -Value $updateScript
Write-Host "   Update script created: $updateScriptPath" -ForegroundColor Green

# 7. Create uninstall script
Write-Host "`n7. Creating uninstall script..." -ForegroundColor Green

$uninstallScript = @"
# UV Manager Uninstall Script
`$managerDir = "$InstallDir"

Write-Host "Uninstalling UV Manager..." -ForegroundColor Cyan

# Remove from PowerShell profile
`$profileContent = Get-Content `$PROFILE.CurrentUserAllHosts
`$newContent = `$profileContent | Where-Object { `$_ -notmatch "UV ENVIRONMENT MANAGER" }
Set-Content -Path `$PROFILE.CurrentUserAllHosts -Value `$newContent

# Remove registry entry
Remove-Item -Path "HKCU:\Software\UVManager" -Recurse -ErrorAction SilentlyContinue

# Remove installation directory
if (Test-Path `$managerDir) {
    Remove-Item -Path `$managerDir -Recurse -Force
    Write-Host "Removed directory: `$managerDir" -ForegroundColor Green
}

Write-Host "Uninstall complete! Please restart PowerShell." -ForegroundColor Green
"@

$uninstallScriptPath = Join-Path $InstallDir "uninstall-uv-manager.ps1"
Set-Content -Path $uninstallScriptPath -Value $uninstallScript
Write-Host "   Uninstall script created: $uninstallScriptPath" -ForegroundColor Green

# 8. Test the installation
Write-Host "`n8. Testing installation..." -ForegroundColor Green

try {
    . "$InstallDir\uv-manager.ps1"
    Write-Host "   UV Manager loaded successfully" -ForegroundColor Green
    
    # Test basic commands
    $envs = Get-Content $global:UV_ENVS_FILE | ConvertFrom-Json
    Write-Host "   Found $($envs.PSObject.Properties.Count) environments" -ForegroundColor Green
} catch {
    Write-Host "   Warning: Could not load UV Manager" -ForegroundColor Yellow
    Write-Host "   Error: $_" -ForegroundColor Red
}

# 9. Display completion message
Write-Host "`n" + "="*50 -ForegroundColor Cyan
Write-Host "INSTALLATION COMPLETE!" -ForegroundColor Green
Write-Host "="*50 -ForegroundColor Cyan
Write-Host "`nWhat to do next:" -ForegroundColor Yellow
Write-Host "1. RESTART POWERSHELL or run: `. `$PROFILE" -ForegroundColor White
Write-Host "2. Test with: `"uvl`" (list environments)" -ForegroundColor White
Write-Host "3. Create your first environment: `"uvc ai -Python 3.12" -ForegroundColor White
Write-Host "`nAvailable commands:" -ForegroundColor Cyan
Write-Host "  uvl, uvc, uva, uvr, uve, uvi, uvu, uvx" -ForegroundColor White
Write-Host "`nInstallation directory: $InstallDir" -ForegroundColor Gray
Write-Host "Update script: $updateScriptPath" -ForegroundColor Gray
Write-Host "Uninstall script: $uninstallScriptPath" -ForegroundColor Gray

# 10. Optional: Ask to create first environment
$createEnv = Read-Host "`nCreate your first 'ai' environment now? (y/N)"
if ($createEnv -eq 'y') {
    . "$InstallDir\uv-manager.ps1"
    uv-env-create -Name ai -Python 3.13
    Write-Host "Environment 'ai' created! Activate with: uva ai" -ForegroundColor Green
}