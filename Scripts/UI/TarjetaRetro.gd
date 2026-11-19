class_name TarjetaRetro
extends CanvasLayer
## La tarjeta de retroalimentación de las decisiones (siempre el mismo diseño, capa 13):
## título («Muy bien», «Casi» u «Ojo»), «Lo que hiciste», «Lo recomendado», «Por qué» y un botón «Entendido» y,
## si la decisión no fue segura, también «Intentar de nuevo». Con el juego en pausa mientras está abierta.
## Diseño de señal de seguridad (pictograma, borde del color del resultado). El tono es cálido y breve: nunca hay burla ni pantalla de muerte.
##
## La crea Retroalimentacion (autoload) desde Scenes/UI/TarjetaRetro.tscn.
## Uso:  var reintentar: bool = await TarjetaRetro.mostrar(get_tree(), "Ojo", hecho, recomendado, por_que, true)

signal cerrada(reintentar: bool)

## Color de la señal según el título (acierto, precaución, riesgo). Los pictogramas se dibujan en Pictograma.gd.
const COLOR_TITULO := {"Muy bien": EstiloUI.TURQUESA, "Casi": EstiloUI.AMBAR, "Ojo": EstiloUI.ROJO}

var _titulo := ""
var _hecho := ""
var _recomendado := ""
var _por_que := ""
var _permite_reintento := false
var _cerrando := false
var _primer_boton: Button
var _panel: PanelContainer
var _fila_botones: HBoxContainer
var _textos: Array[Label] = []


## Muestra la tarjeta y espera. Devuelve true si el jugador pidió «Intentar de nuevo». En las pruebas sin ventana
## (Dialogo.respuesta_de_prueba distinto de -99) no se muestra y devuelve false.
static func mostrar(arbol: SceneTree, titulo: String, hecho: String, recomendado: String, por_que: String, permite_reintento: bool) -> bool:
	if Dialogo.respuesta_de_prueba != -99:
		await arbol.process_frame
		return false
	var tarjeta: TarjetaRetro = (load("res://Scenes/UI/TarjetaRetro.tscn") as PackedScene).instantiate()
	tarjeta._titulo = titulo
	tarjeta._hecho = hecho
	tarjeta._recomendado = recomendado
	tarjeta._por_que = por_que
	tarjeta._permite_reintento = permite_reintento
	arbol.root.add_child.call_deferred(tarjeta)
	var reintentar: bool = await tarjeta.cerrada
	return reintentar


func _ready() -> void:
	layer = 13
	process_mode = Node.PROCESS_MODE_ALWAYS
	var raiz := Control.new()
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.theme = EstiloUI.tema()
	add_child(raiz)
	var velo := ColorRect.new()
	velo.color = Color(EstiloUI.AZUL_NOCHE, 0.7)
	velo.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.add_child(velo)

	# La tarjeta es una señal de seguridad: borde del color del resultado, pictograma y título en la cabecera
	var color: Color = COLOR_TITULO.get(_titulo, EstiloUI.NARANJA)
	var panel := PanelContainer.new()
	panel.position = Vector2(110, 15)
	panel.custom_minimum_size = Vector2(420, 0)
	_panel = panel
	panel.add_theme_stylebox_override("panel", EstiloUI.caja(EstiloUI.PETROLEO, color, 2, 0))
	raiz.add_child(panel)
	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 0)
	panel.add_child(columna)
	var cinta := ColorRect.new()
	cinta.color = color
	cinta.custom_minimum_size = Vector2(0, 5)
	columna.add_child(cinta)
	var cabecera := PanelContainer.new()
	cabecera.add_theme_stylebox_override("panel", EstiloUI.caja(EstiloUI.PETROLEO_OSCURO, EstiloUI.PETROLEO_OSCURO, 0, 8))
	columna.add_child(cabecera)
	var fila_cab := HBoxContainer.new()
	fila_cab.add_theme_constant_override("separation", 10)
	cabecera.add_child(fila_cab)
	fila_cab.add_child(Pictograma.para_titulo(_titulo, 40.0))
	var titulo := EstiloUI.titulo(_titulo.to_upper(), 16, EstiloUI.CREMA)
	titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titulo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fila_cab.add_child(titulo)
	# Sami: preocupado cuando es «Ojo», neutral en los demás casos
	var cara := TextureRect.new()
	cara.texture = Retratos.rostro("sami_preocupado" if _titulo == "Ojo" else "sami_neutral")
	cara.custom_minimum_size = Vector2(48, 48)
	cara.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cara.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	cara.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila_cab.add_child(cara)
	var margen := MarginContainer.new()
	for lado in ["left", "right", "top", "bottom"]:
		margen.add_theme_constant_override("margin_" + lado, 12)
	columna.add_child(margen)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 7)
	margen.add_child(v)
	_textos.append(_bloque(v, "Lo que hiciste", _hecho))
	_textos.append(_bloque(v, "Lo recomendado", _recomendado))
	_textos.append(_bloque(v, "Por qué", _por_que))
	_textos.append(_nota(v, "Para recordar", "Recuerda: %s" % _recomendado.trim_suffix(".")))
	var fila := HBoxContainer.new()
	fila.alignment = BoxContainer.ALIGNMENT_END
	fila.add_theme_constant_override("separation", 10)
	v.add_child(fila)
	if _permite_reintento:
		fila.add_child(_boton("Intentar de nuevo", true))
	_primer_boton = _boton("Entendido", false)
	fila.add_child(_primer_boton)
	_fila_botones = fila
	fila.modulate.a = 0.0
	Audio.efecto("dialogo_opciones")
	get_tree().paused = true
	_escribir.call_deferred()


## Los textos se escriben letra por letra, con el mismo efecto y el mismo sonido de letras que los diálogos.
## Los botones aparecen al terminar (o antes, con E o ENTER, que completa el texto de golpe).
func _escribir() -> void:
	# La tarjeta se ajusta a su contenido y queda centrada en la pantalla
	await get_tree().process_frame
	_panel.reset_size()
	_panel.position = Vector2(110, maxf(8.0, (360.0 - _panel.size.y) / 2.0))
	for e in _textos:
		var texto := e.text
		await Dialogo.escribir_etiqueta(e, texto)
		if _cerrando or not is_instance_valid(self):
			return
	_mostrar_botones()


func _mostrar_botones() -> void:
	for e in _textos:
		e.visible_characters = -1
	_fila_botones.modulate.a = 1.0
	_primer_boton.grab_focus()


func _bloque(padre: Control, rotulo: String, texto: String) -> Label:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.add_child(EstiloUI.titulo(rotulo.to_upper(), 8, EstiloUI.NARANJA))
	var e := EstiloUI.etiqueta(texto, 13, EstiloUI.CREMA)
	e.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	e.custom_minimum_size = Vector2(394, 0)
	e.visible_characters = 0
	v.add_child(e)
	padre.add_child(v)
	return e


## La frase para recordar va en una nota de papel crema con texto oscuro.
func _nota(padre: Control, rotulo: String, texto: String) -> Label:
	var caja := PanelContainer.new()
	caja.add_theme_stylebox_override("panel", EstiloUI.caja(EstiloUI.CREMA, EstiloUI.TINTA, 2, 6))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	caja.add_child(v)
	v.add_child(EstiloUI.titulo(rotulo.to_upper(), 8, EstiloUI.TINTA_SUAVE))
	var e := EstiloUI.etiqueta(texto, 13, EstiloUI.TINTA)
	e.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	e.custom_minimum_size = Vector2(380, 0)
	e.visible_characters = 0
	v.add_child(e)
	padre.add_child(caja)
	return e


func _boton(texto: String, reintentar: bool) -> Button:
	var b := Button.new()
	b.text = texto
	b.custom_minimum_size = Vector2(120, 28)
	b.pressed.connect(_cerrar.bind(reintentar))
	b.focus_entered.connect(func() -> void: Audio.efecto("ui_mover"))
	return b


func _cerrar(reintentar: bool) -> void:
	if _cerrando:
		return
	_cerrando = true
	Audio.efecto("ui_elegir")
	get_tree().paused = false
	cerrada.emit(reintentar)
	queue_free()


# ESC y TAB no cierran la tarjeta ni abren menús: hay que elegir un botón. E o ENTER completan el texto.
func _input(evento: InputEvent) -> void:
	if (evento.is_action_pressed("INTERACTUAR") or evento.is_action_pressed("ui_accept")) and _fila_botones != null and _fila_botones.modulate.a < 1.0:
		get_viewport().set_input_as_handled()
		_mostrar_botones()
		return
	for accion in ["PAUSA", "DIARIO", "ui_cancel"]:
		if evento.is_action_pressed(accion):
			get_viewport().set_input_as_handled()
			return
