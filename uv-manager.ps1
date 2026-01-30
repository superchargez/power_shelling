# ================================================
# UV ENVIRONMENT MANAGER - v3.0 (Self-Installing)
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
            # Refresh env vars so we can use it immediately without restarting
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","User") + ";" + [System.Environment]::GetEnvironmentVariable("Path","Machine")
        } catch {
            Write-Error "Installation failed. Please install manually: 'pip install uv'"
            return
        }
    } else {
        Write-Error "UV is required for this script. Exiting."
        return
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
# CORE FUNCTIONS (Now with Approved Verbs)
# ================================================

function Get-UvEnvList {
    <#
    .SYNOPSIS
        Lists all managed UV environments.
    .DESCRIPTION
        Reads the local JSON registry and checks if environments exist on disk.
        Marks active environment with an asterisk (*).
    .EXAMPLE
        uvl
    #>
    [CmdletBinding()]
    param()

    $envs = Get-UvDb
    if ($envs.Count -eq 0) { Write-Host "No environments found." -ForegroundColor Yellow; return }

    Write-Host "`nUV Environments:" -ForegroundColor Cyan
    Write-Host "----------------" -ForegroundColor Cyan
    
    $envs.Keys | Sort-Object | ForEach-Object {
        $name = $_
        $info = $envs[$name]
        $isActive = ($env:VIRTUAL_ENV -and ($env:VIRTUAL_ENV -eq $info.path))
        $marker = if ($isActive) { "*" } else { " " }
        
        $status = if (Test-Path $info.path) { "$($info.python)" } else { "[MISSING]" }
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
    .DESCRIPTION
        Creates a venv and registers it in the JSON database.
        If python version is 'default', uv uses system python or downloads a managed one.
    .EXAMPLE
        uvc myapp            (Uses default python)
        uvc myapp 3.11       (Downloads/Uses Python 3.11)
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
    
    # Logic: If user specifically asks for 'default', we pass nothing to --python 
    # to let UV decide (System > Managed). If they specify version, we pass it.
    $uvArgs = @("venv", $targetPath)
    if ($Python -ne "default") {
        $uvArgs += "--python"
        $uvArgs += $Python
    }

    Write-Host "Creating '$Name' (Python: $Python)..." -ForegroundColor Cyan
    
    # Run UV command
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
    <#
    .SYNOPSIS
        Activates a specific environment.
    .EXAMPLE
        uva myapp
    #>
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
        Write-Error "Activation script missing at $script"
    }
}

function Remove-UvEnv {
    <#
    .SYNOPSIS
        Deletes an environment from disk and registry.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory=$true, Position=0)] [string]$Name)

    $envs = Get-UvDb
    if (-not $envs.ContainsKey($Name)) { Write-Error "Env '$Name' not found."; return }
    
    if ($env:VIRTUAL_ENV -eq $envs[$Name].path) {
        Write-Warning "Please deactivate (uvx) before removing the active environment."
        return
    }

    if ((Read-Host "Delete '$Name'? (y/N)") -eq 'y') {
        if (Test-Path $envs[$Name].path) { Remove-Item $envs[$Name].path -Recurse -Force -ErrorAction Stop }
        $envs.Remove($Name)
        Set-UvDb $envs
        Write-Host "Removed." -ForegroundColor Green
    }
}

function Update-UvEnv {
    <#
    .SYNOPSIS
        Updates packages in an environment.
    #>
    [CmdletBinding()]
    param([string]$Name)
    
    $targetPath = if ($Name) { (Get-UvDb).$Name.path } else { $env:VIRTUAL_ENV }
    if (-not $targetPath) { Write-Error "No environment specified."; return }
    
    $py = Join-Path $targetPath "Scripts\python.exe"
    
    Write-Host "Scanning updates..." -ForegroundColor Cyan
    try {
        $json = & uv pip list --python $py --outdated --format=json | ConvertFrom-Json
        foreach ($pkg in $json) {
            Write-Host "Updating $($pkg.name)..."
            & uv pip install --python $py --upgrade $pkg.name
        }
        if (-not $json) { Write-Host "Everything is up to date." -ForegroundColor Green }
    } catch {
        Write-Host "Check completed (No updates found or error parsing)." -ForegroundColor Gray
    }
}

function Export-UvEnv {
    <#
    .SYNOPSIS
        Exports requirements.txt.
    #>
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

Write-Host "UV Manager v3.0 Loaded." -ForegroundColor Green
Write-Host "Help: Get-Help uvl -Full" -ForegroundColor Gray