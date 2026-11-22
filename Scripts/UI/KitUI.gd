class_name KitUI
extends CanvasLayer
## La pantalla del kit de emergencia (decisión D5), sobre ModalBase (cabecera fija, cuadrícula en el cuerpo y pie fijo con el
## contador «Elegidos: n de 8» y el botón «Listo», siempre visible): 12 objetos de Assets/UI/kit.png (iconos de 32 x 32, 4 x 3),
## de los que hay que elegir 8. Cuenta si hay al menos 7 correctos y 1 distractor como máximo
## (Resources/contenido/kit.json; la regla es interna: el jugador no la lee). Después sale la tarjeta de retroalimentación con
## lo elegido (✔ correctos, ✖ distractores) y solo lo que faltó.
## Teclado: flechas para moverse por la cuadrícula, E o Espacio para elegir o quitar un objeto y Enter para «Listo».
## Los índices de kit.png son los del JSON: 0 a 7 correctos y 8 a 11 distractores.
##
## Uso:  var lograda: bool = await KitUI.mostrar(get_tree())

signal confirmado(ids: Array)

const RUTA_KIT := "res://Assets/UI/kit.png"
const RUTA_JSON := "res://Resources/contenido/kit.json"
const LADO_ICONO := 32

## Solo para pruebas: si no está vacío, se usa como selección sin abrir la pantalla.
static var seleccion_de_prueba: Array = []

var _datos: Dictionary = {}
var _objetos: Array = []
var _elegidos: Array[String] = []
var _botones: Dictionary = {}
var _contador: Label
var _modal: ModalBase
var _boton_listo: Button
var _cerrando := false


## Si la selección cumple la regla del kit (mínimo de correctos y máximo de distractores).
static func cumple_regla(ids: Array) -> bool:
	var d := _leer()
	var correctos := 0
	var distractores := 0
	for o in d["objetos"]:
		if ids.has(o["id"]):
			if o["correcto"]:
				correctos += 1
			else:
				distractores += 1
	var regla: Dictionary = d["regla"]
	return ids.size() == int(regla["elegir"]) and correctos >= int(regla["minimo_correctos"]) and distractores <= int(regla["maximo_distractores"])


static func _leer() -> Dictionary:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(RUTA_JSON))
	return d if typeof(d) == TYPE_DICTIONARY else {}


## Lo elegido, en el orden del archivo: [{"texto": nombre, "ok": true si es correcto}].
static func lista_elegidos(ids: Array) -> Array:
	var lista: Array = []
	for o in _leer()["objetos"]:
		if ids.has(o["id"]):
			lista.append({"texto": str(o["nombre"]), "ok": bool(o["correcto"])})
	return lista


## Solo los objetos correctos que NO se eligieron, separados por comas ("" si no faltó ninguno).
static func _faltaron(ids: Array) -> String:
	var lista: Array[String] = []
	for o in _leer()["objetos"]:
		if o["correcto"] and not ids.has(o["id"]):
			lista.append(str(o["nombre"]))
	return ", ".join(lista)


static func _nombres(ids: Array, solo_correctos: bool = false) -> String:
	var lista: Array[String] = []
	for o in _leer()["objetos"]:
		if (solo_correctos and o["correcto"]) or (not solo_correctos and ids.has(o["id"])):
			lista.append(str(o["nombre"]))
	return ", ".join(lista)


## Pide el kit, lo evalúa con Estado/TarjetaRetro y se repite si el jugador pide «Intentar de nuevo».
static func mostrar(arbol: SceneTree) -> bool:
	var d := Estado.datos_decision("D5")
	while true:
		var ids: Array
		if not seleccion_de_prueba.is_empty():
			ids = seleccion_de_prueba
			await arbol.process_frame
		else:
			var pantalla := KitUI.new()
			arbol.root.add_child.call_deferred(pantalla)
			ids = await pantalla.confirmado
		var segura := cumple_regla(ids)
		var primero := Estado.registrar_decision("D5", segura)
		var titulo := "Ojo"
		if segura:
			titulo = "Muy bien" if primero else "Casi"
		var reintentar: bool = await TarjetaRetro.mostrar(arbol, titulo, "", _faltaron(ids), str(d["retro"]), not segura, lista_elegidos(ids))
		if segura:
			return true
		if not reintentar or not seleccion_de_prueba.is_empty():
			return false
	return false


func _ready() -> void:
	layer = 12
	process_mode = Node.PROCESS_MODE_ALWAYS
	_datos = _leer()
	_objetos = (_datos["objetos"] as Array).duplicate()
	if Dialogo.respuesta_de_prueba == -99:
		_objetos.shuffle()
	var raiz := Control.new()
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.theme = EstiloUI.tema()
	add_child(raiz)
	var velo := ColorRect.new()
	velo.color = Color(EstiloUI.AZUL_NOCHE, 0.78)
	velo.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.add_child(velo)
	_modal = ModalBase.crear()
	_modal.ancho_deseado = 520.0
	_modal.confirmar_activo = false   # aquí Enter, E y Espacio tienen su propio uso (ver _input)
	_modal.configurar(EstiloUI.PETROLEO, EstiloUI.NARANJA, 12)
	_modal.cabecera.add_child(EstiloUI.titulo("Arma tu kit de emergencia", 14, EstiloUI.NARANJA))
	var ayuda := EstiloUI.etiqueta("Elige 8 de los 12 objetos. Piensa en lo que necesitarías en las primeras horas.", 12, EstiloUI.CREMA)
	ayuda.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ayuda.custom_minimum_size = Vector2(120, 0)
	_modal.cabecera.add_child(ayuda)
	# La cuadrícula: celdas bajas (icono a la izquierda) para que quepa sin scroll
	var rejilla := GridContainer.new()
	rejilla.columns = 4
	rejilla.add_theme_constant_override("h_separation", 6)
	rejilla.add_theme_constant_override("v_separation", 5)
	rejilla.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_modal.cuerpo.add_child(rejilla)
	for o in _objetos:
		rejilla.add_child(_casilla(o))
	# Pie fijo: contador y «Listo»
	_contador = EstiloUI.etiqueta("", 13, EstiloUI.CREMA)
	_contador.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_contador.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_modal.pie.add_child(_contador)
	_boton_listo = EstiloUI.boton_senal("Listo", 110, 28, 10)
	_boton_listo.pressed.connect(_confirmar)
	_modal.pie.add_child(_boton_listo)
	_modal.boton_principal = _boton_listo
	raiz.add_child(_modal)
	_actualizar()
	get_tree().paused = true
	(_botones[_objetos[0]["id"]] as Button).grab_focus.call_deferred()


func _casilla(o: Dictionary) -> Control:
	var b := Button.new()
	b.toggle_mode = true
	b.custom_minimum_size = Vector2(120, 44)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.icon = _icono(int(o["icono"]))
	b.expand_icon = false
	b.text = str(o["nombre"])
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.clip_text = false
	b.add_theme_font_override("font", EstiloUI.fuente_texto())
	b.add_theme_font_size_override("font_size", 11)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.toggled.connect(_on_alternado.bind(str(o["id"]), b))
	b.focus_entered.connect(func() -> void: Audio.efecto("ui_mover"))
	_botones[o["id"]] = b
	return b


func _icono(indice: int) -> Texture2D:
	var atlas := AtlasTexture.new()
	atlas.atlas = load(RUTA_KIT)
	atlas.region = Rect2((indice % 4) * LADO_ICONO, (indice / 4) * LADO_ICONO, LADO_ICONO, LADO_ICONO)
	return atlas


func _on_alternado(activo: bool, id: String, boton: Button) -> void:
	if activo and _elegidos.size() >= int(_datos["regla"]["elegir"]):
		boton.set_pressed_no_signal(false)   # ya hay 8: primero hay que quitar uno
		return
	# El silbato suena al elegirlo; los demás objetos suenan a «recoger»
	Audio.efecto("silbato" if activo and id == "silbato" else ("item_recoge" if activo else "ui_cancelar"))
	if activo:
		_elegidos.append(id)
	else:
		_elegidos.erase(id)
	_actualizar()


func _actualizar() -> void:
	var meta := int(_datos["regla"]["elegir"])
	_contador.text = "Elegidos: %d de %d" % [_elegidos.size(), meta]
	_boton_listo.disabled = _elegidos.size() != meta


func _confirmar() -> void:
	if _cerrando or _elegidos.size() != int(_datos["regla"]["elegir"]):
		return
	_cerrando = true
	Audio.efecto("ui_elegir")
	get_tree().paused = false
	confirmado.emit(_elegidos.duplicate())
	queue_free()


# ESC y TAB no cierran la pantalla: el kit hay que armarlo.
# Enter confirma («Listo»), y E o Espacio eligen o quitan el objeto enfocado.
func _input(evento: InputEvent) -> void:
	for accion in ["PAUSA", "DIARIO", "ui_cancel"]:
		if evento.is_action_pressed(accion):
			get_viewport().set_input_as_handled()
			return
	if Dialogo.debe_ignorarse(evento):   # tecla repetida o demasiado pronto: nada
		get_viewport().set_input_as_handled()
		return
	if evento.is_action_pressed(Dialogo.ACCION_AVANZAR):
		get_viewport().set_input_as_handled()
		if not _boton_listo.disabled:
			_boton_listo.pressed.emit()
		return
	if evento.is_action_pressed("INTERACTUAR") and not evento.is_echo():
		var foco := get_viewport().gui_get_focus_owner()
		if foco is Button and (foco as Button).toggle_mode:
			get_viewport().set_input_as_handled()
			(foco as Button).button_pressed = not (foco as Button).button_pressed
