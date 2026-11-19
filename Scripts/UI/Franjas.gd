class_name Franjas
extends Control
## Franjas diagonales naranja y negro (cinta de precaución): el detalle de la identidad en títulos, botones y pausa.
## Es un Control normal: se le da un tamaño mínimo (por ejemplo 8 px de alto) y rellena todo su ancho.
##   var f := Franjas.new(); f.custom_minimum_size = Vector2(0, 8); contenedor.add_child(f)

@export var color_a := EstiloUI.NARANJA
@export var color_b := Color("0a0f12")
## Ancho de cada franja (en píxeles, medido en horizontal).
@export var ancho_franja := 8.0
## Desplazamiento (se anima en la persiana de transición).
var desplazamiento := 0.0:
	set(v):
		desplazamiento = v
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	custom_minimum_size = Vector2(0, 6)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), color_b)
	var alto := size.y
	var x := -alto - fmod(desplazamiento, ancho_franja * 2.0) - ancho_franja * 2.0
	while x < size.x + alto:
		# Un paralelogramo inclinado a 45 grados
		draw_colored_polygon(PackedVector2Array([
			Vector2(x, alto), Vector2(x + ancho_franja, alto),
			Vector2(x + ancho_franja + alto, 0), Vector2(x + alto, 0)]), color_a)
		x += ancho_franja * 2.0
