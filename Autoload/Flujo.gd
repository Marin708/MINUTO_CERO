extends Node
## El recorrido entre pantallas de MINUTO CERO, con fundido a negro entre ellas:
## Título → Consentimiento → Cuestionario inicial → introducción de Lucía → Nivel 1 → Nivel 2 → Nivel 3 →
## Final → Cuestionario final → Resultados → Créditos → Título.
##
## El consentimiento, el cuestionario y la introducción los hace Introduccion.tscn; el cuestionario final y los
## resultados, Final.tscn. Depuracion usa ir_a_nivel() e ir_al_final() para saltar.

const ESCENA_TITULO := "res://Scenes/UI/PantallaTitulo.tscn"
const ESCENA_INTRODUCCION := "res://Scenes/UI/Introduccion.tscn"
const ESCENA_FINAL := "res://Scenes/Final/Final.tscn"
const SEGUNDOS_FUNDIDO := 0.5

## Si es verdadero, no hay fundidos ni pantallas que esperen al jugador (pruebas sin ventana).
var modo_prueba := false

var _capa: CanvasLayer
var _negro: ColorRect
var _cambiando := false

signal nivel_cargado(nivel: int)
signal escena_cargada(ruta: String)


func ruta_de_nivel(nivel: int) -> String:
	return "res://Scenes/Niveles/Nivel%d.tscn" % clampi(nivel, 1, Estado.NIVELES)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_capa = CanvasLayer.new()
	_capa.layer = 50
	add_child(_capa)
	_negro = ColorRect.new()
	_negro.color = Color(0.03, 0.1, 0.13, 1.0)
	_negro.set_anchors_preset(Control.PRESET_FULL_RECT)
	_negro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_negro.modulate.a = 0.0
	_capa.add_child(_negro)


# --- Recorrido ---

## «Comenzar» del título: partida nueva y a la introducción (consentimiento, cuestionario inicial y Lucía).
func comenzar() -> void:
	Estado.nueva_partida()
	await _cambiar(ESCENA_INTRODUCCION)


## «Continuar» del título: la partida ya está cargada; va al nivel donde se quedó.
func continuar() -> void:
	await ir_a_nivel(Estado.nivel_actual)


func ir_a_nivel(nivel: int) -> void:
	Estado.ir_a_nivel(nivel)
	await _cambiar(ruta_de_nivel(nivel))
	nivel_cargado.emit(nivel)


## Un nivel terminó: del 1 al 2 pasa por «Minuto cero», del 2 al 3 directo y del 3 al final.
func terminar_nivel(nivel: int) -> void:
	match nivel:
		1:
			await minuto_cero()
			await ir_a_nivel(2)
		2:
			await ir_a_nivel(3)
		_:
			await ir_al_final()


func ir_al_final() -> void:
	await _cambiar(ESCENA_FINAL)


func ir_al_titulo() -> void:
	await _cambiar(ESCENA_TITULO)


## La pantalla «Minuto cero» entre el nivel 1 y el 2.
func minuto_cero() -> void:
	if _cambiando:
		return
	_cambiando = true
	await _fundido(1.0)
	var capa := CanvasLayer.new()
	capa.layer = 51
	add_child(capa)
	var caja := VBoxContainer.new()
	caja.set_anchors_preset(Control.PRESET_FULL_RECT)
	caja.alignment = BoxContainer.ALIGNMENT_CENTER
	caja.add_theme_constant_override("separation", 12)
	capa.add_child(caja)
	var titulo := EstiloUI.etiqueta("MINUTO CERO", 48, EstiloUI.NARANJA)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caja.add_child(titulo)
	var sub := EstiloUI.etiqueta("Prepararte hoy puede cambiar el minuto cero.", 14, EstiloUI.CREMA)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caja.add_child(sub)
	Audio.efecto("pista")
	await get_tree().create_timer(0.0 if modo_prueba else 3.2).timeout
	capa.queue_free()
	_cambiando = false


# --- Cambio de escena con fundido ---

func _cambiar(ruta: String) -> void:
	if _cambiando:
		await get_tree().process_frame
	_cambiando = true
	get_tree().paused = false
	await _fundido(1.0)
	var error := get_tree().change_scene_to_file(ruta)
	if error != OK:
		push_error("Flujo: no se pudo abrir %s (error %d)." % [ruta, error])
	await get_tree().process_frame
	await get_tree().process_frame
	await _fundido(0.0)
	_cambiando = false
	escena_cargada.emit(ruta)


func _fundido(alfa: float) -> void:
	if modo_prueba:
		_negro.modulate.a = alfa
		return
	var t := create_tween()
	t.tween_property(_negro, "modulate:a", alfa, SEGUNDOS_FUNDIDO)
	await t.finished
