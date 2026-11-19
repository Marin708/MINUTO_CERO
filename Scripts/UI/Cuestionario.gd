class_name Cuestionario
extends CanvasLayer
## «Evaluación de ingreso» (cuestionario inicial) y «Evaluación de salida» (el final): las preguntas se contestan sobre una
## tablilla con hoja de papel crema; las opciones son casillas que se marcan con lápiz y el progreso es un checklist de 14
## casillas. Un sello «EVALUACIÓN DE INGRESO» (o «DE SALIDA») al empezar y «RECIBIDA» al terminar. Una pregunta a la vez, con
## el progreso («Pregunta 5 de 14»). Es una pantalla de EVALUACIÓN: no se puede cancelar (ESC no hace nada y no abre la
## pausa), ni abrir la libreta; no hay "Ahora no", no se puede saltar ni volver atrás. Nunca
## dice si una respuesta es correcta. Antes de cada bloque Lucía dice unas líneas (trivia, situaciones,
## escala). Al terminar llama a Evaluacion.calcular y emite fase_terminada(fase).
##
## Uso:   await Cuestionario.mostrar(get_tree(), "pre")   (o "post")

signal fase_terminada(fase: String)

const ESCENA := "res://Scenes/UI/Cuestionario.tscn"
const SEGUNDOS_FUNDIDO := 0.5

## Lo que dice Lucía antes de cada bloque (cada elemento es una línea). [REVISAR] textos escritos por el equipo.
const INTRO := {
	"trivia": ["Primero, cuánto sabes sobre qué hacer en un sismo.", "Aquí está bien equivocarse: no es un examen, solo queremos saber qué sabes hoy."],
	"situaciones": ["Ahora, qué harías en distintas situaciones.", "Elige lo que harías en ese momento."],
	"escala": ["Y por último, cómo te sientes con la preparación.", "Piensa en una escala del 1 al 5."],
}
const INTRO_POST := "Hemos llegado al final de este recorrido. Te haré las mismas preguntas del principio. "

var fase := ""

var _preguntas: Array[Dictionary] = []
var _raiz: Control
var _panel_intro: Control
var _texto_intro: Label
var _boton_seguir: Button
var _panel_pregunta: Control
var _progreso: Label
var _tablilla: Tablilla
var _casillas: Array[Casilla] = []
var _fila_progreso: HBoxContainer
var _sello_titulo: Sello
var _marco_intro: Control
var _retrato_intro: TextureRect
var _texto_pregunta: Label
var _contenedor_opciones: Control
var _botones: Array[Button] = []
var _respondida := false
var _respuesta := -1

signal _elegida(indice_original: int)
signal _seguir


## Muestra el cuestionario de la fase y espera a que termine (y se cierre).
static func mostrar(arbol: SceneTree, fase_: String) -> void:
	var escena := (load(ESCENA) as PackedScene).instantiate() as Cuestionario
	escena.fase = fase_
	arbol.root.add_child.call_deferred(escena)   # (diferido: la raíz puede estar ocupada montando la escena)
	await escena.tree_exited


func _ready() -> void:
	layer = 12
	process_mode = Node.PROCESS_MODE_ALWAYS
	FondoEvaluacion.crear(self)
	_raiz = Control.new()
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.theme = EstiloUI.tema()
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.modulate.a = 0.0
	add_child(_raiz)
	_construir()
	_ejecutar()


# Se tragan ESC (pausa) y TAB (libreta) mientras dura la evaluación
func _input(evento: InputEvent) -> void:
	for accion in ["PAUSA", "DIARIO", "ui_cancel"]:
		if evento.is_action_pressed(accion):
			get_viewport().set_input_as_handled()
			return


func _construir() -> void:
	# Intro de cada bloque: Lucía habla por radio (marco de transmisión con su retrato)
	_panel_intro = PanelContainer.new()
	_panel_intro.position = Vector2(70, 80)
	_panel_intro.custom_minimum_size = Vector2(500, 0)
	_panel_intro.add_theme_stylebox_override("panel", EstiloUI.caja(EstiloUI.PETROLEO_OSCURO, EstiloUI.NARANJA, 2, 10))
	_raiz.add_child(_panel_intro)
	var fila_radio := HBoxContainer.new()
	fila_radio.add_theme_constant_override("separation", 12)
	_panel_intro.add_child(fila_radio)
	_retrato_intro = TextureRect.new()
	_retrato_intro.custom_minimum_size = Vector2(96, 96)
	_retrato_intro.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_retrato_intro.texture = Retratos.obtener("lucia_neutral")
	fila_radio.add_child(_retrato_intro)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila_radio.add_child(v)
	var cabecera := HBoxContainer.new()
	cabecera.add_theme_constant_override("separation", 6)
	cabecera.add_child(EstiloUI.titulo("LUCÍA · CANAL 3 · BRIGADA", 8, EstiloUI.NARANJA))
	var franjas_radio := Franjas.new()
	franjas_radio.custom_minimum_size = Vector2(0, 5)
	franjas_radio.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	franjas_radio.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cabecera.add_child(franjas_radio)
	v.add_child(cabecera)
	_texto_intro = EstiloUI.radio("", 22, EstiloUI.CREMA)
	_texto_intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_texto_intro.custom_minimum_size = Vector2(340, 100)
	v.add_child(_texto_intro)
	_boton_seguir = EstiloUI.boton_senal("Seguir", 120, 26, 9)
	_boton_seguir.size_flags_horizontal = Control.SIZE_SHRINK_END
	_boton_seguir.pressed.connect(func() -> void:
		Audio.efecto("ui_elegir")
		_seguir.emit())
	_boton_seguir.focus_entered.connect(func() -> void: Audio.efecto("ui_mover"))
	v.add_child(_boton_seguir)

	# La tablilla con la hoja de la pregunta
	_tablilla = Tablilla.new()
	_tablilla.position = Vector2(80, 14)
	_tablilla.size = Vector2(480, 332)
	_raiz.add_child(_tablilla)
	_panel_pregunta = _tablilla
	var q := _tablilla.contenido
	q.add_theme_constant_override("separation", 6)
	var cabecera_hoja := HBoxContainer.new()
	cabecera_hoja.add_theme_constant_override("separation", 8)
	q.add_child(cabecera_hoja)
	_progreso = EstiloUI.titulo("", 8, EstiloUI.TINTA_SUAVE)
	_progreso.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cabecera_hoja.add_child(_progreso)
	# El progreso: una checklist de casillas, una por pregunta
	_fila_progreso = HBoxContainer.new()
	_fila_progreso.add_theme_constant_override("separation", 5)
	q.add_child(_fila_progreso)
	_texto_pregunta = EstiloUI.etiqueta("", 15, EstiloUI.TINTA)
	_texto_pregunta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_texto_pregunta.custom_minimum_size = Vector2(430, 52)
	q.add_child(_texto_pregunta)
	_contenedor_opciones = VBoxContainer.new()
	_contenedor_opciones.add_theme_constant_override("separation", 5)
	q.add_child(_contenedor_opciones)
	_panel_pregunta.hide()
	_panel_intro.hide()


## Estilo de una opción: casilla de papel a la izquierda, texto oscuro y un recuadro naranja al enfocar.
func _estilo_opcion(b: Button) -> void:
	var normal := EstiloUI.caja(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 2, 6)
	normal.content_margin_left = 30
	var foco := EstiloUI.caja(Color(EstiloUI.NARANJA, 0.18), EstiloUI.NARANJA, 2, 6)
	foco.content_margin_left = 30
	for e in ["normal", "disabled"]:
		b.add_theme_stylebox_override(e, normal)
	for e in ["hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(e, foco)
	b.add_theme_font_override("font", EstiloUI.fuente_texto())
	b.add_theme_font_size_override("font_size", 13)
	for c in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_disabled_color"]:
		b.add_theme_color_override(c, EstiloUI.TINTA)
	var casilla := Casilla.new()
	casilla.position = Vector2(8, 8)
	b.add_child(casilla)
	b.set_meta("casilla", casilla)


# --- Secuencia ---

func _ejecutar() -> void:
	Evaluacion.cuestionario_activo = true
	Evaluacion.iniciar_fase(fase)
	_preguntas = Evaluacion.orden_para(fase)
	_crear_checklist()
	create_tween().tween_property(_raiz, "modulate:a", 1.0, SEGUNDOS_FUNDIDO)
	Audio.efecto("dialogo_abrir")
	await get_tree().create_timer(SEGUNDOS_FUNDIDO).timeout
	await _sellar(("EVALUACIÓN DE INGRESO" if fase == "pre" else "EVALUACIÓN DE SALIDA"), EstiloUI.ROJO_TINTA)
	var bloque := ""
	for i in _preguntas.size():
		if str(_preguntas[i]["bloque"]) != bloque:
			bloque = str(_preguntas[i]["bloque"])
			await _intro(bloque)
		await _preguntar(i)
	Evaluacion.calcular(fase)
	Evaluacion.fase_terminada.emit(fase)
	fase_terminada.emit(fase)
	await _sellar("RECIBIDA", EstiloUI.TURQUESA_TINTA, true)
	var salida := create_tween()
	salida.tween_property(_raiz, "modulate:a", 0.0, SEGUNDOS_FUNDIDO)
	await salida.finished
	Evaluacion.cuestionario_activo = false
	queue_free()


## Una casilla por pregunta en la fila de progreso.
func _crear_checklist() -> void:
	for c in _fila_progreso.get_children():
		c.queue_free()
	_casillas.clear()
	for i in _preguntas.size():
		var c := Casilla.new()
		c.lado = 10.0
		c.custom_minimum_size = Vector2(14, 14)
		_fila_progreso.add_child(c)
		_casillas.append(c)


## Estampa un sello sobre la hoja (al empezar y al terminar) y espera un momento para que se vea.
func _sellar(texto: String, color: Color, sobre_hoja_vacia: bool = false) -> void:
	if is_instance_valid(_sello_titulo):
		_sello_titulo.queue_free()
	_panel_pregunta.hide()
	_panel_intro.hide()
	_sello_titulo = Sello.crear(texto, color, 18, -0.12)
	_sello_titulo.position = Vector2((640.0 - _sello_titulo.size.x) / 2.0, 150.0)
	_raiz.add_child(_sello_titulo)
	_sello_titulo.estampar()
	await get_tree().create_timer(1.1 if not sobre_hoja_vacia else 1.4).timeout
	_sello_titulo.queue_free()


## Lucía dice unas líneas antes de cada bloque.
func _intro(bloque: String) -> void:
	_panel_pregunta.hide()
	var lineas: Array = INTRO[bloque]
	var texto := "\n\n".join(lineas)
	if fase == "post" and bloque == "trivia":
		texto = INTRO_POST + "\n\n" + texto
	_texto_intro.text = texto
	_texto_intro.visible_characters = 0
	_boton_seguir.disabled = true
	_panel_intro.show()
	_retrato_intro.texture = Retratos.obtener("lucia_hablando")
	await Dialogo.escribir_etiqueta(_texto_intro, texto)   # mismo blip que todo el texto del juego
	_retrato_intro.texture = Retratos.obtener("lucia_neutral")
	_boton_seguir.disabled = false
	_boton_seguir.grab_focus()
	await _seguir
	_panel_intro.hide()


## Una pregunta: se espera a que el jugador elija; la respuesta se anota con su índice original.
func _preguntar(indice: int) -> void:
	var p := _preguntas[indice]
	_progreso.text = "Pregunta %d de %d" % [indice + 1, _preguntas.size()]
	_texto_pregunta.text = str(p["texto"])
	for hijo in _contenedor_opciones.get_children():
		hijo.queue_free()
	_botones.clear()
	_respondida = false
	if p["bloque"] == "escala":
		_construir_escala(p)
	else:
		for opcion in p["opciones"]:
			_botones.append(_boton_opcion(str(opcion["texto"]), int(opcion["indice_original"])))
	_panel_pregunta.modulate.a = 0.0
	_panel_pregunta.show()
	create_tween().tween_property(_panel_pregunta, "modulate:a", 1.0, 0.2)
	await get_tree().process_frame
	if not _botones.is_empty():
		_botones[0].grab_focus()
	var elegida: int = await _elegida
	Evaluacion.registrar(fase, str(p["id"]), elegida)
	if indice < _casillas.size():
		_casillas[indice].poner(true)
	# Sin decir si estaba bien o mal: solo un breve fundido hacia la siguiente
	var t := create_tween()
	t.tween_property(_panel_pregunta, "modulate:a", 0.0, 0.18)
	await t.finished


func _boton_opcion(texto: String, indice_original: int) -> Button:
	var b := Button.new()
	b.text = texto
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size = Vector2(430, 36)
	_estilo_opcion(b)
	b.pressed.connect(_al_elegir.bind(indice_original, b))
	b.focus_entered.connect(func() -> void: Audio.efecto("ui_mover"))
	_contenedor_opciones.add_child(b)
	return b


## Escala del 1 al 5: cinco botones numerados y los extremos rotulados debajo.
func _construir_escala(p: Dictionary) -> void:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 8)
	fila.alignment = BoxContainer.ALIGNMENT_CENTER
	_contenedor_opciones.add_child(fila)
	for opcion in p["opciones"]:
		var b := Button.new()
		b.text = str(opcion["texto"])
		b.custom_minimum_size = Vector2(62, 44)
		_estilo_opcion(b)
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.add_theme_font_size_override("font_size", 16)
		b.pressed.connect(_al_elegir.bind(int(opcion["indice_original"]), b))
		b.focus_entered.connect(func() -> void: Audio.efecto("ui_mover"))
		fila.add_child(b)
		_botones.append(b)
	var extremos := HBoxContainer.new()
	_contenedor_opciones.add_child(extremos)
	var izquierda := EstiloUI.etiqueta("1 = %s" % p["minimo"], 11, EstiloUI.TINTA_SUAVE)
	izquierda.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	extremos.add_child(izquierda)
	var derecha := EstiloUI.etiqueta("5 = %s" % p["maximo"], 11, EstiloUI.TINTA_SUAVE)
	derecha.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	derecha.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	extremos.add_child(derecha)


func _al_elegir(indice_original: int, boton: Button = null) -> void:
	if _respondida:
		return
	_respondida = true
	Audio.efecto("ui_elegir")
	for b in _botones:
		b.disabled = true
	# La casilla de la opción elegida se marca con lápiz antes de pasar a la siguiente pregunta
	if boton != null and boton.has_meta("casilla"):
		(boton.get_meta("casilla") as Casilla).poner(true)
		await get_tree().create_timer(0.4).timeout
	_elegida.emit(indice_original)
