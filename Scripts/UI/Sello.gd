class_name Sello
extends Control
## Un sello de goma: un rectángulo de borde grueso con un texto en mayúsculas, un poco girado, que cae con un golpe.
##   var s := Sello.crear("EVALUACIÓN DE INGRESO", EstiloUI.ROJO_TINTA); padre.add_child(s); s.estampar()

var texto := "SELLO"
var color := EstiloUI.ROJO_TINTA
var tamano_texto := 14
var angulo := -0.14   # radianes: un sello nunca queda derecho


static func crear(p_texto: String, p_color: Color = EstiloUI.ROJO_TINTA, p_tamano: int = 14, p_angulo: float = -0.14) -> Sello:
	var s := Sello.new()
	s.texto = p_texto
	s.color = p_color
	s.tamano_texto = p_tamano
	s.angulo = p_angulo
	var f := EstiloUI.fuente_titulo()
	var ancho := f.get_string_size(p_texto, HORIZONTAL_ALIGNMENT_LEFT, -1, p_tamano).x if f != null else 120.0
	s.custom_minimum_size = Vector2(ancho + 20.0, p_tamano + 18.0)
	s.size = s.custom_minimum_size
	s.pivot_offset = s.size / 2.0
	s.rotation = p_angulo
	return s


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## El golpe: empieza grande y transparente y se asienta con un rebote y el sonido del sello.
func estampar(sonido: bool = true) -> void:
	modulate.a = 0.0
	scale = Vector2(1.8, 1.8)
	var t := create_tween().set_parallel(true)
	t.tween_property(self, "modulate:a", 0.92, 0.12)
	t.tween_property(self, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	if sonido and is_inside_tree():
		Audio.efecto("sello")


func _draw() -> void:
	var r := Rect2(Vector2(2, 2), size - Vector2(4, 4))
	draw_rect(r, color, false, 3.0)
	draw_rect(r.grow(-5.0), color, false, 1.0)
	var f := EstiloUI.fuente_titulo()
	if f != null:
		var ancho := f.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamano_texto).x
		draw_string(f, Vector2((size.x - ancho) / 2.0, size.y / 2.0 + tamano_texto * 0.4), texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamano_texto, color)
