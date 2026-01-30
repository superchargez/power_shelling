# ================================================
# UV ENVIRONMENT MANAGER - v3.1 (Gold)
# ================================================

# 1. BOOTSTRAP: Auto-Install UV if missing
if (-not (Get-Command "uv" -ErrorAction SilentlyContinue)) {
    Write-Warning "Atomic 'uv' tool is not installed."
    $confirm = Read-Host "Do you want to install it now? (y/N)"
    if ($confirm -eq 'y') {
        Write-Host "Installing uv..." -ForegroundColor Cyan
        try {
            # Official install method for Windows
            powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
            # Attempt to refresh env vars for current session
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","User") + ";" + [System.Environment]::GetEnvironmentVariable("Path","Machine")
        } catch {
            Write-Error "Installation failed. Please install manually: 'pip install uv'"
            return
        }
    } else {
        return # Exit script if UV is missing and user said No
    }
}

# 2. CONFIGURATION
$global:UV_ENVS_ROOT = Join-Path $HOME ".uv\envs"
$global:UV_ENVS_FILE = Join-Path $global:UV_ENVS_ROOT "envs.json"

# 3. INTERNAL HELPERS
function Get-UvDb {
    if (-not (Test-Path $UV_ENVS_FILE)) { return @{} }
    try {
        $content = Get-Content $UV_ENVS_FILE -Raw -ErrorAction Stop
        if ([string]::IsNullOrWhiteSpace($content)) { return @{} }
        return $content | ConvertFrom-Json -AsHashtable
    } catch { return @{} }
}

function Set-UvDb {
    param($Data)
    try {
        if (-not (Test-Path $UV_ENVS_ROOT)) { New-Item -ItemType Directory -Path $UV_ENVS_ROOT -Force | Out-Null }
        $Data | ConvertTo-Json -Depth 10 | Set-Content -Path $UV_ENVS_FILE -Encoding UTF8
    } catch { Write-Error "DB Save Failed: $_" }
}

# ================================================
# CORE FUNCTIONS
# ================================================

function Get-UvEnvList {
    <#
    .SYNOPSIS
        Lists environments. Use -Prune to clean up deleted folders from DB.
    #>
    [CmdletBinding()]
    param([switch]$Prune)

    $envs = Get-UvDb
    if ($envs.Count -eq 0) { Write-Host "No environments managed." -ForegroundColor Yellow; return }

    # PASS 1: Pruning Logic (Separate from display to avoid errors)
    if ($Prune) {
        $toRemove = @()
        foreach ($key in $envs.Keys) {
            if (-not (Test-Path $envs[$key].path)) {
                $toRemove += $key
            }
        }

        if ($toRemove.Count -gt 0) {
            foreach ($key in $toRemove) {
                Write-Host "  [PRUNING] $key (Folder missing)" -ForegroundColor Red
                $envs.Remove($key)
            }
            Set-UvDb $envs
            Write-Host "Registry pruned.`n" -ForegroundColor Green
        }
    }

    # PASS 2: Display Logic
    Write-Host "`nUV Environments:" -ForegroundColor Cyan
    Write-Host "----------------" -ForegroundColor Cyan
    
    $envs.Keys | Sort-Object | ForEach-Object {
        $name = $_
        $info = $envs[$name]
        $isActive = ($env:VIRTUAL_ENV -and ($env:VIRTUAL_ENV -eq $info.path))
        
        # Check existence only for display purposes now
        $exists = Test-Path $info.path
        
        $marker = if ($isActive) { "*" } else { " " }
        $status = if ($exists) { "$($info.python)" } else { "[MISSING]" }
        $color = if ($status -eq "[MISSING]") { "Red" } else { "Gray" }

        Write-Host "$marker $name " -NoNewline -ForegroundColor Yellow
        Write-Host "($status)" -ForegroundColor $color
        Write-Host "    $($info.path)" -ForegroundColor DarkGray
    }
    Write-Host ""
}

function New-UvEnv {
    <#
    .SYNOPSIS
        Creates a new UV environment.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position=0)] [string]$Name,
        [Parameter(Position=1)] [string]$Python = "default",
        [string]$Path
    )

    $envs = Get-UvDb
    if ($envs.ContainsKey($Name)) { Write-Error "Environment '$Name' already registered."; return }

    $targetPath = if ($Path) { $Path } else { Join-Path $UV_ENVS_ROOT $Name }
    
    # Construct UV arguments
    $uvArgs = @("venv", $targetPath)
    if ($Python -ne "default") {
        $uvArgs += "--python"
        $uvArgs += $Python
    }

    Write-Host "Creating '$Name' (Python: $Python)..." -ForegroundColor Cyan
    
    & uv $uvArgs

    if ($LASTEXITCODE -eq 0) {
        $envs[$Name] = @{ path = $targetPath; python = $Python; created = (Get-Date).ToString("s") }
        Set-UvDb $envs
        Write-Host "Created. Activate with: uva $Name" -ForegroundColor Green
    } else {
        Write-Error "UV creation failed."
    }
}

function Enter-UvEnv {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true, Position=0)] [string]$Name)

    $envs = Get-UvDb
    if (-not $envs.ContainsKey($Name)) { Write-Error "Env '$Name' not found."; return }
    
    $script = Join-Path $envs[$Name].path "Scripts\Activate.ps1"
    
    if (Test-Path $script) {
        if (Get-Command "deactivate" -ErrorAction SilentlyContinue) { deactivate }
        . $script
        Write-Host "Activated $Name" -ForegroundColor Green
    } else {
        Write-Error "Activation script missing. Try 'uvl -Prune' to clean up."
    }
}

function Remove-UvEnv {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true, Position=0)] [string]$Name)

    $envs = Get-UvDb
    if (-not $envs.ContainsKey($Name)) { Write-Error "Env '$Name' not found."; return }
    
    if ($env:VIRTUAL_ENV -eq $envs[$Name].path) {
        Write-Warning "Please deactivate (uvx) before removing the active environment."
        return
    }

    if ((Read-Host "Delete '$Name' and all files? (y/N)") -eq 'y') {
        if (Test-Path $envs[$Name].path) { Remove-Item $envs[$Name].path -Recurse -Force -ErrorAction Stop }
        $envs.Remove($Name)
        Set-UvDb $envs
        Write-Host "Removed." -ForegroundColor Green
    }
}

function Update-UvEnv {
    [CmdletBinding()]
    param([string]$Name)
    
    $targetPath = if ($Name) { (Get-UvDb).$Name.path } else { $env:VIRTUAL_ENV }
    if (-not $targetPath) { Write-Error "No environment specified."; return }
    
    $py = Join-Path $targetPath "Scripts\python.exe"
    if (-not (Test-Path $py)) { Write-Error "Python not found in env."; return }

    Write-Host "Scanning updates..." -ForegroundColor Cyan
    try {
        # Safe JSON parsing
        $json = & uv pip list --python $py --outdated --format=json | ConvertFrom-Json
        foreach ($pkg in $json) {
            Write-Host "Updating $($pkg.name)..."
            & uv pip install --python $py --upgrade $pkg.name
        }
        if (-not $json) { Write-Host "Everything is up to date." -ForegroundColor Green }
    } catch {
        Write-Host "Check completed." -ForegroundColor Gray
    }
}

function Export-UvEnv {
    [CmdletBinding()]
    param([string]$Name, [string]$Output="requirements.txt")
    
    $targetPath = if ($Name) { (Get-UvDb).$Name.path } else { $env:VIRTUAL_ENV }
    if (-not $targetPath) { Write-Error "No environment specified."; return }

    $py = Join-Path $targetPath "Scripts\python.exe"
    & uv pip freeze --python $py | Out-File -FilePath $Output -Encoding UTF8
    Write-Host "Exported to $Output" -ForegroundColor Green
}

function Exit-UvEnv {
    if (Get-Command "deactivate" -ErrorAction SilentlyContinue) { deactivate }
    else { Write-Host "Not in a virtual environment." -ForegroundColor Gray }
}

function Clear-UvCache {
    <#
    .SYNOPSIS
    Cleans UV's global cache to free up disk space.
    #>
    [CmdletBinding()]
    param()
    Write-Host "Cleaning UV global cache..." -ForegroundColor Cyan
    & uv cache clean
    Write-Host "Cache cleared. Disk space reclaimed." -ForegroundColor Green
}

# ================================================
# ALIASES
# ================================================
Set-Alias uvl Get-UvEnvList
Set-Alias uvc New-UvEnv
Set-Alias uva Enter-UvEnv
Set-Alias uvr Remove-UvEnv
Set-Alias uve Export-UvEnv
Set-Alias uvu Update-UvEnv
Set-Alias uvx Exit-UvEnv
Set-Alias uvk Clear-UvCache  # "Kill" Cache

Write-Host "UV Manager v3.1 Loaded." -ForegroundColor Green
Write-Host "Run 'uvl' to list, 'uvk' to free space." -ForegroundColor Gray