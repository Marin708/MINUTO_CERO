class_name DialogoBalloon
extends CanvasLayer
## Balloon propio de MINUTO CERO para Dialogue Manager.
## Caja morada con borde dorado, fuente Pixelify Sans, texto letra por letra,
## nombre de quien habla arriba de la caja y retrato opcional a la izquierda.
##
## Retrato (opcional): en el .dialogue, agrega una etiqueta a la línea:
##   Lucía: Hola.
## También se puede registrar un retrato por personaje en Dialogo.retratos["Nombre"].
## Si no hay ni etiqueta ni retrato registrado, el espacio se oculta.

## Se emite al terminar el diálogo (ya con el fundido de salida hecho).
## indice_respuesta es la posición (0, 1, 2...) de la última respuesta elegida, o -1 si no hubo.
signal terminado(indice_respuesta: int)
## Empieza a escribirse una línea (personaje vacío si es el narrador) y cuando termina de escribirse.
signal escribiendo_iniciado(personaje: String)
signal escribiendo_terminado()

const TAM_FUENTE := 16
const FUNDIDO_ENTRADA := 0.2
const FUNDIDO_SALIDA := 0.15
const ACCION_SIGUIENTE := &"INTERACTUAR"
## ESC: cancela la conversación (una pulsación con opciones visibles; mantenida durante el texto).
const ACCION_CANCELAR := &"PAUSA"
const SEGUNDOS_PARA_SALIR := 0.7
const TEXTO_CANCELAR := "Ahora no"
const COLOR_CANCELAR := EstiloUI.GRIS
const COLOR_CANCELAR_FOCO := EstiloUI.CREMA
## Quien habla por radio (marco de transmisión con antena) en vez de globo de cómic.
const HABLANTE_RADIO := "Lucía"
const TEXTO_CANAL := "CANAL 3 · BRIGADA"

## Recurso .dialogue y cue inicial (los rellena DialogueManager o Dialogo.mostrar).
@export var dialogue_resource: DialogueResource
@export var start_from_cue: String = ""

@onready var raiz: Control = %Raiz
@onready var caja_nombre: PanelContainer = %CajaNombre
@onready var etiqueta_nombre: Label = %Nombre
@onready var caja: PanelContainer = %Caja
@onready var retrato: TextureRect = %Retrato
@onready var texto: DialogueLabel = %Texto
@onready var respuestas: DialogueResponsesMenu = %Respuestas
@onready var indicador: Control = %Indicador

## Estados extra que ve el diálogo (el balloon mismo, por si se usa "locals").
var estados_temporales: Array = []
## true cuando el texto ya terminó y se espera que el jugador avance.
var esperando_entrada := false
## false en los cuestionarios (onboarding y final): no hay "Ahora no" y ESC no hace nada.
var cancelable := true
## Evita elegir dos veces la misma respuesta (clic + tecla).
var _respuesta_tomada := false
var _ultima_respuesta := -1
var _cerrando := false
var _temporizador_mutacion := Timer.new()
var _ocultar_por_mutacion := false
var _boton_cancelar: Button
var _separador: ColorRect
var _pista: Label
var _tiempo_salida := 0.0
## true si quien habla ahora lo hace por la radio (Lucía).
var _es_radio := false
## true mientras se escribe la línea (Lucía se ve hablando) y false cuando espera opciones o a que avances.
var _escribiendo := false
var _cola: ColaGlobo
var _antena: AntenaRadio
var _cabecera_radio: HBoxContainer
var _retrato_nombre: TextureRect
var _tema_globo: Theme
var _tema_radio: Theme

## Línea actual. Al asignar una línea nula, el diálogo terminó.
var linea: DialogueLine:
	set(valor):
		if _cerrando:
			return  # ya se canceló o terminó: se ignoran las líneas que lleguen tarde
		if valor:
			linea = valor
			_aplicar_linea()
		else:
			_terminar()
	get:
		return linea


func _ready() -> void:
	_crear_cancelacion()
	_crear_adornos()
	_aplicar_estilo()
	raiz.hide()
	raiz.modulate.a = 0.0
	retrato.hide()
	indicador.hide()
	respuestas.hide()
	respuestas.next_action = ACCION_SIGUIENTE
	respuestas.auto_focus_first_item = false
	respuestas.response_selected.connect(_on_respuesta_elegida)
	texto.seconds_per_step = Dialogo.SEGUNDOS_POR_LETRA
	texto.spoke.connect(func(letra: String, _indice: int, _velocidad: float) -> void:
		Dialogo.letra_escrita.emit(linea.character if linea != null else "", letra))

	_temporizador_mutacion.one_shot = true
	_temporizador_mutacion.timeout.connect(_on_temporizador_mutacion)
	add_child(_temporizador_mutacion)
	Engine.get_singleton("DialogueManager").mutated.connect(_on_mutacion)

	_animar_indicador()


## Empieza el diálogo. Misma firma que usa DialogueManager.show_dialogue_balloon().
func start(recurso: DialogueResource = null, cue: String = "", estados_extra: Array = []) -> void:
	estados_temporales = [self] + estados_extra
	esperando_entrada = false
	if is_instance_valid(recurso):
		dialogue_resource = recurso
	if not cue.is_empty():
		start_from_cue = cue
	linea = await dialogue_resource.get_next_dialogue_line(start_from_cue, estados_temporales)


func _input(evento: InputEvent) -> void:
	if not raiz.visible or linea == null or _cerrando:
		return
	# Con las opciones a la vista, una pulsación de ESC cancela. También con INTERACTUAR sobre "Ahora no".
	if cancelable and respuestas.visible:
		if evento.is_action_pressed(ACCION_CANCELAR) and not evento.is_echo():
			get_viewport().set_input_as_handled()
			_cancelar()
			return
		if evento.is_action_pressed(ACCION_SIGUIENTE) and _boton_cancelar.has_focus():
			get_viewport().set_input_as_handled()
			_cancelar()
			return
	var presionado := evento.is_action_pressed(ACCION_SIGUIENTE)
	var clic: bool = evento is InputEventMouseButton and evento.pressed \
		and evento.button_index == MOUSE_BUTTON_LEFT
	if not (presionado or clic):
		return

	# Con INTERACTUAR (o clic) se completa el texto al instante
	if texto.is_typing:
		get_viewport().set_input_as_handled()
		texto.skip_typing()
	# Si no hay respuestas, la misma tecla pasa a la siguiente línea
	elif esperando_entrada and linea.responses.is_empty():
		get_viewport().set_input_as_handled()
		_siguiente(linea.next_id)


func _process(delta: float) -> void:
	_colocar_adornos()
	# Durante el texto, mantener ESC sale de la conversación
	if cancelable and raiz.visible and not _cerrando and linea != null and not respuestas.visible:
		if Input.is_action_pressed(ACCION_CANCELAR):
			_tiempo_salida += delta
			_pista.text = "Saliendo…"
			_pista.modulate.a = 1.0
			if _tiempo_salida >= SEGUNDOS_PARA_SALIR:
				_cancelar()
			return
	_tiempo_salida = 0.0
	if _pista != null:
		_pista.text = "Mantén Esc para salir"
		_pista.modulate.a = 0.6


## Cierra la conversación sin elegir nada. NO es una decisión del juego: no se ejecuta ninguna
## línea más del .dialogue, así que ningún estado cambia. mostrar() devuelve Dialogo.CANCELADO.
func _cancelar() -> void:
	if not cancelable or _cerrando:
		return
	_ultima_respuesta = Dialogo.CANCELADO
	Dialogo.cancelado_por_jugador.emit()
	_terminar()


func _siguiente(id: String) -> void:
	linea = await dialogue_resource.get_next_dialogue_line(id, estados_temporales)


## Muestra la línea actual: nombre, retrato, texto escrito letra por letra y respuestas.
func _aplicar_linea() -> void:
	var esta_linea := linea
	_temporizador_mutacion.stop()
	_ocultar_por_mutacion = false
	_respuesta_tomada = false
	esperando_entrada = false
	indicador.hide()
	_tiempo_salida = 0.0
	_boton_cancelar.hide()
	_separador.hide()
	_pista.visible = cancelable

	# Nombre de quien habla (se oculta si es narrador)
	var nombre := tr(linea.character, "dialogue")
	caja_nombre.visible = not linea.character.is_empty()
	etiqueta_nombre.text = nombre

	_es_radio = linea.character == HABLANTE_RADIO
	_escribiendo = false
	_aplicar_modo(_es_radio)
	_actualizar_retrato()

	texto.hide()
	texto.dialogue_line = linea
	respuestas.hide()
	respuestas.responses = linea.responses
	_conectar_botones()

	_mostrar_balloon()
	texto.show()
	if not linea.text.is_empty():
		escribiendo_iniciado.emit(linea.character)
		_escribiendo = true
		_actualizar_retrato()
		texto.type_out()
		await texto.finished_typing
		_escribiendo = false
		_actualizar_retrato()
		escribiendo_terminado.emit()
		if _cerrando or esta_linea != linea:
			return  # ya cambió la línea (o se canceló) mientras se escribía

	if linea.responses.size() > 0:
		respuestas.show()
		Dialogo.opciones_mostradas.emit()
		_pista.hide()
		_boton_cancelar.visible = cancelable
		_separador.visible = cancelable
		respuestas.focus_first_item()
	elif linea.time != "":
		var segundos := linea.text.length() * 0.02 if linea.time == "auto" else linea.time.to_float()
		await get_tree().create_timer(segundos).timeout
		if esta_linea == linea:
			_siguiente(linea.next_id)
	else:
		esperando_entrada = true
		indicador.show()


## Retrato de quien habla. Lucía (radio): hablando mientras se escribe, neutral al esperar y alerta durante el sismo, la
## réplica y la advertencia del gas. Marta, Doña Rosa y Tomás (y Sami): un rostro pequeño junto al nombre, a 1x.
## Un retrato indicado en la línea (etiqueta retrato=) o registrado en Dialogo.retratos manda sobre los demás.
func _actualizar_retrato() -> void:
	var ruta := linea.get_tag_value("retrato")
	var textura: Texture2D = null
	if ruta != "" and ResourceLoader.exists(ruta):
		textura = load(ruta)
	elif Dialogo.retratos.has(linea.character):
		textura = Dialogo.retratos[linea.character]  # registrado por la escena (ver Dialogo.retratos)
	elif _es_radio:
		var estado := "lucia_alerta" if (Dialogo.alerta_radio or Sismo.esta_activo()) else ("lucia_hablando" if _escribiendo else "lucia_neutral")
		textura = Retratos.obtener(estado)
	retrato.texture = textura
	retrato.visible = textura != null
	# Los demás personajes: rostro pequeño en la etiqueta del nombre
	var pequeno: Texture2D = null
	if textura == null and not _es_radio:
		var clave: String = Retratos.DE_HABLANTE.get(linea.character, "")
		if clave != "":
			pequeno = Retratos.rostro(clave)
	_retrato_nombre.texture = pequeno
	_retrato_nombre.visible = pequeno != null


## Hace visible la caja, con fundido si estaba escondida.
func _mostrar_balloon() -> void:
	if raiz.visible and raiz.modulate.a >= 1.0:
		return
	raiz.show()
	var t := create_tween()
	t.tween_property(raiz, "modulate:a", 1.0, FUNDIDO_ENTRADA)


func _terminar() -> void:
	if _cerrando:
		return
	_cerrando = true
	esperando_entrada = false
	indicador.hide()
	var t := create_tween()
	t.tween_property(raiz, "modulate:a", 0.0, FUNDIDO_SALIDA)
	await t.finished
	terminado.emit(_ultima_respuesta)
	queue_free()


# --- Respuestas ---

## Los botones también responden a Enter/clic (el menú solo escucha INTERACTUAR y el ratón).
func _conectar_botones() -> void:
	var items := respuestas.get_menu_items()
	for item in items:
		if item is BaseButton:
			item.pressed.connect(_on_respuesta_elegida.bind(item.get_meta("response")))
	# Con el teclado se llega a "Ahora no" bajando desde la última respuesta (y se vuelve subiendo)
	if not items.is_empty():
		var ultimo := items[items.size() - 1] as Control
		ultimo.focus_neighbor_bottom = ultimo.get_path_to(_boton_cancelar)
		_boton_cancelar.focus_neighbor_top = _boton_cancelar.get_path_to(ultimo)


## "Ahora no": una opción pequeña, gris violácea y separada por una línea tenue de las respuestas,
## para que no se confunda con una decisión. Se crea por código (así no hay que editar la escena).
func _crear_cancelacion() -> void:
	var contenedor := respuestas.get_parent()
	_separador = ColorRect.new()
	_separador.custom_minimum_size = Vector2(0, 1)
	_separador.color = Color(COLOR_CANCELAR, 0.35)
	_separador.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_separador.hide()
	contenedor.add_child(_separador)

	_boton_cancelar = Button.new()
	_boton_cancelar.text = TEXTO_CANCELAR
	_boton_cancelar.flat = true
	_boton_cancelar.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_boton_cancelar.focus_mode = Control.FOCUS_ALL
	_boton_cancelar.add_theme_font_size_override("font_size", 12)
	_boton_cancelar.add_theme_color_override("font_color", COLOR_CANCELAR)
	_boton_cancelar.add_theme_color_override("font_hover_color", COLOR_CANCELAR_FOCO)
	_boton_cancelar.add_theme_color_override("font_focus_color", COLOR_CANCELAR_FOCO)
	_boton_cancelar.hide()
	_boton_cancelar.pressed.connect(_cancelar)
	contenedor.add_child(_boton_cancelar)

	_pista = Label.new()
	_pista.text = "Mantén Esc para salir"
	_pista.size_flags_horizontal = Control.SIZE_SHRINK_END
	_pista.add_theme_font_size_override("font_size", 10)
	_pista.add_theme_color_override("font_color", COLOR_CANCELAR)
	_pista.modulate.a = 0.45
	_pista.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pista.hide()
	contenedor.add_child(_pista)


func _on_respuesta_elegida(respuesta: DialogueResponse) -> void:
	if _respuesta_tomada or linea == null:
		return
	_respuesta_tomada = true
	Dialogo.respuesta_elegida.emit()
	_ultima_respuesta = linea.responses.find(respuesta)
	_siguiente(respuesta.next_id)


# --- Mutaciones (líneas "$>" del .dialogue) ---

func _on_mutacion(mutacion: Dictionary) -> void:
	if not mutacion.is_inline:
		esperando_entrada = false
		_ocultar_por_mutacion = true
		_temporizador_mutacion.start(0.1)


func _on_temporizador_mutacion() -> void:
	if _ocultar_por_mutacion:
		_ocultar_por_mutacion = false
		raiz.hide()
		raiz.modulate.a = 0.0


# --- Estilo: globo de cómic (crema, tinta, borde recto de 2 px) y marco de transmisión para Lucía ---

func _crear_caja(fondo: Color, borde: Color, grosor: int, margen: int) -> StyleBoxFlat:
	return EstiloUI.caja(fondo, borde, grosor, margen)


func _tema_con(color_texto: Color, fuente: Font, tam: int, fondo_boton: Color, texto_boton: Color, foco_fondo: Color, foco_texto: Color) -> Theme:
	var tema := Theme.new()
	tema.default_font = fuente
	tema.default_font_size = tam
	for tipo in ["Label", "Button"]:
		tema.set_font("font", tipo, fuente)
		tema.set_font_size("font_size", tipo, tam)
	for nombre in ["normal_font", "bold_font", "italics_font"]:
		tema.set_font(nombre, "RichTextLabel", fuente)
		tema.set_font_size(nombre + "_size", "RichTextLabel", tam)
	tema.set_color("default_color", "RichTextLabel", color_texto)
	tema.set_color("font_color", "Label", color_texto)
	tema.set_color("font_color", "Button", texto_boton)
	for c in ["font_hover_color", "font_focus_color", "font_pressed_color"]:
		tema.set_color(c, "Button", foco_texto)
	tema.set_stylebox("normal", "Button", _crear_caja(fondo_boton, fondo_boton, 2, 3))
	for e in ["hover", "pressed", "focus"]:
		tema.set_stylebox(e, "Button", _crear_caja(foco_fondo, EstiloUI.TINTA if fondo_boton == EstiloUI.CREMA else foco_fondo, 2, 3))
	tema.set_stylebox("disabled", "Button", _crear_caja(fondo_boton, fondo_boton, 2, 3))
	return tema


func _aplicar_estilo() -> void:
	_tema_globo = _tema_con(EstiloUI.TINTA, EstiloUI.fuente_texto(), 16, EstiloUI.CREMA, EstiloUI.TINTA, EstiloUI.NARANJA, EstiloUI.TINTA)
	_tema_radio = _tema_con(EstiloUI.CREMA, EstiloUI.fuente_radio(), 22, EstiloUI.PETROLEO_OSCURO, EstiloUI.CREMA, EstiloUI.NARANJA, EstiloUI.TINTA)
	_aplicar_modo(false)


## Cambia entre el globo de cómic (todos) y el marco de transmisión (Lucía).
func _aplicar_modo(radio: bool) -> void:
	raiz.theme = _tema_radio if radio else _tema_globo
	if radio:
		caja.add_theme_stylebox_override("panel", _crear_caja(EstiloUI.PETROLEO_OSCURO, EstiloUI.NARANJA, 2, 8))
		caja_nombre.add_theme_stylebox_override("panel", _crear_caja(EstiloUI.NARANJA, EstiloUI.NARANJA, 2, 3))
	else:
		caja.add_theme_stylebox_override("panel", _crear_caja(EstiloUI.CREMA, EstiloUI.TINTA, 2, 8))
		caja_nombre.add_theme_stylebox_override("panel", _crear_caja(EstiloUI.NARANJA, EstiloUI.TINTA, 2, 3))
	etiqueta_nombre.add_theme_font_override("font", EstiloUI.fuente_titulo())
	etiqueta_nombre.add_theme_font_size_override("font_size", 9)
	etiqueta_nombre.add_theme_color_override("font_color", EstiloUI.TINTA)
	var color_aviso := EstiloUI.GRIS if radio else EstiloUI.TINTA_SUAVE
	_pista.add_theme_color_override("font_color", color_aviso)
	_separador.color = Color(color_aviso, 0.5)
	_boton_cancelar.add_theme_color_override("font_color", color_aviso)
	_boton_cancelar.add_theme_color_override("font_hover_color", EstiloUI.CREMA if radio else EstiloUI.TINTA)
	_boton_cancelar.add_theme_color_override("font_focus_color", EstiloUI.CREMA if radio else EstiloUI.TINTA)
	_boton_cancelar.add_theme_font_size_override("font_size", 18 if radio else 14)
	_cola.visible = not radio and not _sin_hablante()
	_antena.visible = radio
	_cabecera_radio.visible = radio
	retrato.custom_minimum_size = Vector2(96, 96) if radio else Vector2(64, 64)


func _sin_hablante() -> bool:
	return linea == null or linea.character.is_empty()


## Cola del globo, antena y cabecera «CANAL 3 · BRIGADA» (se crean por código para no editar la escena).
func _crear_adornos() -> void:
	_cola = ColaGlobo.new()
	_cola.hide()
	raiz.add_child(_cola)
	_antena = AntenaRadio.new()
	_antena.hide()
	raiz.add_child(_antena)
	var textos_box: Control = texto.get_parent()
	_cabecera_radio = HBoxContainer.new()
	_cabecera_radio.add_theme_constant_override("separation", 6)
	_cabecera_radio.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cabecera_radio.add_child(EstiloUI.titulo(TEXTO_CANAL, 8, EstiloUI.NARANJA))
	var franjas := Franjas.new()
	franjas.custom_minimum_size = Vector2(0, 5)
	franjas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	franjas.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_cabecera_radio.add_child(franjas)
	_cabecera_radio.hide()
	textos_box.add_child(_cabecera_radio)
	textos_box.move_child(_cabecera_radio, 0)
	# El rostro pequeño va dentro de la etiqueta del nombre
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 4)
	fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caja_nombre.add_child(fila)
	etiqueta_nombre.reparent(fila, false)
	_retrato_nombre = TextureRect.new()
	_retrato_nombre.custom_minimum_size = Vector2(48, 48)
	_retrato_nombre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_retrato_nombre.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_retrato_nombre.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	_retrato_nombre.hide()
	fila.add_child(_retrato_nombre)
	fila.move_child(_retrato_nombre, 0)


## Pone la cola apuntando al personaje que habla (si está en pantalla) y la antena en la esquina del marco.
func _colocar_adornos() -> void:
	if not raiz.visible:
		return
	var borde_caja := caja.global_position
	_antena.position = Vector2(borde_caja.x + caja.size.x - 40.0, borde_caja.y - 24.0)
	if not _cola.visible or linea == null:
		return
	var ancla: Node2D = Dialogo.anclas.get(linea.character)
	var x := borde_caja.x + caja.size.x * 0.5
	var lean := 0.0
	if is_instance_valid(ancla):
		var pantalla := get_viewport().get_canvas_transform() * ancla.global_position
		lean = clampf((pantalla.x - x) * 0.2, -6.0, 6.0)
		x = pantalla.x
	# Sin pisar la etiqueta del nombre, que ocupa la esquina de arriba a la izquierda del globo
	var minimo := borde_caja.x + 18.0
	if caja_nombre.visible:
		minimo = maxf(minimo, caja_nombre.global_position.x + caja_nombre.size.x + 8.0)
	x = clampf(x, minimo, borde_caja.x + caja.size.x - 28.0)
	_cola.lean = lean
	_cola.queue_redraw()
	_cola.position = Vector2(x - ColaGlobo.MEDIO_ANCHO, borde_caja.y - ColaGlobo.ALTO + 2.0)


## Triangulito dorado que parpadea cuando se puede avanzar.
func _animar_indicador() -> void:
	var t := create_tween().set_loops()
	t.tween_property(indicador, "modulate:a", 0.2, 0.5)
	t.tween_property(indicador, "modulate:a", 1.0, 0.5)
