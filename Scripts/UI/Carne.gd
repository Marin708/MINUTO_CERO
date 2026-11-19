class_name Carne
extends Control
## El carné de brigadista: la identidad visual del jugador. Papel crema, cabecera azul petróleo con franjas, foto de Sami
## (retratos.png a 1x), rol «Brigadista voluntario/a», nivel y un espacio para el sello. No lleva nombre: la partida es anónima.
## Se usa en la inscripción (nivel «pendiente»), en los resultados (carné actualizado) y en la galería de estilo.
##
##   var c := Carne.new(); padre.add_child(c); c.poner_nivel("pendiente"); c.sellar("BRIGADISTA")

const ANCHO := 330.0
const ALTO := 170.0

var _foto: TextureRect
var _valor_nivel: Label
var _valor_numero: Label
var _zona_sello: Control
var _cabecera: Label
# Lo que se pida antes de que el carné esté en la escena se aplica al construirse
var _nivel_pendiente := "pendiente"
var _foto_pendiente := "sami_neutral"
var _cabecera_pendiente := ""


func _init() -> void:
	custom_minimum_size = Vector2(ANCHO, ALTO)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", EstiloUI.caja(EstiloUI.PAPEL, EstiloUI.TINTA, 2, 0))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 0)
	panel.add_child(columna)
	# Cabecera azul petróleo con la brigada y una cinta de franjas
	var banda := PanelContainer.new()
	banda.add_theme_stylebox_override("panel", EstiloUI.caja(EstiloUI.PETROLEO, EstiloUI.PETROLEO, 0, 5))
	columna.add_child(banda)
	_cabecera = EstiloUI.titulo(_cabecera_pendiente if _cabecera_pendiente != "" else "BRIGADA COMUNITARIA · VILLA CAFETAL", 8, EstiloUI.CREMA)
	banda.add_child(_cabecera)
	var franjas := Franjas.new()
	franjas.custom_minimum_size = Vector2(0, 5)
	columna.add_child(franjas)
	var margen := MarginContainer.new()
	for lado in ["left", "right", "top", "bottom"]:
		margen.add_theme_constant_override("margin_" + lado, 8)
	margen.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columna.add_child(margen)
	var cuerpo := HBoxContainer.new()
	cuerpo.add_theme_constant_override("separation", 10)
	margen.add_child(cuerpo)
	# La foto, con marco
	var marco := PanelContainer.new()
	marco.add_theme_stylebox_override("panel", EstiloUI.caja(EstiloUI.CREMA, EstiloUI.TINTA, 2, 2))
	marco.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	cuerpo.add_child(marco)
	_foto = TextureRect.new()
	_foto.custom_minimum_size = Vector2(96, 96)
	_foto.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_foto.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	_foto.texture = Retratos.obtener(_foto_pendiente)
	marco.add_child(_foto)
	# Los datos
	var datos := VBoxContainer.new()
	datos.add_theme_constant_override("separation", 3)
	datos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cuerpo.add_child(datos)
	datos.add_child(EstiloUI.titulo("CARNÉ DE BRIGADISTA", 10, EstiloUI.TINTA))
	_fila(datos, "Rol", "Brigadista voluntario/a")
	_valor_nivel = _fila(datos, "Nivel", _nivel_pendiente)
	_valor_numero = _fila(datos, "N.º", Evaluacion.participante_id if Evaluacion.participante_id != "" else "sin asignar")
	_zona_sello = Control.new()
	_zona_sello.custom_minimum_size = Vector2(0, 44)
	_zona_sello.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_zona_sello.mouse_filter = Control.MOUSE_FILTER_IGNORE
	datos.add_child(_zona_sello)
	# Espacio para el sello: un recuadro de rayas hasta que se estampa
	_zona_sello.draw.connect(_dibujar_espacio_sello)


func _fila(padre: Control, rotulo: String, valor: String) -> Label:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 6)
	var r := EstiloUI.etiqueta(rotulo + ":", 12, EstiloUI.TINTA_SUAVE)
	r.custom_minimum_size = Vector2(36, 0)
	fila.add_child(r)
	var v := EstiloUI.etiqueta(valor, 12, EstiloUI.TINTA)
	fila.add_child(v)
	padre.add_child(fila)
	return v


func _dibujar_espacio_sello() -> void:
	if _zona_sello.get_child_count() > 0:
		return
	var r := Rect2(Vector2(2, 2), Vector2(_zona_sello.size.x - 4.0, _zona_sello.size.y - 4.0))
	var x := r.position.x
	while x < r.end.x:
		_zona_sello.draw_line(Vector2(x, r.position.y), Vector2(minf(x + 5, r.end.x), r.position.y), EstiloUI.TINTA_SUAVE, 1.0)
		_zona_sello.draw_line(Vector2(x, r.end.y), Vector2(minf(x + 5, r.end.x), r.end.y), EstiloUI.TINTA_SUAVE, 1.0)
		x += 9.0
	var y := r.position.y
	while y < r.end.y:
		_zona_sello.draw_line(Vector2(r.position.x, y), Vector2(r.position.x, minf(y + 5, r.end.y)), EstiloUI.TINTA_SUAVE, 1.0)
		_zona_sello.draw_line(Vector2(r.end.x, y), Vector2(r.end.x, minf(y + 5, r.end.y)), EstiloUI.TINTA_SUAVE, 1.0)
		y += 9.0
	var f := EstiloUI.fuente_titulo()
	if f != null:
		_zona_sello.draw_string(f, Vector2(r.position.x + 6, r.position.y + r.size.y / 2.0 + 3.0), "SELLO", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, EstiloUI.TINTA_SUAVE)


## Cambia la foto: «sami_neutral» o «sami_preocupado» (los nombres de Retratos).
func poner_foto(nombre: String) -> void:
	_foto_pendiente = nombre
	if _foto != null:
		_foto.texture = Retratos.obtener(nombre)


func poner_nivel(texto: String) -> void:
	_nivel_pendiente = texto
	if _valor_nivel != null:
		_valor_nivel.text = texto


func poner_cabecera(texto: String) -> void:
	_cabecera_pendiente = texto
	if _cabecera != null:
		_cabecera.text = texto


## Estampa un sello sobre el espacio del carné.
func sellar(texto: String, color: Color = EstiloUI.ROJO_TINTA) -> Sello:
	var s := Sello.crear(texto, color, 10, -0.12)
	_zona_sello.add_child(s)
	s.position = Vector2(2, (_zona_sello.size.y - s.size.y) / 2.0)
	_zona_sello.queue_redraw()
	s.estampar()
	return s
