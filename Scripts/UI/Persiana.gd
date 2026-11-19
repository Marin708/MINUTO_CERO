class_name Persiana
extends Control
## La transición del juego: una persiana horizontal de listones azul noche con un borde de franjas de precaución.
## `cierre` va de 0 (abierta, no se ve nada) a 1 (cerrada del todo). Flujo la anima al cambiar de pantalla.

const LISTONES := 9
const BORDE := 6.0

var cierre := 0.0:
	set(v):
		cierre = clampf(v, 0.0, 1.0)
		visible = cierre > 0.0
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func _draw() -> void:
	var alto_liston := size.y / LISTONES
	var alto := alto_liston * cierre
	if cierre >= 0.999:
		draw_rect(Rect2(Vector2.ZERO, size), EstiloUI.AZUL_NOCHE)
		return
	for i in LISTONES:
		var y := i * alto_liston
		draw_rect(Rect2(0, y, size.x, alto), EstiloUI.AZUL_NOCHE)
		# El borde de abajo de cada listón es una cinta de franjas; se ve cuando el listón ya tiene cuerpo
		var franja := minf(BORDE, alto)
		if franja >= 2.0:
			Franjas.pintar(self, Rect2(0, y + alto - franja, size.x, franja), EstiloUI.NARANJA, Color("0a0f12"), 8.0, cierre * 40.0)
