# ================================================
# UV ENVIRONMENT MANAGER - Centralized Environment Management
# ================================================

# Global configuration
$global:UV_ENVS_ROOT = "C:\Users\$env:USERNAME\.uv\envs"
$global:UV_ENVS_FILE = "C:\Users\$env:USERNAME\.uv\envs\envs.json"

function Test-CommandExists {
    param([string]$Command)
    $oldPreference = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'
    try { if (Get-Command $Command) { return $true } }
    catch { return $false }
    finally { $ErrorActionPreference = $oldPreference }
}

if (-not (Test-CommandExists "uv")) {
    Write-Host "ERROR: UV is not installed or not in PATH!" -ForegroundColor Red
    Write-Host "Please install UV first:" -ForegroundColor Yellow
    Write-Host "  Windows: pip install uv" -ForegroundColor White
    Write-Host "  macOS/Linux: curl -LsSf https://astral.sh/uv/install.sh | sh" -ForegroundColor White
    Write-Host "Or run the installer again: install-uv-manager.ps1" -ForegroundColor White
    return  # Exit script loading
}

# Ensure directories exist
if (-not (Test-Path $UV_ENVS_ROOT)) {
    New-Item -ItemType Directory -Path $UV_ENVS_ROOT -Force
}

if (-not (Test-Path $UV_ENVS_FILE)) {
    @{} | ConvertTo-Json | Out-File -FilePath $UV_ENVS_FILE
}

# ================================================
# CORE FUNCTIONS
# ================================================

function uv-env-list {
    <#
    .SYNOPSIS
    List all UV environments
    #>
    if (Test-Path $UV_ENVS_FILE) {
        $envs = Get-Content $UV_ENVS_FILE | ConvertFrom-Json
        Write-Host "`nAvailable UV Environments:" -ForegroundColor Cyan
        Write-Host "==========================" -ForegroundColor Cyan
        
        foreach ($envName in $envs.PSObject.Properties.Name) {
            $envInfo = $envs.$envName
            $active = if ($env:VIRTUAL_ENV -eq $envInfo.path) { "*" } else { " " }
            $pythonVersion = if ($envInfo.python) { $envInfo.python } else { "Unknown" }
            Write-Host "$active $envName : $pythonVersion" -ForegroundColor Yellow
            Write-Host "    Path: $($envInfo.path)" -ForegroundColor Gray
        }
    } else {
        Write-Host "No environments found." -ForegroundColor Yellow
    }
}

function uv-env-create {
    <#
    .SYNOPSIS
    Create a new UV environment
    .PARAMETER Name
    Name of the environment
    .PARAMETER Python
    Python version (e.g., 3.11, 3.12)
    .PARAMETER Path
    Custom path (optional)
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,
        
        [string]$Python = "3.13",
        
        [string]$Path
    )
    
    # Use custom path or default to central location
    if ($Path) {
        $envPath = $Path
    } else {
        $envPath = Join-Path $UV_ENVS_ROOT $Name
    }
    
    # Check if environment already exists
    if (Test-Path $envPath) {
        Write-Host "Environment '$Name' already exists at $envPath" -ForegroundColor Red
        return
    }
    
    Write-Host "Creating environment '$Name' with Python $Python..." -ForegroundColor Cyan
    
    # Create environment
    uv venv --python $Python $envPath
    
    # Save environment info
    $envs = Get-Content $UV_ENVS_FILE | ConvertFrom-Json
    $envs | Add-Member -NotePropertyName $Name -NotePropertyValue @{
        path = $envPath
        python = $Python
        created = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        updated = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    } -Force
    
    $envs | ConvertTo-Json | Out-File -FilePath $UV_ENVS_FILE
    
    Write-Host "Environment created at: $envPath" -ForegroundColor Green
    Write-Host "Activate with: uv-env-activate $Name" -ForegroundColor Green
}

function uv-env-activate {
    <#
    .SYNOPSIS
    Activate a UV environment from anywhere
    .PARAMETER Name
    Name of the environment to activate
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name
    )
    
    $envs = Get-Content $UV_ENVS_FILE | ConvertFrom-Json
    
    if (-not $envs.$Name) {
        Write-Host "Environment '$Name' not found!" -ForegroundColor Red
        Write-Host "Available environments:" -ForegroundColor Yellow
        uv-env-list
        return
    }
    
    $envPath = $envs.$Name.path
    $activateScript = Join-Path $envPath "Scripts\Activate.ps1"
    
    if (-not (Test-Path $activateScript)) {
        Write-Host "Activation script not found at: $activateScript" -ForegroundColor Red
        return
    }
    
    # Deactivate current environment if any
    if ($env:VIRTUAL_ENV) {
        deactivate
    }
    
    # Activate the environment
    . $activateScript
    
    # Set environment variable to track active env
    $env:UV_ACTIVE_ENV = $Name
    
    Write-Host "Activated environment: $Name" -ForegroundColor Green
    Write-Host "Python: $(python --version)" -ForegroundColor Gray
    Write-Host "Location: $envPath" -ForegroundColor Gray
}

function uv-env-remove {
    <#
    .SYNOPSIS
    Remove a UV environment
    .PARAMETER Name
    Name of the environment to remove
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name
    )
    
    $envs = Get-Content $UV_ENVS_FILE | ConvertFrom-Json
    
    if (-not $envs.$Name) {
        Write-Host "Environment '$Name' not found!" -ForegroundColor Red
        return
    }
    
    $envPath = $envs.$Name.path
    
    # Check if we're in the environment being removed
    if ($env:VIRTUAL_ENV -eq $envPath) {
        deactivate
    }
    
    Write-Host "Removing environment '$Name'..." -ForegroundColor Yellow
    Write-Host "Path: $envPath" -ForegroundColor Gray
    
    $confirmation = Read-Host "Are you sure? This cannot be undone! (y/N)"
    
    if ($confirmation -eq 'y') {
        # Remove directory
        Remove-Item -Path $envPath -Recurse -Force
        
        # Remove from registry
        $envs.PSObject.Properties.Remove($Name)
        $envs | ConvertTo-Json | Out-File -FilePath $UV_ENVS_FILE
        
        Write-Host "Environment '$Name' removed successfully." -ForegroundColor Green
    } else {
        Write-Host "Cancelled." -ForegroundColor Yellow
    }
}

function uv-env-export {
    <#
    .SYNOPSIS
    Export environment packages to requirements.txt
    .PARAMETER Name
    Environment name (optional, uses current if not specified)
    .PARAMETER Output
    Output file path
    #>
    param(
        [string]$Name,
        [string]$Output = "requirements.txt"
    )
    
    if ($Name) {
        # Activate temporarily
        $currentEnv = $env:UV_ACTIVE_ENV
        uv-env-activate $Name
    }
    
    uv pip freeze > $Output
    Write-Host "Exported packages to $Output" -ForegroundColor Green
    
    if ($Name) {
        # Restore previous environment
        if ($currentEnv) {
            uv-env-activate $currentEnv
        } else {
            deactivate
        }
    }
}

function uv-env-clone {
    <#
    .SYNOPSIS
    Clone an existing environment
    .PARAMETER Source
    Source environment name
    .PARAMETER Destination
    New environment name
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Source,
        
        [Parameter(Mandatory=$true)]
        [string]$Destination
    )
    
    $envs = Get-Content $UV_ENVS_FILE | ConvertFrom-Json
    
    if (-not $envs.$Source) {
        Write-Host "Source environment '$Source' not found!" -ForegroundColor Red
        return
    }
    
    if ($envs.$Destination) {
        Write-Host "Destination environment '$Destination' already exists!" -ForegroundColor Red
        return
    }
    
    # Export packages from source
    $tempFile = [System.IO.Path]::GetTempFileName()
    uv-env-export -Name $Source -Output $tempFile
    
    # Create new environment
    $sourceInfo = $envs.$Source
    uv-env-create -Name $Destination -Python $sourceInfo.python
    
    # Install packages
    uv-env-activate $Destination
    uv pip install -r $tempFile
    deactivate
    
    # Cleanup
    Remove-Item $tempFile
    
    Write-Host "Cloned '$Source' to '$Destination'" -ForegroundColor Green
}

function uv-env-update {
    <#
    .SYNOPSIS
    Update all packages in an environment
    .PARAMETER Name
    Environment name (optional, uses current if not specified)
    #>
    param([string]$Name)
    
    if ($Name) {
        $currentEnv = $env:UV_ACTIVE_ENV
        uv-env-activate $Name
    }
    
    Write-Host "Updating packages..." -ForegroundColor Cyan
    uv pip list --outdated --format=freeze | ForEach-Object {
        $package = $_.Split('==')[0]
        Write-Host "Updating $package..." -ForegroundColor Gray
        uv pip install --upgrade $package
    }
    
    Write-Host "Update complete!" -ForegroundColor Green
    
    if ($Name) {
        if ($currentEnv) {
            uv-env-activate $currentEnv
        } else {
            deactivate
        }
    }
}

function uv-env-info {
    <#
    .SYNOPSIS
    Show detailed information about an environment
    .PARAMETER Name
    Environment name (optional, uses current if not specified)
    #>
    param([string]$Name)
    
    if ($Name) {
        $envs = Get-Content $UV_ENVS_FILE | ConvertFrom-Json
        if (-not $envs.$Name) {
            Write-Host "Environment '$Name' not found!" -ForegroundColor Red
            return
        }
        $envPath = $envs.$Name.path
        $python = $envs.$Name.python
    } elseif ($env:VIRTUAL_ENV) {
        $envPath = $env:VIRTUAL_ENV
        $envs = Get-Content $UV_ENVS_FILE | ConvertFrom-Json
        $envName = ($envs.PSObject.Properties | Where-Object {$_.Value.path -eq $envPath}).Name
        $python = if ($envName) { $envs.$envName.python } else { "Unknown" }
    } else {
        Write-Host "No environment specified and no active environment." -ForegroundColor Yellow
        return
    }
    
    Write-Host "`nEnvironment Information:" -ForegroundColor Cyan
    Write-Host "=======================" -ForegroundColor Cyan
    Write-Host "Path: $envPath" -ForegroundColor Yellow
    Write-Host "Python: $python" -ForegroundColor Yellow
    
    if (Test-Path (Join-Path $envPath "Scripts\python.exe")) {
        $activateScript = Join-Path $envPath "Scripts\Activate.ps1"
        . $activateScript
        Write-Host "`nInstalled Packages:" -ForegroundColor Cyan
        Write-Host "===================" -ForegroundColor Cyan
        uv pip list
        deactivate
    }
}

# Add this function to uv-manager.ps1 for better error handling:
function Invoke-SafeUV {
    param([string]$Command)
    
    if (-not (Test-CommandExists "uv")) {
        Write-Host "UV not found!" -ForegroundColor Red
        return $null
    }
    
    try {
        Invoke-Expression "uv $Command"
    } catch {
        Write-Host "UV command failed: uv $Command" -ForegroundColor Red
        Write-Host "Error: $_" -ForegroundColor Red
        return $null
    }
}

# NEW: Invoke-SafeUV "venv --python $Python $envPath"

function uv-env-cleanup {
    <#
    .SYNOPSIS
    Clean UV cache and temporary files
    #>
    Write-Host "Cleaning UV cache..." -ForegroundColor Cyan
    uv cache clean
    Write-Host "Cache cleaned!" -ForegroundColor Green
}

# ================================================
# ALIASES (for quick typing)
# ================================================

Set-Alias uvl uv-env-list
Set-Alias uvc uv-env-create
Set-Alias uva uv-env-activate
Set-Alias uvr uv-env-remove
Set-Alias uve uv-env-export
Set-Alias uvx deactivate
Set-Alias uvi uv-env-info
Set-Alias uvu uv-env-update

# ================================================
# INITIALIZATION
# ================================================

Write-Host "UV Environment Manager loaded!" -ForegroundColor Green
Write-Host "Commands available:" -ForegroundColor Cyan
Write-Host "  uvl / uv-env-list    - List all environments"
Write-Host "  uvc / uv-env-create  - Create new environment"
Write-Host "  uva / uv-env-activate - Activate environment"
Write-Host "  uvr / uv-env-remove  - Remove environment"
Write-Host "  uve / uv-env-export  - Export packages"
Write-Host "  uvi / uv-env-info    - Show environment info"
Write-Host "  uvu / uv-env-update  - Update packages"
Write-Host "  uvx                  - Deactivate"
Write-Host "`nEnvironments are stored in: $UV_ENVS_ROOT" -ForegroundColor Gray