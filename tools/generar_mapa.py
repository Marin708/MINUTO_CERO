#!/usr/bin/env python3
"""Genera los mapas de MINUTO CERO y las escenas de los niveles (sin Pillow).

Escribe:
  Resources/Mundo/apartamento.txt         32 x 20 tiles (niveles 1 y 2)
  Resources/Mundo/apartamento_danos.txt   la misma forma con la capa de daños leves del nivel 2 (grietas, polvo, vidrios, escombros)
  Resources/Mundo/calle.txt               40 x 24 tiles (nivel 3: calle y parque)
  Scenes/Niveles/Nivel1.tscn, Nivel2.tscn, Nivel3.tscn   con un Marker2D por cada objeto, personaje y zona

Cada carácter de los .txt es un tile (leyenda en LEYENDA; los números de tile son los de tools/generar_tileset.py).
Las líneas que empiezan con ';' son comentarios. Los marcadores llevan metadatos: clase ("prop", "npc", "zona",
"spawn"), tipo, etiqueta (la decisión, por ejemplo D1) y, en las zonas, radio en píxeles. Un marcador está en el
suelo, en la base (los pies) del objeto: x = centro del tile, y = borde de abajo del tile.

Comprueba que el mapa sea transitable (que todos los marcadores y el punto de inicio se alcancen) y que las
puertas y los NPC tengan una zona libre alrededor.

Uso:  python tools/generar_mapa.py
"""
import os
import random
from collections import deque

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LADO = 32

#: carácter -> nombre del tile
LEYENDA = {
    ".": "vacio", "F": "piso_madera", "K": "baldosa", "B": "balcon", "P": "pared", "V": "ventana",
    "D": "umbral", "S": "escalera", "A": "alfombra", "c": "calle", "l": "calle_linea", "a": "anden",
    "g": "pasto", "p": "camino", "x": "borde", "m": "muro_edificio",
}
SOLIDOS = set("PVx.m")
#: capa de daños
LEYENDA_DANOS = {"r": "grieta", "u": "polvo", "v": "vidrio", "e": "escombro"}


class Mapa:
    def __init__(self, ancho, alto, relleno):
        self.ancho, self.alto = ancho, alto
        self.celdas = [[relleno] * ancho for _ in range(alto)]

    def poner(self, x, y, ch):
        if 0 <= x < self.ancho and 0 <= y < self.alto:
            self.celdas[y][x] = ch

    def rect(self, x0, y0, x1, y1, ch):
        """Rellena el rectángulo de tiles (x0, y0) a (x1, y1), ambos incluidos."""
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.poner(x, y, ch)

    def en(self, x, y):
        return self.celdas[y][x] if 0 <= x < self.ancho and 0 <= y < self.alto else "."

    def texto(self, titulo, leyenda):
        cab = ["; " + titulo, "; %d x %d tiles. Un carácter por tile." % (self.ancho, self.alto)]
        cab += ["; %s = %s" % (k, v) for k, v in leyenda.items()]
        return "\n".join(cab + ["".join(f) for f in self.celdas]) + "\n"


# ---------------------------------------------------------------------------
# Apartamento (niveles 1 y 2)
def apartamento():
    m = Mapa(32, 20, "P")
    m.rect(1, 2, 13, 10, "F")      # sala-comedor
    m.rect(5, 5, 9, 8, "A")        # alfombra bajo la mesa
    m.rect(15, 2, 20, 8, "K")      # cocina
    m.rect(14, 4, 14, 6, "K")      # paso sala-cocina
    m.rect(23, 2, 30, 9, "F")      # habitación
    m.rect(21, 5, 22, 6, "F")      # paso cocina-habitación
    m.rect(1, 12, 30, 15, "F")     # pasillo
    m.rect(2, 13, 24, 14, "A")     # alfombra del pasillo
    m.rect(6, 11, 8, 11, "F")      # paso sala-pasillo
    m.rect(17, 9, 18, 11, "K")     # paso cocina-pasillo
    m.rect(26, 10, 27, 11, "F")    # paso habitación-pasillo
    m.rect(26, 16, 30, 18, "F")    # vestíbulo de salida
    m.rect(29, 17, 30, 18, "S")    # escalera
    m.rect(2, 17, 9, 18, "B")      # balcón
    m.rect(5, 16, 6, 16, "F")      # puerta del balcón
    for x in (3, 4, 10, 11, 17, 26, 27):
        m.poner(x, 1, "V")         # ventanas en la pared de arriba
    m.rect(4, 12, 4, 12, "D") if False else None
    return m


def danos_apartamento(m):
    """La capa de daños leves del nivel 2: solo dibujo (sin colisión)."""
    azar = random.Random(1999)
    d = Mapa(m.ancho, m.alto, ".")
    libres = [(x, y) for y in range(m.alto) for x in range(m.ancho) if m.en(x, y) in "FKAB"]
    junto_pared = [(x, y) for x, y in libres if m.en(x, y - 1) in "PV" or m.en(x - 1, y) == "P" or m.en(x + 1, y) == "P"]
    for x, y in azar.sample(junto_pared, 12):
        d.poner(x, y, "r")
    for x, y in azar.sample(libres, 26):
        if d.en(x, y) == ".":
            d.poner(x, y, "u")
    for x in (3, 4, 10, 11, 26, 27):
        d.poner(x, 2, "v")
        if azar.random() < 0.6:
            d.poner(x, 3, "v")
    for x, y in ((11, 5), (12, 6), (12, 3), (24, 5), (27, 8), (16, 4), (19, 6), (8, 9), (6, 9)):
        d.poner(x, y, "e")
    return d


MARCADORES_APTO = [
    # (nombre, clase, tipo, etiqueta, tx, ty, radio)
    ("Prop_Mesa", "prop", "mesa", "", 7, 7, 0),
    ("Prop_Sofa", "prop", "sofa", "", 4, 10, 0),
    ("Prop_MuebleTV", "prop", "mueble_tv", "", 8, 3, 0),
    ("Prop_Estante_D1", "prop", "estante", "D1", 12, 4, 0),
    ("Prop_GasEstufa_D3", "prop", "gas_estufa", "D3", 17, 3, 0),
    ("Prop_Nevera", "prop", "nevera", "", 19, 3, 0),
    ("Prop_CuadroCama_D2", "prop", "cuadro_cama", "D2", 27, 7, 0),
    ("Prop_Repisa_D4", "prop", "repisa", "D4", 24, 4, 0),
    ("Prop_Armario", "prop", "armario", "kit", 29, 4, 0),
    ("Prop_PuertaSalida", "prop", "puerta_salida", "salida", 29, 11, 0),
    ("Npc_Marta", "npc", "marta", "", 17, 6, 0),
    ("Zona_Mesa", "zona", "mesa_segura", "", 7, 7, 56),
    ("Zona_Ventana", "zona", "ventana", "", 4, 3, 64),
    ("Zona_Puerta", "zona", "puerta", "", 29, 12, 80),
    ("Zona_Escalera", "zona", "escalera", "", 29, 17, 56),
]


def apartamento_marcadores(nivel):
    lista = list(MARCADORES_APTO)
    if nivel == 1:
        lista += [("Spawn", "spawn", "", "", 8, 13, 0), ("Npc_Lucia", "npc", "lucia", "", 12, 13, 0)]
    else:
        lista += [("Spawn", "spawn", "", "", 11, 9, 0),
                  ("Item_Zapatos", "item", "zapatos", "", 3, 8, 0),
                  ("Item_Mochila", "item", "mochila", "", 12, 7, 0),
                  ("Item_Linterna", "item", "linterna", "", 9, 9, 0)]
    return lista


# ---------------------------------------------------------------------------
# Calle y parque (nivel 3)
def calle():
    m = Mapa(40, 24, "g")
    m.rect(0, 0, 39, 0, "x")
    m.rect(0, 23, 39, 23, "x")
    m.rect(0, 0, 0, 23, "x")
    m.rect(39, 0, 39, 23, "x")
    m.rect(1, 10, 38, 13, "c")
    m.rect(1, 11, 38, 11, "l")
    m.rect(1, 8, 38, 9, "a")
    m.rect(1, 14, 38, 15, "a")
    m.rect(1, 1, 9, 7, "m")        # edificio de Sami
    m.rect(11, 2, 16, 7, "m")      # edificio vecino agrietado
    m.rect(20, 3, 26, 7, "m")
    m.rect(1, 17, 8, 22, "m")
    m.rect(20, 17, 38, 22, "g")
    m.rect(20, 19, 38, 19, "p")    # senderos del parque
    m.rect(29, 16, 29, 22, "p")
    m.rect(11, 8, 16, 9, "x")      # andén bloqueado bajo el edificio agrietado
    m.rect(17, 14, 20, 15, "x")    # andén bloqueado por el cable caído
    for x in range(30, 38):
        m.poner(x, 4, "x")
    return m


MARCADORES_CALLE = [
    ("Spawn", "spawn", "", "", 5, 9, 0),
    ("Npc_Rosa_D12", "npc", "rosa", "D12", 8, 9, 0),
    ("Npc_Tomas_D14", "npc", "tomas", "D14", 24, 9, 0),
    ("Npc_Marta", "npc", "marta", "", 28, 19, 0),
    ("Npc_Lucia", "npc", "lucia", "", 32, 19, 0),
    ("Prop_Edificio", "prop", "edificio", "", 13, 7, 0),
    ("Prop_Escombros", "prop", "escombros", "", 12, 10, 0),
    ("Prop_Barrera1", "prop", "barrera", "", 11, 9, 0),
    ("Prop_Barrera2", "prop", "barrera", "", 16, 9, 0),
    ("Prop_Poste", "prop", "poste", "", 19, 15, 0),
    ("Prop_Barrera3", "prop", "barrera", "", 17, 15, 0),
    ("Prop_Carro", "prop", "carro", "", 25, 15, 0),
    ("Prop_Arbol1", "prop", "arbol", "", 22, 18, 0),
    ("Prop_Arbol2", "prop", "arbol", "", 35, 18, 0),
    ("Prop_Arbol3", "prop", "arbol", "", 24, 22, 0),
    ("Prop_Arbol4", "prop", "arbol", "", 36, 22, 0),
    ("Prop_Arbol5", "prop", "arbol", "", 18, 7, 0),
    ("Prop_Banca", "prop", "banca", "", 26, 20, 0),
    ("Prop_Carpa", "prop", "carpa", "", 30, 20, 0),
    ("Zona_Peligro_D13", "zona", "peligro", "D13", 13, 9, 112),
    ("Zona_Cable", "zona", "cable", "", 18, 14, 48),
    ("Zona_Llegada", "zona", "llegada", "", 30, 19, 72),
]


# ---------------------------------------------------------------------------
# Salidas
def tscn(nombre, script, exterior, marcadores):
    t = ['[gd_scene load_steps=2 format=3]', '',
         '[ext_resource type="Script" path="res://Scripts/Mundo/%s.gd" id="1_nivel"]' % script, '',
         '[node name="%s" type="Node2D" groups=["nivel"]]' % nombre, 'script = ExtResource("1_nivel")',
         'metadata/exterior = %s' % ("true" if exterior else "false"), '',
         '[node name="Suelo" type="Node2D" parent="."]', '',
         '[node name="Objetos" type="Node2D" parent="."]', 'y_sort_enabled = true', '',
         '[node name="Marcadores" type="Node2D" parent="."]', '']
    for n, clase, tipo, etiqueta, tx, ty, radio in marcadores:
        x, y = tx * LADO + LADO // 2, (ty * LADO + LADO) if clase != "spawn" else (ty * LADO + LADO - 4)
        t += ['[node name="%s" type="Marker2D" parent="Marcadores"]' % n, "position = Vector2(%d, %d)" % (x, y),
              'metadata/clase = "%s"' % clase]
        if tipo:
            t.append('metadata/tipo = "%s"' % tipo)
        if etiqueta:
            t.append('metadata/etiqueta = "%s"' % etiqueta)
        if radio:
            t.append("metadata/radio = %d" % radio)
        t.append("")
    return "\n".join(t)


def accesible(m, marcadores):
    """Comprueba que desde el Spawn se llegue a una casilla libre junto a cada marcador."""
    inicio = next(((tx, ty) for n, c, t, e, tx, ty, r in marcadores if c == "spawn"), None)
    vistos = {inicio}
    cola = deque([inicio])
    while cola:
        x, y = cola.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if (nx, ny) not in vistos and m.en(nx, ny) not in SOLIDOS:
                vistos.add((nx, ny))
                cola.append((nx, ny))
    problemas = []
    ocupados = {(tx, ty) for n, c, t, e, tx, ty, r in marcadores if c in ("prop", "npc")}
    for n, c, t, e, tx, ty, r in marcadores:
        if c in ("npc", "prop") and t != "edificio":   # el edificio es un decorado sobre un muro: no hace falta llegar
            # alguna casilla libre a menos de 2 tiles del marcador que se alcance
            ok = any((tx + dx, ty + dy) in vistos for dx in range(-2, 3) for dy in range(-2, 3))
            if not ok:
                problemas.append("no se llega a " + n)
    # zona libre alrededor de NPC, puertas y objetos interactivos: ningún otro marcador a menos de 1 tile
    for n, c, t, e, tx, ty, r in marcadores:
        if c == "npc" or t == "puerta_salida" or e:
            for n2, c2, t2, e2, tx2, ty2, r2 in marcadores:
                if n2 != n and c2 in ("prop", "npc") and abs(tx - tx2) + abs(ty - ty2) < 2:
                    problemas.append("%s está pegado a %s" % (n, n2))
    return problemas


def escribir(ruta, texto):
    destino = os.path.join(RAIZ, ruta)
    os.makedirs(os.path.dirname(destino), exist_ok=True)
    with open(destino, "w", encoding="utf-8", newline="\n") as f:
        f.write(texto)
    print("escrito", ruta)


def main():
    apto = apartamento()
    danos = danos_apartamento(apto)
    escribir("Resources/Mundo/apartamento.txt", apto.texto("MINUTO CERO - apartamento del cuarto piso (niveles 1 y 2)", LEYENDA))
    escribir("Resources/Mundo/apartamento_danos.txt", danos.texto("MINUTO CERO - daños leves del apartamento (nivel 2)", LEYENDA_DANOS))
    c = calle()
    escribir("Resources/Mundo/calle.txt", c.texto("MINUTO CERO - calle y parque de Villa Cafetal (nivel 3)", LEYENDA))
    problemas = []
    for nivel, mapa, marc in ((1, apto, apartamento_marcadores(1)), (2, apto, apartamento_marcadores(2)), (3, c, MARCADORES_CALLE)):
        problemas += ["nivel %d: %s" % (nivel, p) for p in accesible(mapa, marc)]
        escribir("Scenes/Niveles/Nivel%d.tscn" % nivel, tscn("Nivel%d" % nivel, "Nivel%d" % nivel, nivel == 3, marc))
    if problemas:
        print("PROBLEMAS:")
        for p in problemas:
            print(" -", p)
        raise SystemExit(1)
    print("Mapas transitables y con zonas libres.")


if __name__ == "__main__":
    main()
