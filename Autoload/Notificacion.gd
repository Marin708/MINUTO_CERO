extends Node
## Avisos como la alerta de un celular: un banner delgado arriba al centro con el ícono «MC» y dos líneas
## (por ejemplo, "Tarjeta de memoria desbloqueada"). Bajan deslizando y se quedan según el largo del texto.
## Si llegan varios, van en cola de uno en uno (con «1 de 3»); nada se pierde ni se superpone.
##
##   Notificacion.mostrar("Título", "Texto de la tarjeta")
##
## Duración: 4 s + 0.07 s por carácter (mínimo 6, máximo 14). Memoria de 1999 y Lección aprendida esperan al
## jugador hasta 20 s. La cuenta atrás se congela con el ratón encima y con un modal abierto (tarjeta de
## retroalimentación, kit, diálogo, cuestionario, pausa o libreta); los avisos nuevos esperan a que se cierren.
## Se cierran con la X, con la tecla C (acción CERRAR_AVISO) o al acabarse el tiempo, con un fundido corto.
## Todos quedan en el historial (Estado.avisos, pestaña «Avisos» de la libreta).

const ESCENA := preload("res://Scenes/UI/Notificacion.tscn")

const ANCHO := 320.0
const MARGEN := 8.0
const SEGUNDOS_ENTRADA := 0.25
## Desplazamiento vertical de la entrada (el aviso se mide y se coloca ANTES; solo se anima la opacidad y esto).
const DESPLAZAMIENTO_ENTRADA := 8.0
const SEGUNDOS_FUNDIDO := 0.2
## Pausa entre un aviso y el siguiente de la cola.
const SEGUNDOS_ENTRE := 0.4
## Duración por texto: 4 s más 0.07 s por carácter, entre 6 y 14 s.
const BASE_SEGUNDOS := 4.0
const SEGUNDOS_POR_CARACTER := 0.07
const MINIMO_SEGUNDOS := 6.0
const MAXIMO_SEGUNDOS := 14.0
## Los avisos importantes (Memoria de 1999, Lección aprendida) esperan al jugador hasta este tope.
const TOPE_IMPORTANTE := 20.0
const ANCHO_COLUMNA := 52.0

## true mientras haya una tarjeta en pantalla.
var mostrando := false
## true mientras el aviso actual ya está quieto en pantalla (se puede cerrar con C o con la X).
var visible_listo := false
## Segundos que le quedan al aviso en pantalla (se congela con ratón encima o con un modal abierto).
var restante := 0.0

var _cola: Array[Dictionary] = []
var _capa: CanvasLayer
var _tarjeta: PanelContainer
var _titulo: Label
var _texto: Label
var _contador: Label
var _boton_cerrar: Button
var _lote_total := 0
var _lote_pos := 0
var _cerrar_pedido := false


func _ready() -> void:
	# Sigue contando (y esperando a los modales) aunque el árbol esté en pausa
	process_mode = Node.PROCESS_MODE_ALWAYS
	_capa = ESCENA.instantiate()
	add_child(_capa)
	_tarjeta = _capa.get_node("%Tarjeta")
	_titulo = _capa.get_node("%Titulo")
	_texto = _capa.get_node("%Texto")
	_aplicar_estilo()


## Cuántas tarjetas esperan su turno.
func pendientes() -> int:
	return _cola.size()


## Los avisos de memoria y de lección aprendida son importantes: esperan a que el jugador los cierre.
static func es_importante(titulo: String) -> bool:
	return titulo.begins_with("Memoria de 1999") or titulo.begins_with("Lección aprendida")


## Cuántos segundos dura un aviso: 4 s + 0.07 s por carácter, mínimo 6 y máximo 14. Los importantes esperan hasta
## el tope de 20 s. «Larga» duplica el tiempo y «Hasta cerrar» no tiene tope (devuelve INF).
static func duracion_para(caracteres: int, importante: bool, modo: int) -> float:
	if modo == Opciones.DuracionAvisos.HASTA_CERRAR:
		return INF
	var factor := 2.0 if modo == Opciones.DuracionAvisos.LARGA else 1.0
	if importante:
		return TOPE_IMPORTANTE * factor
	return clampf(BASE_SEGUNDOS + SEGUNDOS_POR_CARACTER * caracteres, MINIMO_SEGUNDOS, MAXIMO_SEGUNDOS) * factor


## Muestra una tarjeta (o la pone en la cola si ya hay una en pantalla). Queda en el historial de la libreta.
func mostrar(titulo: String, texto: String, importante: bool = false) -> void:
	Estado.registrar_aviso(titulo, texto)
	_cola.append({"titulo": titulo, "texto": texto, "importante": importante or es_importante(titulo)})
	_lote_total += 1
	_actualizar_contador()
	if not mostrando:
		_procesar_cola()


## Cierra el aviso que está en pantalla (la tecla C y la X llaman a esto).
func cerrar() -> void:
	if visible_listo:
		_cerrar_pedido = true


## ¿Hay algo abierto que merezca que los avisos esperen? Tarjeta de retroalimentación o kit (pausan el árbol),
## diálogo, cuestionario, pausa o libreta.
func hay_modal() -> bool:
	if get_tree().paused or Dialogo.hay_dialogo() or Evaluacion.cuestionario_activo:
		return true
	return Menus.pausa != null and Menus.libreta != null and Menus.hay_menu()


func _procesar_cola() -> void:
	mostrando = true
	while not _cola.is_empty():
		await _mostrar_una(_cola.pop_front())
		if not _cola.is_empty():
			await get_tree().create_timer(SEGUNDOS_ENTRE, true).timeout
	mostrando = false
	_lote_total = 0
	_lote_pos = 0


func _process(delta: float) -> void:
	if visible_listo and restante > 0.0 and not hay_modal() and not _raton_encima():
		restante -= delta


func _input(evento: InputEvent) -> void:
	if visible_listo and evento.is_action_pressed("CERRAR_AVISO") and not evento.is_echo():
		get_viewport().set_input_as_handled()
		cerrar()


## «1 de 3»: solo aparece si hay más de un aviso en el lote.
func _actualizar_contador() -> void:
	if _contador == null:
		return
	_contador.text = "%d de %d" % [_lote_pos, _lote_total] if _lote_total > 1 else ""
	_contador.visible = _lote_total > 1


func _raton_encima() -> bool:
	return _tarjeta.visible and _tarjeta.get_global_rect().has_point(_tarjeta.get_global_mouse_position())


func _mostrar_una(aviso: Dictionary) -> void:
	# Los avisos nuevos esperan a que se cierren los modales
	while hay_modal():
		await get_tree().process_frame
	_lote_pos += 1
	_titulo.text = aviso["titulo"]
	_texto.text = aviso["texto"]
	_texto.visible = aviso["texto"] != ""
	_actualizar_contador()
	# SIN SALTOS: se mide con el aviso invisible (opacidad 0), con el texto completo y el ancho ya fijado
	_tarjeta.modulate.a = 0.0
	_tarjeta.visible = true
	await get_tree().process_frame
	_tarjeta.reset_size()
	await get_tree().process_frame
	_tarjeta.reset_size()
	await get_tree().process_frame
	# La posición se calcula una sola vez con el tamaño final; la entrada solo anima opacidad y un pequeño desplazamiento vertical
	var ancho_pantalla := _tarjeta.get_viewport_rect().size.x
	_tarjeta.position = Vector2(roundf((ancho_pantalla - _tarjeta.size.x) / 2.0), MARGEN - DESPLAZAMIENTO_ENTRADA)
	var entrada := create_tween().set_parallel(true)
	entrada.tween_property(_tarjeta, "modulate:a", 1.0, SEGUNDOS_ENTRADA)
	entrada.tween_property(_tarjeta, "position:y", MARGEN, SEGUNDOS_ENTRADA).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await entrada.finished

	# Cuenta atrás (la congela _process con ratón encima o con un modal abierto)
	_cerrar_pedido = false
	restante = duracion_para(str(aviso["titulo"]).length() + str(aviso["texto"]).length(), bool(aviso["importante"]), Opciones.duracion_avisos)
	visible_listo = true
	while restante > 0.0 and not _cerrar_pedido:
		await get_tree().process_frame
	visible_listo = false

	# Fundido corto al cerrar o al acabarse el tiempo
	var salida := create_tween()
	salida.tween_property(_tarjeta, "modulate:a", 0.0, SEGUNDOS_FUNDIDO)
	await salida.finished
	_tarjeta.visible = false


## Banner de alerta: fondo azul noche, borde naranja de 2 px, ícono cuadrado «MC» a la izquierda, dos líneas de texto
## y a la derecha la X para cerrar, «C cerrar» y el contador.
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
	_construir_columna_derecha(fila)
	for e in [_titulo, _texto]:
		e.custom_minimum_size = Vector2(ANCHO - 56.0 - ANCHO_COLUMNA, 0)
	_titulo.add_theme_font_override("font", EstiloUI.fuente_titulo())
	_titulo.add_theme_font_size_override("font_size", 8)
	_titulo.add_theme_color_override("font_color", EstiloUI.NARANJA)
	_texto.add_theme_font_override("font", EstiloUI.fuente_texto())
	_texto.add_theme_font_size_override("font_size", 12)
	_texto.add_theme_color_override("font_color", EstiloUI.CREMA)


## La X (clic), el texto «C cerrar» y el contador «1 de 3».
func _construir_columna_derecha(fila: HBoxContainer) -> void:
	var derecha := VBoxContainer.new()
	derecha.add_theme_constant_override("separation", 2)
	derecha.custom_minimum_size = Vector2(ANCHO_COLUMNA, 0)
	derecha.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila.add_child(derecha)
	_boton_cerrar = Button.new()
	_boton_cerrar.custom_minimum_size = Vector2(22, 18)
	_boton_cerrar.size_flags_horizontal = Control.SIZE_SHRINK_END
	_boton_cerrar.focus_mode = Control.FOCUS_NONE
	var apagado := EstiloUI.caja(EstiloUI.PETROLEO, EstiloUI.CREMA, 2, 0)
	var lleno := EstiloUI.caja(EstiloUI.ROJO, EstiloUI.CREMA, 2, 0)
	_boton_cerrar.add_theme_stylebox_override("normal", apagado)
	_boton_cerrar.add_theme_stylebox_override("hover", lleno)
	_boton_cerrar.add_theme_stylebox_override("pressed", lleno)
	_boton_cerrar.pressed.connect(func() -> void:
		Audio.efecto("ui_cancelar")
		cerrar())
	var equis := Control.new()
	equis.set_anchors_preset(Control.PRESET_FULL_RECT)
	equis.mouse_filter = Control.MOUSE_FILTER_IGNORE
	equis.draw.connect(func() -> void:   # las fuentes no traen «✕»: se dibuja con dos líneas
		var c := equis.size / 2.0
		equis.draw_line(c + Vector2(-4, -4), c + Vector2(4, 4), EstiloUI.CREMA, 2.0)
		equis.draw_line(c + Vector2(-4, 4), c + Vector2(4, -4), EstiloUI.CREMA, 2.0))
	_boton_cerrar.add_child(equis)
	derecha.add_child(_boton_cerrar)
	var ayuda := EstiloUI.titulo("C cerrar", 7, EstiloUI.CREMA)
	ayuda.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	derecha.add_child(ayuda)
	_contador = EstiloUI.titulo("", 7, EstiloUI.AMBAR)
	_contador.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	derecha.add_child(_contador)
