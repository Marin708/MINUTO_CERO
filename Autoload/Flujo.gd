extends Node
## El recorrido entre pantallas de MINUTO CERO, con una persiana de franjas de precaución entre ellas (y una tarjeta de nivel con reloj):
## Título → Consentimiento → Cuestionario inicial → introducción de Lucía → Nivel 1 → Nivel 2 → Nivel 3 →
## Final → Cuestionario final → Resultados → Créditos → Título.
##
## El consentimiento, el cuestionario y la introducción los hace Introduccion.tscn; el cuestionario final y los
## resultados, Final.tscn. Depuracion usa ir_a_nivel() e ir_al_final() para saltar.

const ESCENA_TITULO := "res://Scenes/UI/PantallaTitulo.tscn"
const ESCENA_INTRODUCCION := "res://Scenes/UI/Introduccion.tscn"
const ESCENA_FINAL := "res://Scenes/Final/Final.tscn"
const SEGUNDOS_FUNDIDO := 0.5
## Cuánto se ve la tarjeta de nivel con el reloj.
const SEGUNDOS_TARJETA_NIVEL := 2.0

## Si es verdadero, no hay fundidos ni pantallas que esperen al jugador (pruebas sin ventana).
var modo_prueba := false

var _capa: CanvasLayer
var _persiana: Persiana
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
	_persiana = Persiana.new()
	_persiana.set_anchors_preset(Control.PRESET_FULL_RECT)
	_capa.add_child(_persiana)


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
	await _cambiar(ruta_de_nivel(nivel), nivel)
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
	var titulo := EstiloUI.titulo("MINUTO CERO", 40, EstiloUI.NARANJA)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caja.add_child(titulo)
	var sub := EstiloUI.etiqueta("Prepararte hoy puede cambiar el minuto cero.", 14, EstiloUI.CREMA)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caja.add_child(sub)
	Audio.efecto("pista")
	await get_tree().create_timer(0.0 if modo_prueba else 3.2).timeout
	capa.queue_free()
	_cambiando = false


# --- Cambio de escena con la persiana ---

## Cierra la persiana, (si es un nivel) muestra su tarjeta con reloj, cambia de escena y abre la persiana.
func _cambiar(ruta: String, nivel_tarjeta: int = 0) -> void:
	if _cambiando:
		await get_tree().process_frame
	_cambiando = true
	get_tree().paused = false
	await _fundido(1.0)
	var capa_tarjeta: CanvasLayer = null
	if nivel_tarjeta > 0 and not modo_prueba:
		capa_tarjeta = CanvasLayer.new()
		capa_tarjeta.layer = 51
		add_child(capa_tarjeta)
		capa_tarjeta.add_child(TarjetaNivel.crear(nivel_tarjeta))
		await get_tree().create_timer(SEGUNDOS_TARJETA_NIVEL).timeout
	var error := get_tree().change_scene_to_file(ruta)
	if error != OK:
		push_error("Flujo: no se pudo abrir %s (error %d)." % [ruta, error])
	await get_tree().process_frame
	await get_tree().process_frame
	if capa_tarjeta != null:
		capa_tarjeta.queue_free()
	await _fundido(0.0)
	_cambiando = false
	escena_cargada.emit(ruta)


## Anima la persiana hasta `cierre` (1 = cerrada, 0 = abierta).
func _fundido(cierre: float) -> void:
	if modo_prueba:
		_persiana.cierre = cierre
		return
	var t := create_tween()
	t.tween_property(_persiana, "cierre", cierre, SEGUNDOS_FUNDIDO)
	await t.finished
