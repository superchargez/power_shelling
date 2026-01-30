# ================================================
# UV ENVIRONMENT MANAGER - v2.0 (Stable)
# ================================================

# Global configuration using standardized paths
$global:UV_ENVS_ROOT = Join-Path $HOME ".uv\envs"
$global:UV_ENVS_FILE = Join-Path $global:UV_ENVS_ROOT "envs.json"

# ================================================
# INTERNAL HELPERS
# ================================================

function Test-CommandExists {
    param([string]$Command)
    return $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
}

# Database Access: Safe Loading
function Get-UvDb {
    if (-not (Test-Path $UV_ENVS_FILE)) { return @{} }
    try {
        $content = Get-Content $UV_ENVS_FILE -Raw -ErrorAction Stop
        if ([string]::IsNullOrWhiteSpace($content)) { return @{} }
        return $content | ConvertFrom-Json -AsHashtable
    } catch {
        Write-Warning "Could not parse environment database. Starting fresh."
        return @{}
    }
}

# Database Access: Safe Saving (Fixes JSON Depth & Encoding bugs)
function Set-UvDb {
    param($Data)
    try {
        # Depth 10 prevents corruption of nested objects
        $json = $Data | ConvertTo-Json -Depth 10 
        $json | Set-Content -Path $UV_ENVS_FILE -Encoding UTF8
    } catch {
        Write-Error "Failed to save environment database: $_"
    }
}

# Helper: Get Python executable path within an environment
function Get-EnvPython {
    param($EnvPath)
    # Windows specific path
    return Join-Path $EnvPath "Scripts\python.exe"
}

# Initialization checks
if (-not (Test-CommandExists "uv")) {
    Write-Warning "ERROR: 'uv' is not found in PATH."
    return
}

if (-not (Test-Path $UV_ENVS_ROOT)) {
    New-Item -ItemType Directory -Path $UV_ENVS_ROOT -Force | Out-Null
}

if (-not (Test-Path $UV_ENVS_FILE)) {
    Set-UvDb @{}
}

# ================================================
# CORE FUNCTIONS
# ================================================

function uv-env-list {
    <#
    .SYNOPSIS
    List all registered environments with health status.
    #>
    $envs = Get-UvDb
    
    if ($envs.Count -eq 0) {
        Write-Host "No environments managed." -ForegroundColor Yellow
        return
    }

    Write-Host "`nUV Environments:" -ForegroundColor Cyan
    Write-Host "----------------" -ForegroundColor Cyan
    
    # Sort by name
    $envs.Keys | Sort-Object | ForEach-Object {
        $name = $_
        $info = $envs[$name]
        $path = $info.path
        
        # Check 1: Is it active?
        $isActive = ($env:VIRTUAL_ENV -and ($env:VIRTUAL_ENV -eq $path))
        $marker = if ($isActive) { "*" } else { " " }
        
        # Check 2: Does the folder actually exist? (Zombie check)
        $status = if (Test-Path $path) { 
            "$($info.python)" 
        } else { 
            "[MISSING/BROKEN]" 
        }
        $statusColor = if ($status -match "MISSING") { "Red" } else { "Gray" }

        Write-Host "$marker $name " -NoNewline -ForegroundColor Yellow
        Write-Host "($status)" -ForegroundColor $statusColor
        Write-Host "    $path" -ForegroundColor DarkGray
    }
    Write-Host ""
}

function uv-env-create {
    <#
    .SYNOPSIS
    Create a new environment and register it.
    #>
    param(
        [Parameter(Mandatory=$true, Position=0)] [string]$Name,
        [Parameter(Position=1)] [string]$Python = "default",
        [string]$Path
    )
    
    # Reload DB to prevent race conditions
    $envs = Get-UvDb
    
    if ($envs.ContainsKey($Name)) {
        Write-Host "Error: Environment '$Name' already exists in registry." -ForegroundColor Red
        return
    }
    
    # Determine path
    $targetPath = if ($Path) { $Path } else { Join-Path $UV_ENVS_ROOT $Name }
    
    Write-Host "Creating '$Name' (Python $Python) at $targetPath..." -ForegroundColor Cyan
    
    # Run UV
    uv venv --python $Python $targetPath
    
    # ONLY register if UV succeeded
    if ($LASTEXITCODE -eq 0) {
        $envs[$Name] = @{
            path = $targetPath
            python = $Python
            created = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        }
        Set-UvDb $envs
        Write-Host "Environment created successfully." -ForegroundColor Green
        Write-Host "Activate with: uva $Name" -ForegroundColor Gray
    } else {
        Write-Host "Failed to create environment. DB not updated." -ForegroundColor Red
    }
}

function uv-env-activate {
    <#
    .SYNOPSIS
    Safely activates an environment in the current shell.
    #>
    param(
        [Parameter(Mandatory=$true, Position=0)] [string]$Name
    )
    
    $envs = Get-UvDb
    
    if (-not $envs.ContainsKey($Name)) {
        Write-Host "Unknown environment: '$Name'" -ForegroundColor Red
        return
    }
    
    $path = $envs[$Name].path
    $activateScript = Join-Path $path "Scripts\Activate.ps1"
    
    if (-not (Test-Path $activateScript)) {
        Write-Host "Activation script not found at:" -ForegroundColor Red
        Write-Host $activateScript -ForegroundColor Gray
        Write-Host "The environment folder might have been deleted." -ForegroundColor Yellow
        return
    }
    
    # 1. Safe Deactivation
    if (Test-CommandExists "deactivate") {
        deactivate
    }
    
    # 2. Activation
    try {
        . $activateScript
        Write-Host "Activated $Name" -ForegroundColor Green
    } catch {
        Write-Host "Failed to activate environment." -ForegroundColor Red
        Write-Error $_
    }
}

function uv-env-remove {
    <#
    .SYNOPSIS
    Removes environment folder and registry entry.
    #>
    param([Parameter(Mandatory=$true, Position=0)] [string]$Name)
    
    $envs = Get-UvDb
    if (-not $envs.ContainsKey($Name)) {
        Write-Host "Environment '$Name' not found." -ForegroundColor Red
        return
    }
    
    $path = $envs[$Name].path
    
    # Prevent deleting current environment while inside it
    if ($env:VIRTUAL_ENV -eq $path) {
        Write-Host "Error: You are currently active in '$Name'." -ForegroundColor Red
        Write-Host "Please deactivate (uvx) before removing it." -ForegroundColor Yellow
        return
    }
    
    $confirm = Read-Host "Are you sure you want to delete '$Name'? (y/N)"
    if ($confirm -eq 'y') {
        # Physical delete
        if (Test-Path $path) {
            Remove-Item -Path $path -Recurse -Force -ErrorAction Stop
        } else {
            Write-Warning "Folder was already missing, cleaning up registry..."
        }
        
        # Registry delete
        $envs.Remove($Name)
        Set-UvDb $envs
        Write-Host "Environment '$Name' removed." -ForegroundColor Green
    }
}

function uv-env-update {
    <#
    .SYNOPSIS
    Updates packages without needing activation (Side-effect free).
    #>
    param([string]$Name)
    
    # Determine target environment
    if ($Name) {
        $envs = Get-UvDb
        if (-not $envs.ContainsKey($Name)) { Write-Error "Env '$Name' not found"; return }
        $path = $envs[$Name].path
    } elseif ($env:VIRTUAL_ENV) {
        $path = $env:VIRTUAL_ENV
    } else {
        Write-Host "No environment specified or active." -ForegroundColor Red
        return
    }
    
    $pythonExe = Get-EnvPython $path
    if (-not (Test-Path $pythonExe)) { Write-Error "Python not found in $path"; return }

    Write-Host "Checking for updates in $path..." -ForegroundColor Cyan
    
    # Use JSON output for robust parsing (Fixes text parsing bug)
    $outdatedRaw = & uv pip list --python $pythonExe --outdated --format=json
    
    try {
        $outdated = $outdatedRaw | ConvertFrom-Json
    } catch {
        # If output is empty or not json, assume up to date or error
        $outdated = $null
    }

    if ($outdated) {
        foreach ($pkg in $outdated) {
            Write-Host "Updating $($pkg.name) ($($pkg.version) -> $($pkg.latest_version))..." -ForegroundColor Gray
            & uv pip install --python $pythonExe --upgrade $pkg.name
        }
        Write-Host "Update complete." -ForegroundColor Green
    } else {
        Write-Host "All packages are up to date." -ForegroundColor Green
    }
}

function uv-env-export {
    <#
    .SYNOPSIS
    Exports requirements.txt without switching contexts.
    #>
    param(
        [string]$Name,
        [string]$Output = "requirements.txt"
    )
    
    if ($Name) {
        $envs = Get-UvDb
        if (-not $envs.ContainsKey($Name)) { Write-Error "Env '$Name' not found"; return }
        $path = $envs[$Name].path
    } elseif ($env:VIRTUAL_ENV) {
        $path = $env:VIRTUAL_ENV
    } else {
        Write-Host "No environment specified or active." -ForegroundColor Red
        return
    }
    
    $pythonExe = Get-EnvPython $path
    
    if (Test-Path $pythonExe) {
        Write-Host "Exporting packages..." -ForegroundColor Cyan
        & uv pip freeze --python $pythonExe | Out-File -FilePath $Output -Encoding UTF8
        Write-Host "Saved to $Output" -ForegroundColor Green
    }
}

function uv-env-info {
    param([string]$Name)
    
    if ($Name) {
        $envs = Get-UvDb
        if (-not $envs.ContainsKey($Name)) { Write-Error "Env not found"; return }
        $path = $envs[$Name].path
        $python = $envs[$Name].python
    } elseif ($env:VIRTUAL_ENV) {
        $path = $env:VIRTUAL_ENV
        $python = "Current"
    } else {
        Write-Host "No active environment." -ForegroundColor Yellow
        return
    }
    
    Write-Host "Info for: $path" -ForegroundColor Cyan
    Write-Host "Python Base: $python" -ForegroundColor Gray
    
    $pythonExe = Get-EnvPython $path
    if (Test-Path $pythonExe) {
        Write-Host "`nInstalled Packages:" -ForegroundColor Cyan
        & uv pip list --python $pythonExe
    }
}

# ================================================
# ALIASES & EXPORT
# ================================================

# Safe wrapper for deactivate
function uv-safe-deactivate {
    if (Test-CommandExists "deactivate") {
        deactivate
    } else {
        Write-Host "No active environment." -ForegroundColor Gray
    }
}

Set-Alias uvl uv-env-list
Set-Alias uvc uv-env-create
Set-Alias uva uv-env-activate
Set-Alias uvr uv-env-remove
Set-Alias uve uv-env-export
Set-Alias uvi uv-env-info
Set-Alias uvu uv-env-update
Set-Alias uvx uv-safe-deactivate

Write-Host "UV Manager v2.0 loaded." -ForegroundColor Green
Write-Host "Use 'uvl' to list environments." -ForegroundColor Gray