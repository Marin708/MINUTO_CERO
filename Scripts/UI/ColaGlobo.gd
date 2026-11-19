class_name ColaGlobo
extends Control
## La cola del globo de cómic: un triángulo de 2 px de borde que sale del borde de arriba del globo y apunta al que habla.
## El globo la coloca cada cuadro: `lean` es cuánto se inclina la punta hacia el personaje.

var relleno := EstiloUI.CREMA
var borde := EstiloUI.TINTA
var lean := 0.0
const ALTO := 14.0
const MEDIO_ANCHO := 9.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(MEDIO_ANCHO * 2.0, ALTO)
	size = custom_minimum_size


func _draw() -> void:
	var base_y := ALTO
	var izq := Vector2(0, base_y)
	var der := Vector2(MEDIO_ANCHO * 2.0, base_y)
	var punta := Vector2(MEDIO_ANCHO + lean, 0)
	draw_colored_polygon(PackedVector2Array([izq, punta, der]), relleno)
	draw_line(izq, punta, borde, 2.0)
	draw_line(punta, der, borde, 2.0)
	# Tapa el borde del globo entre las dos patas, para que la cola y el globo sean una sola pieza
	draw_rect(Rect2(izq.x + 1.0, base_y - 1.0, MEDIO_ANCHO * 2.0 - 2.0, 3.0), relleno)
