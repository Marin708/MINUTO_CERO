#!/usr/bin/env python3
"""Mide, en cada cuadro de una hoja de sprites, el rectángulo que ocupa el dibujo (donde el alfa es mayor que 0).
Sirve para poner el origen de cada objeto en su base y escalar las figuras.

Uso:  python tools/medir_hojas.py          (escribe Resources/Mundo/hojas_info.json)
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import png_simple  # noqa: E402

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HOJAS = {
    "Assets/Personajes/sami.png": 64,
    "Assets/Personajes/personajes.png": 64,
    "Assets/Mundo/riesgos.png": 128,
    "Assets/Mundo/muebles.png": 128,
    "Assets/Mundo/exterior.png": 128,
}


def medir(ruta, lado):
    ancho, alto, filas = png_simple.leer(os.path.join(RAIZ, ruta))
    cuadros = []
    for fy in range(alto // lado):
        for fx in range(ancho // lado):
            x0 = y0 = 10 ** 6
            x1 = y1 = -1
            for y in range(lado):
                fila = filas[fy * lado + y]
                for x in range(lado):
                    if fila[fx * lado + x][3] > 0:
                        x0, x1 = min(x0, x), max(x1, x)
                        y0, y1 = min(y0, y), max(y1, y)
            cuadros.append({"col": fx, "fila": fy, "x0": x0, "y0": y0, "x1": x1, "y1": y1,
                            "ancho": x1 - x0 + 1, "alto": y1 - y0 + 1, "base": y1 + 1})
    return cuadros


def main():
    info = {ruta: medir(ruta, lado) for ruta, lado in HOJAS.items()}
    with open(os.path.join(RAIZ, "Resources", "Mundo", "hojas_info.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(info, f, indent=1)
    for ruta, cuadros in info.items():
        print(ruta)
        for c in cuadros:
            print("  col %d fila %d: %3d x %3d px, base y=%d, x %d..%d" % (c["col"], c["fila"], c["ancho"], c["alto"], c["base"], c["x0"], c["x1"]))


if __name__ == "__main__":
    main()

