class_name MarcaOk
extends Control
## Una marca pequeña dibujada por código (las fuentes no traen ✔ ni ✖): ✔ turquesa si está bien, ✖ roja si no.
## La usan la tarjeta de retroalimentación (lista del kit) y las secciones de una sola línea.

var ok := true


static func crear(es_ok: bool, lado: float = 14.0) -> MarcaOk:
	var m := MarcaOk.new()
	m.ok = es_ok
	m.custom_minimum_size = Vector2(lado, lado)
	m.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	return m


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var s := minf(size.x, size.y)
	var color := EstiloUI.TURQUESA if ok else EstiloUI.ROJO
	draw_rect(Rect2(0, 0, s, s), EstiloUI.AZUL_NOCHE)
	draw_rect(Rect2(0, 0, s, s), color, false, 2.0)
	if ok:
		draw_polyline(PackedVector2Array([Vector2(s * 0.2, s * 0.55), Vector2(s * 0.43, s * 0.78), Vector2(s * 0.82, s * 0.22)]), color, 2.5)
	else:
		draw_line(Vector2(s * 0.25, s * 0.25), Vector2(s * 0.75, s * 0.75), color, 2.5)
		draw_line(Vector2(s * 0.75, s * 0.25), Vector2(s * 0.25, s * 0.75), color, 2.5)
