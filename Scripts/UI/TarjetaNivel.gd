class_name TarjetaNivel
extends Control
## La tarjeta de nivel que se ve tras cerrarse la persiana: un reloj que marca la hora del nivel y el rótulo
## («NIVEL 1 · ANTES», «NIVEL 2 · DURANTE», «NIVEL 3 · DESPUÉS») con una frase corta.
## El reloj es solo decoración (no es un dato del juego): las manecillas cambian de un nivel a otro.

const TITULOS := {1: "NIVEL 1 · ANTES", 2: "NIVEL 2 · DURANTE", 3: "NIVEL 3 · DESPUÉS"}
## [REVISAR] Frases de la tarjeta (voz de brigada, escritas por el equipo; no están en el documento maestro).
const FRASES := {1: "Deja la casa lista.", 2: "Actúa cuando tiembla.", 3: "Revisa y ayuda con seguridad."}
## Hora decorativa de cada nivel (hora, minuto).
const HORAS := {1: Vector2(7, 30), 2: Vector2(7, 42), 3: Vector2(8, 5)}

var nivel := 1
## true en la galería de estilo: sin el sonido del reloj.
var silencioso := false
var _t := 0.0
var _ultimo_tic := -1


static func crear(n: int) -> TarjetaNivel:
	var c := TarjetaNivel.new()
	c.nivel = n
	return c


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fondo := ColorRect.new()
	fondo.color = EstiloUI.AZUL_NOCHE
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)
	var columna := VBoxContainer.new()
	columna.set_anchors_preset(Control.PRESET_FULL_RECT)
	columna.alignment = BoxContainer.ALIGNMENT_CENTER
	columna.add_theme_constant_override("separation", 10)
	add_child(columna)
	var reloj := Control.new()
	reloj.custom_minimum_size = Vector2(0, 110)
	reloj.draw.connect(_dibujar_reloj.bind(reloj))
	columna.add_child(reloj)
	_reloj = reloj
	var franjas := Franjas.new()
	franjas.custom_minimum_size = Vector2(280, 8)
	franjas.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	columna.add_child(franjas)
	var titulo := EstiloUI.titulo(TITULOS.get(nivel, "NIVEL"), 22, EstiloUI.CREMA)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	columna.add_child(titulo)
	var frase := EstiloUI.etiqueta(FRASES.get(nivel, ""), 14, EstiloUI.NARANJA)
	frase.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	columna.add_child(frase)
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.25)


var _reloj: Control


func _process(delta: float) -> void:
	_t += delta
	if _reloj != null:
		_reloj.queue_redraw()
	# Un tic por cada tercio de segundo, con el sonido del reloj
	var tic := int(_t * 3.0)
	if tic != _ultimo_tic:
		_ultimo_tic = tic
		if _t > 0.1 and not silencioso:
			Audio.efecto("reloj_tic")


func _dibujar_reloj(c: Control) -> void:
	var centro := Vector2(c.size.x / 2.0, 55.0)
	var r := 44.0
	c.draw_circle(centro, r + 3.0, EstiloUI.NARANJA)
	c.draw_circle(centro, r, EstiloUI.CREMA)
	for i in 12:
		var d := Vector2.UP.rotated(i * TAU / 12.0)
		c.draw_line(centro + d * (r - 8.0), centro + d * (r - 2.0), EstiloUI.TINTA, 2.0 if i % 3 == 0 else 1.0)
	var hm: Vector2 = HORAS.get(nivel, Vector2(7, 30))
	var minuto: float = hm.y
	var ang_min := minuto / 60.0 * TAU
	var ang_hor := (hm.x + minuto / 60.0) / 12.0 * TAU
	c.draw_line(centro, centro + Vector2.UP.rotated(ang_hor) * (r * 0.5), EstiloUI.TINTA, 3.0)
	c.draw_line(centro, centro + Vector2.UP.rotated(ang_min) * (r * 0.78), EstiloUI.TINTA, 2.0)
	# Segundero: salta un paso por tic y se ve en rojo
	var ang_seg: float = floor(_t * 3.0) / 60.0 * TAU * 3.0
	c.draw_line(centro, centro + Vector2.UP.rotated(ang_seg) * (r * 0.85), EstiloUI.ROJO, 1.0)
	c.draw_circle(centro, 3.0, EstiloUI.TINTA)
