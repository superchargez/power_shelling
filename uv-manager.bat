@echo off
:: ================================================
:: UV ENVIRONMENT MANAGER - v3.2 (CMD)
:: ================================================

:: Configuration
set "UV_ENVS_ROOT=%USERPROFILE%\.uv\envs"
set "UV_ENVS_FILE=%UV_ENVS_ROOT%\envs.json"

:: If no arguments, just setup aliases
if "%~1"=="" goto setup_aliases

:: Route commands
if /I "%~1"=="list" goto uvl
if /I "%~1"=="create" goto uvc
if /I "%~1"=="activate" goto uva
if /I "%~1"=="remove" goto uvr
if /I "%~1"=="export" goto uve
if /I "%~1"=="update" goto uvu
if /I "%~1"=="clear" goto uvk
goto :eof

:setup_aliases
doskey uvl="%~f0" list
doskey uvc="%~f0" create $*
doskey uva="%~f0" activate $*
doskey uvr="%~f0" remove $*
doskey uve="%~f0" export $*
doskey uvu="%~f0" update
doskey uvx=deactivate
doskey uvk="%~f0" clear
echo UV Manager v3.2 Loaded (CMD).
goto :eof

:uvl
powershell -NoProfile -Command "$f='%UV_ENVS_FILE%'; $envs = if (Test-Path $f) { Get-Content $f | ConvertFrom-Json } else { @{} }; if ($envs.PSObject.Properties.Count -eq 0) { Write-Host 'No environments managed.' -ForegroundColor Yellow } else { Write-Host 'UV Environments:' -ForegroundColor Cyan; foreach ($n in $envs.psobject.properties.Name) { $p=$envs.$n.path; $v=$envs.$n.python; $m=if($env:VIRTUAL_ENV -eq $p){'*'}else{' '}; Write-Host (\"$m \" + $n + \" ($v)\") -ForegroundColor Yellow; Write-Host \"    $p\" -ForegroundColor Gray } }"
goto :eof

:uvc
set "name=%~2"
set "py=%~3"
if "%name%"=="" (echo Usage: uvc name [python_version] && goto :eof)
if "%py%"=="" set "py=default"

echo Creating '%name%'...
if "%py%"=="default" (
    uv venv "%UV_ENVS_ROOT%\%name%"
) else (
    uv venv --python %py% "%UV_ENVS_ROOT%\%name%"
)

if %ERRORLEVEL% EQU 0 (
    powershell -NoProfile -Command "$f='%UV_ENVS_FILE%'; $db = if (Test-Path $f) { Get-Content $f | ConvertFrom-Json -AsHashtable } else { @{} }; $db['%name%'] = @{ path = '%UV_ENVS_ROOT%\%name%'.Replace('\','\\'); python = '%py%'; created = (Get-Date).ToString('s') }; $db | ConvertTo-Json | Set-Content $f"
    echo Created. Activate with: uva %name%
)
goto :eof

:uva
set "name=%~2"
if "%name%"=="" (echo Usage: uva name && goto :eof)
for /f "usebackq delims=" %%i in (`powershell -NoProfile -Command "(Get-Content '%UV_ENVS_FILE%' | ConvertFrom-Json).'%name%'.path"`) do set "target_path=%%i"
if exist "%target_path%\Scripts\activate.bat" (
    call "%target_path%\Scripts\activate.bat"
    echo Activated %name%
) else (
    echo Environment '%name%' not found or invalid.
)
goto :eof

:uvr
set "name=%~2"
if "%name%"=="" (echo Usage: uvr name && goto :eof)
set /p confirm="Delete '%name%'? (y/n): "
if /I "%confirm%"=="y" (
    powershell -NoProfile -Command "$f='%UV_ENVS_FILE%'; $db = Get-Content $f | ConvertFrom-Json -AsHashtable; $path = $db['%name%'].path; if (Test-Path $path) { Remove-Item $path -Recurse -Force }; $db.Remove('%name%'); $db | ConvertTo-Json | Set-Content $f"
    echo Removed.
)
goto :eof

:uve
set "out=%~2"
if "%out%"=="" set "out=requirements.txt"
uv pip freeze > %out%
echo Exported to %out%
goto :eof

:uvu
uv pip install --upgrade uv
goto :eof

:uvk
uv cache clean
goto :eof