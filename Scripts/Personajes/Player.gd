class_name Player
extends CharacterBody2D
## Sami, el jugador de MINUTO CERO: movimiento suave en 8 direcciones, interacción con objetos
## cercanos, sombra, burbuja de ayuda "E" y cámara.
##
## El origen del nodo está en los PIES del personaje (así funciona bien el y-sort).

## Se emite cuando cambia el objeto con el que se puede interactuar (puede ser null).
signal interactuable_cambiado(nodo: Node)

const RUTA_FUENTE := "res://Assets/PixelifySans-VariableFont_wght.ttf"

@export_group("Movimiento")
## Velocidad máxima en píxeles por segundo.
@export var velocidad: float = 88.0
## Qué tan rápido alcanza la velocidad máxima (px/s²).
@export var aceleracion: float = 600.0
## Qué tan rápido se frena al soltar las teclas (px/s²).
@export var friccion: float = 800.0

@export_group("Animación")
## Altura máxima del rebote al caminar (px).
@export var rebote_altura: float = 1.5
## Rebotes por segundo (uno por paso; la animación de caminar va a 8 FPS).
@export var rebote_velocidad: float = 4.0

@export_group("Ayuda")
## Dónde flota la burbuja "E" respecto al objeto activo.
@export var desplazamiento_ayuda: Vector2 = Vector2(0, -44)

## Última dirección de movimiento, normalizada (hacia dónde mira Sami).
var facing: Vector2 = Vector2.DOWN

## true si el jugador puede moverse e interactuar. Se puede asignar directamente
## (can_move = false) o con bloquear() / liberar(). También se bloquea solo mientras hay un diálogo.
var can_move: bool:
	get:
		return not _bloqueado and not _dialogo_abierto
	set(valor):
		_bloqueado = not valor

## Objetos interactuables que están dentro de la zona.
var interactuables: Array[Node] = []
## El objeto con el que se interactuaría ahora (el más cercano que lo permita).
var activo: Node = null

var _cuadro_paso := -1   # último cuadro de caminar visto (para sonar un paso por pisada)
var _bloqueado := false
## Indicador de la tecla E (con el verbo de la acción) que flota sobre lo que se puede usar.
var indicador: IndicadorTecla
## Mantener E: de 0 a 1 muestra el anillo de avance sobre Sami (-1 = no hay nada que mantener). Lo pone el nivel.
var progreso_mantener := -1.0:
	set(v):
		_progreso = v
		_vigencia = 0.25   # si el nivel deja de ponerlo, el anillo desaparece solo
	get:
		return _progreso if _vigencia > 0.0 else -1.0
var _progreso := -1.0
var _vigencia := 0.0
var _dialogo_abierto := false
var _tiempo_rebote := 0.0


@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var zona: Area2D = $ZonaInteraccion
@onready var camara: Camera2D = $Camera2D
@onready var burbuja: Node2D = $BurbujaAyuda
@onready var panel_burbuja: PanelContainer = $BurbujaAyuda/Panel
@onready var etiqueta_burbuja: Label = $BurbujaAyuda/Panel/Etiqueta


func _ready() -> void:
	add_to_group("player")
	# Solo el nodo Objetos del nivel ordena en Y: el jugador es un elemento más (sus hijos, como
	# el sprite que está 29 px más arriba de los pies, no deben ordenarse por su cuenta).
	y_sort_enabled = false
	_aplicar_estilo_burbuja()
	burbuja.hide()

	zona.area_entered.connect(_on_zona_area_entrada)
	zona.area_exited.connect(_on_zona_area_salida)
	zona.body_entered.connect(_on_zona_cuerpo_entrada)
	zona.body_exited.connect(_on_zona_cuerpo_salida)

	# Se bloquea mientras haya un diálogo abierto
	Dialogo.dialogo_abierto.connect(func() -> void: _dialogo_abierto = true)
	Dialogo.dialogo_cerrado.connect(func() -> void: _dialogo_abierto = false)
	_dialogo_abierto = Dialogo.hay_dialogo()

	_actualizar_animacion(false)


func _physics_process(delta: float) -> void:
	if can_move:
		var direccion := Input.get_vector("IZQUIERDA", "DERECHA", "ARRIBA", "ABAJO")
		if direccion != Vector2.ZERO:
			facing = direccion.normalized()
		# Aceleración suave al moverse, fricción suave al soltar
		var cambio := aceleracion if direccion != Vector2.ZERO else friccion
		velocity = velocity.move_toward(direccion * velocidad, cambio * delta)
	else:
		velocity = Vector2.ZERO

	move_and_slide()
	_actualizar_animacion(velocity.length() > 5.0, delta)
	_actualizar_activo()


func _process(delta: float) -> void:
	_vigencia = maxf(_vigencia - delta, 0.0)
	_actualizar_burbuja()


func _unhandled_input(evento: InputEvent) -> void:
	if not can_move:
		return
	# Con _unhandled_input, el diálogo puede "comerse" la tecla sin que el jugador la use también
	if evento.is_action_pressed("INTERACTUAR") and activo != null:
		get_viewport().set_input_as_handled()
		activo.interactuar()


# --- Colisiones ---

## Si Sami aparece dentro de una colisión (un mueble o una pared), lo lleva al punto libre más cercano (búsqueda en espiral,
## de 4 en 4 px). Espera dos fotogramas de física para que los cuerpos del nivel ya existan en el espacio.
func sacar_de_colision() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not is_inside_tree() or not _choca_en(global_position):
		return
	for radio in range(4, 161, 4):
		var pasos := maxi(8, radio / 2)
		for i in pasos:
			var punto := global_position + Vector2.from_angle(TAU * float(i) / pasos) * radio
			if not _choca_en(punto):
				global_position = punto
				return


## ¿Chocaría la forma de los pies de Sami en este punto del mundo?
func _choca_en(punto: Vector2) -> bool:
	var parametros := PhysicsTestMotionParameters2D.new()
	parametros.from = Transform2D(0.0, punto)
	parametros.motion = Vector2.ZERO
	return PhysicsServer2D.body_test_motion(get_rid(), parametros)


# --- Bloqueo ---

## Impide que el jugador se mueva e interactúe (por ejemplo, en una cinemática).
func bloquear() -> void:
	_bloqueado = true


## Devuelve el control al jugador. No lo libera si todavía hay un diálogo abierto.
func liberar() -> void:
	_bloqueado = false


# --- Cámara ---

## Limita hasta dónde puede mostrar la cámara (usar con el rectángulo del mapa, en píxeles).
func establecer_limites(rect: Rect2) -> void:
	camara.limit_left = int(rect.position.x)
	camara.limit_top = int(rect.position.y)
	camara.limit_right = int(rect.end.x)
	camara.limit_bottom = int(rect.end.y)


# --- Animación ---

## Nombre de la animación según hacia dónde mira el jugador.
func _animacion_actual() -> StringName:
	if absf(facing.x) >= absf(facing.y):
		return &"walk_right" if facing.x > 0.0 else &"walk_left"
	return &"walk_down" if facing.y > 0.0 else &"walk_up"


func _actualizar_animacion(caminando: bool, delta: float = 0.0) -> void:
	var anim := _animacion_actual()
	if sprite.animation != anim:
		sprite.animation = anim
	if caminando:
		if not sprite.is_playing():
			sprite.play(anim)
		# Un paso cada vez que el pie toca el suelo (cuadros 0 y 2 de la animación de caminar)
		if sprite.frame != _cuadro_paso and (sprite.frame == 0 or sprite.frame == 2):
			Audio.paso(_en_exterior())
		_cuadro_paso = sprite.frame
		# Rebote vertical leve, siempre hacia arriba
		_tiempo_rebote += delta * rebote_velocidad
		sprite.offset.y = -absf(sin(_tiempo_rebote * PI)) * rebote_altura
	else:
		# Quieto: primer cuadro de la dirección actual
		sprite.stop()
		sprite.frame = 0
		_cuadro_paso = -1
		_tiempo_rebote = 0.0
		sprite.offset.y = move_toward(sprite.offset.y, 0.0, 20.0 * delta)


## true si el nivel actual es al aire libre (suena el paso de calle): la escena del nivel lo marca con
## set_meta("exterior", true).
func _en_exterior() -> bool:
	var escena := get_tree().current_scene
	return escena != null and bool(escena.get_meta("exterior", false))


# --- Sombra ---

## Elipse oscura translúcida bajo los pies (se dibuja antes que los hijos, o sea, debajo del sprite).
func _draw() -> void:
	draw_set_transform(Vector2(0, -1), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 11.0, Color(0, 0, 0, 0.3))


# --- Interacción ---

## Devuelve el nodo interactuable que corresponde a un área o cuerpo, o null.
func _resolver_interactuable(nodo: Node) -> Node:
	if nodo.has_method("interactuar"):
		return nodo
	var padre := nodo.get_parent()
	if padre != null and padre != self and padre.has_method("interactuar"):
		return padre
	return null


func _agregar_interactuable(nodo: Node) -> void:
	var objetivo := _resolver_interactuable(nodo)
	if objetivo != null and not interactuables.has(objetivo):
		interactuables.append(objetivo)


func _quitar_interactuable(nodo: Node) -> void:
	var objetivo := _resolver_interactuable(nodo)
	if objetivo != null:
		interactuables.erase(objetivo)


func _on_zona_area_entrada(area: Area2D) -> void:
	_agregar_interactuable(area)


func _on_zona_area_salida(area: Area2D) -> void:
	_quitar_interactuable(area)


func _on_zona_cuerpo_entrada(cuerpo: Node2D) -> void:
	_agregar_interactuable(cuerpo)


func _on_zona_cuerpo_salida(cuerpo: Node2D) -> void:
	_quitar_interactuable(cuerpo)


## Elige el interactuable más cercano que permita interactuar ahora.
func _actualizar_activo() -> void:
	var mejor: Node = null
	var mejor_distancia := INF
	for nodo in interactuables.duplicate():
		if not is_instance_valid(nodo):
			interactuables.erase(nodo)
			continue
		# Si no tiene puede_interactuar(), se asume que sí se puede
		if nodo.has_method("puede_interactuar") and not nodo.puede_interactuar():
			continue
		var distancia := 0.0
		if nodo is Node2D:
			distancia = global_position.distance_to(nodo.global_position)
		if distancia < mejor_distancia:
			mejor_distancia = distancia
			mejor = nodo
	if mejor != activo:
		activo = mejor
		interactuable_cambiado.emit(activo)


# --- Burbuja de ayuda ("E") ---

func _aplicar_estilo_burbuja() -> void:
	# Un panel transparente con el indicador de tecla (keycap E + verbo) en lugar de la etiqueta de texto
	panel_burbuja.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	etiqueta_burbuja.hide()
	indicador = IndicadorTecla.new()
	panel_burbuja.add_child(indicador)


## Muestra la burbuja sobre el objeto activo, flotando suavemente.
func _actualizar_burbuja() -> void:
	var manteniendo := progreso_mantener >= 0.0
	var visible_ahora := (activo != null and is_instance_valid(activo) and can_move) or manteniendo
	burbuja.visible = visible_ahora
	if not visible_ahora:
		return
	var base := global_position
	var verbo := "Mantén"
	if manteniendo:
		base = global_position + Vector2(0, -62)
	else:
		if activo is Node2D:
			base = activo.global_position
		verbo = activo.verbo() if activo != null and activo.has_method("verbo") else "Revisar"
	indicador.verbo = verbo
	indicador.progreso = progreso_mantener
	var flote := sin(Time.get_ticks_msec() / 1000.0 * 4.0) * 2.0
	burbuja.global_position = (base + (Vector2.ZERO if manteniendo else desplazamiento_ayuda) + Vector2(0, flote)).round()
	# Centra el indicador sobre ese punto
	panel_burbuja.position = -indicador.size / 2.0
