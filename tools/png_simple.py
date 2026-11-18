"""Lector y escritor mínimo de PNG (8 bits, RGB o RGBA) usando solo la biblioteca estándar.
Sirve para los scripts de `tools/` sin instalar Pillow.

    ancho, alto, pixeles = leer("a.png")        # pixeles: lista de filas; cada fila es una lista de (r, g, b, a)
    escribir("b.png", ancho, alto, pixeles)
"""
import struct
import zlib


def leer(ruta):
    datos = open(ruta, "rb").read()
    if datos[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("no es un PNG: " + ruta)
    pos = 8
    idat = b""
    ancho = alto = tipo = profundidad = 0
    paleta = None
    while pos < len(datos):
        largo, nombre = struct.unpack(">I4s", datos[pos:pos + 8])
        cuerpo = datos[pos + 8:pos + 8 + largo]
        pos += 12 + largo
        if nombre == b"IHDR":
            ancho, alto, profundidad, tipo, _, _, entrelazado = struct.unpack(">IIBBBBB", cuerpo)
            if profundidad != 8 or tipo not in (2, 3, 6) or entrelazado:
                raise ValueError("solo PNG de 8 bits, sin entrelazado, RGB, RGBA o paleta")
        elif nombre == b"PLTE":
            paleta = [tuple(cuerpo[i:i + 3]) for i in range(0, len(cuerpo), 3)]
        elif nombre == b"IDAT":
            idat += cuerpo
    canales = {2: 3, 3: 1, 6: 4}[tipo]
    bruto = zlib.decompress(idat)
    fila_bytes = ancho * canales
    anterior = bytearray(fila_bytes)
    filas = []
    p = 0
    for _ in range(alto):
        filtro = bruto[p]
        actual = bytearray(bruto[p + 1:p + 1 + fila_bytes])
        p += 1 + fila_bytes
        for i in range(fila_bytes):
            a = actual[i - canales] if i >= canales else 0
            b = anterior[i]
            c = anterior[i - canales] if i >= canales else 0
            if filtro == 1:
                actual[i] = (actual[i] + a) & 255
            elif filtro == 2:
                actual[i] = (actual[i] + b) & 255
            elif filtro == 3:
                actual[i] = (actual[i] + ((a + b) >> 1)) & 255
            elif filtro == 4:
                pa, pb, pc = abs(b - c), abs(a - c), abs(a + b - 2 * c)
                pr = a if pa <= pb and pa <= pc else (b if pb <= pc else c)
                actual[i] = (actual[i] + pr) & 255
        anterior = actual
        if tipo == 6:
            filas.append([tuple(actual[i:i + 4]) for i in range(0, fila_bytes, 4)])
        elif tipo == 2:
            filas.append([(actual[i], actual[i + 1], actual[i + 2], 255) for i in range(0, fila_bytes, 3)])
        else:
            filas.append([paleta[v] + (255,) for v in actual])
    return ancho, alto, filas


def _trozo(nombre, cuerpo):
    return struct.pack(">I", len(cuerpo)) + nombre + cuerpo + struct.pack(">I", zlib.crc32(nombre + cuerpo) & 0xFFFFFFFF)


def escribir(ruta, ancho, alto, pixeles):
    crudo = bytearray()
    for fila in pixeles:
        crudo.append(0)
        for r, g, b, a in fila:
            crudo += bytes((r, g, b, a))
    png = b"\x89PNG\r\n\x1a\n" + _trozo(b"IHDR", struct.pack(">IIBBBBB", ancho, alto, 8, 6, 0, 0, 0))
    png += _trozo(b"IDAT", zlib.compress(bytes(crudo), 9)) + _trozo(b"IEND", b"")
    open(ruta, "wb").write(png)
