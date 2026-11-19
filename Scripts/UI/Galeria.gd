class_name Galeria
extends CanvasLayer
## GALERÍA DE ESTILO (solo en depuración, tecla G): todos los componentes de la interfaz uno junto al otro, para revisarlos con
## una sola captura. Cada página es una pantalla de 640 x 360 dentro de su propio SubViewport:
##   1 Diálogo y avisos   2 Radio y retratos   3 Retroalimentación   4 Libreta   5 HUD y pausa
##   6 Tablilla, carné y botones   7 Título   8 Transiciones, señales y sellos
## Vista general (por defecto): las 8 páginas juntas en 4 x 2. Flechas izquierda y derecha: una página a tamaño real.
## V: vuelve a la vista general. K: abre la prueba de modales (GaleriaModales). G o Esc: cerrar. No es parte del juego: no se usa fuera de OS.is_debug_build().

const ESCENA := "res://Scenes/UI/Galeria.tscn"
const PAGINAS := ["1 · Diálogo y avisos", "2 · Radio y retratos", "3 · Retroalimentación", "4 · Libreta",
		"5 · HUD y pausa", "6 · Tablilla, carné y botones", "7 · Título", "8 · Transiciones, señales y sellos"]
const COLUMNAS := 4
const PANTALLA := Vector2i(640, 360)

static var _abierta: Galeria

var pagina := -1   # -1 = vista general
var _contenedores: Array[SubViewportContainer] = []
var _escala_anterior := Vector2i(640, 360)
var _pausa_anterior := false
var _temporizador := 0.0


## G: abre la galería si está cerrada y la cierra si está abierta. Solo en depuración.
static func alternar(arbol: SceneTree) -> void:
	if not OS.is_debug_build():
		return
	if is_instance_valid(_abierta):
		_abierta.cerrar()
		return
	_abierta = (load(ESCENA) as PackedScene).instantiate() as Galeria
	arbol.root.add_child(_abierta)


## La galería abierta (o null).
static func actual() -> Galeria:
	return _abierta if is_instance_valid(_abierta) else null


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_pausa_anterior = get_tree().paused
	get_tree().paused = true
	_escala_anterior = get_window().content_scale_size
	var fondo := ColorRect.new()
	fondo.color = Color("05090c")
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)
	for i in PAGINAS.size():
		_contenedores.append(_crear_pagina(i))
	ir_a_pagina(-1)


func cerrar() -> void:
	get_window().content_scale_size = _escala_anterior
	get_tree().paused = _pausa_anterior
	Dialogo.anclas.erase("Doña Rosa")
	_abierta = null
	queue_free()


## -1 = vista general; 0 a 7 = esa página a tamaño real.
func ir_a_pagina(n: int) -> void:
	pagina = n
	if n < 0:
		get_window().content_scale_size = Vector2i(PANTALLA.x * COLUMNAS, PANTALLA.y * 2)
		for i in _contenedores.size():
			_contenedores[i].visible = true
			_contenedores[i].position = Vector2((i % COLUMNAS) * PANTALLA.x, (i / COLUMNAS) * PANTALLA.y)
	else:
		get_window().content_scale_size = PANTALLA
		for i in _contenedores.size():
			_contenedores[i].visible = i == n
			_contenedores[i].position = Vector2.ZERO


func _input(evento: InputEvent) -> void:
	if not (evento is InputEventKey) or not evento.pressed or evento.echo:
		return
	match evento.keycode:
		KEY_G, KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			cerrar()
		KEY_K:
			get_viewport().set_input_as_handled()
			cerrar()
			GaleriaModales.abrir(get_tree())
		KEY_V:
			get_viewport().set_input_as_handled()
			ir_a_pagina(-1)
		KEY_RIGHT:
			get_viewport().set_input_as_handled()
			ir_a_pagina(posmod(pagina + 1, PAGINAS.size()) if pagina >= 0 else 0)
		KEY_LEFT:
			get_viewport().set_input_as_handled()
			ir_a_pagina(posmod(pagina - 1, PAGINAS.size()) if pagina >= 0 else PAGINAS.size() - 1)


func _process(delta: float) -> void:
	# El banner de alerta se repite cada pocos segundos para que siempre se vea en la captura
	_temporizador += delta
	if _temporizador > 5.0:
		_temporizador = 0.0
		Notificacion.mostrar("Memoria de 1999", "Nueva tarjeta en tu libreta (Tab).")


# --- Páginas ---

func _crear_pagina(i: int) -> SubViewportContainer:
	var contenedor := SubViewportContainer.new()
	contenedor.stretch = false
	contenedor.size = Vector2(PANTALLA)
	contenedor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(contenedor)
	var vp := SubViewport.new()
	vp.size = PANTALLA
	vp.transparent_bg = false
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.handle_input_locally = false
	contenedor.add_child(vp)
	var raiz := Control.new()
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.theme = EstiloUI.tema()
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vp.add_child(raiz)
	var fondo := ColorRect.new()
	fondo.color = EstiloUI.AZUL_NOCHE if i != 6 else Color("3b5a63")
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.add_child(fondo)
	call(["_p_dialogo", "_p_radio", "_p_retro", "_p_libreta", "_p_hud_pausa", "_p_papel", "_p_titulo", "_p_transiciones"][i], vp, raiz)
	var rotulo := EstiloUI.titulo(PAGINAS[i], 8, EstiloUI.GRIS)
	rotulo.position = Vector2(4, 2)
	raiz.add_child(rotulo)
	return contenedor


## Un texto de diálogo para el globo (con opciones) dentro del SubViewport de la página.
func _globo(vp: SubViewport, nombre: String, texto: String, opciones: Array) -> DialogoBalloon:
	var guion := "~ start\n%s: %s\n" % [nombre, texto]
	for o in opciones:
		guion += "- %s\n" % o
	var recurso: DialogueResource = DialogueManager.create_resource_from_text(guion)
	var globo: DialogoBalloon = Dialogo.BALLOON.instantiate()
	vp.add_child(globo)
	globo.start(recurso, "start", [])
	return globo


func _sprite_personaje(columna: int, posicion: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = load("res://Assets/Personajes/personajes.png")
	atlas.region = Rect2(columna * 64, 0, 64, 64)
	s.texture = atlas
	s.position = posicion
	s.scale = Vector2(2, 2)
	return s


func _p_dialogo(vp: SubViewport, raiz: Control) -> void:
	# Teclas de interacción
	var verbos := ["Revisar", "Hablar", "Abrir", "Tomar"]
	for k in verbos.size():
		var t := IndicadorTecla.new()
		t.verbo = verbos[k]
		t.position = Vector2(14 + k * 100, 26)
		raiz.add_child(t)
	var mantener := IndicadorTecla.new()
	mantener.verbo = "Mantén"
	mantener.position = Vector2(430, 26)
	raiz.add_child(mantener)
	var anillo := mantener.create_tween().set_loops()
	anillo.tween_property(mantener, "progreso", 1.0, 2.0).from(0.0)
	# Doña Rosa y la cola del globo que apunta hacia ella
	var rosa := _sprite_personaje(2, Vector2(470, 150))
	raiz.add_child(rosa)
	Dialogo.anclas["Doña Rosa"] = rosa
	_globo(vp, "Doña Rosa", "Ay, mijo, ¿me ayudas con la bolsa?", ["Sí, con cuidado", "No puedo ahora"])


func _p_radio(vp: SubViewport, raiz: Control) -> void:
	var nombres := Retratos.NOMBRES
	for k in nombres.size():
		var r := TextureRect.new()
		r.texture = Retratos.obtener(nombres[k])
		r.position = Vector2(8 + (k % 4) * 100, 18 + (k / 4) * 100)
		r.custom_minimum_size = Vector2(96, 96)
		r.size = Vector2(96, 96)
		raiz.add_child(r)
		var e := EstiloUI.etiqueta(nombres[k], 10, EstiloUI.GRIS)
		e.position = r.position + Vector2(0, 94)
		raiz.add_child(e)
	_globo(vp, "Lucía", "Aquí Lucía, canal 3. Revisa primero lo que pueda caerse.", [])


func _p_retro(_vp: SubViewport, raiz: Control) -> void:
	var casos := [
		["Muy bien", "Fijaste el estante a la pared.", "Fijar el estante a la pared.", "Un mueble alto sin fijar puede caerse durante un sismo.", false],
		["Casi", "Elegiste la escalera al segundo intento.", "Bajar por la escalera, no por el ascensor.", "En un sismo el ascensor puede quedar detenido.", false],
		["Ojo", "Dejaste el estante sin fijar.", "Fijar el estante a la pared.", "Un mueble alto sin fijar puede caerse durante un sismo.", true],
	]
	for k in casos.size():
		var c: Array = casos[k]
		var tarjeta := TarjetaRetro.para_galeria(c[0], c[1], c[2], c[3], c[4], Vector2(4 + k * 212, 22), 0.5)
		raiz.get_parent().add_child(tarjeta)


func _p_libreta(vp: SubViewport, _raiz: Control) -> void:
	Estado.registrar_decision("D1", true)
	var libreta := Libreta.new()
	vp.add_child(libreta)
	libreta.abrir()


func _p_hud_pausa(vp: SubViewport, _raiz: Control) -> void:
	var hud := HUD.new()
	vp.add_child(hud)
	hud.configurar("Nivel 1 · Antes", [{"id": "D1", "texto": "Revisar el estante"}, {"id": "D2", "texto": "Revisar el cuadro de la cama"}, {"id": "D3", "texto": "Revisar el cilindro de gas"}])
	hud.marcar.call_deferred("D1")
	var pausa: MenuPausa = (load("res://Scenes/UI/Pausa.tscn") as PackedScene).instantiate()
	vp.add_child(pausa)
	pausa.abrir.call_deferred()


func _p_papel(_vp: SubViewport, raiz: Control) -> void:
	# Tablilla con una pregunta de ejemplo, el carné y los botones tipo señal
	var tablilla := Tablilla.new()
	tablilla.position = Vector2(10, 22)
	tablilla.size = Vector2(300, 190)
	raiz.add_child(tablilla)
	tablilla.contenido.add_child(EstiloUI.titulo("PREGUNTA 3 DE 14", 8, EstiloUI.TINTA_SUAVE))
	var q := EstiloUI.etiqueta("¿Qué haces durante un temblor fuerte?", 12, EstiloUI.TINTA)
	q.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	q.custom_minimum_size = Vector2(270, 0)
	tablilla.contenido.add_child(q)
	var opciones := ["Me agacho, me cubro y me sujeto", "Corro a la salida", "Me paro en el marco de la puerta"]
	for k in opciones.size():
		var fila := HBoxContainer.new()
		fila.add_theme_constant_override("separation", 6)
		var c := Casilla.new()
		fila.add_child(c)
		fila.add_child(EstiloUI.etiqueta(opciones[k], 11, EstiloUI.TINTA))
		tablilla.contenido.add_child(fila)
		c.poner.call_deferred(k == 0, false)
	var carne := Carne.new()
	carne.position = Vector2(318, 18)
	carne.scale = Vector2(0.95, 0.95)
	raiz.add_child(carne)
	carne.sellar.call_deferred("BRIGADISTA", EstiloUI.TURQUESA_TINTA)
	var rotulo := EstiloUI.titulo("BOTONES", 8, EstiloUI.CREMA)
	rotulo.position = Vector2(14, 224)
	raiz.add_child(rotulo)
	var b1 := EstiloUI.boton_senal("Acepto y continúo", 180, 30, 9)
	b1.position = Vector2(14, 238)
	raiz.add_child(b1)
	var b2 := EstiloUI.boton_senal("Jugar sin guardar", 180, 30, 9)
	b2.position = Vector2(206, 238)
	raiz.add_child(b2)
	var b3 := Button.new()
	b3.text = "Botón del tema"
	b3.position = Vector2(398, 238)
	b3.custom_minimum_size = Vector2(150, 30)
	raiz.add_child(b3)
	var sello := Sello.crear("EVALUACIÓN DE INGRESO", EstiloUI.ROJO_TINTA, 12, -0.1)
	sello.position = Vector2(330, 196)
	raiz.add_child(sello)
	var sello2 := Sello.crear("RECIBIDA", EstiloUI.TURQUESA_TINTA, 12, 0.1)
	sello2.position = Vector2(500, 200)
	raiz.add_child(sello2)
	var nota := EstiloUI.etiqueta("Textos largos: Pixelify Sans. Títulos: Silkscreen. Radio: VT323.", 11, EstiloUI.CREMA)
	nota.position = Vector2(14, 290)
	raiz.add_child(nota)
	var radio := EstiloUI.radio("Canal 3 · Lucía: ¿me copias? Cambio.", 20, EstiloUI.CREMA)
	radio.position = Vector2(14, 316)
	raiz.add_child(radio)


func _p_titulo(_vp: SubViewport, raiz: Control) -> void:
	var fondo := TextureRect.new()
	fondo.texture = load("res://Assets/UI/fondo_titulo.png")
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fondo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fondo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	raiz.add_child(fondo)
	var sismografo := Sismografo.new()
	sismografo.position = Vector2(0, 150)
	sismografo.size = Vector2(640, 50)
	raiz.add_child(sismografo)
	var titulo := EstiloUI.titulo("MINUTO CERO", 44, EstiloUI.NARANJA)
	titulo.add_theme_color_override("font_outline_color", EstiloUI.AZUL_NOCHE)
	titulo.add_theme_constant_override("outline_size", 10)
	titulo.position = Vector2(100, 22)
	raiz.add_child(titulo)
	var cuenta := EstiloUI.radio("00:00", 36, EstiloUI.ROJO)
	cuenta.add_theme_color_override("font_outline_color", EstiloUI.AZUL_NOCHE)
	cuenta.add_theme_constant_override("outline_size", 8)
	cuenta.position = Vector2(270, 74)
	raiz.add_child(cuenta)
	var sub := EstiloUI.etiqueta("Aprende a actuar ante un sismo", 16, EstiloUI.CREMA)
	sub.add_theme_color_override("font_outline_color", EstiloUI.AZUL_NOCHE)
	sub.add_theme_constant_override("outline_size", 6)
	sub.position = Vector2(190, 112)
	raiz.add_child(sub)
	for k in 3:
		var b := EstiloUI.boton_senal(["Comenzar", "Continuar", "Salir"][k], 150, 30, 12)
		b.position = Vector2(470, 226 + k * 40)
		raiz.add_child(b)
		if k == 0:
			var flecha := Polygon2D.new()
			flecha.polygon = PackedVector2Array([Vector2(0, 0), Vector2(12, 7), Vector2(0, 14)])
			flecha.color = EstiloUI.NARANJA
			flecha.position = Vector2(450, 234)
			raiz.add_child(flecha)


func _p_transiciones(_vp: SubViewport, raiz: Control) -> void:
	# Persiana a medio cerrar
	var persiana := Persiana.new()
	persiana.set_anchors_preset(Control.PRESET_FULL_RECT)
	persiana.size = Vector2(PANTALLA)
	raiz.add_child(persiana)
	persiana.cierre = 0.7
	# Tarjeta de nivel con reloj (en un recuadro)
	var recuadro := Control.new()
	recuadro.position = Vector2(330, 22)
	recuadro.size = Vector2(300, 200)
	recuadro.clip_contents = true
	raiz.add_child(recuadro)
	var tarjeta := TarjetaNivel.crear(2)
	tarjeta.silencioso = true
	tarjeta.set_anchors_preset(Control.PRESET_FULL_RECT)
	recuadro.add_child(tarjeta)
	# Pictogramas de la retroalimentación
	for k in 3:
		var p := Pictograma.new()
		p.tipo = k as Pictograma.Tipo
		p.custom_minimum_size = Vector2(40, 40)
		p.size = Vector2(40, 40)
		p.position = Vector2(14 + k * 56, 240)
		raiz.add_child(p)
	var f := Franjas.new()
	f.position = Vector2(14, 296)
	f.size = Vector2(300, 12)
	raiz.add_child(f)
	var casillas := HBoxContainer.new()
	casillas.position = Vector2(14, 320)
	casillas.add_theme_constant_override("separation", 6)
	raiz.add_child(casillas)
	for k in 6:
		var c := Casilla.new()
		casillas.add_child(c)
		c.poner.call_deferred(k < 3, false)
	var paleta := HBoxContainer.new()
	paleta.position = Vector2(200, 240)
	paleta.add_theme_constant_override("separation", 4)
	raiz.add_child(paleta)
	for color in [EstiloUI.PETROLEO, EstiloUI.AZUL_NOCHE, EstiloUI.NARANJA, EstiloUI.CREMA, EstiloUI.ROJO, EstiloUI.AMBAR, EstiloUI.TURQUESA]:
		var m := ColorRect.new()
		m.color = color
		m.custom_minimum_size = Vector2(16, 32)
		paleta.add_child(m)
