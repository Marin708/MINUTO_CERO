class_name IndicadorScroll
extends Control
## «▼ Sigue leyendo»: una flecha pulsante que ModalBase muestra sobre el pie mientras queda contenido debajo.
## (Las fuentes del juego no traen ▼: el triángulo se dibuja por código.)

var _t := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(128, 16)


func _process(delta: float) -> void:
	if visible:
		_t += delta
		queue_redraw()


func _draw() -> void:
	var latido := 0.65 + 0.35 * sin(_t * 6.0)
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Color(EstiloUI.AZUL_NOCHE, 0.92))
	draw_rect(r, Color(EstiloUI.NARANJA, latido), false, 2.0)
	var abajo := 1.5 * sin(_t * 6.0)
	var tri := PackedVector2Array([Vector2(8, 5 + abajo), Vector2(16, 5 + abajo), Vector2(12, 11 + abajo)])
	draw_colored_polygon(tri, EstiloUI.NARANJA)
	var f := EstiloUI.fuente_titulo()
	if f != null:
		draw_string(f, Vector2(22, 11), "Sigue leyendo", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, EstiloUI.CREMA)
