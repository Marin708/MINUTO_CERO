class_name Prop
extends Node2D
## Un objeto del mundo: mueble, riesgo del apartamento u objeto del exterior (adaptado de Prop de ECOS).
##
## Se dibuja con el recorte de su hoja (Assets/Mundo/muebles.png, riesgos.png o exterior.png), apoyado por la
## base en la posición del nodo (así el y-sort lo ordena bien con Sami). El origen está en la base. Tiene una
## colisión pequeña solo en la base. Si `interactuable` es verdadero, Sami lo puede usar con E (emite `interactuado`).
## Los riesgos tienen dos estados: fila 1 = con riesgo y fila 2 = asegurado (`asegurar()` cambia el cuadro).

signal interactuado(prop: Prop)

const TAMANO_CUADRO := 128
## Punto de apoyo dentro del cuadro: centrado y a 2 px del borde de abajo (las bases miden entre y=125 y y=126).
const APOYO_Y := 126.0
const HOJAS := {
	"muebles": "res://Assets/Mundo/muebles.png",
	"riesgos": "res://Assets/Mundo/riesgos.png",
	"exterior": "res://Assets/Mundo/exterior.png",
}
const RUTA_MEDIDAS := "res://Resources/Mundo/hojas_info.json"

## Cada tipo: "hoja", "cuadro" (columna, fila), "escala" (Sami mide unos 56 px de alto; puerta 80 a 90 px,
## mesa unos 60 px de ancho, árbol unos 130 px, carro unos 70 px de ancho) y "colision" (false = sin colisión).
const DATOS := {
	# muebles.png
	"mesa": {"hoja": "muebles", "cuadro": Vector2i(0, 0), "escala": 0.56, "colision": true},
	"sofa": {"hoja": "muebles", "cuadro": Vector2i(1, 0), "escala": 0.64, "colision": true},
	"cama": {"hoja": "muebles", "cuadro": Vector2i(2, 0), "escala": 0.67, "colision": true},
	"nevera": {"hoja": "muebles", "cuadro": Vector2i(3, 0), "escala": 0.58, "colision": true},
	"mueble_tv": {"hoja": "muebles", "cuadro": Vector2i(0, 1), "escala": 0.5, "colision": true},
	"estufa": {"hoja": "muebles", "cuadro": Vector2i(1, 1), "escala": 0.5, "colision": true},
	"armario": {"hoja": "muebles", "cuadro": Vector2i(2, 1), "escala": 0.62, "colision": true},
	"puerta_salida": {"hoja": "muebles", "cuadro": Vector2i(3, 1), "escala": 0.82, "colision": false},
	# riesgos.png (fila 1 = con riesgo, fila 2 = asegurado)
	"estante": {"hoja": "riesgos", "cuadro": Vector2i(0, 0), "escala": 0.62, "colision": true},
	"cuadro_cama": {"hoja": "riesgos", "cuadro": Vector2i(1, 0), "escala": 0.6, "colision": true},
	"gas_estufa": {"hoja": "riesgos", "cuadro": Vector2i(2, 0), "escala": 0.55, "colision": true},
	"repisa": {"hoja": "riesgos", "cuadro": Vector2i(3, 0), "escala": 0.5, "colision": true},
	# exterior.png
	"poste": {"hoja": "exterior", "cuadro": Vector2i(0, 0), "escala": 0.85, "colision": true},
	"escombros": {"hoja": "exterior", "cuadro": Vector2i(1, 0), "escala": 0.45, "colision": true},
	"carro": {"hoja": "exterior", "cuadro": Vector2i(2, 0), "escala": 0.65, "colision": true},
	"edificio": {"hoja": "exterior", "cuadro": Vector2i(3, 0), "escala": 1.2, "colision": true},
	"arbol": {"hoja": "exterior", "cuadro": Vector2i(0, 1), "escala": 1.13, "colision": true},
	"banca": {"hoja": "exterior", "cuadro": Vector2i(1, 1), "escala": 0.55, "colision": true},
	"carpa": {"hoja": "exterior", "cuadro": Vector2i(2, 1), "escala": 0.75, "colision": true},
	"barrera": {"hoja": "exterior", "cuadro": Vector2i(3, 1), "escala": 0.6, "colision": true},
}

## Tipos altos: sobresalen hacia arriba y pueden tapar a quien esté detrás (se vuelven semitransparentes).
const ALTOS: Array[String] = ["arbol", "poste", "edificio", "carpa", "armario", "estante", "nevera", "puerta_salida"]
## Tipos planos o bajos (no se ordenan con Sami: se dibujan en la capa de suelo, siempre debajo del jugador).
## Si uno se vuelve interactivo, pasa solo a la capa con y-sort (ningún interactivo cuelga de un padre sin y-sort).
const PLANOS: Array[String] = ["escombros"]
const ALPHA_TAPANDO := 0.45
const SEGUNDOS_FUNDIDO := 0.15
## Alto de la colisión de la base (px del mundo) y fracción del ancho visible que ocupa.
const ALTO_COLISION := 12.0
const FRACCION_ANCHO_COLISION := 0.8

static var _medidas: Dictionary = {}

@export_enum("mesa", "sofa", "cama", "nevera", "mueble_tv", "estufa", "armario", "puerta_salida",
		"estante", "cuadro_cama", "gas_estufa", "repisa",
		"poste", "escombros", "carro", "edificio", "arbol", "banca", "carpa", "barrera")
var tipo: String = "mesa"
## Escala del dibujo (y de su colisión). 0 = la escala por defecto del tipo (ver DATOS).
@export var escala: float = 0.0
## Si es verdadero, Sami lo puede usar con E.
@export var interactuable: bool = false
## Etiqueta que se muestra al interactuar o para depurar (por ejemplo "D1").
@export var etiqueta: String = ""
## Asegurado = fila 2 de la hoja (solo tiene sentido en los riesgos).
@export var asegurado: bool = false:
	set(valor):
		asegurado = valor
		_poner_cuadro()

var _factor := 1.0
var _tapando := false
var _tween_alpha: Tween
var _rect_local := Rect2()   # lo que se ve del sprite, relativo a la base y ya escalado

@onready var _sprite: Sprite2D = $Sprite
@onready var _cuerpo: StaticBody2D = $Cuerpo
@onready var _forma: CollisionShape2D = $Cuerpo/Forma
@onready var _zona: Area2D = $Zona
var _interrogacion: Label


func _ready() -> void:
	if not DATOS.has(tipo):
		push_error("Prop: el tipo '%s' no existe." % tipo)
		return
	var datos: Dictionary = DATOS[tipo]
	_factor = escala if escala > 0.0 else float(datos["escala"])
	var medida := _medida(tipo)

	# Dibujo: un recorte de la hoja, con la base del objeto sobre la posición del nodo y centrado en lo visible
	var atlas := AtlasTexture.new()
	atlas.atlas = load(HOJAS[datos["hoja"]])
	atlas.region = _region()
	_sprite.texture = atlas
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.centered = false
	var centro_x := (float(medida["x0"]) + float(medida["x1"]) + 1.0) / 2.0
	_sprite.offset = Vector2(-centro_x, -APOYO_Y)
	_sprite.scale = Vector2(_factor, _factor)
	_rect_local = Rect2(Vector2((float(medida["x0"]) - centro_x) * _factor, (float(medida["y0"]) - APOYO_Y) * _factor),
			Vector2(float(medida["ancho"]), float(medida["alto"])) * _factor)
	if ALTOS.has(tipo):
		add_to_group("props_altos")

	# Colisión pequeña solo en la base (capa 1 = mundo)
	if bool(datos["colision"]):
		var cuadrado := RectangleShape2D.new()
		cuadrado.size = Vector2(maxf(float(medida["ancho"]) * _factor * FRACCION_ANCHO_COLISION, 8.0), ALTO_COLISION)
		_forma.shape = cuadrado
		_forma.position = Vector2(0, -ALTO_COLISION / 2.0)
	else:
		_cuerpo.queue_free()

	# Zona de interacción (capa 2 = interactuable)
	if interactuable:
		var circulo := CircleShape2D.new()
		circulo.radius = maxf(float(medida["ancho"]) * _factor * 0.5, 24.0)
		$Zona/Forma.shape = circulo
		$Zona/Forma.position = Vector2(0, -8)
		add_to_group("interactuables")
		_crear_interrogacion()
	else:
		_zona.queue_free()


## El ícono «?» flota sobre los riesgos sin resolver y aparece cuando Sami está cerca.
func _crear_interrogacion() -> void:
	if etiqueta == "" or not etiqueta.begins_with("D") or tipo not in ["estante", "cuadro_cama", "gas_estufa", "repisa"]:
		return
	_interrogacion = EstiloUI.etiqueta("?", 18, EstiloUI.NARANJA)
	_interrogacion.add_theme_color_override("font_outline_color", Color("0f2d38"))
	_interrogacion.add_theme_constant_override("outline_size", 6)
	_interrogacion.z_index = 90
	_interrogacion.modulate.a = 0.0
	add_child(_interrogacion)
	_interrogacion.position = Vector2(-5, _rect_local.position.y - 22.0)


func _process(_delta: float) -> void:
	if _interrogacion == null:
		return
	var jugador := get_tree().get_first_node_in_group("player") as Node2D
	var cerca := jugador != null and jugador.global_position.distance_to(global_position) < 120.0 and not asegurado
	var objetivo := 1.0 if cerca else 0.0
	_interrogacion.modulate.a = move_toward(_interrogacion.modulate.a, objetivo, 0.1)
	_interrogacion.position.y = _rect_local.position.y - 22.0 + sin(Time.get_ticks_msec() / 1000.0 * 4.0) * 2.0


## true mientras Sami puede usarlo (los riesgos ya asegurados siguen respondiendo para repetir el mensaje).
func puede_interactuar() -> bool:
	return interactuable


## La llama Player al pulsar E.
func interactuar() -> void:
	interactuado.emit(self)


## Cambia al cuadro de «asegurado» (fila 2) con un pequeño destello.
func asegurar() -> void:
	asegurado = true
	if is_inside_tree() and _sprite != null:
		_sprite.modulate = Color(1.6, 1.6, 1.6)
		create_tween().tween_property(_sprite, "modulate", Color.WHITE, 0.4)


func _region() -> Rect2:
	var cuadro: Vector2i = DATOS[tipo]["cuadro"]
	var fila := cuadro.y + (1 if asegurado and DATOS[tipo]["hoja"] == "riesgos" else 0)
	return Rect2(Vector2(cuadro.x, fila) * TAMANO_CUADRO, Vector2(TAMANO_CUADRO, TAMANO_CUADRO))


func _poner_cuadro() -> void:
	if _sprite != null and _sprite.texture is AtlasTexture:
		(_sprite.texture as AtlasTexture).region = _region()


## El rectángulo (global) que ocupa lo visible del sprite.
func rect_visible() -> Rect2:
	return Rect2(global_position + _rect_local.position, _rect_local.size)


## Pone o quita la transparencia (45 % con un fundido de 0.15 s) según tape o no a alguien.
func poner_tapando(tapa: bool) -> void:
	if tapa == _tapando:
		return
	_tapando = tapa
	if _tween_alpha != null:
		_tween_alpha.kill()
	_tween_alpha = create_tween()
	_tween_alpha.tween_property(_sprite, "modulate:a", ALPHA_TAPANDO if tapa else 1.0, SEGUNDOS_FUNDIDO)


func esta_tapando() -> bool:
	return _tapando


## Lo que mide de verdad el dibujo del tipo dentro de su cuadro (de tools/medir_hojas.py).
static func _medida(p_tipo: String) -> Dictionary:
	if _medidas.is_empty():
		var datos: Variant = JSON.parse_string(FileAccess.get_file_as_string(RUTA_MEDIDAS))
		if typeof(datos) == TYPE_DICTIONARY:
			_medidas = datos
	var d: Dictionary = DATOS[p_tipo]
	var cuadro: Vector2i = d["cuadro"]
	var hoja: String = "Assets/Mundo/%s.png" % d["hoja"]
	var lista: Array = _medidas.get(hoja, [])
	var indice := cuadro.y * 4 + cuadro.x
	if indice < lista.size():
		return lista[indice]
	return {"x0": 0, "x1": 127, "y0": 0, "y1": 127, "ancho": 128, "alto": 128}
