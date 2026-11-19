class_name IndicadorTecla
extends Control
## Indicador de interacción: una tecla (keycap) cuadrada con sombra inferior y la letra E, y al lado el verbo de la acción
## («Revisar», «Hablar», «Abrir», «Tomar»), con un leve pulso. Con `progreso` entre 0 y 1 (mantener E) dibuja un anillo
## de avance alrededor de la tecla. Se dibuja por código; vale en el mundo (Player) y en la galería de estilo.
##
##   var i := IndicadorTecla.new(); i.verbo = "Revisar"; i.progreso = -1.0   # sin anillo

const LADO := 18.0
const SOMBRA := 3.0

@export var letra := "E"
@export var verbo := "Revisar":
	set(v):
		verbo = v
		_recalcular()
		queue_redraw()
## -1 = no se muestra el anillo; de 0 a 1 = mantener E.
@export var progreso := -1.0:
	set(v):
		progreso = v
		queue_redraw()

var _t := 0.0
var _ancho_verbo := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_recalcular()


func _recalcular() -> void:
	var f := EstiloUI.fuente_titulo()
	_ancho_verbo = f.get_string_size(verbo, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x if f != null and verbo != "" else 0.0
	custom_minimum_size = Vector2(LADO + 8.0 + (_ancho_verbo + 12.0 if verbo != "" else 0.0), LADO + SOMBRA + 4.0)
	size = custom_minimum_size


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var pulso := 1.0 + 0.04 * sin(_t * 5.0)
	var centro := Vector2(LADO / 2.0 + 4.0, LADO / 2.0 + 2.0)
	var mitad := LADO / 2.0 * pulso
	var rect := Rect2(centro - Vector2(mitad, mitad), Vector2(mitad, mitad) * 2.0)
	# Sombra inferior (el grosor de la tecla)
	draw_rect(Rect2(rect.position + Vector2(0, SOMBRA), rect.size), EstiloUI.TINTA)
	draw_rect(rect, EstiloUI.CREMA)
	draw_rect(rect, EstiloUI.TINTA, false, 2.0)
	var f := EstiloUI.fuente_titulo()
	if f != null:
		var ancho := f.get_string_size(letra, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		draw_string(f, centro + Vector2(-ancho / 2.0, 4.0), letra, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, EstiloUI.TINTA)
	if progreso >= 0.0:
		draw_arc(centro, LADO * 0.85, 0.0, TAU, 32, Color(EstiloUI.TINTA, 0.8), 4.0)
		draw_arc(centro, LADO * 0.85, -PI / 2.0, -PI / 2.0 + TAU * clampf(progreso, 0.0, 1.0), 32, EstiloUI.NARANJA, 3.0)
	if verbo != "" and f != null:
		var x := LADO + 10.0
		var alto := 14.0
		var caja := Rect2(Vector2(x, centro.y - alto / 2.0), Vector2(_ancho_verbo + 8.0, alto))
		draw_rect(caja, EstiloUI.PETROLEO_OSCURO)
		draw_rect(caja, EstiloUI.NARANJA, false, 2.0)
		draw_string(f, Vector2(caja.position.x + 4.0, caja.position.y + 10.0), verbo, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, EstiloUI.CREMA)
