extends Node
## Avisos como la alerta de un celular: un banner delgado arriba al centro con el ícono «MC» y dos líneas
## (por ejemplo, "Tarjeta de memoria desbloqueada"). Bajan deslizando, se quedan unos segundos y suben. Si llegan varios, van en cola.
##
##   Notificacion.mostrar("Título", "Texto de la tarjeta")

const ESCENA := preload("res://Scenes/UI/Notificacion.tscn")

const ANCHO := 300.0
const MARGEN := 8.0
const SEGUNDOS_VISIBLE := 3.0
const SEGUNDOS_ENTRADA := 0.4
const SEGUNDOS_SALIDA := 0.5

## true mientras haya una tarjeta en pantalla.
var mostrando := false

var _cola: Array[Dictionary] = []
var _capa: CanvasLayer
var _tarjeta: PanelContainer
var _titulo: Label
var _texto: Label


func _ready() -> void:
	_capa = ESCENA.instantiate()
	add_child(_capa)
	_tarjeta = _capa.get_node("%Tarjeta")
	_titulo = _capa.get_node("%Titulo")
	_texto = _capa.get_node("%Texto")
	_aplicar_estilo()


## Cuántas tarjetas esperan su turno.
func pendientes() -> int:
	return _cola.size()


## Muestra una tarjeta (o la pone en la cola si ya hay una en pantalla).
func mostrar(titulo: String, texto: String) -> void:
	_cola.append({"titulo": titulo, "texto": texto})
	if not mostrando:
		_procesar_cola()


func _procesar_cola() -> void:
	mostrando = true
	while not _cola.is_empty():
		await _mostrar_una(_cola.pop_front())
	mostrando = false


func _mostrar_una(aviso: Dictionary) -> void:
	_titulo.text = aviso["titulo"]
	_texto.text = aviso["texto"]
	_texto.visible = aviso["texto"] != ""
	_tarjeta.modulate.a = 1.0
	_tarjeta.visible = true
	# Un contenedor no encoge solo: se pide el tamaño mínimo para que el alto se ajuste al texto
	await get_tree().process_frame
	_tarjeta.reset_size()
	await get_tree().process_frame

	var ancho_pantalla := _tarjeta.get_viewport_rect().size.x
	_tarjeta.position = Vector2((ancho_pantalla - _tarjeta.size.x) / 2.0, -_tarjeta.size.y - 6.0)

	# Baja deslizando desde arriba
	var entrada := create_tween()
	entrada.tween_property(_tarjeta, "position:y", MARGEN, SEGUNDOS_ENTRADA) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await entrada.finished

	await get_tree().create_timer(SEGUNDOS_VISIBLE).timeout

	# Sube y se va
	var salida := create_tween()
	salida.tween_property(_tarjeta, "position:y", -_tarjeta.size.y - 6.0, SEGUNDOS_SALIDA)
	await salida.finished
	_tarjeta.visible = false


## Banner de alerta: fondo azul noche, borde naranja de 2 px, ícono cuadrado «MC» a la izquierda y dos líneas de texto.
func _aplicar_estilo() -> void:
	_tarjeta.custom_minimum_size = Vector2(ANCHO, 0)
	_tarjeta.add_theme_stylebox_override("panel", EstiloUI.caja(EstiloUI.PETROLEO_OSCURO, EstiloUI.NARANJA, 2, 5))
	var contenido: Control = _tarjeta.get_node("Contenido")
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 8)
	fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tarjeta.add_child(fila)
	contenido.reparent(fila, false)
	contenido.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	contenido.add_theme_constant_override("separation", 0)
	var icono := PanelContainer.new()
	icono.custom_minimum_size = Vector2(26, 26)
	icono.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icono.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icono.add_theme_stylebox_override("panel", EstiloUI.caja(EstiloUI.NARANJA, EstiloUI.TINTA, 2, 2))
	var mc := EstiloUI.titulo("MC", 9, EstiloUI.TINTA)
	mc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mc.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icono.add_child(mc)
	fila.add_child(icono)
	fila.move_child(icono, 0)
	for e in [_titulo, _texto]:
		e.custom_minimum_size = Vector2(ANCHO - 56.0, 0)
	_titulo.add_theme_font_override("font", EstiloUI.fuente_titulo())
	_titulo.add_theme_font_size_override("font_size", 8)
	_titulo.add_theme_color_override("font_color", EstiloUI.NARANJA)
	_texto.add_theme_font_override("font", EstiloUI.fuente_texto())
	_texto.add_theme_font_size_override("font_size", 12)
	_texto.add_theme_color_override("font_color", EstiloUI.CREMA)
