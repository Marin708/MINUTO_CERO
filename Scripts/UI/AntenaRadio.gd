class_name AntenaRadio
extends Control
## La antena del marco de transmisión de Lucía: un mástil con ondas que se encienden en secuencia.

var _t := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(28, 26)
	size = custom_minimum_size


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var base := Vector2(14, 26)
	var punta := Vector2(14, 8)
	draw_line(base, punta, EstiloUI.NARANJA, 2.0)
	draw_line(base + Vector2(-6, 0), base + Vector2(6, 0), EstiloUI.NARANJA, 2.0)
	draw_circle(punta, 2.5, EstiloUI.NARANJA)
	# Tres ondas: se encienden una tras otra
	var paso := int(_t * 3.0) % 4
	for i in 3:
		var color := EstiloUI.CREMA if paso > i else Color(EstiloUI.CREMA, 0.25)
		var r := 5.0 + i * 4.0
		draw_arc(punta, r, -PI * 0.85, -PI * 0.15, 8, color, 1.5)
