#!/usr/bin/env python3
"""Genera el tileset de MINUTO CERO (Assets/Mundo/tileset.png) por código, sin Pillow (usa tools/png_simple.py).

Cada tile mide 32 x 32 px y la hoja tiene 8 columnas. Paleta: azul petróleo, naranja de seguridad, crema, gris y
toques cálidos. Los números de tile son los de TILES (el mismo orden que usa tools/generar_mapa.py y
Scripts/Mundo/ConjuntoTiles.gd). Los tiles 16 a 19 son detalles de daños leves (grietas, polvo, vidrios,
escombros) que van en una capa encima del suelo en el nivel 2.

Uso:  python tools/generar_tileset.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import png_simple  # noqa: E402

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LADO = 32
COLUMNAS = 8

PETROLEO_OSCURO = (15, 45, 56)
PETROLEO = (20, 65, 79)
PETROLEO_CLARO = (29, 85, 102)
NARANJA = (255, 138, 42)
CREMA = (255, 244, 220)
GRIS = (157, 176, 184)
GRIS_OSCURO = (96, 114, 122)
MADERA = (201, 156, 104)
MADERA_OSCURA = (168, 122, 78)
BALDOSA = (214, 224, 226)
BALDOSA_OSCURA = (178, 194, 198)
VERDE = (106, 160, 92)
VERDE_OSCURO = (76, 128, 72)
ASFALTO = (78, 88, 96)
ASFALTO_CLARO = (96, 107, 115)
ANDEN = (212, 205, 188)
ANDEN_OSCURO = (186, 178, 160)
TIERRA = (176, 144, 104)
LADRILLO = (176, 92, 70)
LADRILLO_OSCURO = (140, 68, 54)

#: nombre de cada tile, en orden (el índice es su posición en la hoja)
TILES = ["vacio", "piso_madera", "baldosa", "balcon", "pared", "ventana", "umbral", "escalera",
         "alfombra", "calle", "calle_linea", "anden", "pasto", "camino", "borde", "muro_edificio",
         "grieta", "polvo", "vidrio", "escombro"]
#: los que bloquean el paso (colisión)
SOLIDOS = ["vacio", "pared", "ventana", "borde", "muro_edificio"]


def ruido(x, y, semilla):
    """Número entre 0 y 1 que depende solo de la posición (siempre sale igual)."""
    n = (x * 374761393 + y * 668265263 + semilla * 2147483647) & 0xFFFFFFFF
    n = ((n ^ (n >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((n ^ (n >> 16)) & 0xFFFF) / 65535.0


def nuevo(color):
    return [[color + (255,) for _ in range(LADO)] for _ in range(LADO)]


def poner(t, x, y, color, a=255):
    if 0 <= x < LADO and 0 <= y < LADO:
        t[y][x] = color + (a,)


def rect(t, x0, y0, x1, y1, color, a=255):
    for y in range(y0, y1):
        for x in range(x0, x1):
            poner(t, x, y, color, a)


def moteado(t, claro, oscuro, semilla, densidad=0.12):
    for y in range(LADO):
        for x in range(LADO):
            r = ruido(x, y, semilla)
            if r < densidad:
                poner(t, x, y, oscuro)
            elif r > 1 - densidad:
                poner(t, x, y, claro)


def piso_madera():
    t = nuevo(MADERA)
    for y in range(0, LADO, 8):
        rect(t, 0, y, LADO, y + 1, MADERA_OSCURA)
        corte = 4 + (y // 8 % 3) * 9
        rect(t, corte, y, corte + 1, y + 8, MADERA_OSCURA)
    moteado(t, (214, 170, 118), MADERA_OSCURA, 1, 0.05)
    return t


def baldosa():
    t = nuevo(BALDOSA)
    rect(t, 0, 0, LADO, 1, BALDOSA_OSCURA)
    rect(t, 0, 0, 1, LADO, BALDOSA_OSCURA)
    rect(t, 16, 0, 17, LADO, BALDOSA_OSCURA)
    rect(t, 0, 16, LADO, 17, BALDOSA_OSCURA)
    moteado(t, CREMA, BALDOSA_OSCURA, 2, 0.03)
    return t


def balcon():
    t = nuevo(GRIS)
    for y in range(0, LADO, 16):
        rect(t, 0, y, LADO, y + 1, GRIS_OSCURO)
    for x in range(0, LADO, 16):
        rect(t, x, 0, x + 1, LADO, GRIS_OSCURO)
    moteado(t, (176, 192, 198), GRIS_OSCURO, 3, 0.06)
    return t


def pared():
    t = nuevo(PETROLEO)
    rect(t, 0, 0, LADO, 3, PETROLEO_CLARO)
    rect(t, 0, LADO - 4, LADO, LADO, PETROLEO_OSCURO)
    for x in range(0, LADO, 8):
        rect(t, x, 3, x + 1, LADO - 4, PETROLEO_OSCURO)
    moteado(t, PETROLEO_CLARO, PETROLEO_OSCURO, 4, 0.05)
    return t


def ventana():
    t = pared()
    rect(t, 5, 5, 27, 24, CREMA)
    rect(t, 7, 7, 25, 22, (150, 200, 216))
    rect(t, 15, 7, 17, 22, CREMA)
    rect(t, 7, 14, 25, 16, CREMA)
    rect(t, 9, 8, 13, 10, (205, 232, 240))
    rect(t, 4, 24, 28, 26, NARANJA)
    return t


def umbral():
    t = piso_madera()
    rect(t, 0, 0, LADO, 6, NARANJA)
    rect(t, 0, 6, LADO, 8, MADERA_OSCURA)
    return t


def escalera():
    t = nuevo(GRIS)
    for i in range(4):
        rect(t, 0, i * 8, LADO, i * 8 + 5, (190, 204, 210))
        rect(t, 0, i * 8 + 5, LADO, i * 8 + 8, GRIS_OSCURO)
    rect(t, 0, 0, 3, LADO, NARANJA)
    return t


def alfombra():
    t = nuevo(PETROLEO_CLARO)
    rect(t, 2, 2, LADO - 2, LADO - 2, PETROLEO)
    rect(t, 5, 5, LADO - 5, LADO - 5, PETROLEO_CLARO)
    rect(t, 2, 2, LADO - 2, 4, NARANJA)
    rect(t, 2, LADO - 4, LADO - 2, LADO - 2, NARANJA)
    return t


def calle():
    t = nuevo(ASFALTO)
    moteado(t, ASFALTO_CLARO, PETROLEO_OSCURO, 5, 0.07)
    return t


def calle_linea():
    t = calle()
    for x in range(2, LADO, 12):
        rect(t, x, 14, x + 7, 18, CREMA)
    return t


def anden():
    t = nuevo(ANDEN)
    rect(t, 0, 0, LADO, 1, ANDEN_OSCURO)
    rect(t, 0, 0, 1, LADO, ANDEN_OSCURO)
    rect(t, 16, 0, 17, LADO, ANDEN_OSCURO)
    moteado(t, CREMA, ANDEN_OSCURO, 6, 0.04)
    return t


def pasto():
    t = nuevo(VERDE)
    moteado(t, (126, 178, 108), VERDE_OSCURO, 7, 0.10)
    for i in range(5):
        x, y = int(ruido(i, 1, 8) * 28) + 2, int(ruido(i, 2, 8) * 26) + 3
        rect(t, x, y, x + 1, y + 3, VERDE_OSCURO)
    return t


def camino():
    t = nuevo(TIERRA)
    moteado(t, (196, 166, 124), (150, 118, 82), 9, 0.10)
    return t


def borde():
    """Arbusto y valla: sólido, con borde naranja de seguridad abajo."""
    t = pasto()
    rect(t, 0, 6, LADO, 24, VERDE_OSCURO)
    moteado(t, (104, 156, 88), (56, 100, 60), 10, 0.2)
    rect(t, 0, 24, LADO, 27, ANDEN_OSCURO)
    return t


def muro_edificio():
    t = nuevo(LADRILLO)
    for y in range(0, LADO, 8):
        rect(t, 0, y, LADO, y + 1, LADRILLO_OSCURO)
        for x in range((y // 8 % 2) * 8, LADO, 16):
            rect(t, x, y, x + 1, y + 8, LADRILLO_OSCURO)
    moteado(t, (196, 112, 88), LADRILLO_OSCURO, 11, 0.05)
    return t


def vacio():
    return nuevo(PETROLEO_OSCURO)


def transparente():
    return [[(0, 0, 0, 0) for _ in range(LADO)] for _ in range(LADO)]


def grieta():
    t = transparente()
    x, y = 6, 2
    for i in range(26):
        poner(t, x, y, PETROLEO_OSCURO)
        poner(t, x + 1, y, PETROLEO_OSCURO, 180)
        y += 1
        r = ruido(i, 3, 12)
        x += -1 if r < 0.35 else (1 if r > 0.65 else 0)
        if i == 12:
            for k in range(8):
                poner(t, x + k, y + k // 2, PETROLEO_OSCURO)
    return t


def polvo():
    t = transparente()
    for y in range(LADO):
        for x in range(LADO):
            if ruido(x, y, 13) < 0.18:
                poner(t, x, y, CREMA, 150)
    return t


def vidrio():
    t = transparente()
    for i in range(14):
        x, y = int(ruido(i, 4, 14) * 28) + 2, int(ruido(i, 5, 14) * 28) + 2
        rect(t, x, y, x + 2, y + 1, (205, 232, 240), 230)
        poner(t, x + 1, y + 1, (150, 200, 216), 230)
    return t


def escombro():
    t = transparente()
    for i in range(7):
        x, y = int(ruido(i, 6, 15) * 24) + 3, int(ruido(i, 7, 15) * 22) + 6
        w = 3 + int(ruido(i, 8, 15) * 4)
        rect(t, x, y, x + w, y + w - 1, GRIS_OSCURO if i % 2 else LADRILLO_OSCURO)
        rect(t, x, y, x + w, y + 1, GRIS)
    return t


def main():
    funciones = {"vacio": vacio, "piso_madera": piso_madera, "baldosa": baldosa, "balcon": balcon, "pared": pared,
                 "ventana": ventana, "umbral": umbral, "escalera": escalera, "alfombra": alfombra, "calle": calle,
                 "calle_linea": calle_linea, "anden": anden, "pasto": pasto, "camino": camino, "borde": borde,
                 "muro_edificio": muro_edificio, "grieta": grieta, "polvo": polvo, "vidrio": vidrio,
                 "escombro": escombro}
    filas = (len(TILES) + COLUMNAS - 1) // COLUMNAS
    ancho, alto = COLUMNAS * LADO, filas * LADO
    hoja = [[(0, 0, 0, 0) for _ in range(ancho)] for _ in range(alto)]
    for i, nombre in enumerate(TILES):
        t = funciones[nombre]()
        ox, oy = (i % COLUMNAS) * LADO, (i // COLUMNAS) * LADO
        for y in range(LADO):
            for x in range(LADO):
                hoja[oy + y][ox + x] = t[y][x]
    destino = os.path.join(RAIZ, "Assets", "Mundo", "tileset.png")
    png_simple.escribir(destino, ancho, alto, hoja)
    print("escrito", os.path.relpath(destino, RAIZ), ancho, "x", alto, "con", len(TILES), "tiles")


if __name__ == "__main__":
    main()
