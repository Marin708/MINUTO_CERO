# Publicar MINUTO CERO en la web con Vercel

MINUTO CERO se exporta como una página web estática (Godot 4.7, renderizador Compatibility / WebGL 2, **sin hilos y sin
extensiones**) y se aloja en Vercel (plan gratuito, solo archivos estáticos). El juego se publica en una **rama huérfana
llamada `web`**, que solo contiene los archivos exportados, así `main` queda limpia. **No se usa `vercel.json`.**

> Este proyecto va en un **proyecto de Vercel NUEVO**, propio de este repositorio. No reutilices el de ECOS.

## 0. Antes de empezar (una sola vez)

- **Plantillas de exportación de Godot 4.7.2** instaladas (en este equipo ya están en
  `%APPDATA%\Godot\export_templates\4.7.2.stable`; si no, en el editor: `Editor > Administrar plantillas de exportación`).
- `git` con acceso al repositorio de GitHub: este repositorio todavía **no tiene remoto `origin`**; agrégalo con
  `git remote add origin URL` antes de publicar (o usa `-SinPush`).
- El preset **"Web"** está en `export_presets.cfg`: sin hilos (`thread_support=false`), sin extensiones
  (`extensions_support=false`), sin PWA, en modo release y sin `tools/`, `docs/`, `.md`, `.py`, `.ps1` ni ejemplos del
  Dialogue Manager.
- El proyecto ya tiene los ajustes web: `window/stretch/aspect="keep"`, `scale_mode.web="fractional"`,
  `rendering_method.web="gl_compatibility"`, color de fondo oscuro y `audio/general/default_playback_type.web=0` (Stream).
- Las **teclas de depuración no existen en la versión exportada**: solo funcionan con `OS.is_debug_build()` y la
  exportación es en modo release.

## a) Ejecutar `tools/publicar_web.ps1`

Desde la raíz del proyecto, en PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File tools\publicar_web.ps1
```

El script:

1. Importa los recursos y exporta con `godot --headless --export-release "Web" build/web/index.html`.
2. **No genera `vercel.json`.**
3. Mide `index.wasm`, `index.pck`, `index.js` e `index.html` (objetivo: **menos de 80 MB cada uno**) y avisa si alguno pasa.
4. Publica el contenido de `build/web` en la rama huérfana `web` con un **git worktree temporal** (no toca `main` ni tus
   cambios sin commit): un commit por publicación, `Publicacion <versión> <fecha>`, y `git push -u origin web`.
   En la **primera publicación pide confirmación** antes de crear la rama en `origin`.

Opciones: `-SoloExportar` (exporta y mide, sin publicar), `-SinPush` (commit en `web` pero sin subir), `-ForzarPush`
(si el push se rechaza, **pide confirmación** antes de un `--force-with-lease`), `-Godot RUTA`.

La versión sale de `config/version` en `project.godot` (ahora `0.1.0`). Súbela cuando publiques algo nuevo.

### Pesos medidos (exportación del 18 de noviembre de 2026)

| Archivo | Peso |
|---|---|
| `index.wasm` | 37,7 MB |
| `index.pck` | 7,2 MB |
| `index.js` | 0,27 MB |
| `index.html` | 0,01 MB |

Todos muy por debajo del objetivo de 80 MB (y del límite de 100 MB de Vercel).

## b) Configurar Vercel (una sola vez)

1. En [vercel.com](https://vercel.com): **Add New > Project** e importa **este repositorio** (un proyecto nuevo).
2. **Framework Preset:** `Other`.
3. **Build Command:** vacío. **Output Directory:** `.` (un punto). **Install Command:** vacío.
4. Despliega. Luego, en **Settings > Git**, pon **Production Branch = `web`** (Branch Tracking en `web`).

## c) Probar en local (antes de publicar)

```powershell
powershell -ExecutionPolicy Bypass -File tools\publicar_web.ps1 -SoloExportar
cd build\web
python -m http.server 8000
```

Abre `http://localhost:8000` en Chrome y en Firefox. No hace falta ninguna cabecera especial porque el build no usa hilos.

## d) Probar el enlace de producción

Abre la URL de Vercel en Chrome y en Firefox y revisa:

- Aparece «Haz clic para empezar» y, tras el clic, carga el título con su música (los navegadores bloquean el audio hasta ese clic).
- Se puede jugar con el teclado, la pausa (ESC) y la libreta (TAB) funcionan, y **no** hay teclas de depuración (N, B, V, X, 1, 2, 3, M no hacen nada).
- Guardar y recargar la página: «Continuar» sigue ahí.
- Al terminar el juego, «Exportar mis resultados» descarga `MINUTOCERO_resultados.csv` y «Descargar mi plan» baja un `.txt`.
- La proporción se mantiene al cambiar el tamaño de la ventana (barras oscuras, sin estirarse).

## e) Actualizar el juego

1. Haz tus cambios y commitea en `main`.
2. Sube `config/version` en `project.godot`.
3. Ejecuta de nuevo `tools\publicar_web.ps1`. Vercel despliega solo cuando llega el commit a la rama `web`.
4. Si ves la versión vieja, recarga con Ctrl+F5 (el navegador guarda en caché `index.wasm` y `index.pck`).

## f) Límites que debes recordar

- **100 MB por archivo** en el plan gratuito de Vercel (el objetivo es no pasar de **80 MB**).
- **Solo uso no comercial** en el plan gratuito (Hobby).
- **El juego se juega con teclado**: en móviles se muestra un aviso en el título.
- La partida se guarda **en el navegador**: si el jugador borra los datos del sitio o cambia de navegador, no la verá.
  Las respuestas de la evaluación se **descargan** como archivo.
- En la web no hay botón «Salir» ni «Abrir carpeta de datos».
