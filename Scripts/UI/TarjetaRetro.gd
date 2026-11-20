class_name TarjetaRetro
extends CanvasLayer
## La tarjeta de retroalimentación de las decisiones (siempre el mismo diseño, capa 13), construida sobre ModalBase:
## cabecera fija (pictograma, título «Muy bien», «Casi» u «Ojo» y el rostro de Sami), cuerpo con scroll («Lo que hiciste»,
## «Lo recomendado», «Por qué» y una frase para recordar) y pie fijo con «Entendido» y, si la decisión no fue segura,
## «Intentar de nuevo». Con el juego en pausa mientras está abierta. El tono es cálido y breve: nunca hay burla.
##
## Reglas del contenido:
##   - Si «Lo que hiciste» y «Lo recomendado» son iguales, hay UNA sola sección con la marca ✔ (sin repetir).
##   - Con `lista_hecho` (el kit) «Lo que hiciste» es una lista con ✔ (correcto) y ✖ (distractor), y «Lo recomendado» solo trae lo
##     que faltó; si no faltó nada, esa sección no aparece.
##
## Uso:  var reintentar: bool = await TarjetaRetro.mostrar(get_tree(), "Ojo", hecho, recomendado, por_que, true)

signal cerrada(reintentar: bool)

## Color de la señal según el título (acierto, precaución, riesgo). Los pictogramas se dibujan en Pictograma.gd.
const COLOR_TITULO := {"Muy bien": EstiloUI.TURQUESA, "Casi": EstiloUI.AMBAR, "Ojo": EstiloUI.ROJO}

var _titulo := ""
var _hecho := ""
var _recomendado := ""
var _por_que := ""
var _permite_reintento := false
## El kit: [{"texto": "Agua potable", "ok": true}, ...]. Vacío en las demás decisiones.
var _lista_hecho: Array = []
var _cerrando := false
var _modal: ModalBase
var _primer_boton: Button
var _fila_botones: Control
var _textos: Array[Label] = []
## SOLO la galería de estilo: la tarjeta se coloca y se escala donde se pide, sin pausar, sin sonido y con todo el texto visible.
var modo_galeria := false
var _posicion := Vector2.ZERO
var _escala := 1.0


static func _crear(titulo: String, hecho: String, recomendado: String, por_que: String, permite_reintento: bool, lista_hecho: Array) -> TarjetaRetro:
	var tarjeta: TarjetaRetro = (load("res://Scenes/UI/TarjetaRetro.tscn") as PackedScene).instantiate()
	tarjeta._titulo = titulo
	tarjeta._hecho = hecho
	tarjeta._recomendado = recomendado
	tarjeta._por_que = por_que
	tarjeta._permite_reintento = permite_reintento
	tarjeta._lista_hecho = lista_hecho
	return tarjeta


## La tarjeta lista para la galería de estilo (se añade a una escena; no pausa el juego ni suena).
static func para_galeria(titulo: String, hecho: String, recomendado: String, por_que: String, permite_reintento: bool, posicion: Vector2, escala: float, lista_hecho: Array = []) -> TarjetaRetro:
	var tarjeta := _crear(titulo, hecho, recomendado, por_que, permite_reintento, lista_hecho)
	tarjeta.modo_galeria = true
	tarjeta._posicion = posicion
	tarjeta._escala = escala
	return tarjeta


## Muestra la tarjeta y espera. Devuelve true si el jugador pidió «Intentar de nuevo». En las pruebas sin ventana
## (Dialogo.respuesta_de_prueba distinto de -99) no se muestra y devuelve false.
static func mostrar(arbol: SceneTree, titulo: String, hecho: String, recomendado: String, por_que: String, permite_reintento: bool, lista_hecho: Array = []) -> bool:
	if Dialogo.respuesta_de_prueba != -99:
		await arbol.process_frame
		return false
	var tarjeta := _crear(titulo, hecho, recomendado, por_que, permite_reintento, lista_hecho)
	arbol.root.add_child.call_deferred(tarjeta)
	var reintentar: bool = await tarjeta.cerrada
	return reintentar


## true si «Lo que hiciste» y «Lo recomendado» dicen lo mismo (no se repite).
func _son_iguales() -> bool:
	return _lista_hecho.is_empty() and _recomendado.strip_edges() != "" and _hecho.strip_edges() == _recomendado.strip_edges()


func _ready() -> void:
	layer = 13
	process_mode = Node.PROCESS_MODE_ALWAYS
	var raiz := Control.new()
	raiz.theme = EstiloUI.tema()
	if modo_galeria:
		raiz.set_anchors_preset(Control.PRESET_TOP_LEFT)
		raiz.size = Vector2(640, 360)
		raiz.scale = Vector2(_escala, _escala)
		raiz.position = _posicion
	else:
		raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
		var velo := ColorRect.new()
		velo.color = Color(EstiloUI.AZUL_NOCHE, 0.7)
		velo.set_anchors_preset(Control.PRESET_FULL_RECT)
		raiz.add_child(velo)
	add_child(raiz)

	# La tarjeta es una señal de seguridad: borde del color del resultado, pictograma y título en la cabecera
	var color: Color = COLOR_TITULO.get(_titulo, EstiloUI.NARANJA)
	_modal = ModalBase.crear()
	_modal.ancho_deseado = 420.0
	_modal.configurar(EstiloUI.PETROLEO, color, 10)
	var cabecera := PanelContainer.new()
	cabecera.add_theme_stylebox_override("panel", EstiloUI.caja(EstiloUI.PETROLEO_OSCURO, EstiloUI.PETROLEO_OSCURO, 0, 8))
	_modal.cabecera.add_child(cabecera)
	var fila_cab := HBoxContainer.new()
	fila_cab.add_theme_constant_override("separation", 10)
	cabecera.add_child(fila_cab)
	fila_cab.add_child(Pictograma.para_titulo(_titulo, 40.0))
	var titulo := EstiloUI.titulo(_titulo.to_upper(), 16, EstiloUI.CREMA)
	titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titulo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fila_cab.add_child(titulo)
	# Sami: preocupado cuando es «Ojo», neutral en los demás casos (rostro a 1x, sin escalar)
	var cara := TextureRect.new()
	cara.texture = Retratos.rostro("sami_preocupado" if _titulo == "Ojo" else "sami_neutral")
	cara.custom_minimum_size = Vector2(56, 56)
	cara.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cara.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	cara.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila_cab.add_child(cara)

	# Cuerpo
	var margen := MarginContainer.new()
	margen.add_theme_constant_override("margin_right", 6)
	margen.add_theme_constant_override("margin_top", 6)
	_modal.cuerpo.add_child(margen)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 7)
	margen.add_child(v)
	var iguales := _son_iguales()
	if not _lista_hecho.is_empty():
		_textos.append_array(_bloque_lista(v, "Lo que hiciste", _lista_hecho))
	elif iguales:
		_textos.append_array(_bloque_lista(v, "Lo que hiciste", [{"texto": _hecho, "ok": true}]))
	else:
		_textos.append(_bloque(v, "Lo que hiciste", _hecho))
	if not iguales and _recomendado.strip_edges() != "":
		_textos.append(_bloque(v, "Lo recomendado", _recomendado))
	if _por_que.strip_edges() != "":
		_textos.append(_bloque(v, "Por qué", _por_que))
	if not iguales and _lista_hecho.is_empty() and _recomendado.strip_edges() != "":
		_textos.append(_nota(v, "Para recordar", "Recuerda: %s" % _recomendado.trim_suffix(".")))

	# Pie: botones (aparecen al terminar de escribirse el texto)
	var espacio := Control.new()
	espacio.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_modal.pie.add_child(espacio)
	if _permite_reintento:
		_modal.pie.add_child(_boton("Intentar de nuevo", true))
	_primer_boton = _boton("Entendido", false)
	_modal.pie.add_child(_primer_boton)
	_modal.boton_principal = _primer_boton
	_fila_botones = _modal.pie
	_modal.pie.modulate.a = 0.0
	_modal.confirmar_activo = false
	raiz.add_child(_modal)
	if modo_galeria:
		for e in _textos:
			e.visible_characters = -1
		_modal.pie.modulate.a = 1.0
		return
	Audio.efecto("dialogo_opciones")
	get_tree().paused = true
	_escribir.call_deferred()


## Los textos se escriben letra por letra, con el mismo efecto y el mismo sonido de letras que los diálogos.
## Los botones aparecen al terminar (o antes, con E o ENTER, que completa el texto de golpe).
func _escribir() -> void:
	# Espera a que el modal se mida (así se sabe qué parte se ve)
	await _modal.reajustado
	# Con el cuadro ya medido (texto completo) se reserva el alto de cada texto y recién entonces se ocultan las letras:
	# la escritura no cambia ningún tamaño
	for e in _textos:
		Dialogo.reservar_alto(e)
		e.visible_characters = 0
	for e in _textos:
		if _cerrando or not is_instance_valid(self):
			return
		var texto := e.text
		_modal.scroll.ensure_control_visible(e)
		await Dialogo.escribir_etiqueta(e, texto)
	if _cerrando or not is_instance_valid(self):
		return
	_mostrar_botones()


func _mostrar_botones() -> void:
	for e in _textos:
		e.visible_characters = -1
	_fila_botones.modulate.a = 1.0
	_modal.confirmar_activo = true
	_primer_boton.grab_focus()


func _bloque(padre: Control, rotulo: String, texto: String) -> Label:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.add_child(EstiloUI.titulo(rotulo.to_upper(), 8, EstiloUI.NARANJA))
	var e := _etiqueta_texto(texto)
	v.add_child(e)
	padre.add_child(v)
	return e


## Una sección con una lista: cada fila lleva su marca ✔ o ✖. Devuelve las etiquetas (para escribirlas).
func _bloque_lista(padre: Control, rotulo: String, lista: Array) -> Array[Label]:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.add_child(EstiloUI.titulo(rotulo.to_upper(), 8, EstiloUI.NARANJA))
	var etiquetas: Array[Label] = []
	for item in lista:
		var fila := HBoxContainer.new()
		fila.add_theme_constant_override("separation", 6)
		fila.add_child(MarcaOk.crear(bool(item["ok"])))
		var e := _etiqueta_texto(str(item["texto"]))
		e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fila.add_child(e)
		v.add_child(fila)
		etiquetas.append(e)
	padre.add_child(v)
	return etiquetas


func _etiqueta_texto(texto: String) -> Label:
	var e := EstiloUI.etiqueta(texto, 13, EstiloUI.CREMA)
	e.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	e.custom_minimum_size = Vector2(120, 0)   # se mide con el texto completo; _escribir reserva el alto y lo oculta
	return e


## La frase para recordar va en una nota de papel crema con texto oscuro.
func _nota(padre: Control, rotulo: String, texto: String) -> Label:
	var caja := PanelContainer.new()
	caja.add_theme_stylebox_override("panel", EstiloUI.caja(EstiloUI.CREMA, EstiloUI.TINTA, 2, 6))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	caja.add_child(v)
	v.add_child(EstiloUI.titulo(rotulo.to_upper(), 8, EstiloUI.TINTA_SUAVE))
	var e := EstiloUI.etiqueta(texto, 13, EstiloUI.TINTA)
	e.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	e.custom_minimum_size = Vector2(120, 0)
	v.add_child(e)
	padre.add_child(caja)
	return e


func _boton(texto: String, reintentar: bool) -> Button:
	var b := Button.new()
	b.text = texto
	b.custom_minimum_size = Vector2(120, 28)
	b.pressed.connect(_cerrar.bind(reintentar))
	b.focus_entered.connect(func() -> void: Audio.efecto("ui_mover"))
	return b


func _cerrar(reintentar: bool) -> void:
	if _cerrando:
		return
	_cerrando = true
	Audio.efecto("ui_elegir")
	get_tree().paused = false
	cerrada.emit(reintentar)
	queue_free()


# ESC y TAB no cierran la tarjeta ni abren menús: hay que elegir un botón. E o ENTER completan el texto.
func _input(evento: InputEvent) -> void:
	if modo_galeria:
		return
	if (evento.is_action_pressed("INTERACTUAR") or evento.is_action_pressed("ui_accept")) and _fila_botones != null and _fila_botones.modulate.a < 1.0:
		get_viewport().set_input_as_handled()
		_mostrar_botones()
		return
	for accion in ["PAUSA", "DIARIO", "ui_cancel"]:
		if evento.is_action_pressed(accion):
			get_viewport().set_input_as_handled()
			return
