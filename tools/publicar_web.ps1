<#
.SYNOPSIS
  Exporta MINUTO CERO a la web y publica el resultado en la rama "web" (para Vercel).

.DESCRIPTION
  1. Exporta con Godot en modo release (preset "Web": sin hilos, sin extensiones, renderizador Compatibility) a
     build/web/index.html. La version exportada no tiene las teclas de depuracion (solo existen con OS.is_debug_build()).
  2. NO genera vercel.json (el proyecto de Vercel se configura en su panel; ver docs/DESPLIEGUE_VERCEL.md).
  3. Mide el peso de index.wasm, index.pck, index.js e index.html (objetivo: menos de 80 MB cada uno).
  4. Publica el contenido de build/web en la rama huerfana "web" (solo con los archivos exportados) usando un
     git worktree temporal: no toca tu rama actual (main) ni tus cambios sin commit. Un commit por publicacion
     ("Publicacion <version> <fecha>") y push de esa rama.

.PARAMETER Godot
  Ruta al ejecutable de Godot. Si no se pasa, usa la variable de entorno GODOT o la ruta habitual de este equipo.
.PARAMETER SoloExportar
  Exporta y mide, pero no publica en la rama "web".
.PARAMETER SinPush
  Hace el commit en la rama "web" pero no lo sube (git push).
.PARAMETER ForzarPush
  Si el push normal es rechazado, permite un push forzado (--force-with-lease). SIEMPRE pide confirmacion antes.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tools\publicar_web.ps1 -SoloExportar
#>
param(
    [string]$Godot = "",
    [switch]$SoloExportar,
    [switch]$SinPush,
    [switch]$ForzarPush
)

$ErrorActionPreference = "Stop"
$raiz = Split-Path -Parent $PSScriptRoot
Set-Location $raiz

# --- Godot ---
if ($Godot -eq "") { $Godot = $env:GODOT }
if ($Godot -eq "" -or -not $Godot) {
    $Godot = "C:\Users\Usuario\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe"
}
if (-not (Test-Path $Godot)) { throw "No encuentro Godot en '$Godot'. Pasalo con -Godot RUTA o define la variable GODOT." }

# --- Version (de project.godot) ---
$version = "0"
$linea = Select-String -Path (Join-Path $raiz "project.godot") -Pattern '^config/version="(.+)"' | Select-Object -First 1
if ($linea) { $version = $linea.Matches[0].Groups[1].Value }
$fecha = Get-Date -Format "yyyy-MM-dd HH:mm"

# --- 1. Exportar ---
$salida = Join-Path $raiz "build\web"
if (Test-Path $salida) { Remove-Item -Recurse -Force $salida }
New-Item -ItemType Directory -Force $salida | Out-Null
Write-Host "Exportando MINUTO CERO $version a build/web ..." -ForegroundColor Cyan
# Se importan los recursos primero (en un proyecto recien clonado no existe la carpeta .godot)
& $Godot --headless --path $raiz --import --quit | Out-Null
& $Godot --headless --path $raiz --export-release "Web" "build/web/index.html"
if ($LASTEXITCODE -ne 0) { throw "La exportacion fallo (codigo $LASTEXITCODE). Estan instaladas las plantillas de exportacion de Godot 4.7.2 (Editor > Administrar plantillas de exportacion)?" }
foreach ($archivo in @("index.html", "index.wasm", "index.pck", "index.js")) {
    if (-not (Test-Path (Join-Path $salida $archivo))) { throw "Falta $archivo en build/web: la exportacion no termino bien." }
}
# Por si alguna version de Godot o un script anterior dejo un vercel.json: este proyecto NO lo usa
if (Test-Path (Join-Path $salida "vercel.json")) { Remove-Item (Join-Path $salida "vercel.json") }

# --- 2. Pesos ---
Write-Host ""
Write-Host "Peso de los archivos (objetivo: menos de 80 MB cada uno):" -ForegroundColor Cyan
$total = 0
$demasiado = $false
Get-ChildItem $salida -File | Sort-Object Length -Descending | ForEach-Object {
    $mb = [math]::Round($_.Length / 1MB, 2)
    $total += $_.Length
    $marca = ""
    if ($_.Length -gt 80MB) { $marca = "  <-- SUPERA 80 MB"; $demasiado = $true }
    Write-Host ("  {0,-26} {1,8} MB{2}" -f $_.Name, $mb, $marca)
}
Write-Host ("  {0,-26} {1,8} MB" -f "TOTAL", [math]::Round($total / 1MB, 2)) -ForegroundColor Green
if ($demasiado) { Write-Warning "Algun archivo pasa de 80 MB (el limite gratuito de Vercel es 100 MB). Optimiza antes de publicar." }

if ($SoloExportar) {
    Write-Host "`nListo (solo exportar). Prueba local: cd build\web ; python -m http.server 8000 ; abre http://localhost:8000" -ForegroundColor Yellow
    return
}

# --- 3. Publicar en la rama "web" con un worktree temporal ---
$tmp = Join-Path $env:TEMP "minutocero_web_worktree"
if (Test-Path $tmp) {
    git worktree remove --force $tmp 2>$null
    if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp }
}
git worktree prune

$tieneOrigin = [bool](git remote | Select-String -SimpleMatch "origin")
if (-not $tieneOrigin -and -not $SinPush) {
    throw "Este repositorio no tiene un remoto 'origin'. Agregalo (git remote add origin URL) o usa -SinPush para dejar el commit solo en la rama web local."
}
$existeLocal = [bool](git branch --list web)
$existeRemota = $tieneOrigin -and [bool](git ls-remote --heads origin web 2>$null)
if ($existeRemota) {
    # Se parte SIEMPRE de lo que hay en GitHub (por si alguien cambio la rama alli)
    git fetch origin web | Out-Null
    if ($existeLocal) { git branch -f web origin/web | Out-Null }
}
if ($existeLocal) {
    git worktree add $tmp web | Out-Null
} elseif ($existeRemota) {
    git worktree add -b web $tmp origin/web | Out-Null
} else {
    # Primera publicacion: rama huerfana (sin la historia del juego)
    git worktree add --detach $tmp | Out-Null
    Push-Location $tmp
    git checkout --orphan web | Out-Null
    Pop-Location
}

try {
    Push-Location $tmp
    # Se vacia el contenido anterior y se copia el nuevo
    git rm -rf --quiet --ignore-unmatch . | Out-Null
    Get-ChildItem -Force | Where-Object { $_.Name -ne ".git" } | Remove-Item -Recurse -Force
    Copy-Item -Path (Join-Path $salida "*") -Destination $tmp -Recurse -Force
    git -c core.autocrlf=false add -A
    git diff --cached --quiet
    if ($LASTEXITCODE -eq 0) {
        Write-Host "`nNo hay cambios respecto a la ultima publicacion: no se crea otro commit." -ForegroundColor Yellow
    } else {
        git commit --quiet -m "Publicacion $version $fecha"
        Write-Host "`nCommit creado en la rama 'web': Publicacion $version $fecha" -ForegroundColor Green
        if (-not $SinPush) {
            if (-not $existeRemota) {
                $r = Read-Host "Es la PRIMERA publicacion: se creara la rama 'web' en origin. Confirmas el push? (s/n)"
                if ($r -ne "s") { Write-Host "Push cancelado. El commit quedo en la rama web local."; return }
            }
            git push -u origin web
            if ($LASTEXITCODE -ne 0) {
                if ($ForzarPush) {
                    $r = Read-Host "El push normal fue rechazado. Confirmas un push FORZADO (--force-with-lease) a la rama 'web'? (s/n)"
                    if ($r -eq "s") { git push --force-with-lease -u origin web }
                } else {
                    Write-Warning "El push fue rechazado. Si estas seguro, vuelve a ejecutar con -ForzarPush (pedira confirmacion)."
                }
            }
        }
    }
} finally {
    Pop-Location
    git worktree remove --force $tmp 2>$null
    git worktree prune
}

Write-Host ("`nPeso total publicado: {0} MB" -f [math]::Round($total / 1MB, 2)) -ForegroundColor Green
Write-Host @"

Siguientes pasos (detalle en docs/DESPLIEGUE_VERCEL.md):
  1. En Vercel: Add New > Project > importa ESTE repositorio (un proyecto NUEVO, no el de ECOS).
  2. Framework Preset: Other. Build Command: vacio. Output Directory: .
  3. Settings > Git > Production Branch = web.
  4. Cada vez que publiques (este script), Vercel despliega solo la rama 'web'.
"@
