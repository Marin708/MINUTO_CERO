class_name HUD
extends CanvasLayer
## El HUD discreto de los niveles (capa 5): la lista de tareas del nivel arriba a la izquierda y el contador de
## lecciones aprendidas arriba a la derecha. Se construye por código.
##
##   hud.configurar("Nivel 1 · Antes", [{"id": "D1", "texto": "Revisar el estante"}, ...])
##   hud.marcar("D1")

var _titulo: Label
var _lista: VBoxContainer
var _lecciones: Label
var _tareas: Array[Dictionary] = []
var _filas: Dictionary = {}


func _ready() -> void:
	layer = 5
	var panel := PanelContainer.new()
	panel.position = Vector2(6, 6)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", EstiloUI.caja(Color("0f2d38", 0.78), Color("1d5566"), 1, 6, 4))
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	panel.add_child(v)
	_titulo = EstiloUI.etiqueta("", 11, EstiloUI.NARANJA)
	v.add_child(_titulo)
	_lista = VBoxContainer.new()
	_lista.add_theme_constant_override("separation", 1)
	v.add_child(_lista)

	var caja_lecciones := PanelContainer.new()
	caja_lecciones.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	caja_lecciones.position = Vector2(640 - 108, 6)
	caja_lecciones.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caja_lecciones.add_theme_stylebox_override("panel", EstiloUI.caja(Color("0f2d38", 0.78), Color("1d5566"), 1, 5, 4))
	add_child(caja_lecciones)
	_lecciones = EstiloUI.etiqueta("", 10, EstiloUI.CREMA)
	caja_lecciones.add_child(_lecciones)
	Estado.leccion_aprendida.connect(func(_id: String) -> void: _actualizar_lecciones())
	_actualizar_lecciones()


func configurar(titulo: String, tareas: Array) -> void:
	_titulo.text = titulo
	_tareas.clear()
	for hijo in _lista.get_children():
		hijo.queue_free()
	_filas.clear()
	for t in tareas:
		_tareas.append({"id": str(t["id"]), "texto": str(t["texto"]), "hecho": false})
		var e := EstiloUI.etiqueta("", 10, EstiloUI.CREMA)
		_lista.add_child(e)
		_filas[str(t["id"])] = e
	_refrescar()


func marcar(id: String) -> void:
	for t in _tareas:
		if t["id"] == id:
			t["hecho"] = true
	_refrescar()


func esta_hecha(id: String) -> bool:
	for t in _tareas:
		if t["id"] == id:
			return bool(t["hecho"])
	return false


func todas_hechas() -> bool:
	for t in _tareas:
		if not t["hecho"]:
			return false
	return true


func _refrescar() -> void:
	for t in _tareas:
		var e: Label = _filas[t["id"]]
		e.text = "%s %s" % ["[x]" if t["hecho"] else "[ ]", t["texto"]]
		e.add_theme_color_override("font_color", EstiloUI.GRIS if t["hecho"] else EstiloUI.CREMA)


func _actualizar_lecciones() -> void:
	if _lecciones != null:
		_lecciones.text = "Lecciones: %d" % Estado.cantidad_lecciones()
