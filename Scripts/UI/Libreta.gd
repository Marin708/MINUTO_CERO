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
const PESTANAS := ["Lecciones", "Mitos y realidades", "Memoria de 1999", "Mi plan", "Avisos"]
## Color del separador de cada pestaña y color de su texto (contraste alto sobre cada uno).
const COLOR_PESTANA := [EstiloUI.NARANJA, EstiloUI.AMBAR, EstiloUI.TURQUESA, Color("7fbfd0"), Color("e8957f")]
const PAPEL := Color("fbf5e4")

var abierto := false
var pestana := 0

var _raiz: Control
var _contenido: VBoxContainer
var _scroll: ScrollContainer
var _botones: Array[Button] = []
var _modal: ModalBase
var _lomo_cuaderno: ColorRect


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
	# El cuaderno sobre ModalBase: separadores de colores fijos arriba, la pestaña con scroll y el pie con la ayuda
	_modal = ModalBase.crear()
	_modal.ancho_deseado = 540.0
	var hoja := EstiloUI.caja(EstiloUI.CREMA, EstiloUI.TINTA, 2, 8)
	hoja.content_margin_left = 32   # el lomo de espiral va a la izquierda
	_modal.panel.add_theme_stylebox_override("panel", hoja)
	_modal.color_separadores(Color(EstiloUI.TINTA_SUAVE, 0.6))
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 4)
	_modal.cabecera.add_child(fila)
	for i in PESTANAS.size():
		var b := Button.new()
		b.text = PESTANAS[i]
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_ALL
		_estilo_pestana(b, COLOR_PESTANA[i])
		b.pressed.connect(_elegir.bind(i))
		fila.add_child(b)
		_botones.append(b)
	_scroll = _modal.scroll
	_contenido = _modal.cuerpo
	_modal.pie.add_child(EstiloUI.etiqueta("Tab o Esc para cerrar · flechas izquierda y derecha cambian de pestaña", 11, EstiloUI.TINTA_SUAVE))
	_raiz.add_child(_modal)
	_lomo_cuaderno = _lomo()
	_raiz.add_child(_lomo_cuaderno)
	_modal.reajustado.connect(_colocar_lomo)


## El lomo se pega al borde izquierdo del cuaderno y mide lo mismo que él.
func _colocar_lomo() -> void:
	_lomo_cuaderno.position = _modal.panel.position + Vector2(2, 2)
	_lomo_cuaderno.size = Vector2(22, _modal.panel.size.y - 4)
	for h in _lomo_cuaderno.get_children():
		h.queue_free()
	for i in int((_lomo_cuaderno.size.y - 20) / 30):
		var agujero := ColorRect.new()
		agujero.color = EstiloUI.CREMA
		agujero.size = Vector2(10, 5)
		agujero.position = Vector2(6, 14 + i * 30)
		agujero.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_lomo_cuaderno.add_child(agujero)


## El lomo del cuaderno: una tira azul petróleo con los agujeros de la espiral.
func _lomo() -> Control:
	var lomo := ColorRect.new()
	lomo.color = EstiloUI.PETROLEO
	lomo.custom_minimum_size = Vector2(22, 0)
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
		4:
			_avisos()
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


## Historial de avisos: los últimos 30, del más nuevo al más viejo, con su hora de juego.
func _avisos() -> void:
	_contenido.add_child(_texto("Aquí quedan los últimos %d avisos por si se te pasó alguno." % Estado.MAX_AVISOS, 10, EstiloUI.TINTA_SUAVE))
	if Estado.avisos.is_empty():
		_contenido.add_child(_texto("Todavía no hay avisos.", 13, EstiloUI.TINTA_SUAVE))
		return
	for i in range(Estado.avisos.size() - 1, -1, -1):
		var a: Dictionary = Estado.avisos[i]
		var cuerpo: Array = []
		if str(a.get("texto", "")) != "":
			cuerpo.append(str(a["texto"]))
		cuerpo.append("Hora de juego: %s" % Estado.formato_hora(float(a.get("hora", 0.0))))
		_contenido.add_child(_tarjeta(str(a.get("titulo", "")), cuerpo))
