#!/usr/bin/env python3
"""Revisión de calidad de MINUTO CERO, sin ejecutar el juego (solo biblioteca estándar).

    python tools/revisar_proyecto.py [--salida docs/revision_calidad.md]

Revisa y escribe docs/revision_calidad.md, ordenado por gravedad (Bloqueante, Alta, Media, Baja, Informativa):
  1. Referencias res:// rotas en scripts, escenas, recursos y project.godot.
  2. Textos del juego que mencionan una tecla que no corresponde (las del juego: flechas, W A S D, E, TAB, ESC y F8).
  3. Posibles faltas de ortografía en los JSON de contenido y en las cadenas de los scripts (tildes que suelen olvidarse).
  4. Sonidos que faltan (se usan en el código o están en el catálogo pero no hay archivo) o sobran (hay archivo y nadie lo usa).
  5. Archivos de más de 5 MB.
  6. Teclas de depuración (KEY_*) sin proteger con OS.is_debug_build().
  7. Textos de seguridad frente al documento maestro: decisiones, preguntas, mitos, memoria, finales y plan deben ser
     IGUALES a docs/DISENO_MAESTRO.md (se comparan letra por letra, sin mayúsculas ni signos de cierre).
  8. Palabras que podrían afirmar reglas absolutas (siempre, nunca, todos, 100 %...) para revisarlas a mano.
Sale con código 1 si hay hallazgos bloqueantes o altos.
"""
import argparse
import glob
import json
import os
import re
import sys

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.stdout.reconfigure(encoding="utf-8") if hasattr(sys.stdout, "reconfigure") else None
IGNORAR_DIRS = {".git", ".godot", "build", "audio_originales", "__pycache__", "_PRUEBA"}
TECLAS_PERMITIDAS = {"E", "TAB", "ESC", "W", "A", "S", "D", "F8", "ENTER", "ESCAPE", "FLECHAS", "WASD", "Y"}
hallazgos = []   # (gravedad, categoría, archivo, texto)


def anotar(gravedad, categoria, archivo, texto):
    hallazgos.append((gravedad, categoria, archivo, texto))


def archivos(extensiones, carpetas=None):
    for base, dirs, nombres in os.walk(RAIZ):
        dirs[:] = [d for d in dirs if d not in IGNORAR_DIRS]
        if carpetas and not any(os.path.relpath(base, RAIZ).replace("\\", "/").startswith(c) for c in carpetas):
            continue
        for n in nombres:
            if n.endswith(tuple(extensiones)):
                yield os.path.join(base, n)


def rel(p):
    return os.path.relpath(p, RAIZ).replace("\\", "/")


def leer(p):
    with open(p, encoding="utf-8", errors="replace") as f:
        return f.read()


# ---------------------------------------------------------------------------
def referencias_rotas():
    patron = re.compile(r"res://[A-Za-z0-9_./\- ]+")
    for p in archivos((".gd", ".tscn", ".tres", ".godot", ".cfg", ".dialogue")):
        if "/addons/" in rel(p).join("//") or rel(p).startswith("tools/pruebas_"):
            continue
        for n, linea in enumerate(leer(p).splitlines(), 1):
            if linea.strip().startswith("#") or linea.strip().startswith("##"):
                continue
            for m in patron.finditer(linea):
                ruta = m.group(0).rstrip(".")
                if "%" in linea[m.start():m.end() + 3] or ruta.endswith("/"):
                    continue
                destino = os.path.join(RAIZ, ruta[6:])
                if not os.path.exists(destino) and not os.path.exists(destino + ".import"):
                    anotar("Alta", "Referencia rota", "%s:%d" % (rel(p), n), "no existe %s" % ruta)


def teclas_ajenas():
    patron = re.compile(r"(?:tecla|pulsa|presiona|mant[eé]n|oprime)\s+(?:la\s+|el\s+)?([A-Za-z0-9]{1,8})\b")
    textos = []
    for p in archivos((".gd",), ("Scripts", "Autoload")):
        for n, linea in enumerate(leer(p).splitlines(), 1):
            for cadena in re.findall(r'"((?:[^"\\]|\\.)*)"', linea):
                textos.append((rel(p), n, cadena))
    for p in archivos((".json", ".txt"), ("Resources/contenido", "Resources/creditos.txt")):
        for n, linea in enumerate(leer(p).splitlines(), 1):
            textos.append((rel(p), n, linea))
    for archivo, n, cadena in textos:
        for m in patron.finditer(cadena):
            tecla = m.group(1).upper()
            if tecla in ("LA", "EL", "UN", "UNA", "TU", "TUS", "LOS", "LAS", "PARA", "SOBRE", "ANTES", "CERO", "AQUI", "AHORA"):
                continue
            if tecla not in TECLAS_PERMITIDAS:
                anotar("Media", "Tecla que no corresponde", "%s:%d" % (archivo, n), "menciona la tecla «%s»: %s" % (m.group(1), cadena.strip()[:90]))
        m = re.search(r"(tecla|pulsa|presiona|mant[eé]n|barra)\s+(?:de\s+|la\s+)?(espacio|espaciadora)", cadena, re.I)
        if m or re.search(r"clic izquierdo", cadena, re.I):
            anotar("Media", "Tecla que no corresponde", "%s:%d" % (archivo, n), "menciona la barra espaciadora o el clic: %s" % cadena.strip()[:90])


FALTAS = {
    "accion": "acción", "situacion": "situación", "informacion": "información", "reaccion": "reacción", "evacuacion": "evacuación",
    "prevencion": "prevención", "preparacion": "preparación", "proteccion": "protección", "direccion": "dirección",
    "construccion": "construcción", "ubicacion": "ubicación", "atencion": "atención", "decision": "decisión", "despues": "después",
    "tambien": "también", "ademas": "además", "aqui": "aquí", "asi": "así", "mas": "más", "rapido": "rápido", "facil": "fácil",
    "telefono": "teléfono", "electrico": "eléctrico", "sismico": "sísmico", "area": "área", "peligroso": None, "ultimo": "último",
    "pagina": "página", "numero": "número", "dificil": "difícil", "util": "útil", "mama": "mamá", "papa": "papá", "ayudame": "ayúdame",
    "tendria": "tendría", "podria": "podría", "debera": "deberá", "habia": "había", "estan": "están", "esta?": None,
}
PALABRAS_SUELTAS_OK = {"mas": False}   # «mas» solo se marca si va sola entre espacios y no es parte de otra palabra


def ortografia():
    cadenas = []
    for p in archivos((".json",), ("Resources/contenido",)):
        d = json.loads(leer(p))
        def recorrer(x, ruta=""):
            if isinstance(x, str):
                cadenas.append((rel(p), ruta, x))
            elif isinstance(x, list):
                for i, y in enumerate(x):
                    recorrer(y, "%s[%d]" % (ruta, i))
            elif isinstance(x, dict):
                for k, y in x.items():
                    if k not in ("nota", "id", "tipo", "revisar", "revisar_titulo", "revisar_retro"):
                        recorrer(y, "%s.%s" % (ruta, k))
        recorrer(d)
    for p in archivos((".gd",), ("Scripts", "Autoload")):
        for n, linea in enumerate(leer(p).splitlines(), 1):
            if linea.strip().startswith("#"):
                continue
            for c in re.findall(r'"((?:[^"\\]|\\.){12,})"', linea):
                if (" " in c and not c.startswith(("res://", "user://")) and re.search(r"[a-záéíóú]{3}", c)
                        and not re.search(r"[()\[\]=<>_]|\\n|^[,.:;]", c) and len(c.split()) >= 3):
                    cadenas.append((rel(p), "línea %d" % n, c))
    for archivo, donde, texto in cadenas:
        for palabra in re.findall(r"[A-Za-záéíóúüñÁÉÍÓÚÜÑ]+", texto):
            correcta = FALTAS.get(palabra.lower())
            if correcta and palabra.lower() != correcta and palabra.lower() == palabra.lower():
                if palabra.lower() == "mas" and not re.search(r"(^|\s)mas(\s|$)", texto.lower()):
                    continue
                anotar("Baja", "Posible falta de ortografía", "%s %s" % (archivo, donde), "«%s» ¿«%s»?  …%s" % (palabra, correcta, texto[:70]))
        if "  " in texto.strip():
            anotar("Baja", "Posible falta de ortografía", "%s %s" % (archivo, donde), "doble espacio: %s" % texto[:70])
        if texto.count("¿") != texto.count("?") and "%" not in texto:
            anotar("Baja", "Posible falta de ortografía", "%s %s" % (archivo, donde), "signos ¿ ? sin cerrar: %s" % texto[:70])
        if texto.count("¡") != texto.count("!"):
            anotar("Baja", "Posible falta de ortografía", "%s %s" % (archivo, donde), "signos ¡ ! sin cerrar: %s" % texto[:70])


# ---------------------------------------------------------------------------
def sonidos():
    carpeta = os.path.join(RAIZ, "Assets", "Audio")
    existentes = {}
    for ruta in glob.glob(os.path.join(carpeta, "*", "*")):
        if ruta.endswith((".wav", ".ogg", ".mp3")):
            existentes[os.path.splitext(os.path.basename(ruta))[0]] = ruta
    audio = leer(os.path.join(RAIZ, "Autoload", "Audio.gd"))
    # El catálogo de Audio.gd y su tabla de volúmenes (no cuentan como «uso»)
    catalogo = set()
    for m in re.finditer(r"const (EFECTOS|AMBIENTES|MUSICAS) := \[(.*?)\]", audio, re.S):
        catalogo |= set(re.findall(r'"([a-z_]+)"', m.group(2)))
    audio_sin_listas = re.sub(r"const (EFECTOS|AMBIENTES|MUSICAS) := \[.*?\]", "", audio, flags=re.S)
    audio_sin_listas = re.sub(r"const VOLUMEN_DB := \{.*?\n\}", "", audio_sin_listas, flags=re.S)
    codigo = audio_sin_listas
    for p in archivos((".gd",), ("Scripts", "Autoload")):
        if rel(p) != "Autoload/Audio.gd":
            codigo += "\n" + leer(p)
    literales = set(re.findall(r'"([a-z][a-z_]{2,})"', codigo))
    # Lo que el código PIDE como sonido: llamadas directas efecto("x"), musica("x"), ambiente("x")
    pedidos = set(re.findall(r'(?:efecto|musica|ambiente)\(\s*"([a-z_]+)"', codigo)) | catalogo
    if re.search(r'"final_%s"', codigo):
        pedidos |= {"final_preparado", "final_encamino", "final_reforzar"}
        literales |= {"final_preparado", "final_encamino", "final_reforzar"}
    for n in sorted(pedidos - set(existentes)):
        anotar("Alta", "Sonido que falta", "Assets/Audio", "%s se %s pero no hay archivo" % (n, "usa en el código" if n not in catalogo else "lista en el catálogo de Audio.gd"))
    for n in sorted(set(existentes) - literales - catalogo):
        anotar("Baja", "Sonido que sobra", rel(existentes[n]), "hay archivo pero no está en el catálogo ni se usa")
    for n in sorted((set(existentes) & catalogo) - literales - {"dialogo_blip_guia"}):
        anotar("Media", "Sonido sin uso", rel(existentes[n]), "está en el catálogo pero ningún script lo pide")
    anotar("Informativa", "Sonidos", "Assets/Audio", "%d archivos, %d en el catálogo, %d pedidos por el código; faltan: %d" % (len(existentes), len(catalogo), len(pedidos), len(pedidos - set(existentes))))


def pesados():
    for p in archivos(("",)):
        if os.path.getsize(p) > 5 * 1024 * 1024:
            anotar("Media" if not p.endswith((".ogg", ".png")) else "Informativa", "Archivo de más de 5 MB", rel(p), "%.1f MB" % (os.path.getsize(p) / 1048576))


def teclas_de_depuracion():
    for p in archivos((".gd",), ("Scripts", "Autoload")):
        codigo = leer(p)
        if "KEY_" not in codigo:
            continue
        protegido = "OS.is_debug_build()" in codigo
        for n, linea in enumerate(codigo.splitlines(), 1):
            if re.search(r"\bKEY_(?:[A-Z0-9]|F\d+)\b", linea) and not linea.strip().startswith("#"):
                if not protegido:
                    anotar("Alta", "Tecla de depuración sin proteger", "%s:%d" % (rel(p), n), "usa %s y el archivo no comprueba OS.is_debug_build()" % re.search(r"KEY_[A-Z0-9_]+", linea).group(0))
                elif re.search(r"KEY_F\d+", linea) and "Reportes" not in rel(p):
                    anotar("Media", "Tecla F", "%s:%d" % (rel(p), n), "usa una tecla F (chocan con el editor): %s" % linea.strip()[:80])
    # Las teclas F no deben aparecer en los mapas de entrada
    pg = leer(os.path.join(RAIZ, "project.godot"))
    for m in re.finditer(r'physical_keycode":(\d+)', pg):
        if 4194332 <= int(m.group(1)) <= 4194343:
            anotar("Media", "Tecla F", "project.godot", "una acción del Input Map usa una tecla F (código %s)" % m.group(1))
    # Debe existir el aviso de que Reportes usa F8 (informativo)
    if os.path.exists(os.path.join(RAIZ, "Autoload", "Reportes.gd")) and "KEY_F8" in leer(os.path.join(RAIZ, "Autoload", "Reportes.gd")):
        anotar("Informativa", "Tecla F8", "Autoload/Reportes.gd", "F8 abre el reporte de problemas para jugadores (no es de depuración); se anuncia en los controles de la pausa")


# ---------------------------------------------------------------------------
def norm(t):
    t = str(t).lower().strip()
    t = t.replace("“", "").replace("”", "").replace("«", "").replace("»", "").replace('"', "").replace("’", "'")
    t = re.sub(r"\s+", " ", t)
    return t.rstrip(".;: ")


def comparar(archivo, donde, json_valor, maestro_valor):
    if norm(json_valor) != norm(maestro_valor):
        anotar("Alta", "Texto distinto del maestro", "%s %s" % (archivo, donde), "JSON: «%s»  ≠  maestro: «%s»" % (str(json_valor)[:80], str(maestro_valor)[:80]))
        return False
    return True


def contra_el_maestro():
    maestro = leer(os.path.join(RAIZ, "docs", "DISENO_MAESTRO.md"))
    comparados = 0
    # --- Decisiones (sección 6)
    dec = {d["id"]: d for d in json.loads(leer(os.path.join(RAIZ, "Resources", "contenido", "decisiones.json")))["decisiones"]}
    for fila in re.finditer(r"^\| (D\d+) \| (\d) \| (.+?) \| (.+?) \| (.+?) \| (.+?) \|$", maestro, re.M):
        did, nivel, situacion, segura, otras, retro = fila.groups()
        d = dec.get(did)
        if d is None:
            anotar("Alta", "Texto distinto del maestro", "decisiones.json", "falta %s" % did)
            continue
        comparar("decisiones.json", did + ".nivel", d["nivel"], nivel)
        comparar("decisiones.json", did + ".situacion", d["situacion"], situacion)
        comparados += 2
        if did == "D5":
            continue   # D5 se resuelve con kit.json
        comparar("decisiones.json", did + ".opcion segura", d["opciones"][0], segura)
        partes = [x for x in otras.split("; ")]
        if [norm(o) for o in d["opciones"][1:]] != [norm(o) for o in partes]:
            anotar("Alta", "Texto distinto del maestro", "decisiones.json " + did, "opciones no seguras: %s ≠ %s" % (d["opciones"][1:], partes))
        comparar("decisiones.json", did + ".retro", d["retro"].replace(" **[REVISAR primeros auxilios]**", ""), retro.replace(" **[REVISAR primeros auxilios]**", ""))
        comparados += 3
    # --- Preguntas (sección 10)
    bnc = json.loads(leer(os.path.join(RAIZ, "Resources", "contenido", "preguntas.json")))
    todas = {q["id"]: q for b in ("trivia", "situaciones", "escala") for q in bnc[b]}
    for m in re.finditer(r"- \*\*(t\d)\*\* «(.+?)»\s*\n\s*Correcta: (.+?)\n\s*Otras: (.+?)\n\s*Explicación: (.+?)\n", maestro):
        qid, texto, correcta, otras, explicacion = m.groups()
        q = todas.get(qid)
        comparar("preguntas.json", qid + ".texto", q["texto"], texto)
        comparar("preguntas.json", qid + ".correcta", q["opciones"][0], correcta)
        if [norm(o) for o in q["opciones"][1:]] != [norm(o) for o in otras.split(" · ")]:
            anotar("Alta", "Texto distinto del maestro", "preguntas.json " + qid, "opciones: %s ≠ %s" % (q["opciones"][1:], otras.split(" · ")))
        comparar("preguntas.json", qid + ".explicacion", q["explicacion"], explicacion)
        comparados += 4
    for m in re.finditer(r"- \*\*(s\d)\*\* «(.+?)» Correcta: (.+?)\. Otras: (.+)", maestro):
        qid, texto, correcta, otras = m.groups()
        q = todas.get(qid)
        comparar("preguntas.json", qid + ".texto", q["texto"], texto)
        comparar("preguntas.json", qid + ".correcta", q["opciones"][0], correcta)
        if [norm(o) for o in q["opciones"][1:]] != [norm(o) for o in otras.split(" · ")]:
            anotar("Alta", "Texto distinto del maestro", "preguntas.json " + qid, "opciones: %s ≠ %s" % (q["opciones"][1:], otras.split(" · ")))
        comparados += 3
    for m in re.finditer(r"- \*\*(e\d)\*\* «(.+?)»", maestro):
        comparar("preguntas.json", m.group(1) + ".texto", todas[m.group(1)]["texto"], m.group(2))
        comparados += 1
    # --- Mitos (sección 9)
    mitos = json.loads(leer(os.path.join(RAIZ, "Resources", "contenido", "mitos.json")))["mitos"]
    sec9 = maestro[maestro.index("Mitos y realidades (texto"):maestro.index("Memoria de 1999 (se desbloquea")]
    filas = re.findall(r"^- \*\*(.+?)\*\* (.+)$", sec9, re.M)
    if len(filas) != len(mitos):
        anotar("Alta", "Texto distinto del maestro", "mitos.json", "el maestro tiene %d mitos y el JSON %d" % (len(filas), len(mitos)))
    for (mito, realidad), m in zip(filas, mitos):
        comparar("mitos.json", m["id"] + ".mito", m["mito"], mito)
        comparar("mitos.json", m["id"] + ".realidad", m["realidad"], realidad)
        comparados += 2
    # --- Memoria (sección 9)
    memoria = json.loads(leer(os.path.join(RAIZ, "Resources", "contenido", "memoria.json")))["tarjetas"]
    for i, m in enumerate(re.findall(r"^\d\. (.+)$", maestro[maestro.index("Memoria de 1999 (se desbloquea"):maestro.index("## 10.")], re.M)):
        comparar("memoria.json", memoria[i]["id"] + ".texto", memoria[i]["texto"], m)
        comparados += 1
    # --- Finales (sección 8) y plan
    finales = json.loads(leer(os.path.join(RAIZ, "Resources", "contenido", "finales.json")))["finales"]
    sec8 = maestro[maestro.index("## 8. Finales"):maestro.index("## 9.")]
    for m in re.finditer(r"^\| \*\*(.+?)\*\* \| (.+?) \| (.+?) \|$", sec8, re.M):
        nombre, condicion, mensaje = m.groups()
        f = next((x for x in finales if norm(x["nombre"]) == norm(nombre)), None)
        if f is None:
            anotar("Alta", "Texto distinto del maestro", "finales.json", "falta el final «%s»" % nombre)
            continue
        comparar("finales.json", f["id"] + ".mensaje", f["mensaje"], mensaje)
        num = [int(x) for x in re.findall(r"\d+", condicion)]
        esperado = (num[0], 15) if "más" in condicion else ((num[0], num[1]) if len(num) == 2 else (0, num[0]))
        if (f["minimo"], f["maximo"]) != esperado:
            anotar("Alta", "Texto distinto del maestro", "finales.json " + f["id"], "umbrales %s ≠ %s (%s)" % ((f["minimo"], f["maximo"]), esperado, condicion))
        comparados += 3
    plan = json.loads(leer(os.path.join(RAIZ, "Resources", "contenido", "plan.json")))["pasos"]
    pasos = re.search(r"«Mi plan en 5 pasos»\*\*: (.+?)\. Opcional", sec8, re.S).group(1)
    for p, t in zip(plan, re.findall(r"\(\d\) ([^;]+?)(?:;|$)", pasos.replace("; (", ";(").replace("y (5)", "(5)"))):
        comparar("plan.json", "paso %d" % p["numero"], p["texto"], t.strip())
        comparados += 1
    # --- Kit (D5)
    kit = json.loads(leer(os.path.join(RAIZ, "Resources", "contenido", "kit.json")))["objetos"]
    esperados = ["agua potable", "alimentos no perecederos", "linterna", "pilas de repuesto", "silbato", "botiquín", "medicinas de uso diario", "documentos en bolsa impermeable", "vela", "televisor pequeño", "perfume", "videojuego"]
    for o, e in zip(kit, esperados):
        comparar("kit.json", o["id"], o["nombre"].replace("Documentos en bolsa impermeable", "documentos en bolsa impermeable"), e)
        comparados += 1
    anotar("Informativa", "Textos de seguridad", "docs/DISENO_MAESTRO.md", "%d comparaciones texto a texto con el maestro (decisiones, preguntas, mitos, memoria, finales, plan y kit)" % comparados)


ABSOLUTAS = re.compile(r"\b(siempre|nunca|jamás|jamas|todos|todas|nadie|ninguno|ninguna|100 ?%|garantiz\w+|imposible|seguro que|sin falta|obligatori\w+)\b", re.I)


def reglas_absolutas():
    for p in archivos((".json",), ("Resources/contenido",)):
        d = json.loads(leer(p))
        def recorrer(x, ruta=""):
            if isinstance(x, str):
                for m in ABSOLUTAS.finditer(x):
                    anotar("Informativa", "Palabra posiblemente absoluta", "%s %s" % (rel(p), ruta), "«%s» en: %s" % (m.group(0), x[:100]))
            elif isinstance(x, list):
                for i, y in enumerate(x):
                    recorrer(y, "%s[%d]" % (ruta, i))
            elif isinstance(x, dict):
                for k, y in x.items():
                    if k != "nota":
                        recorrer(y, "%s.%s" % (ruta, k))
        recorrer(d)
    for p in archivos((".gd",), ("Scripts/Mundo", "Scripts/UI", "Scripts/Final", "Autoload")):
        for n, linea in enumerate(leer(p).splitlines(), 1):
            if linea.strip().startswith("#"):
                continue
            for c in re.findall(r'"((?:[^"\\]|\\.){15,})"', linea):
                for m in ABSOLUTAS.finditer(c):
                    anotar("Informativa", "Palabra posiblemente absoluta", "%s:%d" % (rel(p), n), "«%s» en: %s" % (m.group(0), c[:100]))


# ---------------------------------------------------------------------------
ORDEN = ["Bloqueante", "Alta", "Media", "Baja", "Informativa"]


def escribir(salida):
    L = ["# Revisión de calidad de MINUTO CERO", "",
         "Generada por `tools/revisar_proyecto.py`. Ordenada por gravedad: **Bloqueante** (impide entregar), **Alta** (arreglar antes de entregar), "
         "**Media**, **Baja** e **Informativa** (para revisar a mano).", ""]
    resumen = {g: sum(1 for h in hallazgos if h[0] == g) for g in ORDEN}
    L += ["| Gravedad | Hallazgos |", "|---|---|"] + ["| %s | %d |" % (g, resumen[g]) for g in ORDEN] + [""]
    for g in ORDEN:
        lista = [h for h in hallazgos if h[0] == g]
        if not lista:
            continue
        L += ["## %s (%d)" % (g, len(lista)), ""]
        por_cat = {}
        for _, cat, archivo, texto in lista:
            por_cat.setdefault(cat, []).append((archivo, texto))
        for cat, items in por_cat.items():
            L += ["### %s" % cat, ""]
            for archivo, texto in items[:60]:
                L.append("- `%s`: %s" % (archivo, texto.replace("\n", " ")))
            if len(items) > 60:
                L.append("- … y %d más." % (len(items) - 60))
            L.append("")
    ruta = os.path.join(RAIZ, salida)
    with open(ruta, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(L))
    return resumen


def main():
    ap = argparse.ArgumentParser(description="Revisión de calidad de MINUTO CERO")
    ap.add_argument("--salida", default="docs/revision_calidad.md")
    args = ap.parse_args()
    for funcion in (referencias_rotas, teclas_ajenas, ortografia, sonidos, pesados, teclas_de_depuracion, contra_el_maestro, reglas_absolutas):
        try:
            funcion()
        except Exception as e:  # noqa: BLE001 (un fallo del revisor se anota, no detiene todo)
            anotar("Bloqueante", "Fallo del revisor", funcion.__name__, "%s: %s" % (type(e).__name__, e))
    resumen = escribir(args.salida)
    print("Revisión escrita en %s: %s" % (args.salida, ", ".join("%s %d" % (g, resumen[g]) for g in ORDEN)))
    sys.exit(1 if resumen["Bloqueante"] or resumen["Alta"] else 0)


if __name__ == "__main__":
    main()
