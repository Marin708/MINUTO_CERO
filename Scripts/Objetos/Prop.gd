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
	# La puerta de salida y el ascensor (con su cartel «No usar») son un solo dibujo empotrado en la pared: los tiles de pared ya son sólidos
	"puerta_salida": {"hoja": "muebles", "cuadro": Vector2i(3, 1), "escala": 0.82, "colision": false},
	# riesgos.png (fila 1 = con riesgo, fila 2 = asegurado)
	"estante": {"hoja": "riesgos", "cuadro": Vector2i(0, 0), "escala": 0.62, "colision": true},
	"cuadro_cama": {"hoja": "riesgos", "cuadro": Vector2i(1, 0), "escala": 0.6, "colision": true},
	"gas_estufa": {"hoja": "riesgos", "cuadro": Vector2i(2, 0), "escala": 0.55, "colision": true},
	"repisa": {"hoja": "riesgos", "cuadro": Vector2i(3, 0), "escala": 0.5, "colision": true},
	# exterior.png
	"poste": {"hoja": "exterior", "cuadro": Vector2i(0, 0), "escala": 0.85, "colision": true},
	"escombros": {"hoja": "exterior", "cuadro": Vector2i(1, 0), "escala": 0.45, "colision": false},   # plano: sin colisión, va en SueloObjetos
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
## Colisión de la base: (fracción del ANCHO visible, fracción del ALTO visible) que ocupa, siempre pegada a la base.
## Por defecto cubre todo el ancho y el 38 % inferior (entre 30 y 45 %) para que Sami no pueda ponerse encima del mueble.
const COLISION_BASE := Vector2(1.0, 0.38)
const COLISION_TIPO := {
	"nevera": Vector2(1.0, 0.35), "armario": Vector2(1.0, 0.35), "estante": Vector2(1.0, 0.35), "repisa": Vector2(1.0, 0.35),
	"carpa": Vector2(1.0, 0.35), "edificio": Vector2(1.0, 0.30),
	"cama": Vector2(1.0, 0.40), "sofa": Vector2(1.0, 0.40), "carro": Vector2(1.0, 0.40), "banca": Vector2(1.0, 0.40),
	"gas_estufa": Vector2(1.0, 0.40), "barrera": Vector2(1.0, 0.40),
	# solo el tronco y el pie del poste estorban (la copa y el cable quedan por encima de la cabeza de Sami)
	"arbol": Vector2(0.22, 0.0), "poste": Vector2(0.30, 0.0),
}
## Alto fijo (px) de la colisión de los tipos que solo bloquean por el pie.
const ALTO_COLISION_FIJO := {"arbol": 14.0, "poste": 14.0}
## La mesa solo es sólida en las patas (ancho en px) y en el fondo (grosor en px): por delante queda la zona segura.
const ANCHO_PATA := 8.0
const GROSOR_FONDO := 4.0
## Cuánto sobresale (px) la zona de interacción del borde de la colisión por cada lado: así se puede usar desde cualquier lado.
const MARGEN_ZONA := 14.0
## Capa de física 4 = «zona segura» (nadie la detecta salvo el nivel, que mira el grupo `zonas_seguras`).
const CAPA_ZONA_SEGURA := 8

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

	# Colisión en la base (capa 1 = mundo): todo el ancho visible y entre 30 y 45 % del alto, sin huecos en los bordes
	var ancho_vis := float(medida["ancho"]) * _factor
	var alto_vis := float(medida["alto"]) * _factor
	var cfg: Vector2 = COLISION_TIPO.get(tipo, COLISION_BASE)
	var col_ancho := maxf(ancho_vis * cfg.x, 8.0)
	var col_alto: float = float(ALTO_COLISION_FIJO[tipo]) if ALTO_COLISION_FIJO.has(tipo) else alto_vis * cfg.y
	if bool(datos["colision"]):
		if tipo == "mesa":
			_colision_mesa(col_ancho, col_alto)
		else:
			_poner_forma(_forma, Vector2(col_ancho, col_alto), Vector2(0, -col_alto / 2.0))
	else:
		_cuerpo.queue_free()

	# Zona de interacción (capa 2 = interactuable): un rectángulo MÁS GRANDE que la colisión, para usarlo desde cualquier lado
	if interactuable:
		var rect := RectangleShape2D.new()
		rect.size = Vector2(col_ancho + 2.0 * MARGEN_ZONA, col_alto + 2.0 * MARGEN_ZONA)
		$Zona/Forma.shape = rect
		$Zona/Forma.position = Vector2(0, -col_alto / 2.0)
		add_to_group("interactuables")
		_crear_interrogacion()
	else:
		_zona.queue_free()


func _poner_forma(nodo: CollisionShape2D, tamano: Vector2, centro: Vector2) -> void:
	var cuadrado := RectangleShape2D.new()
	cuadrado.size = tamano
	nodo.shape = cuadrado
	nodo.position = centro


## Mesa del comedor: dos patas y un fondo sólidos; por delante queda libre el espacio de abajo (la zona segura donde Sami se
## agacha y mantiene E). Las patas y el fondo no dejan huecos por los que se cuele Sami hacia atrás.
func _colision_mesa(ancho: float, alto: float) -> void:
	var pata_x := ancho / 2.0 - ANCHO_PATA / 2.0
	_poner_forma(_forma, Vector2(ANCHO_PATA, alto), Vector2(-pata_x, -alto / 2.0))
	var pata_der := CollisionShape2D.new()
	pata_der.name = "PataDerecha"
	_cuerpo.add_child(pata_der)
	_poner_forma(pata_der, Vector2(ANCHO_PATA, alto), Vector2(pata_x, -alto / 2.0))
	var fondo := CollisionShape2D.new()
	fondo.name = "Fondo"
	_cuerpo.add_child(fondo)
	_poner_forma(fondo, Vector2(ancho, GROSOR_FONDO), Vector2(0, -alto + GROSOR_FONDO / 2.0))
	# Zona segura: el hueco entre las patas, por delante del fondo y un poco más allá de la base (se entra por el frente)
	var segura := Area2D.new()
	segura.name = "ZonaSegura"
	segura.collision_layer = CAPA_ZONA_SEGURA
	segura.collision_mask = 0
	var forma := CollisionShape2D.new()
	segura.add_child(forma)
	add_child(segura)
	var hueco := Vector2(ancho - 2.0 * ANCHO_PATA, alto - GROSOR_FONDO + 8.0)
	_poner_forma(forma, hueco, Vector2(0, -alto + GROSOR_FONDO + hueco.y / 2.0))
	segura.add_to_group("zonas_seguras")


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


## El verbo que se muestra junto a la tecla E.
func verbo() -> String:
	return "Abrir" if tipo in ["puerta_salida", "armario"] else "Revisar"


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
