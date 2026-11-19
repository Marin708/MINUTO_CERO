class_name HUD
extends CanvasLayer
## El HUD discreto de los niveles (capa 5): la lista de tareas del nivel como un checklist de brigada sobre una
## tablilla pequeña, con casillas que se marcan con lápiz, y arriba a la derecha el contador de lecciones.
## Se construye por código.
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
	# La tablilla: hoja crema con un sujetapapeles naranja y un borde de madera oscura
	var tablilla := PanelContainer.new()
	tablilla.position = Vector2(6, 10)
	tablilla.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tablilla.add_theme_stylebox_override("panel", EstiloUI.caja(Color(EstiloUI.CREMA, 0.94), EstiloUI.TINTA, 2, 6))
	add_child(tablilla)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	tablilla.add_child(v)
	_titulo = EstiloUI.titulo("", 8, EstiloUI.TINTA)
	v.add_child(_titulo)
	var raya := ColorRect.new()
	raya.color = EstiloUI.TINTA_SUAVE
	raya.custom_minimum_size = Vector2(0, 1)
	v.add_child(raya)
	_lista = VBoxContainer.new()
	_lista.add_theme_constant_override("separation", 2)
	v.add_child(_lista)
	var clip := ColorRect.new()
	clip.color = EstiloUI.NARANJA
	clip.size = Vector2(26, 8)
	clip.position = Vector2(6 + 12, 4)
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(clip)

	var caja_lecciones := PanelContainer.new()
	caja_lecciones.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	caja_lecciones.position = Vector2(640 - 118, 6)
	caja_lecciones.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caja_lecciones.add_theme_stylebox_override("panel", EstiloUI.caja(Color(EstiloUI.PETROLEO, 0.92), EstiloUI.NARANJA, 2, 5))
	add_child(caja_lecciones)
	_lecciones = EstiloUI.titulo("", 8, EstiloUI.CREMA)
	caja_lecciones.add_child(_lecciones)
	Estado.leccion_aprendida.connect(func(_id: String) -> void: _actualizar_lecciones())
	_actualizar_lecciones()


func configurar(titulo: String, tareas: Array) -> void:
	_titulo.text = titulo.to_upper()
	_tareas.clear()
	for hijo in _lista.get_children():
		hijo.queue_free()
	_filas.clear()
	for t in tareas:
		_tareas.append({"id": str(t["id"]), "texto": str(t["texto"]), "hecho": false})
		var fila := HBoxContainer.new()
		fila.add_theme_constant_override("separation", 5)
		fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var casilla := Casilla.new()
		casilla.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		fila.add_child(casilla)
		var e := EstiloUI.etiqueta(str(t["texto"]), 11, EstiloUI.TINTA)
		fila.add_child(e)
		_lista.add_child(fila)
		_filas[str(t["id"])] = {"casilla": casilla, "texto": e}


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
		var fila: Dictionary = _filas[t["id"]]
		(fila["casilla"] as Casilla).poner(bool(t["hecho"]))
		(fila["texto"] as Label).add_theme_color_override("font_color", EstiloUI.TINTA_SUAVE if t["hecho"] else EstiloUI.TINTA)


func _actualizar_lecciones() -> void:
	if _lecciones != null:
		_lecciones.text = "LECCIONES: %d" % Estado.cantidad_lecciones()
