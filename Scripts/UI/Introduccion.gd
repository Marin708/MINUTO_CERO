class_name Introduccion
extends CanvasLayer
## La introducción de MINUTO CERO, después del título:
##   Boletín de la brigada (Lucía por radio explica cómo se juega) → Inscripción (el carné de brigadista) →
##   Acuerdo de la brigada (consentimiento) → Evaluación de ingreso (cuestionario inicial) → cierre: Lucía entrega el carné,
##   suena un despertador y se pasa a la mañana en el apartamento (nivel 1).
## Si el «pre» ya está hecho (partida cargada) se salta la inscripción, el acuerdo y la evaluación. En las pruebas sin
## ventana (Flujo.modo_prueba) se pasa directo al nivel 1.
## [REVISAR] Todos los textos de Lucía los escribió el equipo (ver docs/textos_a_revisar.md).

const BOLETIN := [
	"Aquí Lucía, de la brigada de Villa Cafetal. Te cuento cómo funciona esto.",
	"Eres Sami. Te mueves con las flechas o con W, A, S y D. Con E hablas, revisas y recoges cosas.",
	"Con Tab abres tu libreta, donde queda lo que vas aprendiendo. Con Esc, la pausa.",
	"Aquí no hay combate ni se pierde. Si algo sale mal, te explico por qué y lo intentas otra vez.",
	"Ahora te inscribo en la brigada. Después, unas preguntas y a casa de Sami.",
]
const INSCRIPCION := [
	"Este es tu carné de brigadista. No te pido nombre: es anónimo.",
	"Dice «pendiente» porque se completa cuando termines la evaluación de ingreso.",
]
const CIERRE := [
	"Evaluación recibida. Ya eres brigadista: aquí tienes tu carné.",
	"Empieza la mañana en casa de Sami. Primero, revisar la casa.",
]

var _raiz: Control
var _carne: Carne
var _rotulo: Label


func _ready() -> void:
	layer = 1
	FondoEvaluacion.crear(self)
	_raiz = Control.new()
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.theme = EstiloUI.tema()
	add_child(_raiz)
	_secuencia.call_deferred()


func _secuencia() -> void:
	Audio.musica("musica_titulo", 1.0)
	if Flujo.modo_prueba:
		Evaluacion.consentimiento_dado = true
		await Flujo.ir_a_nivel(1)
		return
	await _boletin()
	if not Evaluacion.pre_completo():
		await _inscripcion()
		if not Evaluacion.consentimiento_dado:
			await Consentimiento.mostrar(get_tree())
		if Evaluacion.valido:
			await Cuestionario.mostrar(get_tree(), "pre")
	await _cierre()
	await Flujo.ir_a_nivel(1)


## Pone el título de la pantalla arriba a la izquierda, con una cinta de franjas debajo.
func _rotular(texto: String) -> void:
	if _rotulo != null:
		_rotulo.get_parent().queue_free()
	var caja := VBoxContainer.new()
	caja.position = Vector2(24, 18)
	caja.add_theme_constant_override("separation", 4)
	caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rotulo = EstiloUI.titulo(texto, 14, EstiloUI.CREMA)
	caja.add_child(_rotulo)
	var franjas := Franjas.new()
	franjas.custom_minimum_size = Vector2(190, 6)
	caja.add_child(franjas)
	_raiz.add_child(caja)


## Boletín de la brigada: pantalla oscura con grano y la radio de Lucía; el texto se escribe como una transmisión.
func _boletin() -> void:
	_rotular("BOLETÍN DE LA BRIGADA")
	var antena := AntenaRadio.new()
	antena.scale = Vector2(4, 4)
	antena.position = Vector2(320 - 56, 80)
	_raiz.add_child(antena)
	var en_vivo := EstiloUI.radio("● EN VIVO · CANAL 3", 20, EstiloUI.ROJO)
	en_vivo.position = Vector2(320 - 96, 200)
	_raiz.add_child(en_vivo)
	var latido := en_vivo.create_tween().set_loops()
	latido.tween_property(en_vivo, "modulate:a", 0.35, 0.7)
	latido.tween_property(en_vivo, "modulate:a", 1.0, 0.7)
	Audio.efecto("radio_squelch")
	await get_tree().create_timer(0.8).timeout
	await Dialogo.mostrar_texto("Lucía", BOLETIN)
	antena.queue_free()
	en_vivo.queue_free()


## Inscripción: el carné de brigadista con la foto de Sami, rol, nivel «pendiente» y el espacio para el sello.
func _inscripcion() -> void:
	_rotular("INSCRIPCIÓN")
	_carne = Carne.new()
	_carne.scale = Vector2(1.3, 1.3)
	_carne.position = Vector2((640 - Carne.ANCHO * 1.3) / 2.0, 58)
	_raiz.add_child(_carne)
	_carne.modulate.a = 0.0
	create_tween().tween_property(_carne, "modulate:a", 1.0, 0.4)
	await get_tree().create_timer(0.5).timeout
	await Dialogo.mostrar_texto("Lucía", INSCRIPCION)


## Cierre: Lucía entrega el carné (sellado y con el nivel inicial), suena un despertador y empieza la mañana.
func _cierre() -> void:
	_rotular("BIENVENIDO/A A LA BRIGADA")
	if _carne == null:
		_carne = Carne.new()
		_carne.scale = Vector2(1.3, 1.3)
		_carne.position = Vector2((640 - Carne.ANCHO * 1.3) / 2.0, 58)
		_raiz.add_child(_carne)
	_carne.poner_nivel("1 · Antes")
	await get_tree().create_timer(0.6).timeout
	_carne.sellar("BRIGADISTA", EstiloUI.TURQUESA_TINTA)
	await Dialogo.mostrar_texto("Lucía", CIERRE)
	Audio.efecto("despertador")
	await get_tree().create_timer(2.2).timeout
