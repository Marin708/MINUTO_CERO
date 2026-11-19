class_name Grano
extends Control
## Grano de película sobre una pantalla oscura (el boletín de la brigada y las pantallas de evaluación): un ruido
## de puntos que cambia unas diez veces por segundo. Se generan pocas imágenes una vez y se van alternando.

const ANCHO := 160
const ALTO := 90
const CUADROS := 4

@export var intensidad := 0.16

var _texturas: Array[ImageTexture] = []
var _t := 0.0
var _actual := 0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	for i in CUADROS:
		var imagen := Image.create(ANCHO, ALTO, false, Image.FORMAT_RGBA8)
		for y in ALTO:
			for x in ANCHO:
				if randf() < 0.22:
					imagen.set_pixel(x, y, Color(1, 1, 1, randf() * intensidad))
		_texturas.append(ImageTexture.create_from_image(imagen))


func _process(delta: float) -> void:
	_t += delta
	if _t >= 0.1:
		_t = 0.0
		_actual = (_actual + 1 + randi() % (CUADROS - 1)) % CUADROS
		queue_redraw()


func _draw() -> void:
	if _texturas.is_empty():
		return
	draw_texture_rect(_texturas[_actual], Rect2(Vector2.ZERO, size), false)
