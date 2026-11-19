extends Node2D
## Pantalla de título de MINUTO CERO (escena principal del proyecto).
##
## Secuencia: negro -> aparece la ilustración (con una línea de sismógrafo que la cruza y se agita) -> cuenta regresiva
## 00:59 a 00:00 -> temblor breve y aparece «MINUTO CERO» -> subtítulo -> menú de botones tipo señal de seguridad
## (Comenzar, Continuar, Salir). Se puede saltar la entrada con INTERACTUAR o Enter.
## "Comenzar": nueva partida y fundido a negro hacia el consentimiento. "Continuar": carga la partida guardada
## y va al nivel donde se quedó. El recorrido de pantallas lo hace el autoload Flujo.

const ESCENA_CONSENTIMIENTO := "res://Scenes/UI/Consentimiento.tscn"
const RUTA_FONDO := "res://Assets/UI/fondo_titulo.png"

const PANTALLA := Vector2(640, 360)
const NARANJA := EstiloUI.NARANJA
const CREMA := EstiloUI.CREMA
const PETROLEO_OSCURO := EstiloUI.AZUL_NOCHE
const LETRAS_TITULO := "MINUTO CERO"
const SUBTITULO := "Aprende a actuar ante un sismo"
## La frase central va pequeña al pie.
const FRASE_CENTRAL := "Prepararte hoy puede cambiar el minuto cero."
const SEGUNDOS_APARICION := 1.5
## Cuánto dura la cuenta regresiva de 00:59 a 00:00.
const SEGUNDOS_CUENTA := 2.6
const SEGUNDOS_POR_LETRA_TITULO := 0.12

@onready var mundo: Node2D = $Mundo
@onready var contenedor_letras: HBoxContainer = %Letras
@onready var subtitulo: Label = %Subtitulo
@onready var menu: PanelContainer = %Menu
@onready var boton_comenzar: Button = %Comenzar
@onready var boton_continuar: Button = %Continuar
@onready var boton_salir: Button = %Salir
@onready var negro: ColorRect = %Negro
## Reproductores propios de la escena (el sonido y la música salen por Audio; estos quedan solo en los buses).
@onready var musica: AudioStreamPlayer = $Musica
@onready var sonido_seleccion: AudioStreamPlayer = $SonidoSeleccion

var _letras: Array[Label] = []
var _en_intro := true
var _eligiendo := false
var _tween_intro: Tween
var _tweens_letras: Array[Tween] = []
var _fuente: Font
var _sismografo: Sismografo
var _cuenta: Label
var _flecha: Control
var _contando := false
var _t_cuenta := 0.0
var _ultimo_segundo := 60
var _sacudida := 0.0


func _ready() -> void:
	musica.bus = Opciones.BUS_MUSICA          # los volúmenes de Opciones valen también aquí
	sonido_seleccion.bus = Opciones.BUS_EFECTOS
	Audio.musica("musica_titulo", 1.0)
	_fuente = EstiloUI.fuente_titulo()
	# Sin brillos: el título usa colores planos (se quita el glow del entorno de la escena)
	var entorno := get_node_or_null("WorldEnvironment")
	if entorno != null:
		entorno.queue_free()
	_crear_fondo()
	_crear_sismografo()
	_crear_titulo()
	_crear_flecha()
	# Un murmullo suave de fondo, solo si existe el sonido
	if ResourceLoader.exists(Audio.RAIZ + "Ambiente/amb_casa.ogg"):
		Audio.ambiente("amb_casa", 2.0, -18.0)
	_aplicar_estilo_menu()
	_preparar_menu()
	_iniciar_respiracion()

	# Todo empieza en negro absoluto
	negro.color.a = 1.0
	subtitulo.modulate.a = 0.0
	menu.modulate.a = 0.0
	menu.visible = false
	_iniciar_intro()


func _process(delta: float) -> void:
	# Cuenta regresiva
	if _contando:
		_t_cuenta += delta
		var restante := int(ceil(maxf(59.0 * (1.0 - _t_cuenta / SEGUNDOS_CUENTA), 0.0)))
		_cuenta.text = "00:%02d" % restante
		if restante != _ultimo_segundo and restante % 6 == 0 and restante > 0:
			Audio.efecto("reloj_tic")
		_ultimo_segundo = restante
		if _t_cuenta >= SEGUNDOS_CUENTA:
			_llegar_a_cero()
	# Temblor breve de toda la imagen al llegar a cero
	if _sacudida > 0.0:
		_sacudida = maxf(_sacudida - delta, 0.0)
		var fuerza := _sacudida * 22.0
		var desvio := Vector2(randf_range(-fuerza, fuerza), randf_range(-fuerza, fuerza))
		if _sacudida <= 0.0:
			desvio = Vector2.ZERO
		mundo.position = PANTALLA / 2.0 + desvio
		$Interfaz.offset = desvio
	# La flecha de foco sigue al botón enfocado
	var foco := get_viewport().gui_get_focus_owner()
	_flecha.visible = foco is Button and menu.visible and not _eligiendo and (foco as Button).is_visible_in_tree()
	if _flecha.visible:
		var r := (foco as Button).get_global_rect()
		_flecha.position = Vector2(r.position.x - 18.0 + sin(Time.get_ticks_msec() / 1000.0 * 6.0) * 2.0, r.position.y + r.size.y / 2.0 - 7.0)


func _unhandled_input(evento: InputEvent) -> void:
	# Saltar la animación de entrada
	if _en_intro and (evento.is_action_pressed("INTERACTUAR") or evento.is_action_pressed("ui_accept")):
		get_viewport().set_input_as_handled()
		_saltar_intro()
		return
	if _en_intro or _eligiendo:
		return
	var foco := get_viewport().gui_get_focus_owner()
	if foco == null:
		return
	# W/S (acciones del juego) también mueven el foco del menú
	if evento.is_action_pressed("ABAJO"):
		get_viewport().set_input_as_handled()
		foco.find_next_valid_focus().grab_focus()
	elif evento.is_action_pressed("ARRIBA"):
		get_viewport().set_input_as_handled()
		foco.find_prev_valid_focus().grab_focus()
	elif evento.is_action_pressed("INTERACTUAR") and foco is Button:
		get_viewport().set_input_as_handled()
		foco.pressed.emit()


# --- Fondo: la ilustración ---

func _crear_fondo() -> void:
	# "mundo" está en el centro de la pantalla y el fondo compensa, así el zoom parte del centro
	mundo.position = PANTALLA / 2.0
	if not ResourceLoader.exists(RUTA_FONDO):
		return
	var ilustracion := Sprite2D.new()
	ilustracion.texture = load(RUTA_FONDO)  # importada con filtro Nearest (pixel art)
	ilustracion.position = Vector2.ZERO
	mundo.add_child(ilustracion)


## La ilustración "respira" muy despacio (escala 1.0 a 1.03).
func _iniciar_respiracion() -> void:
	var t := create_tween().set_loops()
	t.tween_property(mundo, "scale", Vector2(1.03, 1.03), 6.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(mundo, "scale", Vector2.ONE, 6.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# --- Título y subtítulo ---

func _crear_titulo() -> void:
	for letra in LETRAS_TITULO:
		var caja := Control.new()
		caja.custom_minimum_size = Vector2(18 if letra == " " else 36, 60)
		caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
		contenedor_letras.add_child(caja)
		if letra == " ":
			continue
		var etiqueta := EstiloUI.titulo(letra, 44, NARANJA)
		etiqueta.add_theme_color_override("font_outline_color", PETROLEO_OSCURO)
		etiqueta.add_theme_constant_override("outline_size", 10)
		etiqueta.modulate.a = 0.0
		etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		etiqueta.size = Vector2(36, 56)
		etiqueta.position = Vector2(0, 8)
		caja.add_child(etiqueta)
		_letras.append(etiqueta)

	subtitulo.text = SUBTITULO
	subtitulo.add_theme_font_override("font", EstiloUI.fuente_texto())
	subtitulo.add_theme_font_size_override("font_size", 16)
	subtitulo.add_theme_color_override("font_color", CREMA)
	subtitulo.add_theme_color_override("font_outline_color", PETROLEO_OSCURO)
	subtitulo.add_theme_constant_override("outline_size", 6)
	subtitulo.offset_top = 92.0
	subtitulo.offset_bottom = 116.0

	# La cuenta regresiva ocupa el lugar del título hasta llegar a cero
	_cuenta = EstiloUI.radio("00:59", 64, EstiloUI.ROJO)
	_cuenta.add_theme_color_override("font_outline_color", PETROLEO_OSCURO)
	_cuenta.add_theme_constant_override("outline_size", 10)
	_cuenta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cuenta.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_cuenta.offset_top = 18.0
	_cuenta.offset_bottom = 90.0
	_cuenta.visible = false
	$Interfaz.add_child(_cuenta)

	var frase := EstiloUI.etiqueta(FRASE_CENTRAL, 12, EstiloUI.GRIS)
	frase.add_theme_color_override("font_outline_color", PETROLEO_OSCURO)
	frase.add_theme_constant_override("outline_size", 5)
	frase.position = Vector2(14, 336)
	$Interfaz.add_child(frase)


## La línea de sismógrafo cruza toda la pantalla, por debajo del título.
func _crear_sismografo() -> void:
	_sismografo = Sismografo.new()
	_sismografo.position = Vector2(0, 150)
	_sismografo.size = Vector2(PANTALLA.x, 50)
	$Interfaz.add_child(_sismografo)


## Triángulo naranja que señala el botón enfocado.
func _crear_flecha() -> void:
	_flecha = Control.new()
	_flecha.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flecha.size = Vector2(12, 14)
	_flecha.draw.connect(func() -> void:
		var tri := PackedVector2Array([Vector2(0, 0), Vector2(12, 7), Vector2(0, 14)])
		_flecha.draw_colored_polygon(tri, EstiloUI.NARANJA)
		tri.append(tri[0])
		_flecha.draw_polyline(tri, EstiloUI.AZUL_NOCHE, 2.0))
	_flecha.visible = false
	$Interfaz.add_child(_flecha)


# --- Entrada animada ---

func _iniciar_intro() -> void:
	_tween_intro = create_tween()
	# Un instante de negro absoluto -> aparece la ilustración
	_tween_intro.tween_interval(0.4)
	_tween_intro.tween_property(negro, "color:a", 0.0, SEGUNDOS_APARICION)
	_tween_intro.tween_interval(0.3)
	# Empieza la cuenta regresiva; al llegar a cero (_llegar_a_cero) tiembla y aparece el título
	_tween_intro.tween_callback(_empezar_cuenta)


func _empezar_cuenta() -> void:
	_cuenta.visible = true
	_contando = true
	_t_cuenta = 0.0


## 00:00: un temblor breve, la línea del sismógrafo se dispara y el título aparece de golpe.
func _llegar_a_cero() -> void:
	_contando = false
	_cuenta.text = "00:00"
	_cuenta.visible = false
	_sacudida = 0.45
	_sismografo.sacudir()
	Audio.efecto("sello")
	for i in _letras.size():
		_animar_letra(i)
	var t := create_tween()
	t.tween_interval(0.6)
	t.tween_property(subtitulo, "modulate:a", 1.0, 0.8)
	t.tween_interval(0.3)
	t.tween_callback(_mostrar_menu)
	_tween_intro = t


func _animar_letra(indice: int) -> void:
	var letra := _letras[indice]
	var t := create_tween().set_parallel(true)
	t.tween_property(letra, "modulate:a", 1.0, 0.4)
	t.tween_property(letra, "position:y", 0.0, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tweens_letras.append(t)


func _mostrar_menu() -> void:
	_en_intro = false
	menu.visible = true
	var t := create_tween()
	t.tween_property(menu, "modulate:a", 1.0, 0.5)
	_enfocar_primera_opcion()


## Salta directo al título completo y al menú.
func _saltar_intro() -> void:
	if _tween_intro != null:
		_tween_intro.kill()
	for t in _tweens_letras:
		t.kill()
	_contando = false
	_cuenta.visible = false
	negro.color.a = 0.0
	for letra in _letras:
		letra.modulate.a = 1.0
		letra.position = Vector2.ZERO
	subtitulo.modulate.a = 1.0
	_en_intro = false
	menu.visible = true
	menu.modulate.a = 1.0
	_enfocar_primera_opcion()


# --- Menú ---

## true en un móvil o con una pantalla táctil pequeña (en la web): MINUTO CERO se juega con teclado.
static func es_movil() -> bool:
	if OS.has_feature("web_android") or OS.has_feature("web_ios"):
		return true
	return OS.has_feature("web") and DisplayServer.is_touchscreen_available() and DisplayServer.screen_get_size().x <= 1100


func _preparar_menu() -> void:
	# En la web no se puede cerrar la pestaña desde el juego
	if OS.has_feature("web"):
		boton_salir.visible = false
	if es_movil():
		var aviso := Label.new()
		aviso.text = "MINUTO CERO se juega con teclado, ábrelo en un computador"
		aviso.add_theme_font_size_override("font_size", 9)
		aviso.add_theme_color_override("font_color", NARANJA)
		aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		aviso.position = Vector2(0, 342)   # (el título es un Node2D: sin anclas)
		aviso.size = Vector2(640, 14)
		aviso.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(aviso)
	boton_continuar.visible = Estado.hay_partida_guardada()
	for boton in [boton_comenzar, boton_continuar, boton_salir]:
		boton.focus_entered.connect(_on_foco_cambiado.bind(boton))
		boton.mouse_entered.connect(boton.grab_focus)
	boton_comenzar.pressed.connect(_comenzar)
	boton_continuar.pressed.connect(_continuar)
	boton_salir.pressed.connect(_salir)


func _enfocar_primera_opcion() -> void:
	var primera: Button = boton_continuar if boton_continuar.visible else boton_comenzar
	primera.grab_focus()


## Pequeño rebote del botón que recibe el foco.
func _on_foco_cambiado(boton: Button) -> void:
	_sonido_seleccion()
	boton.pivot_offset = boton.size / 2.0
	boton.scale = Vector2(1.12, 1.12)
	var t := create_tween()
	t.tween_property(boton, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _sonido_seleccion() -> void:
	if not _en_intro:
		Audio.efecto("ui_mover")


## Botones tipo señal de seguridad: rectángulos naranja con franjas de precaución arriba y abajo, texto oscuro.
func _aplicar_estilo_menu() -> void:
	var tema := Theme.new()
	tema.set_font("font", "Button", EstiloUI.fuente_titulo())
	tema.set_font_size("font_size", "Button", 12)
	for c in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		tema.set_color(c, "Button", EstiloUI.TINTA)
	tema.set_stylebox("normal", "Button", _crear_caja(EstiloUI.NARANJA.darkened(0.12), EstiloUI.TINTA, 2, 8))
	for e in ["hover", "pressed", "focus"]:
		tema.set_stylebox(e, "Button", _crear_caja(EstiloUI.NARANJA, EstiloUI.CREMA, 2, 8))
	menu.theme = tema
	# Sin caja de fondo: los botones solos sobre la ilustración
	menu.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	for b in [boton_comenzar, boton_continuar, boton_salir]:
		b.custom_minimum_size = Vector2(150, 30)
		b.draw.connect(func() -> void:
			var ancho: float = b.size.x - 8.0
			Franjas.pintar(b, Rect2(4, 3, ancho, 3), EstiloUI.TINTA, EstiloUI.NARANJA, 6.0)
			Franjas.pintar(b, Rect2(4, b.size.y - 6, ancho, 3), EstiloUI.TINTA, EstiloUI.NARANJA, 6.0))


func _crear_caja(fondo: Color, borde: Color, grosor: int, margen: int) -> StyleBoxFlat:
	return EstiloUI.caja(fondo, borde, grosor, margen)


# --- Acciones del menú ---

func _comenzar() -> void:
	if _eligiendo:
		return
	_eligiendo = true
	Audio.efecto("ui_aceptar")
	Estado.nueva_partida()
	var t := create_tween()
	t.tween_property(menu, "modulate:a", 0.0, 0.3)
	t.tween_property(negro, "color:a", 1.0, 0.7)
	t.tween_callback(_ir_a_consentimiento)


func _ir_a_consentimiento() -> void:
	var flujo := get_node_or_null("/root/Flujo")
	if flujo != null and flujo.has_method("comenzar"):
		flujo.comenzar()
	else:
		get_tree().change_scene_to_file(ESCENA_CONSENTIMIENTO)


func _continuar() -> void:
	if _eligiendo:
		return
	if not Estado.cargar():
		# La partida falta o está dañada: no se rompe nada, se avisa y se ofrece una partida nueva
		var dañada := Estado.diagnosticar_partida() == "danada"
		boton_continuar.visible = false
		boton_comenzar.grab_focus()
		Notificacion.mostrar(
			"No se pudo leer la partida" if dañada else "No hay partida guardada",
			"Tu partida guardada está dañada. Puedes empezar una nueva con Comenzar." if dañada \
				else "Empieza una nueva con Comenzar.")
		return
	_eligiendo = true
	Audio.efecto("ui_aceptar")
	var t := create_tween()
	t.tween_property(menu, "modulate:a", 0.0, 0.3)
	t.tween_property(negro, "color:a", 1.0, 0.7)
	t.tween_callback(_ir_a_partida_guardada)


func _ir_a_partida_guardada() -> void:
	var flujo := get_node_or_null("/root/Flujo")
	if flujo != null and flujo.has_method("continuar"):
		flujo.continuar()
	else:
		get_tree().change_scene_to_file(ESCENA_CONSENTIMIENTO)


func _salir() -> void:
	Audio.efecto("ui_cancelar")
	Audio.salir()
