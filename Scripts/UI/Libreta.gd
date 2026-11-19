class_name Libreta
extends CanvasLayer
## La libreta (tecla TAB, capa 8): un cuaderno de campo con separadores de colores, uno por pestaña.
##   Lecciones          cada retroalimentación recibida (la situación, lo recomendado y por qué)
##   Mitos y realidades Resources/contenido/mitos.json
##   Memoria de 1999    las tarjetas desbloqueadas, una por nivel (Resources/contenido/memoria.json)
##   Mi plan            «Mi plan en 5 pasos» (Resources/contenido/plan.json)
## Reemplaza al diario de ECOS. Las tarjetas y las lecciones salen de Estado.

signal abierta_cambiada(abierta: bool)

const CARPETA := "res://Resources/contenido/"
const PESTANAS := ["Lecciones", "Mitos y realidades", "Memoria de 1999", "Mi plan"]
## Color del separador de cada pestaña y color de su texto (contraste alto sobre cada uno).
const COLOR_PESTANA := [EstiloUI.NARANJA, EstiloUI.AMBAR, EstiloUI.TURQUESA, Color("7fbfd0")]
const PAPEL := Color("fbf5e4")

var abierto := false
var pestana := 0

var _raiz: Control
var _contenido: VBoxContainer
var _scroll: ScrollContainer
var _botones: Array[Button] = []


func _ready() -> void:
	layer = 8
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_raiz = Control.new()
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.theme = EstiloUI.tema()
	add_child(_raiz)
	var velo := ColorRect.new()
	velo.color = Color(0.03, 0.12, 0.16, 0.7)
	velo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.add_child(velo)
	# El cuaderno: hoja crema con el lomo de espiral a la izquierda y los separadores de colores arriba
	var panel := PanelContainer.new()
	panel.position = Vector2(50, 20)
	panel.size = Vector2(540, 320)
	panel.add_theme_stylebox_override("panel", EstiloUI.caja(EstiloUI.CREMA, EstiloUI.TINTA, 2, 0))
	_raiz.add_child(panel)
	var cuerpo := HBoxContainer.new()
	cuerpo.add_theme_constant_override("separation", 0)
	panel.add_child(cuerpo)
	cuerpo.add_child(_lomo())
	var margen := MarginContainer.new()
	margen.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for lado in ["left", "right", "top", "bottom"]:
		margen.add_theme_constant_override("margin_" + lado, 8)
	cuerpo.add_child(margen)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	margen.add_child(v)
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 4)
	v.add_child(fila)
	for i in PESTANAS.size():
		var b := Button.new()
		b.text = PESTANAS[i]
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_ALL
		_estilo_pestana(b, COLOR_PESTANA[i])
		b.pressed.connect(_elegir.bind(i))
		fila.add_child(b)
		_botones.append(b)
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(488, 246)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(_scroll)
	_contenido = VBoxContainer.new()
	_contenido.add_theme_constant_override("separation", 8)
	_contenido.custom_minimum_size = Vector2(470, 0)
	_scroll.add_child(_contenido)
	v.add_child(EstiloUI.etiqueta("Tab o Esc para cerrar · flechas izquierda y derecha cambian de pestaña", 11, EstiloUI.TINTA_SUAVE))


## El lomo del cuaderno: una tira azul petróleo con los agujeros de la espiral.
func _lomo() -> Control:
	var lomo := ColorRect.new()
	lomo.color = EstiloUI.PETROLEO
	lomo.custom_minimum_size = Vector2(22, 0)
	for i in 10:
		var agujero := ColorRect.new()
		agujero.color = EstiloUI.CREMA
		agujero.size = Vector2(10, 5)
		agujero.position = Vector2(6, 14 + i * 30)
		agujero.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lomo.add_child(agujero)
	return lomo


## Un separador de color: apagado cuando no está elegido, y lleno y con borde oscuro cuando sí.
func _estilo_pestana(b: Button, color: Color) -> void:
	var apagado := EstiloUI.caja(color.darkened(0.35), EstiloUI.TINTA, 2, 5)
	var lleno := EstiloUI.caja(color, EstiloUI.TINTA, 2, 5)
	b.add_theme_stylebox_override("normal", apagado)
	b.add_theme_stylebox_override("hover", lleno)
	b.add_theme_stylebox_override("pressed", lleno)
	b.add_theme_stylebox_override("hover_pressed", lleno)
	b.add_theme_stylebox_override("focus", lleno)
	b.add_theme_font_size_override("font_size", 8)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, EstiloUI.TINTA)


func abrir() -> void:
	if abierto:
		return
	abierto = true
	visible = true
	Audio.efecto("diario_abrir")
	_elegir(pestana)
	_botones[pestana].grab_focus()
	abierta_cambiada.emit(true)


func cerrar() -> void:
	if not abierto:
		return
	abierto = false
	visible = false
	Audio.efecto("diario_cerrar")
	abierta_cambiada.emit(false)


func _unhandled_input(evento: InputEvent) -> void:
	if not abierto:
		return
	if evento.is_action_pressed("DIARIO") or evento.is_action_pressed("PAUSA"):
		get_viewport().set_input_as_handled()
		cerrar()
	elif evento.is_action_pressed("DERECHA") or evento.is_action_pressed("IZQUIERDA"):
		get_viewport().set_input_as_handled()
		_elegir((pestana + (1 if evento.is_action_pressed("DERECHA") else PESTANAS.size() - 1)) % PESTANAS.size())
		_botones[pestana].grab_focus()


func _elegir(indice: int) -> void:
	pestana = indice
	for i in _botones.size():
		_botones[i].set_pressed_no_signal(i == indice)
	for hijo in _contenido.get_children():
		hijo.queue_free()
	match indice:
		0:
			_lecciones()
		1:
			_mitos()
		2:
			_memoria()
		3:
			_plan()
	_scroll.scroll_vertical = 0


static func _leer(nombre: String) -> Dictionary:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(CARPETA + nombre))
	return d if typeof(d) == TYPE_DICTIONARY else {}


func _texto(texto: String, tamano: int = 12, color: Color = EstiloUI.TINTA) -> Label:
	var e := EstiloUI.etiqueta(texto, tamano, color)
	e.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	e.custom_minimum_size = Vector2(458, 0)
	return e


func _tarjeta(titulo: String, cuerpo: Array) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", EstiloUI.caja(PAPEL, EstiloUI.TINTA_SUAVE, 2, 7))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	panel.add_child(v)
	v.add_child(_texto(titulo, 13, EstiloUI.PETROLEO))
	for linea in cuerpo:
		v.add_child(_texto(str(linea)))
	return panel


func _lecciones() -> void:
	if Estado.lecciones.is_empty():
		_contenido.add_child(_texto("Aquí irás guardando lo que aprendas en cada decisión.", 13, EstiloUI.TINTA_SUAVE))
		return
	for id in Estado.lecciones:
		var d := Estado.datos_decision(id)
		var cuerpo: Array = []
		if int(d.get("segura", -1)) >= 0:
			cuerpo.append("Lo recomendado: %s" % str((d["opciones"] as Array)[int(d["segura"])]))
		cuerpo.append(str(d.get("retro", "")))
		_contenido.add_child(_tarjeta("%s · %s" % [id, str(d.get("situacion", ""))], cuerpo))


func _mitos() -> void:
	for m in _leer("mitos.json").get("mitos", []):
		var decision := str(m.get("desbloqueo", ""))
		if decision == "" or Estado.decision_resuelta(decision):
			_contenido.add_child(_tarjeta("Mito: %s" % str(m["mito"]), ["Realidad: %s" % str(m["realidad"])]))
		else:
			_contenido.add_child(_tarjeta("Mito por descubrir", ["Se desbloquea al avanzar en el juego."]))


func _memoria() -> void:
	_contenido.add_child(_texto("Homenaje al terremoto del Eje Cafetero del 25 de enero de 1999. Se desbloquea una tarjeta por nivel.", 10, EstiloUI.TINTA_SUAVE))
	for t in _leer("memoria.json").get("tarjetas", []):
		if Estado.tarjeta_desbloqueada_id(str(t["id"])):
			_contenido.add_child(_tarjeta(str(t["titulo"]), [str(t["texto"])]))
		else:
			_contenido.add_child(_tarjeta("Tarjeta bloqueada", ["Se desbloquea al terminar el nivel %d." % int(t["nivel"])]))


func _plan() -> void:
	var d := _leer("plan.json")
	for p in d.get("pasos", []):
		_contenido.add_child(_tarjeta("%d. %s" % [int(p["numero"]), str(p["texto"])], []))
