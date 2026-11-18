extends Node
## Guardado de la partida. Autoguarda cuando se registra una decisión, se desbloquea una tarjeta de memoria
## o cambia el nivel, y muestra un pequeño ícono de "guardado" 1.5 s abajo a la derecha. "Guardar partida"
## del menú de pausa lo hace a demanda (guardar_ahora()).
##
## Solo autoguarda dentro de un nivel (grupo "nivel"): el título y los cuestionarios no tocan la partida.

const SEGUNDOS_ICONO := 1.5
const RUTA_FUENTE := "res://Assets/PixelifySans-VariableFont_wght.ttf"

var _capa: CanvasLayer
var _icono: Control
var _tween: Tween
var _pendiente := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_crear_icono()
	Estado.decision_registrada.connect(func(_id: String, _segura: bool, _primero: bool) -> void: _pedir_autoguardado())
	Estado.tarjeta_desbloqueada.connect(func(_id: String) -> void: _pedir_autoguardado())
	Estado.nivel_cambiado.connect(func(_nivel: int) -> void: _pedir_autoguardado())


## true si ahora se puede guardar: dentro de un nivel y con jugador. En el título y en los cuestionarios no se
## guarda, para no pisar la partida real.
func puede_guardar() -> bool:
	return get_tree().get_first_node_in_group("nivel") != null and get_tree().get_first_node_in_group("player") != null


func _pedir_autoguardado() -> void:
	if not puede_guardar() or _pendiente:
		return
	_pendiente = true   # varios cambios en el mismo fotograma se guardan una sola vez
	_autoguardar.call_deferred()


func _autoguardar() -> void:
	_pendiente = false
	if puede_guardar():
		guardar_ahora()


## Guarda ya (autoguardado o botón "Guardar partida"). Devuelve true si se pudo guardar.
func guardar_ahora() -> bool:
	var bien := Estado.guardar()
	if bien:
		_mostrar_icono()
	else:
		Notificacion.mostrar("No se pudo guardar", "Revisa que haya espacio en el disco e inténtalo otra vez.")
	return bien


# --- Ícono de "guardado" ---

func _crear_icono() -> void:
	_capa = CanvasLayer.new()
	_capa.layer = 11   # sobre la pausa (9) y los diálogos (10)
	_capa.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_capa)
	_icono = Control.new()
	_icono.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icono.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_icono.offset_left = -78.0
	_icono.offset_top = -26.0
	_icono.offset_right = -8.0
	_icono.offset_bottom = -8.0
	_icono.modulate.a = 0.0
	_icono.draw.connect(_dibujar_icono)
	_capa.add_child(_icono)


## Un disquete naranja y la palabra "Guardado".
func _dibujar_icono() -> void:
	var dorado := Color("ff8a2a")
	var oscuro := Color("0f2d38")
	_icono.draw_rect(Rect2(0, 0, 70, 18), Color(oscuro, 0.9))
	_icono.draw_rect(Rect2(0, 0, 70, 18), dorado, false, 1.0)
	# disquete
	_icono.draw_rect(Rect2(4, 3, 12, 12), dorado)
	_icono.draw_rect(Rect2(6, 3, 8, 4), oscuro)
	_icono.draw_rect(Rect2(7, 9, 6, 6), oscuro)
	if ResourceLoader.exists(RUTA_FUENTE):
		_icono.draw_string(load(RUTA_FUENTE), Vector2(20, 13), "Guardado", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("fff4dc"))


func _mostrar_icono() -> void:
	Audio.efecto("guardar")
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	# 0.2 s entra, 1.0 s se queda, 0.3 s sale: 1.5 s en total
	_tween.tween_property(_icono, "modulate:a", 1.0, 0.2)
	_tween.tween_interval(1.0)
	_tween.tween_property(_icono, "modulate:a", 0.0, 0.3)
