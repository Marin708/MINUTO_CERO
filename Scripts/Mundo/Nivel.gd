class_name Nivel
extends Node2D
## Base de los tres niveles (adaptada de Mundo de ECOS). Construye el mapa de texto, coloca los objetos y los
## personajes en sus marcadores (Marker2D con metadatos clase, tipo, etiqueta y radio), pone a Sami, la cámara, el
## HUD y la transparencia de los props altos. Cada nivel (Nivel1, Nivel2, Nivel3) añade sus tareas.
##
## Marcadores: clase "prop" (Prop), "npc" (Npc), "zona" (círculo con `radio` en píxeles) y "spawn" (dónde empieza
## Sami). Su posición es el suelo, la base (los pies) del objeto, así que el y-sort los ordena bien.

const ESCENA_PLAYER := preload("res://Scenes/Personajes/Player.tscn")
const ESCENA_PROP := preload("res://Scenes/Objetos/Prop.tscn")
const ESCENA_NPC := preload("res://Scenes/Personajes/Npc.tscn")

## Número del nivel (1, 2 o 3); lo fija cada subclase.
var numero := 1
## Archivos de mapa de Resources/Mundo (la capa de daños es opcional).
var archivo_mapa := "res://Resources/Mundo/apartamento.txt"
var archivo_danos := ""
var titulo_hud := ""

var jugador: Player
var hud: HUD
var props: Array[Prop] = []
var npcs: Array[Npc] = []
var items: Array[ObjetoSuelo] = []
var zonas: Dictionary = {}   # nombre -> {"pos": Vector2, "radio": float, "tipo": String}
var tamano_mapa := Vector2.ZERO
## true mientras una decisión o un diálogo tiene ocupado al jugador (para no abrir dos a la vez).
var ocupado := false

var _temblor := 0.0
var _temblor_total := 0.0
var _temblor_intensidad := 0.0
var _temblor_decae := true
var _capa_polvo: CanvasLayer

@onready var suelo: Node2D = $Suelo
@onready var objetos: Node2D = $Objetos
@onready var marcadores: Node2D = $Marcadores
## Capa de objetos planos o de suelo (escombros bajos, tapetes, charcos, manchas, cintas): SIN y-sort, justo encima del
## mapa y siempre debajo del jugador. Los altos e interactivos viven en `objetos` (con y_sort_enabled).
var suelo_objetos: Node2D


func _ready() -> void:
	suelo_objetos = Node2D.new()
	suelo_objetos.name = "SueloObjetos"
	suelo_objetos.y_sort_enabled = false
	add_child(suelo_objetos)
	move_child(suelo_objetos, objetos.get_index())   # después de Suelo y antes de Objetos: se dibuja debajo de todo lo alto
	_construir_mapa()
	_colocar_marcadores()
	_colocar_jugador()
	var oclusion := OclusionProps.new()
	add_child(oclusion)
	hud = HUD.new()
	add_child(hud)
	Estado.nivel_actual = numero
	Audio.ambientar_nivel(numero)
	_preparar()


## Cada nivel lo reescribe: crea sus tareas, conecta sus señales, etc.
func _preparar() -> void:
	pass


# --- Mapa ---

func _construir_mapa() -> void:
	var filas := ConjuntoTiles.leer_mapa(archivo_mapa)
	tamano_mapa = ConjuntoTiles.tamano(filas)
	suelo.add_child(ConjuntoTiles.pintar(filas, ConjuntoTiles.TILE_DE, true))
	if archivo_danos != "":
		var danos := ConjuntoTiles.pintar(ConjuntoTiles.leer_mapa(archivo_danos), ConjuntoTiles.TILE_DANOS, false)
		suelo.add_child(danos)


func _colocar_marcadores() -> void:
	for m in marcadores.get_children():
		if not (m is Marker2D):
			continue
		var clase := str(m.get_meta("clase", ""))
		var tipo := str(m.get_meta("tipo", ""))
		var etiqueta := str(m.get_meta("etiqueta", ""))
		match clase:
			"prop":
				var p: Prop = ESCENA_PROP.instantiate()
				p.tipo = tipo
				p.etiqueta = etiqueta
				p.interactuable = etiqueta != "" and _es_interactuable(etiqueta)
				p.position = m.position
				p.name = m.name
				# Plano y sin interacción: a la capa de suelo. Todo lo demás, dentro del nodo con y-sort.
				(suelo_objetos if (p.tipo in Prop.PLANOS and not p.interactuable) else objetos).add_child(p)
				props.append(p)
				p.interactuado.connect(_on_prop)
			"npc":
				var n: Npc = ESCENA_NPC.instantiate()
				n.personaje = tipo
				n.position = m.position
				n.name = m.name
				objetos.add_child(n)
				npcs.append(n)
				n.interactuado.connect(_on_npc)
			"item":
				if _usa_items():
					var o := ObjetoSuelo.new()
					o.tipo = tipo
					o.position = m.position
					o.name = m.name
					objetos.add_child(o)
					items.append(o)
					o.interactuado.connect(_on_item)
			"zona":
				zonas[m.name] = {"pos": m.position, "radio": float(m.get_meta("radio", 48.0)), "tipo": tipo, "etiqueta": etiqueta}


func _colocar_jugador() -> void:
	jugador = ESCENA_PLAYER.instantiate()
	var spawn := marcadores.get_node_or_null("Spawn") as Marker2D
	jugador.position = spawn.position if spawn != null else Vector2(64, 64)
	objetos.add_child(jugador)
	jugador.establecer_limites(Rect2(Vector2.ZERO, tamano_mapa))


# --- Búsquedas ---

func prop_con_etiqueta(etiqueta: String) -> Prop:
	for p in props:
		if p.etiqueta == etiqueta:
			return p
	return null


func prop_de_tipo(tipo: String) -> Prop:
	for p in props:
		if p.tipo == tipo:
			return p
	return null


func npc_de(personaje: String) -> Npc:
	for n in npcs:
		if n.personaje == personaje:
			return n
	return null


func pos_zona(nombre: String) -> Vector2:
	return zonas[nombre]["pos"] if zonas.has(nombre) else Vector2.ZERO


## Distancia de Sami (sus pies) al centro de una zona.
func distancia_a(nombre: String) -> float:
	if not zonas.has(nombre) or jugador == null:
		return INF
	return jugador.global_position.distance_to(zonas[nombre]["pos"])


## true si Sami está dentro del círculo de la zona.
func en_zona(nombre: String) -> bool:
	return zonas.has(nombre) and distancia_a(nombre) <= float(zonas[nombre]["radio"])


# --- Reacciones (las reescribe cada nivel) ---

## ¿El objeto con esta etiqueta se puede usar en este nivel? (el nivel 2 lo reescribe)
func _es_interactuable(_etiqueta: String) -> bool:
	return true


func _on_prop(_prop: Prop) -> void:
	pass


func _on_npc(_npc: Npc) -> void:
	pass


func _on_item(_item: ObjetoSuelo) -> void:
	pass


## ¿Este nivel pone los objetos del piso (zapatos, mochila, linterna)?
func _usa_items() -> bool:
	return false


# --- Diálogos y decisiones sin chocar entre sí ---

## Muestra un diálogo con Sami bloqueado; devuelve el índice de la opción elegida.
func decir(quien: String, texto: Variant, opciones: Array = []) -> int:
	ocupado = true
	var respuesta: int = await Dialogo.mostrar_texto(quien, texto, opciones)
	ocupado = false
	return respuesta


## Resuelve una decisión (D1 a D15) y marca la tarea en el HUD si fue segura.
func decidir(id: String) -> bool:
	if ocupado:
		return false
	ocupado = true
	var lograda: bool = await Decisiones.resolver(get_tree(), id)
	ocupado = false
	if lograda:
		hud.marcar(id)
	return lograda


# --- Temblor y polvo ---

## Temblor de cámara: `intensidad` en píxeles durante `segundos`.
func temblar(intensidad: float, segundos: float, decae: bool = true) -> void:
	_temblor_decae = decae
	_temblor_intensidad = intensidad
	_temblor = segundos
	_temblor_total = segundos


func _process(delta: float) -> void:
	if jugador == null:
		return
	if _temblor > 0.0:
		_temblor = maxf(_temblor - delta, 0.0)
		var fuerza := _temblor_intensidad * ((_temblor / _temblor_total if _temblor_total > 0.0 else 0.0) if _temblor_decae else 1.0)
		jugador.camara.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * fuerza
		if _temblor <= 0.0:
			jugador.camara.offset = Vector2.ZERO
	_tick(delta)


## Se ejecuta cada fotograma (los niveles lo usan para sus mecánicas).
func _tick(_delta: float) -> void:
	pass


## Enciende o apaga el polvo que cae del techo (en el nivel 2 y en la réplica).
func polvo(activo: bool) -> void:
	if activo and _capa_polvo == null:
		_capa_polvo = CanvasLayer.new()
		_capa_polvo.layer = 4
		add_child(_capa_polvo)
		var p := CPUParticles2D.new()
		p.position = Vector2(320, -6)
		p.amount = 60
		p.lifetime = 2.4
		p.preprocess = 1.0
		p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		p.emission_rect_extents = Vector2(330, 2)
		p.direction = Vector2(0, 1)
		p.spread = 12.0
		p.gravity = Vector2(0, 40)
		p.initial_velocity_min = 20.0
		p.initial_velocity_max = 60.0
		p.scale_amount_min = 1.0
		p.scale_amount_max = 2.5
		p.color = Color(1.0, 0.96, 0.86, 0.5)
		_capa_polvo.add_child(p)
	elif not activo and _capa_polvo != null:
		_capa_polvo.queue_free()
		_capa_polvo = null


## Un objeto que cae desde arriba hasta `destino` (global) y suena al chocar.
func objeto_cae(destino: Vector2, sonido: String = "objeto_cae", color: Color = Color("c99c68")) -> void:
	var cuadro := Polygon2D.new()
	cuadro.polygon = PackedVector2Array([Vector2(-4, -8), Vector2(4, -8), Vector2(4, 0), Vector2(-4, 0)])
	cuadro.color = color
	cuadro.position = destino + Vector2(0, -150)
	objetos.add_child(cuadro)
	var t := create_tween()
	t.tween_property(cuadro, "position:y", destino.y, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(func() -> void:
		Audio.efecto(sonido)
		temblar(1.5, 0.15))
	t.tween_interval(6.0)
	t.tween_callback(cuadro.queue_free)


func esperar(segundos: float) -> void:
	await get_tree().create_timer(segundos).timeout


## Termina el nivel: desbloquea la tarjeta de memoria y pasa al siguiente (o al final).
func terminar_nivel() -> void:
	var tarjeta := Estado.desbloquear_tarjeta_de_nivel(numero)
	if tarjeta != "":
		Notificacion.mostrar("Memoria de 1999", "Nueva tarjeta en tu libreta (TAB).")
	await esperar(0.8)
	Flujo.terminar_nivel(numero)
