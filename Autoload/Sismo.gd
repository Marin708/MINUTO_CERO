extends Node
## El sismo y sus efectos. Una secuencia: un aviso corto de temblor, el sismo fuerte (unos 20 s) y un final con
## silencio. Con `intensidad` menor (por ejemplo 0.5 en la réplica del nivel 3) todo es más suave y corto.
##
##   Sismo.iniciar(nivel)                                   el sismo del nivel 2 (intensidad 1.0, 2 s + 20 s)
##   Sismo.iniciar(nivel, 0.5, 6.0, 1.0)                    la réplica: intensidad 0.5, 6 s, aviso de 1 s
##   Sismo.detener()                                        corta el sismo y deja el silencio final
##
## Efectos: temblor de cámara moderado (no dificulta el control), polvo con partículas, objetos que caen cerca de
## las ventanas, el estante y la lámpara (con rebote y sonido) y un tinte rojizo suave sobre las zonas de riesgo.
## Las reglas de lo que debe hacer Sami (D8 y D15) las pone cada nivel; este autoload solo da el escenario.

signal aviso_iniciado
signal fuerte_iniciado
signal terminado

enum Fase { NINGUNA, AVISO, FUERTE, FINAL }

const SEGUNDOS_AVISO := 2.0
const SEGUNDOS_FUERTE := 20.0
const SEGUNDOS_SILENCIO := 2.0
const TEMBLOR_AVISO := 1.5   # píxeles de cámara con intensidad 1.0
const TEMBLOR_FUERTE := 3.5
const RUTA_KIT := "res://Assets/UI/kit.png"
## Íconos de kit.png que caen como objetos de la casa: televisor, perfume, videojuego y vela.
const ICONOS_CAIDA := [9, 10, 11, 8]

var fase: Fase = Fase.NINGUNA
## Segundos transcurridos del sismo fuerte (0 mientras no haya empezado).
var t_fuerte := 0.0
var intensidad := 1.0
var duracion_fuerte := SEGUNDOS_FUERTE

var _nivel: Nivel
var _t_aviso := 0.0
var _caidas: Array[float] = []
var _siguiente_caida := 0
var _tinte: Node2D
var _es_exterior := false
var _version := 0   # sube en cada inicio o parada para cancelar secuencias viejas


func esta_activo() -> bool:
	return fase != Fase.NINGUNA


## Empieza el sismo en `nivel`. `con_aviso_segundos` es lo que dura el temblor corto previo.
func iniciar(nivel: Nivel, p_intensidad: float = 1.0, p_duracion_fuerte: float = SEGUNDOS_FUERTE, con_aviso_segundos: float = SEGUNDOS_AVISO) -> void:
	_version += 1
	var mi_version := _version
	_nivel = nivel
	intensidad = clampf(p_intensidad, 0.1, 1.0)
	duracion_fuerte = p_duracion_fuerte
	_es_exterior = bool(nivel.get_meta("exterior", false))
	t_fuerte = 0.0
	_t_aviso = 0.0
	_siguiente_caida = 0
	_planear_caidas()
	fase = Fase.AVISO
	for n in nivel.npcs:
		n.asustado = true
	_crear_tinte()
	_nivel.temblar(TEMBLOR_AVISO * intensidad, con_aviso_segundos, false)
	Audio.efecto("replica" if intensidad < 0.8 else "sismo_aviso")
	aviso_iniciado.emit()
	await get_tree().create_timer(con_aviso_segundos).timeout
	if mi_version != _version:
		return
	# Sismo fuerte
	fase = Fase.FUERTE
	_nivel.temblar(TEMBLOR_FUERTE * intensidad, p_duracion_fuerte, false)
	if not _es_exterior:
		_nivel.polvo(true)
	Audio.ambiente("amb_sismo", 0.5)
	fuerte_iniciado.emit()
	await get_tree().create_timer(p_duracion_fuerte).timeout
	if mi_version != _version:
		return
	await detener()


## Corta el sismo: el temblor y el polvo paran, el sonido se apaga y queda un silencio antes de volver el ambiente.
func detener() -> void:
	if fase == Fase.NINGUNA or fase == Fase.FINAL:
		return
	_version += 1
	var mi_version := _version
	fase = Fase.FINAL
	if is_instance_valid(_nivel):
		_nivel.temblar(0.0, 0.01)
		_nivel.polvo(false)
		for n in _nivel.npcs:
			n.asustado = false
	Audio.efecto("sismo_fin")
	Audio.detener_ambiente(0.4)   # el silencio
	_quitar_tinte()
	await get_tree().create_timer(SEGUNDOS_SILENCIO).timeout
	if mi_version != _version:
		return
	fase = Fase.NINGUNA
	if is_instance_valid(_nivel):
		Audio.ambiente("amb_calle" if _es_exterior else "amb_casa", 1.5)
	terminado.emit()


func _process(delta: float) -> void:
	if fase == Fase.AVISO:
		_t_aviso += delta
	elif fase == Fase.FUERTE:
		t_fuerte += delta
		if _siguiente_caida < _caidas.size() and t_fuerte >= _caidas[_siguiente_caida]:
			_soltar(_siguiente_caida)
			_siguiente_caida += 1
	if _tinte != null:
		_tinte.modulate.a = (0.55 + 0.45 * sin(Time.get_ticks_msec() / 1000.0 * 5.0)) * (1.0 if fase == Fase.FUERTE else 0.5)


# --- Objetos que caen ---

func _planear_caidas() -> void:
	_caidas.clear()
	var cantidad := maxi(2, int(round(5.0 * intensidad)))
	for i in cantidad:
		_caidas.append((duracion_fuerte * 0.7) * (float(i) + 0.5) / float(cantidad))


## Los sitios donde caen cosas: junto a las ventanas, el estante y la lámpara (la mesa y su zona segura quedan libres).
func _sitios_de_caida() -> Array[Dictionary]:
	var sitios: Array[Dictionary] = []
	if _es_exterior:
		# Afuera: cosas sueltas de los edificios, lejos de Sami
		var p := _nivel.jugador.global_position
		for d in [Vector2(-90, -30), Vector2(100, -20), Vector2(-60, 70), Vector2(80, 60)]:
			sitios.append({"pos": p + d, "sonido": "escombros"})
		return sitios
	for nombre in _nivel.zonas:
		if _nivel.zonas[nombre]["tipo"] == "ventana":
			sitios.append({"pos": _nivel.zonas[nombre]["pos"] + Vector2(0, 30), "sonido": "vidrio_roto"})
	var estante := _nivel.prop_con_etiqueta("D1")
	if estante != null:
		sitios.append({"pos": estante.global_position + Vector2(-26, 22), "sonido": "estante_cae"})
	var repisa := _nivel.prop_con_etiqueta("D4")
	if repisa != null:
		sitios.append({"pos": repisa.global_position + Vector2(10, 24), "sonido": "objeto_cae"})
	# La lámpara (no tiene dibujo propio): cae un objeto desde el techo de la sala, al lado de la zona segura
	var mesa := _nivel.pos_zona("Zona_Mesa")
	sitios.append({"pos": mesa + Vector2(-70, -40), "sonido": "objeto_cae"})
	return sitios


func _soltar(indice: int) -> void:
	var sitios := _sitios_de_caida()
	if sitios.is_empty():
		return
	var sitio: Dictionary = sitios[indice % sitios.size()]
	soltar_objeto(sitio["pos"] + Vector2(randf_range(-14.0, 14.0), randf_range(-6.0, 6.0)), str(sitio["sonido"]), ICONOS_CAIDA[indice % ICONOS_CAIDA.size()])


## Un objeto (ícono de kit.png) que cae desde arriba hasta `destino` (global), rebota y suena al chocar.
func soltar_objeto(destino: Vector2, sonido: String = "objeto_cae", icono: int = 9) -> void:
	if not is_instance_valid(_nivel):
		return
	var atlas := AtlasTexture.new()
	atlas.atlas = load(RUTA_KIT)
	atlas.region = Rect2((icono % 4) * 32, (icono / 4) * 32, 32, 32)
	var sprite := Sprite2D.new()
	sprite.texture = atlas
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = false
	sprite.offset = Vector2(-16, -30)   # la base del ícono queda en el suelo
	sprite.position = destino + Vector2(randf_range(-10.0, 10.0), -170.0)
	sprite.rotation = randf_range(-0.6, 0.6)
	_nivel.objetos.add_child(sprite)
	var t := create_tween().set_parallel(true)
	t.tween_property(sprite, "position:y", destino.y, 0.9).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	t.tween_property(sprite, "position:x", destino.x, 0.9)
	t.tween_property(sprite, "rotation", 0.0, 0.9)
	get_tree().create_timer(0.35).timeout.connect(func() -> void: Audio.efecto(sonido))
	get_tree().create_timer(0.7).timeout.connect(func() -> void:
		if is_instance_valid(_nivel):
			_nivel.temblar(1.2 * intensidad, 0.15))
	await get_tree().create_timer(7.0).timeout
	if is_instance_valid(sprite):
		var s := create_tween()
		s.tween_property(sprite, "modulate:a", 0.0, 0.6)
		s.tween_callback(sprite.queue_free)


# --- Tinte rojizo sobre las zonas de riesgo ---

func _crear_tinte() -> void:
	_quitar_tinte()
	if _es_exterior or not is_instance_valid(_nivel):
		return
	_tinte = Node2D.new()
	_tinte.z_index = 4
	_nivel.suelo.add_child(_tinte)
	_tinte.draw.connect(_dibujar_tinte)
	_tinte.queue_redraw()


func _dibujar_tinte() -> void:
	if _tinte == null or not is_instance_valid(_nivel):
		return
	var color := Color(1.0, 0.18, 0.12, 0.16)
	for nombre in _nivel.zonas:
		var z: Dictionary = _nivel.zonas[nombre]
		if z["tipo"] in ["ventana", "puerta"]:
			_tinte.draw_circle(z["pos"] + Vector2(0, -16), float(z["radio"]), color)
	var estante := _nivel.prop_con_etiqueta("D1")
	if estante != null:
		_tinte.draw_circle(estante.position + Vector2(0, -16), 44.0, color)


func _quitar_tinte() -> void:
	if _tinte != null:
		_tinte.queue_free()
		_tinte = null
