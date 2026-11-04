# Construcción nativa Windows de viewrv. Su ejecución y validación están pendientes.
$ErrorActionPreference = "Stop"
$SoftwareRoot = Split-Path $PSScriptRoot -Parent
$Python = Join-Path $SoftwareRoot ".venv\Scripts\python.exe"
Push-Location $SoftwareRoot
try {
    & $Python -m pip install --require-hashes -r requirements-windows.lock
    if ($LASTEXITCODE -ne 0) { throw "Falló la instalación de dependencias." }
    & $Python packaging/build_python.py
    if ($LASTEXITCODE -ne 0) { throw "Falló la construcción Python." }
    Push-Location gui
    try {
        if ((node --version) -ne "v24.22.1") { throw "Se requiere Node.js 24.22.1." }
        npm ci --no-audit --no-fund
        if ($LASTEXITCODE -ne 0) { throw "Falló npm ci." }
        node node_modules/electron/install.js
        if ($LASTEXITCODE -ne 0) { throw "Falló la preparación de Electron." }
        npm run build
        if ($LASTEXITCODE -ne 0) { throw "Falló la construcción GUI." }
        npm run package:windows
        if ($LASTEXITCODE -ne 0) { throw "Falló la generación NSIS." }
    } finally { Pop-Location }
} finally { Pop-Location }
