#!/usr/bin/env python3
"""Genera los SpriteFrames de los personajes (Resources/Personajes/frames_<id>.tres) a partir de Assets/Personajes/personajes.png.

personajes.png mide 256 x 128: cuadros de 64 x 64, 4 columnas (Lucía, Marta/Mamá, Doña Rosa, Tomás) y 2 filas
(fila 1 = animación "normal", fila 2 = "asustado"; un solo cuadro cada una).

Uso:  python tools/generar_frames.py
"""
import os

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PERSONAJES = ["lucia", "marta", "rosa", "tomas"]
ANIMACIONES = ["normal", "asustado"]


def escribir(indice, nombre):
    lineas = ['[gd_resource type="SpriteFrames" load_steps=4 format=3]', "",
              '[ext_resource type="Texture2D" path="res://Assets/Personajes/personajes.png" id="1_hoja"]', ""]
    for fila, anim in enumerate(ANIMACIONES):
        lineas += ['[sub_resource type="AtlasTexture" id="Atlas_%s"]' % anim, 'atlas = ExtResource("1_hoja")',
                   "region = Rect2(%d, %d, 64, 64)" % (indice * 64, fila * 64), ""]
    lineas += ["[resource]", "animations = [{"]
    bloques = []
    for anim in ANIMACIONES:
        bloques.append('"frames": [{\n"duration": 1.0,\n"texture": SubResource("Atlas_%s")\n}],\n"loop": true,\n"name": &"%s",\n"speed": 5.0' % (anim, anim))
    lineas.append("}, {\n".join(bloques) + "}]")
    ruta = os.path.join(RAIZ, "Resources", "Personajes", "frames_%s.tres" % nombre)
    os.makedirs(os.path.dirname(ruta), exist_ok=True)
    with open(ruta, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lineas) + "\n")
    print("escrito", os.path.relpath(ruta, RAIZ))


def main():
    for i, n in enumerate(PERSONAJES):
        escribir(i, n)


if __name__ == "__main__":
    main()
