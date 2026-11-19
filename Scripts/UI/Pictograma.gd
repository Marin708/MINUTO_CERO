class_name Pictograma
extends Control
## Pictograma de señal de seguridad dibujado por código (las fuentes del juego no traen ✔ ⚠ ✖):
##   ACIERTO  círculo turquesa con ✔     PRECAUCION  triángulo ámbar con !     RIESGO  octágono rojo con ✖
## Siempre de línea gruesa y colores de la paleta, para que se lea también sin color (formas distintas).

enum Tipo { ACIERTO, PRECAUCION, RIESGO }

@export var tipo: Tipo = Tipo.ACIERTO:
	set(v):
		tipo = v
		queue_redraw()


static func para_titulo(titulo: String, lado: float = 40.0) -> Pictograma:
	var p := Pictograma.new()
	p.tipo = Tipo.ACIERTO if titulo == "Muy bien" else (Tipo.PRECAUCION if titulo == "Casi" else Tipo.RIESGO)
	p.custom_minimum_size = Vector2(lado, lado)
	return p


static func color_de(titulo: String) -> Color:
	return EstiloUI.TURQUESA if titulo == "Muy bien" else (EstiloUI.AMBAR if titulo == "Casi" else EstiloUI.ROJO)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(32, 32)


func _draw() -> void:
	var l := minf(size.x, size.y)
	var c := Vector2(size.x, size.y) / 2.0
	var s := l / 32.0
	var blanco := EstiloUI.CREMA
	match tipo:
		Tipo.ACIERTO:
			_circulo(c, 15.0 * s, EstiloUI.TURQUESA)
			var linea := PackedVector2Array([c + Vector2(-8, 0) * s, c + Vector2(-3, 6) * s, c + Vector2(8, -6) * s])
			draw_polyline(linea, blanco, 3.5 * s)
		Tipo.PRECAUCION:
			var tri := PackedVector2Array([c + Vector2(0, -15) * s, c + Vector2(16, 13) * s, c + Vector2(-16, 13) * s])
			draw_colored_polygon(tri, EstiloUI.AMBAR)
			tri.append(tri[0])
			draw_polyline(tri, EstiloUI.TINTA, 2.0 * s)
			draw_rect(Rect2(c + Vector2(-1.8, -6) * s, Vector2(3.6, 11) * s), EstiloUI.TINTA)
			draw_rect(Rect2(c + Vector2(-1.8, 8) * s, Vector2(3.6, 3.6) * s), EstiloUI.TINTA)
		Tipo.RIESGO:
			var oct := PackedVector2Array()
			for i in 8:
				oct.append(c + Vector2.from_angle(PI / 8.0 + i * PI / 4.0) * 16.5 * s)
			draw_colored_polygon(oct, EstiloUI.ROJO)
			oct.append(oct[0])
			draw_polyline(oct, EstiloUI.CREMA, 2.0 * s)
			draw_line(c + Vector2(-6, -6) * s, c + Vector2(6, 6) * s, blanco, 3.5 * s)
			draw_line(c + Vector2(6, -6) * s, c + Vector2(-6, 6) * s, blanco, 3.5 * s)


func _circulo(c: Vector2, radio: float, color: Color) -> void:
	draw_circle(c, radio, color)
	draw_arc(c, radio, 0.0, TAU, 32, EstiloUI.CREMA, 2.0)
