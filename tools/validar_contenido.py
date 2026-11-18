#!/usr/bin/env python3
"""Valida los JSON de Resources/contenido/ (la misma lógica que la comprobación del juego en depuración).

Uso:  python tools/validar_contenido.py
Sale con código 0 si todo está bien y con 1 si hay errores.

Revisa: ids únicos, índices correctos, textos no vacíos, decisiones D1 a D15 completas, preguntas 7 + 5 + 2,
kit de 12 objetos (8 correctos y 4 distractores), 7 mitos, 3 tarjetas de memoria, 3 finales sin huecos y 5 pasos.
"""
import json
import os
import sys

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CARPETA = os.path.join(RAIZ, "Resources", "contenido")
errores = []


def error(texto):
    errores.append(texto)


def leer(nombre):
    ruta = os.path.join(CARPETA, nombre)
    try:
        with open(ruta, encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError) as e:
        error(f"{nombre}: no se pudo leer ({e}).")
        return {}


def texto_ok(valor):
    return isinstance(valor, str) and valor.strip() != ""


def ids_unicos(nombre, elementos, clave="id"):
    vistos = set()
    for e in elementos:
        i = e.get(clave) if isinstance(e, dict) else None
        if not texto_ok(i):
            error(f"{nombre}: hay un elemento sin '{clave}'.")
        elif i in vistos:
            error(f"{nombre}: el id '{i}' está repetido.")
        else:
            vistos.add(i)
    return vistos


def validar_preguntas():
    d = leer("preguntas.json")
    esperado = {"trivia": 7, "situaciones": 5, "escala": 2}
    todos = []
    for bloque, cantidad in esperado.items():
        lista = d.get(bloque, [])
        if len(lista) != cantidad:
            error(f"preguntas.json: '{bloque}' debe tener {cantidad} y tiene {len(lista)}.")
        todos += lista
        for p in lista:
            pid = p.get("id", "?")
            if not texto_ok(p.get("texto")):
                error(f"preguntas.json: '{pid}' no tiene texto.")
            if bloque == "escala":
                if int(p.get("valores", 0)) < 2:
                    error(f"preguntas.json: '{pid}' necesita 'valores' >= 2.")
                continue
            ops = p.get("opciones", [])
            if len(ops) < 2 or not all(texto_ok(o) for o in ops):
                error(f"preguntas.json: '{pid}' necesita 2 o más opciones con texto.")
            c = p.get("correcta")
            if not isinstance(c, int) or not 0 <= c < len(ops):
                error(f"preguntas.json: '{pid}' tiene 'correcta' fuera de rango.")
            if bloque == "trivia" and not texto_ok(p.get("explicacion")):
                error(f"preguntas.json: '{pid}' (trivia) no tiene explicación.")
    ids_unicos("preguntas.json", todos)


def validar_decisiones():
    d = leer("decisiones.json").get("decisiones", [])
    ids = ids_unicos("decisiones.json", d)
    for n in range(1, 16):
        if f"D{n}" not in ids:
            error(f"decisiones.json: falta D{n}.")
    for e in d:
        did = e.get("id", "?")
        if e.get("nivel") not in (1, 2, 3):
            error(f"decisiones.json: {did} tiene un nivel no válido.")
        if not texto_ok(e.get("situacion")) or not texto_ok(e.get("retro")):
            error(f"decisiones.json: {did} necesita situación y retroalimentación.")
        if e.get("tipo") == "kit":
            continue
        ops = e.get("opciones", [])
        if len(ops) < 2 or not all(texto_ok(o) for o in ops):
            error(f"decisiones.json: {did} necesita 2 o más opciones con texto.")
        s = e.get("segura")
        if not isinstance(s, int) or not 0 <= s < len(ops):
            error(f"decisiones.json: {did} tiene 'segura' fuera de rango.")


def validar_kit():
    d = leer("kit.json")
    objs = d.get("objetos", [])
    ids_unicos("kit.json", objs)
    if len(objs) != 12:
        error(f"kit.json: debe tener 12 objetos y tiene {len(objs)}.")
    if sum(1 for o in objs if o.get("correcto") is True) != 8:
        error("kit.json: debe haber 8 objetos correctos.")
    if sum(1 for o in objs if o.get("correcto") is False) != 4:
        error("kit.json: debe haber 4 distractores.")
    iconos = [o.get("icono") for o in objs]
    if sorted(iconos) != list(range(12)):
        error("kit.json: los iconos deben ser 0 a 11 sin repetir.")
    for o in objs:
        if not texto_ok(o.get("nombre")):
            error(f"kit.json: '{o.get('id')}' no tiene nombre.")
    r = d.get("regla", {})
    if r.get("elegir") != 8 or r.get("minimo_correctos") != 7 or r.get("maximo_distractores") != 1:
        error("kit.json: la regla de D5 debe ser elegir 8, mínimo 7 correctos y máximo 1 distractor.")


def validar_listas(nombre, clave, cantidad, campos):
    lista = leer(nombre).get(clave, [])
    if len(lista) != cantidad:
        error(f"{nombre}: '{clave}' debe tener {cantidad} y tiene {len(lista)}.")
    for e in lista:
        for c in campos:
            if not texto_ok(e.get(c)):
                error(f"{nombre}: un elemento no tiene '{c}'.")
    return lista


def validar_finales():
    d = leer("finales.json")
    lista = d.get("finales", [])
    ids_unicos("finales.json", lista)
    if len(lista) != 3:
        error("finales.json: debe haber 3 finales.")
    for e in lista:
        if not texto_ok(e.get("nombre")) or not texto_ok(e.get("mensaje")):
            error(f"finales.json: '{e.get('id')}' necesita nombre y mensaje.")
    cubiertos = []
    for e in lista:
        cubiertos += range(e.get("minimo", 1), e.get("maximo", 0) + 1)
    if sorted(cubiertos) != list(range(0, d.get("total_decisiones", 15) + 1)):
        error("finales.json: los rangos deben cubrir de 0 a 15 sin huecos ni repetir.")


def main():
    validar_preguntas()
    validar_decisiones()
    validar_kit()
    validar_listas("mitos.json", "mitos", 7, ["id", "mito", "realidad"])
    validar_listas("memoria.json", "tarjetas", 3, ["id", "titulo", "texto"])
    validar_finales()
    validar_listas("plan.json", "pasos", 5, ["texto"])
    if errores:
        print("Contenido con errores:")
        for e in errores:
            print(" -", e)
        return 1
    print("Contenido válido: 14 preguntas (7+5+2), 15 decisiones, 12 objetos de kit, 7 mitos, 3 tarjetas, 3 finales, 5 pasos.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
