class_name Tablilla
extends Control
## Una tablilla (portapapeles) con una hoja de papel crema: el tablero azul petróleo, la pinza metálica arriba y la hoja con
## texto oscuro. Las evaluaciones de ingreso y de salida se contestan sobre ella. Los hijos van en `contenido`.
##
##   var t := Tablilla.new(); t.size = Vector2(480, 310); padre.add_child(t); t.contenido.add_child(...)

var contenido: VBoxContainer
var hoja: PanelContainer


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	contenido = VBoxContainer.new()
	contenido.add_theme_constant_override("separation", 6)


func _ready() -> void:
	var tablero := PanelContainer.new()
	tablero.set_anchors_preset(Control.PRESET_FULL_RECT)
	tablero.add_theme_stylebox_override("panel", EstiloUI.caja(EstiloUI.PETROLEO, EstiloUI.TINTA, 2, 0))
	tablero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tablero)
	var margen := MarginContainer.new()
	margen.add_theme_constant_override("margin_left", 10)
	margen.add_theme_constant_override("margin_right", 10)
	margen.add_theme_constant_override("margin_top", 22)
	margen.add_theme_constant_override("margin_bottom", 10)
	tablero.add_child(margen)
	hoja = PanelContainer.new()
	hoja.add_theme_stylebox_override("panel", EstiloUI.caja(EstiloUI.PAPEL, EstiloUI.TINTA_SUAVE, 2, 12))
	margen.add_child(hoja)
	hoja.add_child(contenido)
	# La pinza metálica
	var pinza := PanelContainer.new()
	pinza.add_theme_stylebox_override("panel", EstiloUI.caja(EstiloUI.GRIS, EstiloUI.TINTA, 2, 0))
	pinza.custom_minimum_size = Vector2(70, 16)
	pinza.size = pinza.custom_minimum_size
	pinza.position = Vector2((size.x - 70.0) / 2.0, 6)
	pinza.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pinza)
	var agujero := ColorRect.new()
	agujero.color = EstiloUI.TINTA
	agujero.custom_minimum_size = Vector2(26, 4)
	agujero.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	agujero.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pinza.add_child(agujero)
