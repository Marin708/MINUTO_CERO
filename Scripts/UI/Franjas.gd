class_name Franjas
extends Control
## Franjas diagonales naranja y negro (cinta de precaución): el detalle de la identidad en títulos, botones y pausa.
## Es un Control normal: se le da un tamaño mínimo (por ejemplo 8 px de alto) y rellena todo su ancho.
##   var f := Franjas.new(); f.custom_minimum_size = Vector2(0, 8); contenedor.add_child(f)
## Otros controles que quieran la cinta dentro de su propio dibujo usan Franjas.pintar().

@export var color_a := EstiloUI.NARANJA
@export var color_b := Color("0a0f12")
## Ancho de cada franja (en píxeles, medido en horizontal).
@export var ancho_franja := 8.0
## Desplazamiento (anima las franjas).
var desplazamiento := 0.0:
	set(v):
		desplazamiento = v
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	custom_minimum_size = Vector2(0, 6)


func _draw() -> void:
	pintar(self, Rect2(Vector2.ZERO, size), color_a, color_b, ancho_franja, desplazamiento)


## Dibuja la cinta de precaución dentro de `rect` en cualquier CanvasItem (dentro de su _draw), recortada al rectángulo.
static func pintar(ci: CanvasItem, rect: Rect2, a: Color = EstiloUI.NARANJA, b: Color = Color("0a0f12"), ancho: float = 8.0, desplazamiento_x: float = 0.0) -> void:
	ci.draw_rect(rect, b)
	var alto := rect.size.y
	var x := -alto - fmod(desplazamiento_x, ancho * 2.0) - ancho * 2.0
	while x < rect.size.x + alto:
		# Un paralelogramo a 45 grados, recortado a los lados del rectángulo
		var puntos := PackedVector2Array([
			Vector2(x, alto), Vector2(x + ancho, alto),
			Vector2(x + ancho + alto, 0), Vector2(x + alto, 0)])
		var recortado := Geometry2D.intersect_polygons(puntos, PackedVector2Array([
			Vector2(0, 0), Vector2(rect.size.x, 0), Vector2(rect.size.x, alto), Vector2(0, alto)]))
		for poligono in recortado:
			var movido := PackedVector2Array()
			for p in poligono:
				movido.append(p + rect.position)
			ci.draw_colored_polygon(movido, a)
		x += ancho * 2.0
