class_name Creditos
extends CanvasLayer
## Créditos: un texto que baja solo, despacio, dentro de un modal con el botón «Cerrar» siempre visible (capa 13). El contenido se edita en
## Resources/creditos.txt (secciones con "# ", líneas de texto, espacios en blanco y una nota final con "> ").
## Se cierra solo al terminar, o con ENTER, ESPACIO, ESC o un clic. Flecha abajo acelera el desplazamiento.
##
## Uso:   await Creditos.mostrar(get_tree())

const ESCENA := "res://Scenes/UI/Creditos.tscn"
const RUTA_TEXTO := "res://Resources/creditos.txt"
const VELOCIDAD := 26.0   # píxeles por segundo
const ANCHO := 420.0

signal cerrados

var _raiz: Control
var _columna: VBoxContainer
var _modal: ModalBase
var _fraccion := 0.0
var _espera := 1.5       # segundos de calma antes de empezar a bajar
var _al_final := 0.0     # segundos que lleva el texto en el final
var _cerrando := false


static func mostrar(arbol: SceneTree) -> void:
	var escena := (load(ESCENA) as PackedScene).instantiate() as Creditos
	arbol.root.add_child.call_deferred(escena)
	await escena.tree_exited


func _ready() -> void:
	layer = 13
	process_mode = Node.PROCESS_MODE_ALWAYS
	FondoEvaluacion.crear(self)
	_raiz = Control.new()
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_STOP
	_raiz.theme = EstiloUI.tema()
	_raiz.modulate.a = 0.0
	add_child(_raiz)
	# Sobre ModalBase: título fijo, los créditos en el cuerpo (que baja solo, despacio) y el botón siempre visible
	_modal = ModalBase.crear()
	_modal.ancho_deseado = ANCHO + 56.0
	_modal.configurar(Color(EstiloUI.AZUL_NOCHE, 0.96), EstiloUI.NARANJA, 12)
	_modal.cabecera.add_child(EstiloUI.titulo("CRÉDITOS", 14, EstiloUI.CREMA))
	_columna = _modal.cuerpo
	_columna.add_theme_constant_override("separation", 6)
	_leer_texto()
	var cerrar := EstiloUI.boton_senal("Cerrar", 130, 28, 10)
	cerrar.pressed.connect(_cerrar)
	var espacio := Control.new()
	espacio.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_modal.pie.add_child(EstiloUI.etiqueta("Enter o Esc para salir", 11, EstiloUI.GRIS))
	_modal.pie.add_child(espacio)
	_modal.pie.add_child(cerrar)
	_modal.boton_principal = cerrar
	_raiz.add_child(_modal)
	create_tween().tween_property(_raiz, "modulate:a", 1.0, 0.6)
	cerrar.grab_focus.call_deferred()


## Lee Resources/creditos.txt y crea una etiqueta por línea.
func _leer_texto() -> void:
	var texto := FileAccess.get_file_as_string(RUTA_TEXTO)
	for linea in texto.split("\n"):
		var l := linea.strip_edges()
		if l.begins_with("#") and not l.begins_with("# "):
			continue
		if l.begins_with("# "):
			# Los comentarios del principio del archivo (antes de la primera sección) también empiezan con "# ":
			# se distinguen porque el primer título real es "Juego"
			if _columna.get_child_count() == 0 and l != "# Juego":
				continue
			_columna.add_child(_espacio(18))
			var titulo := EstiloUI.titulo(l.substr(2), 12, EstiloUI.NARANJA)
			titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_columna.add_child(titulo)
		elif l == "":
			if _columna.get_child_count() > 0:
				_columna.add_child(_espacio(6))
		elif l.begins_with("> "):
			_columna.add_child(_espacio(30))
			var nota := EstiloUI.etiqueta(l.substr(2), 12, EstiloUI.CREMA)
			nota.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			nota.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			nota.custom_minimum_size = Vector2(ANCHO, 0)
			_columna.add_child(nota)
		else:
			if _columna.get_child_count() == 0:
				continue
			var e := EstiloUI.etiqueta(l, 12, EstiloUI.CREMA if not l.begins_with("[COMPLETAR") else EstiloUI.AMBAR)
			e.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			e.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			e.custom_minimum_size = Vector2(ANCHO, 0)
			_columna.add_child(e)
	_columna.add_child(_espacio(20))


func _espacio(alto: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, alto)
	return c


func _process(delta: float) -> void:
	if _cerrando or _modal == null:
		return
	if _espera > 0.0:
		_espera -= delta
		return
	# Baja solo y despacio; la flecha abajo acelera. Quien desplaza a mano (rueda, flechas, AvPág) se suma a esto
	var rapido := Input.is_key_pressed(KEY_DOWN)
	_fraccion += VELOCIDAD * (4.0 if rapido else 1.0) * delta
	var paso := int(_fraccion)
	_fraccion -= paso
	_modal.scroll.scroll_vertical += paso
	var barra := _modal.scroll.get_v_scroll_bar()
	if _modal.scroll.scroll_vertical >= barra.max_value - barra.page - 1.0:
		_al_final += delta
		if _al_final > 4.0:
			_cerrar()
	else:
		_al_final = 0.0


func _input(evento: InputEvent) -> void:
	if _cerrando:
		return
	var salir := evento.is_action_pressed("ui_accept") or evento.is_action_pressed("ui_cancel") or evento.is_action_pressed("PAUSA")
	if salir:
		get_viewport().set_input_as_handled()
		_cerrar()


func _cerrar() -> void:
	if _cerrando:
		return
	_cerrando = true
	Audio.efecto("ui_cancelar")
	cerrados.emit()
	var t := create_tween()
	t.tween_property(_raiz, "modulate:a", 0.0, 0.4)
	await t.finished
	queue_free()
