class_name EstiloUI
extends RefCounted
## Estilo común de los menús (libreta y pausa): el mismo del cuadro de diálogo, con la paleta azul petróleo y
## dorada y la fuente Pixelify Sans. Todo se crea por código, sin imágenes.

const RUTA_FUENTE := "res://Assets/PixelifySans-VariableFont_wght.ttf"
const PETROLEO_OSCURO := Color("0f2d38")
const PETROLEO := Color("14414f")
const PETROLEO_CLARO := Color("1d5566")
const PETROLEO_PULSADO := Color("2a6c80")
const NARANJA := Color("ff8a2a")
const CREMA := Color("fff4dc")
const GRIS := Color("9db0b8")

static var _fuente: Font
static var _tema: Theme


static func fuente() -> Font:
	if _fuente == null and ResourceLoader.exists(RUTA_FUENTE):
		_fuente = load(RUTA_FUENTE)
	return _fuente


## Una caja con borde (fondo, borde, grosor del borde, margen interior y esquinas redondeadas).
static func caja(fondo: Color, borde: Color, grosor: int = 2, margen: int = 8, radio: int = 4) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fondo
	s.border_color = borde
	s.set_border_width_all(grosor)
	s.set_corner_radius_all(radio)
	s.set_content_margin_all(margen)
	return s


## Una etiqueta con la fuente del juego (no recibe el ratón).
static func etiqueta(texto: String, tamano: int = 12, color: Color = CREMA) -> Label:
	var e := Label.new()
	e.text = texto
	e.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if fuente() != null:
		e.add_theme_font_override("font", fuente())
	e.add_theme_font_size_override("font_size", tamano)
	e.add_theme_color_override("font_color", color)
	return e


## Un cuadradito liso de un color (para el control deslizante y la casilla).
static func _cuadro(ancho: int, alto: int, color: Color, borde: Color = Color(0, 0, 0, 0)) -> ImageTexture:
	var imagen := Image.create(ancho, alto, false, Image.FORMAT_RGBA8)
	imagen.fill(borde if borde.a > 0.0 else color)
	if borde.a > 0.0:
		for y in range(1, alto - 1):
			for x in range(1, ancho - 1):
				imagen.set_pixel(x, y, color)
	return ImageTexture.create_from_image(imagen)


## Tema para botones, controles deslizantes y casillas (foco bien visible: borde dorado).
static func tema() -> Theme:
	if _tema != null:
		return _tema
	var t := Theme.new()
	if fuente() != null:
		for tipo in ["Label", "Button", "CheckButton"]:
			t.set_font("font", tipo, fuente())
	for tipo in ["Label", "Button", "CheckButton"]:
		t.set_font_size("font_size", tipo, 14)
	t.set_color("font_color", "Label", CREMA)
	for tipo in ["Button", "CheckButton"]:
		t.set_color("font_color", tipo, Color("d9cfe8"))
		t.set_color("font_hover_color", tipo, NARANJA)
		t.set_color("font_focus_color", tipo, NARANJA)
		t.set_color("font_pressed_color", tipo, NARANJA)
		t.set_color("font_disabled_color", tipo, Color("6a6485"))
	t.set_stylebox("normal", "Button", caja(PETROLEO, PETROLEO, 1, 5))
	t.set_stylebox("hover", "Button", caja(PETROLEO_CLARO, NARANJA, 2, 5))
	t.set_stylebox("pressed", "Button", caja(PETROLEO_PULSADO, NARANJA, 2, 5))
	t.set_stylebox("focus", "Button", caja(PETROLEO_CLARO, NARANJA, 2, 5))
	t.set_stylebox("disabled", "Button", caja(Color("24203a"), Color("24203a"), 1, 5))
	# Casilla (interruptor)
	for estilo in ["normal", "hover", "pressed", "hover_pressed"]:
		t.set_stylebox(estilo, "CheckButton", caja(PETROLEO if estilo == "normal" else PETROLEO_CLARO, PETROLEO if estilo == "normal" else NARANJA, 1 if estilo == "normal" else 2, 5))
	t.set_stylebox("focus", "CheckButton", caja(PETROLEO_CLARO, NARANJA, 2, 5))
	var apagado := _cuadro(14, 14, PETROLEO_OSCURO, NARANJA)
	var encendido := _cuadro(14, 14, NARANJA, NARANJA)
	t.set_icon("unchecked", "CheckButton", apagado)
	t.set_icon("checked", "CheckButton", encendido)
	t.set_icon("unchecked_disabled", "CheckButton", apagado)
	t.set_icon("checked_disabled", "CheckButton", encendido)
	# Control deslizante
	var pista := caja(PETROLEO_OSCURO, PETROLEO_CLARO, 1, 0, 2)
	pista.content_margin_top = 3
	pista.content_margin_bottom = 3
	t.set_stylebox("slider", "HSlider", pista)
	t.set_stylebox("grabber_area", "HSlider", caja(NARANJA.darkened(0.25), NARANJA.darkened(0.25), 0, 0, 2))
	t.set_stylebox("grabber_area_highlight", "HSlider", caja(NARANJA, NARANJA, 0, 0, 2))
	t.set_stylebox("focus", "HSlider", caja(Color(0, 0, 0, 0), NARANJA, 1, 2, 2))
	var asa := _cuadro(8, 16, NARANJA)
	t.set_icon("grabber", "HSlider", asa)
	t.set_icon("grabber_highlight", "HSlider", asa)
	t.set_icon("grabber_disabled", "HSlider", asa)
	_tema = t
	return t
