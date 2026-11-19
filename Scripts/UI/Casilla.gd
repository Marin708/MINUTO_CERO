class_name Casilla
extends Control
## Una casilla de papel que se marca con lápiz: cuadrado con borde oscuro y una palomita trazada a mano.
## Al marcarla el trazo se dibuja poco a poco (animar = true). La usan el HUD, la evaluación y la galería.

@export var lado := 12.0
@export var color_lapiz := Color("2b3a40")
var marcada := false
var _trazo := 0.0   # de 0 a 1: cuánto de la palomita está dibujado


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(14, 14)


## Marca o desmarca. Con `animar` el lápiz traza la palomita en medio segundo.
func poner(valor: bool, animar: bool = true) -> void:
	if valor == marcada:
		return
	marcada = valor
	if not valor:
		_trazo = 0.0
		queue_redraw()
	elif animar and is_inside_tree():
		_trazo = 0.0
		var t := create_tween()
		t.tween_method(func(v: float) -> void:
			_trazo = v
			queue_redraw(), 0.0, 1.0, 0.35)
		Audio.efecto("lapiz_marca")
	else:
		_trazo = 1.0
		queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2(1, 1), Vector2(lado, lado))
	draw_rect(r, Color("fbf5e4"))
	draw_rect(r, EstiloUI.TINTA, false, 2.0)
	if marcada:
		# Dos trazos: baja y sube (la palomita)
		var a := Vector2(3, lado * 0.55)
		var b := Vector2(lado * 0.42, lado - 1)
		var c := Vector2(lado + 3, -1)
		var primero := clampf(_trazo * 2.0, 0.0, 1.0)
		var segundo := clampf(_trazo * 2.0 - 1.0, 0.0, 1.0)
		draw_line(a, a.lerp(b, primero), color_lapiz, 2.0)
		if segundo > 0.0:
			draw_line(b, b.lerp(c, segundo), color_lapiz, 2.0)
