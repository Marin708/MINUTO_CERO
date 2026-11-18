#!/usr/bin/env python3
"""Activa el Loop (loop=true) en los .import de los .ogg que deben sonar en bucle.

Uso:  python tools/activar_bucles.py     (después de que Godot haya generado los .import: godot --headless --path . --import)
Luego reimporta:  godot --headless --path . --import
Con bucle: amb_casa, amb_sismo, amb_calle, musica_titulo, musica_antes y musica_despues.
Los tres finales (final_*) NO van en bucle.
"""
import os
import re

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CON_BUCLE = {
    "Ambiente": ["amb_casa", "amb_sismo", "amb_calle"],
    "Musica": ["musica_titulo", "musica_antes", "musica_despues"],
}


def main() -> int:
    for carpeta, nombres in CON_BUCLE.items():
        for n in nombres:
            ruta = os.path.join(RAIZ, "Assets", "Audio", carpeta, n + ".ogg.import")
            if not os.path.exists(ruta):
                print("Falta", ruta, "(importa primero con Godot)")
                return 1
            t = open(ruta, encoding="utf-8").read()
            t2 = re.sub(r"(?m)^loop=false", "loop=true", t)
            if t2 != t:
                open(ruta, "w", encoding="utf-8", newline="\n").write(t2)
            print("%-16s loop=%s" % (n, "true" if "loop=true" in t2 else "?"))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
