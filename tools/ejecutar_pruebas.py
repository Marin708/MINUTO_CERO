#!/usr/bin/env python3
"""Ejecuta TODAS las pruebas de humo de MINUTO CERO en Godot sin ventana y vigila la consola.

    python tools/ejecutar_pruebas.py [--godot RUTA_A_GODOT]

Corre tres escenas y suma sus comprobaciones:
  tools/pruebas_estado.tscn  contenido, finales, intentos y lecciones, guardado, evaluación (14 preguntas), código MC1 y audio
  tools/pruebas_flujo.tscn   tarjeta de retroalimentación, recorrido de los tres niveles (Nivel 2 con fallo y reintento y con
                             el sismo en tiempo real, réplica del nivel 3), los tres finales y las teclas de depuración
  tools/pruebas_humo.tscn    título, consentimiento, cuestionarios inicial y final contestados, resultados, código y créditos
Muestra cuántas comprobaciones pasaron y cuántos errores o advertencias salieron en la consola (se ignoran los avisos de
recursos sin liberar al cerrar Godot sin ventana y los avisos que las pruebas provocan a propósito).
Termina con código 0 solo si pasó todo y la consola quedó limpia. Tarda unos 3 minutos.
"""
import argparse
import os
import re
import subprocess
import sys

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GODOT = os.environ.get("GODOT", r"C:\Users\Usuario\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe")
ESCENAS = ["pruebas_estado", "pruebas_flujo", "pruebas_humo"]
IGNORAR = (
    # Avisos ESPERADOS: las pruebas dañan el guardado, piden un sonido que no existe y la URL del formulario aún está vacía
    re.compile(r"el archivo de guardado está dañado"),
    re.compile(r"config_formulario\.json no tiene 'url'"),
    re.compile(r"no existe el audio 'no_existe_xyz'"),
    re.compile(r"leaked at exit|still in use at exit|ObjectDB instances were leaked|RIDs? of type|RID allocations|at: (cleanup|clear|_free_rids|push_warning)|Pages in use exist|Thread object is being destroyed|wait_to_finish"),
    re.compile(r"^\s+(GDScript backtrace|\[\d+\])"),
)


def correr(godot, escena):
    proc = subprocess.run([godot, "--headless", "--path", RAIZ, "res://tools/%s.tscn" % escena], capture_output=True, text=True,
                          encoding="utf-8", errors="replace", timeout=1500)
    lineas = [l.rstrip() for l in (proc.stdout + "\n" + proc.stderr).splitlines()]
    fallos = [l for l in lineas if "FALLA" in l]
    resumen = [l for l in lineas if re.match(r"Pruebas.*: \d+ comprobaciones, \d+ fallos", l)]
    problemas = []
    previa = ""
    for l in lineas:
        if re.search(r"ERROR|WARNING|SCRIPT ERROR", l) and not any(p.search(l) for p in IGNORAR):
            # un aviso cuyo mensaje esperado sigue en la línea siguiente
            problemas.append(l)
    return fallos, resumen, problemas


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--godot", default=GODOT)
    args = ap.parse_args()
    # Importa los recursos por si el proyecto es nuevo
    subprocess.run([args.godot, "--headless", "--path", RAIZ, "--import", "--quit"], capture_output=True, timeout=600)
    total = fallidas = 0
    todo_problemas = []
    terminaron = True
    for escena in ESCENAS:
        fallos, resumen, problemas = correr(args.godot, escena)
        if not resumen:
            terminaron = False
            print("%s: no terminó (revisa la consola)" % escena)
            continue
        m = re.search(r"(\d+) comprobaciones, (\d+) fallos", resumen[-1])
        total += int(m.group(1))
        fallidas += int(m.group(2))
        print("%-16s %s" % (escena, resumen[-1]))
        for l in fallos:
            print("   ", l.strip())
        todo_problemas += ["[%s] %s" % (escena, l) for l in problemas]
    print()
    print("RESULTADO: %d comprobaciones, %d fallidas." % (total, fallidas))
    print("Errores o advertencias en consola: %d" % len(todo_problemas))
    for l in todo_problemas[:25]:
        print("   ", l)
    sys.exit(0 if (fallidas == 0 and not todo_problemas and terminaron) else 1)


if __name__ == "__main__":
    main()
