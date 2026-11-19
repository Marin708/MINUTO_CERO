class_name ModalBase
extends Control
## El modal reutilizable de MINUTO CERO: una cabecera fija, un cuerpo que se desplaza (solo en vertical) y un pie fijo con los
## botones, SIEMPRE visible. El modal mide lo que mide su contenido y, si no cabe, el cuerpo pasa a scroll:
##   alto máximo = alto del viewport - 16 px arriba y abajo; ancho máximo = ancho del viewport - 24 px.
## Se recalcula al cambiar el tamaño de la ventana o de la pantalla completa (señal size_changed del viewport).
##
## Scroll: rueda del ratón, flechas arriba y abajo (una línea) cuando no hay una opción enfocada en el cuerpo, AvPág y RePág,
## y arrastre. Barra delgada naranja sobre petróleo. follow_focus: lo que se enfoca en el cuerpo se desplaza a la vista.
## Si queda contenido abajo aparece «Sigue leyendo» sobre el pie. E, Enter y Espacio activan el botón principal aunque el
## scroll esté arriba (si no hay una opción del cuerpo enfocada). ESC y Tab los siguen manejando quienes lo usan.
##
##   var m := ModalBase.crear()
##   m.ancho_deseado = 440
##   m.cabecera.add_child(...); m.cuerpo.add_child(...); m.pie.add_child(boton)
##   m.boton_principal = boton
##   capa.add_child(m)                # (se ajusta solo; `await m.reajustado` si hace falta medirlo)

signal reajustado

const ESCENA := "res://Scenes/UI/ModalBase.tscn"
const MARGEN_VERTICAL := 16.0
const MARGEN_HORIZONTAL := 12.0   # 24 px entre los dos lados
const LINEA := 18.0
## Alto mínimo útil del cuerpo: si es menor, se baja un paso el tamaño de la letra.
const CUERPO_MINIMO := 60.0
const TAMANO_MINIMO_CUERPO := 8
const TAMANO_MINIMO_ETIQUETA := 7

@export var ancho_deseado := 440.0

var panel: PanelContainer
var cabecera: VBoxContainer
var cuerpo: VBoxContainer
var pie: HBoxContainer
var scroll: ScrollContainer
var boton_principal: Button
## Si es false, E, Enter y Espacio no activan el botón principal (quien lo usa maneja las teclas, por ejemplo el kit).
var confirmar_activo := true
## true cuando el cuerpo se desplaza (no cabía) en el último ajuste.
var con_scroll := false

var _separador_cabecera: ColorRect
var _separador_pie: ColorRect
var _indicador: IndicadorScroll
var _ajustando := false
var _pendiente := false
var _pasos_fuente := 0
var _arrastrando := false


## Crea el modal (la escena ModalBase.tscn) con las referencias ya enlazadas, listo para llenar antes de añadirlo.
static func crear() -> ModalBase:
	var m := (load(ESCENA) as PackedScene).instantiate() as ModalBase
	m._enlazar()
	return m


func _enlazar() -> void:
	panel = get_node("%Panel")
	cabecera = get_node("%Cabecera")
	cuerpo = get_node("%Cuerpo")
	pie = get_node("%Pie")
	scroll = get_node("%Scroll")
	_separador_cabecera = get_node("%SeparadorCabecera")
	_separador_pie = get_node("%SeparadorPie")
	_indicador = get_node("%Indicador")


func _ready() -> void:
	if panel == null:
		_enlazar()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.follow_focus = true
	if not scroll.has_theme_stylebox_override("panel"):
		scroll.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_estilar_barra()
	scroll.gui_input.connect(_on_scroll_gui_input)
	get_viewport().size_changed.connect(reajustar)
	cabecera.minimum_size_changed.connect(reajustar)
	cuerpo.minimum_size_changed.connect(reajustar)
	pie.minimum_size_changed.connect(reajustar)
	if not panel.has_theme_stylebox_override("panel"):
		panel.add_theme_stylebox_override("panel", EstiloUI.caja(EstiloUI.PETROLEO, EstiloUI.NARANJA, 2, 12))
	_separador_cabecera.visible = cabecera.get_child_count() > 0
	_separador_pie.visible = pie.get_child_count() > 0
	panel.modulate.a = 0.0   # invisible hasta que se mide (así no se ve el salto de tamaño)
	reajustar()


## Fondo, borde y margen interior del panel.
func configurar(fondo: Color, borde: Color, margen: int = 12, grosor: int = 2) -> void:
	panel.add_theme_stylebox_override("panel", EstiloUI.caja(fondo, borde, grosor, margen))


## Color de las dos líneas que separan cabecera y pie del cuerpo.
func color_separadores(color: Color) -> void:
	_separador_cabecera.color = color
	_separador_pie.color = color


## Fondo del cuerpo (por ejemplo, la hoja de papel de la tablilla).
func fondo_cuerpo(estilo: StyleBox) -> void:
	scroll.add_theme_stylebox_override("panel", estilo)


func _estilar_barra() -> void:
	var barra := scroll.get_v_scroll_bar()
	var pista := EstiloUI.caja(EstiloUI.AZUL_NOCHE, EstiloUI.PETROLEO_CLARO, 1, 0)
	pista.content_margin_left = 3
	pista.content_margin_right = 3
	barra.add_theme_stylebox_override("scroll", pista)
	for e in ["grabber", "grabber_highlight", "grabber_pressed"]:
		var g := EstiloUI.caja(EstiloUI.NARANJA if e != "grabber" else EstiloUI.NARANJA.darkened(0.15), EstiloUI.NARANJA, 0, 0)
		g.content_margin_left = 3
		g.content_margin_right = 3
		barra.add_theme_stylebox_override(e, g)


## Calcula el tamaño del modal: lo que mide su contenido, sin pasar del viewport (y con scroll si no cabe).
func reajustar() -> void:
	if _ajustando:
		_pendiente = true
		return
	_ajustando = true
	_pendiente = false
	if not is_inside_tree():
		_ajustando = false
		return
	var vp := get_viewport().get_visible_rect().size
	var max_ancho := vp.x - MARGEN_HORIZONTAL * 2.0
	var max_alto := vp.y - MARGEN_VERTICAL * 2.0
	var ancho := minf(ancho_deseado, max_ancho)
	# Primero con todo el alto posible (así el texto se acomoda al ancho), luego se mide
	panel.size = Vector2(ancho, max_alto)
	_centrar(vp)
	await get_tree().process_frame
	await get_tree().process_frame
	var fijo := cabecera.get_combined_minimum_size().y + pie.get_combined_minimum_size().y
	fijo += _separador_cabecera.get_combined_minimum_size().y if _separador_cabecera.visible else 0.0
	fijo += _separador_pie.get_combined_minimum_size().y if _separador_pie.visible else 0.0
	var estilo := panel.get_theme_stylebox("panel")
	fijo += estilo.get_margin(SIDE_TOP) + estilo.get_margin(SIDE_BOTTOM)
	var estilo_cuerpo := scroll.get_theme_stylebox("panel")
	var cuerpo_alto := cuerpo.get_combined_minimum_size().y + estilo_cuerpo.get_margin(SIDE_TOP) + estilo_cuerpo.get_margin(SIDE_BOTTOM)
	var natural := fijo + cuerpo_alto
	panel.size = Vector2(ancho, minf(natural, max_alto))
	_centrar(vp)
	await get_tree().process_frame
	con_scroll = natural > max_alto + 0.5
	# Si el cuerpo queda demasiado bajo, un paso menos de letra (solo una vez)
	if con_scroll and scroll.size.y < CUERPO_MINIMO and _pasos_fuente < 1:
		_pasos_fuente += 1
		_bajar_un_paso()
		_ajustando = false
		reajustar()
		return
	panel.modulate.a = 1.0
	_actualizar_indicador()
	_ajustando = false
	reajustado.emit()
	if _pendiente:
		reajustar()


func _centrar(vp: Vector2) -> void:
	panel.position = ((vp - panel.size) / 2.0).round()


## Baja un paso el tamaño de letra de todo el modal (nunca menos de 8 en el cuerpo ni 7 en etiquetas).
func _bajar_un_paso() -> void:
	for zona in [cabecera, cuerpo, pie]:
		_bajar_en(zona)


func _bajar_en(nodo: Node) -> void:
	if nodo is Label or nodo is Button:
		var c := nodo as Control
		var tam := c.get_theme_font_size("font_size")
		var minimo := TAMANO_MINIMO_ETIQUETA if tam <= 9 else TAMANO_MINIMO_CUERPO
		if tam - 1 >= minimo:
			c.add_theme_font_size_override("font_size", tam - 1)
	for h in nodo.get_children():
		_bajar_en(h)


func _process(_delta: float) -> void:
	_actualizar_indicador()


## «Sigue leyendo» solo si queda contenido por debajo del que se ve.
func _actualizar_indicador() -> void:
	if scroll == null:
		return
	var barra := scroll.get_v_scroll_bar()
	var resta := barra.max_value - (scroll.scroll_vertical + barra.page)
	_indicador.visible = con_scroll and resta > 2.0


# --- Teclado y ratón ---

func _foco_en_cuerpo() -> Control:
	var f := get_viewport().gui_get_focus_owner()
	return f if f != null and cuerpo.is_ancestor_of(f) else null


func _input(evento: InputEvent) -> void:
	if not is_visible_in_tree() or panel.modulate.a < 0.5:
		return
	if evento is InputEventKey and evento.pressed:
		match evento.keycode:
			KEY_PAGEUP:
				scroll.scroll_vertical -= int(scroll.size.y * 0.9)
				get_viewport().set_input_as_handled()
				return
			KEY_PAGEDOWN:
				scroll.scroll_vertical += int(scroll.size.y * 0.9)
				get_viewport().set_input_as_handled()
				return
	# Flechas: si hay una opción enfocada en el cuerpo, las flechas cambian de opción (y follow_focus la muestra);
	# si no, desplazan una línea.
	if con_scroll and (evento.is_action_pressed("ui_down") or evento.is_action_pressed("ABAJO") or evento.is_action_pressed("ui_up") or evento.is_action_pressed("ARRIBA")):
		var abajo := evento.is_action_pressed("ui_down") or evento.is_action_pressed("ABAJO")
		var foco_actual := get_viewport().gui_get_focus_owner()
		var vecino: Control = foco_actual.find_valid_focus_neighbor(SIDE_BOTTOM if abajo else SIDE_TOP) if foco_actual != null else null
		# Si hay otra opción o botón hacia ese lado, la flecha cambia el foco; si no, desplaza una línea
		if vecino == null or vecino == foco_actual:
			scroll.scroll_vertical += int(LINEA) * (1 if abajo else -1)
			get_viewport().set_input_as_handled()
			return
	# Confirmar: el botón principal desde cualquier posición del scroll
	if confirmar_activo and boton_principal != null and is_instance_valid(boton_principal) and not boton_principal.disabled \
			and (evento.is_action_pressed("INTERACTUAR") or evento.is_action_pressed("ui_accept")) and not evento.is_echo():
		var foco := get_viewport().gui_get_focus_owner()
		if foco is Button and (pie.is_ancestor_of(foco) or cuerpo.is_ancestor_of(foco)):
			# Una opción o un botón enfocado: con Enter o Espacio lo maneja el propio botón; con E lo activamos aquí
			if evento.is_action_pressed("INTERACTUAR") and not evento.is_action_pressed("ui_accept"):
				get_viewport().set_input_as_handled()
				_activar(foco as Button)
			return
		get_viewport().set_input_as_handled()
		boton_principal.pressed.emit()


## Activa un botón como si se hubiera pulsado (los de alternar cambian de estado).
static func _activar(b: Button) -> void:
	if b.disabled:
		return
	if b.toggle_mode:
		b.button_pressed = not b.button_pressed
	else:
		b.pressed.emit()


## Arrastrar con el ratón sobre el cuerpo desplaza el contenido.
func _on_scroll_gui_input(evento: InputEvent) -> void:
	if evento is InputEventMouseButton and evento.button_index == MOUSE_BUTTON_LEFT:
		_arrastrando = evento.pressed
	elif evento is InputEventMouseMotion and _arrastrando:
		scroll.scroll_vertical -= int(evento.relative.y)
