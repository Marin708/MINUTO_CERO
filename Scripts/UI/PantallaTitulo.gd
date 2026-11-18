extends Node2D
## Pantalla de título de MINUTO CERO (escena principal del proyecto).
##
## Secuencia: negro -> aparece la ilustración -> el título "MINUTO CERO" letra por letra -> subtítulo -> menú
## (Comenzar, Continuar, Salir). Se puede saltar la entrada con INTERACTUAR o Enter.
## "Comenzar": nueva partida y fundido a negro hacia el consentimiento. "Continuar": carga la partida guardada
## y va al nivel donde se quedó. El recorrido de pantallas lo hace el autoload Flujo.

const ESCENA_CONSENTIMIENTO := "res://Scenes/UI/Consentimiento.tscn"
const RUTA_FUENTE := "res://Assets/PixelifySans-VariableFont_wght.ttf"
const RUTA_FONDO := "res://Assets/UI/fondo_titulo.png"

const PANTALLA := Vector2(640, 360)
const NARANJA := Color("ff8a2a")
const CREMA := Color("fff4dc")
const PETROLEO_OSCURO := Color("0f2d38")
const LETRAS_TITULO := "MINUTO CERO"
const SUBTITULO := "Prepararte hoy puede cambiar el minuto cero."
const SEGUNDOS_APARICION := 1.5
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


func _ready() -> void:
	musica.bus = Opciones.BUS_MUSICA          # los volúmenes de Opciones valen también aquí
	sonido_seleccion.bus = Opciones.BUS_EFECTOS
	Audio.musica("musica_titulo", 1.0)
	Audio.detener_ambiente(0.5)
	if ResourceLoader.exists(RUTA_FUENTE):
		_fuente = load(RUTA_FUENTE)
	_crear_fondo()
	_crear_titulo()
	_aplicar_estilo_menu()
	_preparar_menu()
	_iniciar_respiracion()

	# Todo empieza en negro absoluto
	negro.color.a = 1.0
	subtitulo.modulate.a = 0.0
	menu.modulate.a = 0.0
	menu.visible = false
	_iniciar_intro()


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
		caja.custom_minimum_size = Vector2(20 if letra == " " else 42, 60)
		caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
		contenedor_letras.add_child(caja)
		if letra == " ":
			continue
		var etiqueta := Label.new()
		etiqueta.text = letra
		etiqueta.add_theme_font_size_override("font_size", 46)
		etiqueta.add_theme_color_override("font_color", NARANJA)
		etiqueta.add_theme_color_override("font_outline_color", PETROLEO_OSCURO)
		etiqueta.add_theme_constant_override("outline_size", 8)
		if _fuente != null:
			etiqueta.add_theme_font_override("font", _fuente)
		etiqueta.modulate.a = 0.0
		etiqueta.position = Vector2(0, 12)
		caja.add_child(etiqueta)
		_letras.append(etiqueta)

	subtitulo.text = SUBTITULO
	if _fuente != null:
		subtitulo.add_theme_font_override("font", _fuente)
	subtitulo.add_theme_font_size_override("font_size", 14)
	subtitulo.add_theme_color_override("font_color", CREMA)
	subtitulo.add_theme_color_override("font_outline_color", PETROLEO_OSCURO)
	subtitulo.add_theme_constant_override("outline_size", 5)


# --- Entrada animada ---

func _iniciar_intro() -> void:
	_tween_intro = create_tween()
	# Un instante de negro absoluto -> aparece la ilustración
	_tween_intro.tween_interval(0.4)
	_tween_intro.tween_property(negro, "color:a", 0.0, SEGUNDOS_APARICION)
	_tween_intro.tween_interval(0.3)
	# Letra por letra, con fundido y una pequeña subida
	for i in _letras.size():
		_tween_intro.tween_callback(_animar_letra.bind(i))
		_tween_intro.tween_interval(SEGUNDOS_POR_LETRA_TITULO)
	_tween_intro.tween_interval(0.5)
	_tween_intro.tween_property(subtitulo, "modulate:a", 1.0, 1.0)
	_tween_intro.tween_interval(0.3)
	_tween_intro.tween_callback(_mostrar_menu)


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


func _aplicar_estilo_menu() -> void:
	var tema := Theme.new()
	if _fuente != null:
		tema.set_font("font", "Button", _fuente)
	tema.set_font_size("font_size", "Button", 16)
	tema.set_color("font_color", "Button", Color("d6e2e7"))
	tema.set_color("font_hover_color", "Button", NARANJA)
	tema.set_color("font_focus_color", "Button", NARANJA)
	tema.set_stylebox("normal", "Button", _crear_caja(Color("14414f"), Color("14414f"), 1, 4))
	tema.set_stylebox("hover", "Button", _crear_caja(Color("1d5566"), NARANJA, 2, 4))
	tema.set_stylebox("pressed", "Button", _crear_caja(Color("2a6c80"), NARANJA, 2, 4))
	tema.set_stylebox("focus", "Button", _crear_caja(Color("1d5566"), NARANJA, 2, 4))
	menu.theme = tema
	# Caja del menú: azul petróleo semitransparente con borde naranja (se lee sobre la ilustración)
	menu.add_theme_stylebox_override("panel", _crear_caja(Color(PETROLEO_OSCURO, 0.82), NARANJA, 2, 8))


func _crear_caja(fondo: Color, borde: Color, grosor: int, margen: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fondo
	s.border_color = borde
	s.set_border_width_all(grosor)
	s.set_corner_radius_all(4)
	s.set_content_margin_all(margen)
	return s


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
