class_name Consentimiento
extends CanvasLayer
## «Acuerdo de la brigada»: el consentimiento presentado como un acuerdo en una hoja de papel, antes del primer cuestionario (capa 12). Con "Acepto y continúo" las respuestas
## se guardan de forma anónima en este computador (Evaluacion.consentimiento_guardar = true); con "Jugar sin
## guardar mis respuestas" las preguntas se hacen igual y se muestra el resultado, pero no se escribe nada en
## archivos. No se puede cancelar: hay que elegir una de las dos.
##
## Uso:   await Consentimiento.mostrar(get_tree())

const ESCENA := "res://Scenes/UI/Consentimiento.tscn"
# [REVISAR] texto de consentimiento adaptado de ECOS por el equipo (con la frase «No es un test psicológico»).
const TEXTO := "MINUTO CERO es un juego educativo sobre qué hacer antes, durante y después de un sismo. Antes y después de jugar te haremos algunas preguntas para saber qué aprendiste. Tus respuestas se guardan de forma anónima en este computador y solo se usan para evaluar el juego. No es un examen oficial ni reemplaza la orientación de las autoridades de gestión del riesgo. No es un test psicológico. Puedes dejar de jugar cuando quieras."

signal decidido(acepta: bool)

var _raiz: Control
var _decidido := false


static func mostrar(arbol: SceneTree) -> void:
	var escena := (load(ESCENA) as PackedScene).instantiate() as Consentimiento
	arbol.root.add_child.call_deferred(escena)   # (diferido: la raíz puede estar ocupada montando la escena)
	await escena.tree_exited


func _ready() -> void:
	layer = 12
	process_mode = Node.PROCESS_MODE_ALWAYS
	Evaluacion.cuestionario_activo = true
	FondoEvaluacion.crear(self)
	_raiz = Control.new()
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.theme = EstiloUI.tema()
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.modulate.a = 0.0
	add_child(_raiz)

	# La hoja del acuerdo: papel crema con texto oscuro, un título con franjas y la línea de firma
	var hoja := PanelContainer.new()
	hoja.position = Vector2(110, 14)
	hoja.custom_minimum_size = Vector2(420, 0)
	hoja.add_theme_stylebox_override("panel", EstiloUI.caja(EstiloUI.PAPEL, EstiloUI.TINTA, 2, 16))
	_raiz.add_child(hoja)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	hoja.add_child(v)
	v.add_child(EstiloUI.titulo("ACUERDO DE LA BRIGADA", 14, EstiloUI.TINTA))
	var franjas := Franjas.new()
	franjas.custom_minimum_size = Vector2(0, 6)
	v.add_child(franjas)
	var texto := EstiloUI.etiqueta(TEXTO, 13, EstiloUI.TINTA)
	texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texto.custom_minimum_size = Vector2(386, 124)
	v.add_child(texto)
	var firma := ColorRect.new()
	firma.color = EstiloUI.TINTA_SUAVE
	firma.custom_minimum_size = Vector2(0, 1)
	v.add_child(firma)
	v.add_child(EstiloUI.etiqueta("Sin nombre: tu respuesta es anónima.", 11, EstiloUI.TINTA_SUAVE))
	var acepto := _boton("Acepto y continúo", true)
	var sin_guardar := _boton("Jugar sin guardar mis respuestas", false)
	v.add_child(acepto)
	v.add_child(sin_guardar)
	await get_tree().process_frame
	hoja.reset_size()
	hoja.position.y = maxf(6.0, (360.0 - hoja.size.y) / 2.0)
	create_tween().tween_property(_raiz, "modulate:a", 1.0, 0.5)
	Audio.efecto("dialogo_abrir")
	await get_tree().process_frame
	acepto.grab_focus()


# ESC y TAB no hacen nada aquí
func _input(evento: InputEvent) -> void:
	for accion in ["PAUSA", "DIARIO", "ui_cancel"]:
		if evento.is_action_pressed(accion):
			get_viewport().set_input_as_handled()
			return


func _boton(texto: String, acepta: bool) -> Button:
	var b := EstiloUI.boton_senal(texto, 386, 30, 9)
	b.pressed.connect(_decidir.bind(acepta))
	b.focus_entered.connect(func() -> void: Audio.efecto("ui_mover"))
	return b


func _decidir(acepta: bool) -> void:
	if _decidido:
		return
	_decidido = true
	Audio.efecto("ui_elegir")
	Evaluacion.consentimiento_dado = true
	Evaluacion.consentimiento_guardar = acepta
	decidido.emit(acepta)
	var t := create_tween()
	t.tween_property(_raiz, "modulate:a", 0.0, 0.4)
	await t.finished
	Evaluacion.cuestionario_activo = false
	queue_free()
