class_name EstiloUI
extends RefCounted
## IDENTIDAD VISUAL de MINUTO CERO en un solo lugar: colores, fuentes, cajas y el tema del juego.
## Para cambiar el aspecto de todas las pantallas se cambia aquí (y se vuelve a generar el tema con
## `godot --headless --script res://tools/generar_tema.gd`, que escribe Resources/tema_minutocero.tres).
##
## Reglas: esquinas rectas con borde de 2 px (sin esquinas redondeadas), franjas diagonales naranja y negro
## como detalle (Franjas.gd), y nada de dorado ni morado.

# --- Paleta ---
const AZUL_NOCHE := Color("10202a")    # fondo
const PETROLEO := Color("0f3d4a")      # paneles
const PETROLEO_OSCURO := Color("0b2c36")
const PETROLEO_CLARO := Color("17566a")
const PETROLEO_PULSADO := Color("1f6b82")
const NARANJA := Color("ff7a1a")       # acentos y foco
const CREMA := Color("f3e9d2")         # papel y texto claro
const ROJO := Color("d64b2a")          # riesgo
const AMBAR := Color("f2b134")         # precaución
const TURQUESA := Color("2a9d8f")      # acierto
const GRIS := Color("a9bcc4")          # texto secundario sobre petróleo (contraste > 4.5)
const TINTA := Color("14232b")         # texto oscuro sobre papel crema
const TINTA_SUAVE := Color("4a5a60")   # nota a lápiz
const PAPEL := Color("fbf5e4")         # hoja más clara que la crema (tablilla, carné, acuerdo)
# Versiones oscuras de los colores de señal, para texto sobre papel crema (contraste mínimo 4.5)
const TURQUESA_TINTA := Color("1a6b61")
const AMBAR_TINTA := Color("85560a")
const ROJO_TINTA := Color("a3341a")
const NARANJA_TINTA := Color("a84400")

# --- Fuentes (Google Fonts, licencia OFL) ---
const RUTA_TITULO := "res://Assets/Fuentes/Silkscreen-Regular.ttf"
const RUTA_TITULO_NEGRITA := "res://Assets/Fuentes/Silkscreen-Bold.ttf"
const RUTA_RADIO := "res://Assets/Fuentes/VT323-Regular.ttf"
const RUTA_TEXTO := "res://Assets/Fuentes/PixelifySans.ttf"
const RUTA_TEMA := "res://Resources/tema_minutocero.tres"

static var _fuentes: Dictionary = {}
static var _tema: Theme


static func _cargar(ruta: String) -> Font:
	if not _fuentes.has(ruta):
		var f: Font = load(ruta) if ResourceLoader.exists(ruta) else null
		if f != null:
			# Sin ligaduras: en Pixelify Sans «fi» se dibuja como un solo signo que parece «Aj» («fijar» se lee «Ajar»)
			var v := FontVariation.new()
			v.base_font = f
			v.opentype_features = {"liga": 0, "clig": 0, "dlig": 0}
			f = v
		_fuentes[ruta] = f
	return _fuentes[ruta]


## Silkscreen: títulos y etiquetas (es una fuente de mayúsculas pequeñas: no sirve para párrafos).
static func fuente_titulo() -> Font:
	return _cargar(RUTA_TITULO)


## VT323: texto de la radio y de las transmisiones.
static func fuente_radio() -> Font:
	return _cargar(RUTA_RADIO)


## Pixelify Sans: lectura larga (diálogos, tarjetas, cuestionarios). Se usa porque Silkscreen y VT323 se cansan en párrafos.
static func fuente_texto() -> Font:
	return _cargar(RUTA_TEXTO)


## Compatibilidad: la fuente de lectura.
static func fuente() -> Font:
	return fuente_texto()


## Una caja de esquinas rectas (fondo, borde, grosor del borde y margen interior).
static func caja(fondo: Color, borde: Color, grosor: int = 2, margen: int = 8, _radio: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fondo
	s.border_color = borde
	s.set_border_width_all(grosor)
	s.set_corner_radius_all(0)
	s.set_content_margin_all(margen)
	return s


## Una etiqueta de lectura (Pixelify Sans) que no recibe el ratón.
static func etiqueta(texto: String, tamano: int = 12, color: Color = CREMA) -> Label:
	return _etiqueta_con(fuente_texto(), texto, tamano, color)


## Una etiqueta de título (Silkscreen).
static func titulo(texto: String, tamano: int = 12, color: Color = CREMA) -> Label:
	return _etiqueta_con(fuente_titulo(), texto, tamano, color)


## Una etiqueta de radio (VT323). Es una fuente más chica: usa tamaños mayores (16 a 20).
static func radio(texto: String, tamano: int = 16, color: Color = CREMA) -> Label:
	return _etiqueta_con(fuente_radio(), texto, tamano, color)


static func _etiqueta_con(f: Font, texto: String, tamano: int, color: Color) -> Label:
	var e := Label.new()
	e.text = texto
	e.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if f != null:
		e.add_theme_font_override("font", f)
	e.add_theme_font_size_override("font_size", tamano)
	e.add_theme_color_override("font_color", color)
	return e


## Botón tipo señal de seguridad: rectángulo naranja con franjas de precaución arriba y abajo y texto oscuro en Silkscreen.
## Sirve para las pantallas de introducción (acuerdo, resultados). Foco: borde crema.
static func boton_senal(texto: String, ancho: float = 0.0, alto: float = 30.0, tamano: int = 10) -> Button:
	var b := Button.new()
	b.text = texto
	b.custom_minimum_size = Vector2(ancho, alto)
	b.add_theme_font_override("font", fuente_titulo())
	b.add_theme_font_size_override("font_size", tamano)
	for c in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_disabled_color"]:
		b.add_theme_color_override(c, TINTA)
	b.add_theme_stylebox_override("normal", caja(NARANJA.darkened(0.12), TINTA, 2, 6))
	for e in ["hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(e, caja(NARANJA, CREMA if e == "focus" else TINTA, 2, 6))
	b.add_theme_stylebox_override("disabled", caja(NARANJA.darkened(0.45), TINTA, 2, 6))
	b.draw.connect(func() -> void:
		var ancho_franja: float = b.size.x - 8.0
		Franjas.pintar(b, Rect2(4, 3, ancho_franja, 3), TINTA, NARANJA, 6.0)
		Franjas.pintar(b, Rect2(4, b.size.y - 6, ancho_franja, 3), TINTA, NARANJA, 6.0))
	return b


## Relación de contraste (WCAG) entre dos colores: la identidad pide al menos 4.5 en texto.
static func contraste(a: Color, b: Color) -> float:
	var la := _luminancia(a)
	var lb := _luminancia(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


static func _luminancia(c: Color) -> float:
	var f := func(v: float) -> float:
		return v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4)
	return 0.2126 * f.call(c.r) + 0.7152 * f.call(c.g) + 0.0722 * f.call(c.b)


## Un cuadradito liso con borde de 2 px (casilla del interruptor).
static func _cuadro(ancho: int, alto: int, color: Color, borde: Color = Color(0, 0, 0, 0)) -> ImageTexture:
	var imagen := Image.create(ancho, alto, false, Image.FORMAT_RGBA8)
	imagen.fill(borde if borde.a > 0.0 else color)
	if borde.a > 0.0:
		for y in range(2, alto - 2):
			for x in range(2, ancho - 2):
				imagen.set_pixel(x, y, color)
	return ImageTexture.create_from_image(imagen)


## El tema del juego: se carga de Resources/tema_minutocero.tres y, si no existe, se construye al vuelo.
static func tema() -> Theme:
	if _tema == null:
		if ResourceLoader.exists(RUTA_TEMA):
			_tema = load(RUTA_TEMA)
		if _tema == null:
			_tema = construir_tema()
	return _tema


## Construye el tema (lo usa tools/generar_tema.gd para escribir el .tres).
static func construir_tema() -> Theme:
	var t := Theme.new()
	if fuente_texto() != null:
		t.default_font = fuente_texto()
	t.default_font_size = 14
	for tipo in ["Label", "Button", "CheckButton", "CheckBox", "LineEdit"]:
		t.set_font_size("font_size", tipo, 14)
	t.set_font("font", "Button", fuente_titulo())
	t.set_font_size("font_size", "Button", 10)
	t.set_color("font_color", "Label", CREMA)
	for tipo in ["Button", "CheckButton"]:
		t.set_color("font_color", tipo, CREMA)
		t.set_color("font_hover_color", tipo, NARANJA)
		t.set_color("font_focus_color", tipo, NARANJA)
		t.set_color("font_pressed_color", tipo, NARANJA)
		t.set_color("font_disabled_color", tipo, Color("6f8791"))
	t.set_stylebox("normal", "Button", caja(PETROLEO, CREMA.darkened(0.45), 2, 6))
	t.set_stylebox("hover", "Button", caja(PETROLEO_CLARO, NARANJA, 2, 6))
	t.set_stylebox("pressed", "Button", caja(PETROLEO_PULSADO, NARANJA, 2, 6))
	t.set_stylebox("focus", "Button", caja(PETROLEO_CLARO, NARANJA, 2, 6))
	t.set_stylebox("disabled", "Button", caja(AZUL_NOCHE, Color("2c4650"), 2, 6))
	for estilo in ["normal", "hover", "pressed", "hover_pressed"]:
		t.set_stylebox(estilo, "CheckButton", caja(PETROLEO if estilo == "normal" else PETROLEO_CLARO, CREMA.darkened(0.45) if estilo == "normal" else NARANJA, 2, 6))
	t.set_stylebox("focus", "CheckButton", caja(PETROLEO_CLARO, NARANJA, 2, 6))
	var apagado := _cuadro(16, 16, AZUL_NOCHE, NARANJA)
	var encendido := _cuadro(16, 16, NARANJA, NARANJA)
	t.set_icon("unchecked", "CheckButton", apagado)
	t.set_icon("checked", "CheckButton", encendido)
	t.set_icon("unchecked_disabled", "CheckButton", apagado)
	t.set_icon("checked_disabled", "CheckButton", encendido)
	var pista := caja(AZUL_NOCHE, PETROLEO_CLARO, 2, 0)
	pista.content_margin_top = 3
	pista.content_margin_bottom = 3
	t.set_stylebox("slider", "HSlider", pista)
	t.set_stylebox("grabber_area", "HSlider", caja(NARANJA.darkened(0.25), NARANJA.darkened(0.25), 0, 0))
	t.set_stylebox("grabber_area_highlight", "HSlider", caja(NARANJA, NARANJA, 0, 0))
	t.set_stylebox("focus", "HSlider", caja(Color(0, 0, 0, 0), NARANJA, 2, 2))
	var asa := _cuadro(8, 16, NARANJA)
	t.set_icon("grabber", "HSlider", asa)
	t.set_icon("grabber_highlight", "HSlider", asa)
	t.set_icon("grabber_disabled", "HSlider", asa)
	t.set_stylebox("panel", "PanelContainer", caja(PETROLEO, NARANJA, 2, 8))
	t.set_stylebox("panel", "Panel", caja(PETROLEO, NARANJA, 2, 8))
	return t
