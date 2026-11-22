class_name PruebaColisiones
extends Node
## Prueba FÍSICA de las colisiones de los tres niveles (con ventana real; también corre sin ella). Para cada nivel carga la escena
## de verdad, recorre el mapa en una cuadrícula de 8 px poniendo en cada punto la forma de los pies de Sami (14 x 8) y pregunta
## al motor de física si choca. Con las celdas libres hace una búsqueda de alcance desde el punto de salida (cada paso de 8 px se
## comprueba también a la mitad, así no se «salta» una pared delgada) y comprueba:
##
##   1. Ninguna celda DENTRO de la base sólida de un objeto (todo su ancho y el 30 % inferior de su alto) es alcanzable.
##      Árboles y postes: solo el tronco / el pie. Mesa: solo las patas y el fondo. Planos (escombros): sin colisión.
##   2. Mesa: se puede llegar al hueco de abajo (zona segura) y a la zona de «mantener E» (Zona_Mesa), entrando por delante.
##   3. Todo lo interactivo (objetos, personas, zapatos, mochila y linterna) se puede usar desde al menos un lado, con la misma
##      zona de interacción de Sami (círculo de 34 px), y todas las zonas del nivel (escalera, punto de encuentro, cable...) son alcanzables.
##   4. Sami no empieza dentro de una colisión, y si se le pone dentro (un mueble) `sacar_de_colision()` lo lleva a un punto libre.
##
##   godot --path . res://Scenes/UI/PruebaColisiones.tscn -- --auto
##
## Guarda un mapa por nivel en tools/capturas_colisiones/ (gris = sólido, verde = alcanzable, naranja = libre pero inalcanzable,
## azul = base sólida exigida de los objetos) y escribe docs/revision_colisiones.md. Falla (salida 1) si algo no se cumple.
## Solo en depuración: no es parte del juego.

const CARPETA := "res://tools/capturas_colisiones/"
const INFORME := "res://docs/revision_colisiones.md"
const PASO := 8
const ESCALA_IMAGEN := 3
## Fracción mínima del alto visible que debe ser sólida en la base de un objeto con volumen.
const FRACCION_MINIMA := 0.30
const ALCANCE_INTERACCION := 34.0
const PIES := Vector2(14, 8)

var _fallos: Array[String] = []
var _lineas: Array[String] = []
var _espacio: PhysicsDirectSpaceState2D
var _nivel: Nivel
var _forma_pies := RectangleShape2D.new()
var _forma_circulo := CircleShape2D.new()


func _ready() -> void:
	var automatico := OS.get_cmdline_user_args().has("--auto")
	_forma_pies.size = PIES
	_forma_circulo.radius = ALCANCE_INTERACCION
	await get_tree().process_frame
	_lineas.append("# Revisión de colisiones\n")
	_lineas.append("Generado por `tools/probar_colisiones.gd` (prueba física: cuadrícula de %d px con la forma de los pies de Sami, 14 x 8). Es un informe automático, no se edita a mano.\n" % PASO)
	for n in [1, 2, 3]:
		await _probar_nivel(n)
	_lineas.append("\n## Resultado\n")
	if _fallos.is_empty():
		_lineas.append("**Todo se cumple.**\n")
	else:
		_lineas.append("**Fallos (%d):**\n" % _fallos.size())
		for f in _fallos:
			_lineas.append("- " + f)
	var archivo := FileAccess.open(INFORME, FileAccess.WRITE)
	if archivo != null:
		archivo.store_string("\n".join(_lineas) + "\n")
		archivo.close()
	for f in _fallos:
		printerr("FALLO: ", f)
	print("Colisiones: %s" % ("todo se cumple" if _fallos.is_empty() else "%d fallos" % _fallos.size()))
	if automatico:
		get_tree().quit(1 if not _fallos.is_empty() else 0)


func _probar_nivel(n: int) -> void:
	var escena: PackedScene = load("res://Scenes/Niveles/Nivel%d.tscn" % n)
	_nivel = escena.instantiate()
	add_child(_nivel)
	for i in 6:
		await get_tree().physics_frame
	_espacio = _nivel.get_world_2d().direct_space_state
	var jugador := _nivel.jugador
	_lineas.append("\n## Nivel %d\n" % n)

	# --- cuadrícula de celdas libres ---
	var columnas := int(_nivel.tamano_mapa.x) / PASO + 1
	var filas := int(_nivel.tamano_mapa.y) / PASO + 1
	var libre := PackedByteArray()
	libre.resize(columnas * filas)
	for y in filas:
		for x in columnas:
			libre[y * columnas + x] = 1 if _libre(Vector2(x, y) * PASO, jugador) else 0

	# 4a. Sami no empieza dentro de una colisión
	if not _libre(jugador.global_position, jugador):
		_fallos.append("Nivel %d: Sami empieza dentro de una colisión (%s)" % [n, jugador.global_position])
	var inicio := Vector2i(roundi(jugador.global_position.x / PASO), roundi(jugador.global_position.y / PASO))
	inicio = _celda_libre_cercana(inicio, libre, columnas, filas)

	# --- alcance ---
	var alcanzable := PackedByteArray()
	alcanzable.resize(columnas * filas)
	var cola: Array[Vector2i] = [inicio]
	alcanzable[inicio.y * columnas + inicio.x] = 1
	var total_alcanzables := 1
	while not cola.is_empty():
		var c: Vector2i = cola.pop_back()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var v: Vector2i = c + d
			if v.x < 0 or v.y < 0 or v.x >= columnas or v.y >= filas:
				continue
			var idx := v.y * columnas + v.x
			if alcanzable[idx] == 1 or libre[idx] == 0:
				continue
			# a mitad de camino también tiene que estar libre (una pared delgada no se puede «saltar»)
			var medio := (Vector2(c) + Vector2(v)) / 2.0 * PASO
			if not _libre(medio, jugador):
				continue
			alcanzable[idx] = 1
			total_alcanzables += 1
			cola.push_back(v)
	var total_libres := 0
	for b in libre:
		total_libres += b
	_lineas.append("Mapa de %dx%d px: %d celdas libres, %d alcanzables desde el punto de salida %s.\n" % [
			int(_nivel.tamano_mapa.x), int(_nivel.tamano_mapa.y), total_libres, total_alcanzables, jugador.global_position])

	# --- 1 y 2. bases sólidas de los objetos ---
	_lineas.append("| Objeto | Colisión (ancho x alto px) | Celdas alcanzables dentro de la base | Resultado |")
	_lineas.append("|---|---|---|---|")
	var bandas: Array[Rect2] = []
	for p in _nivel.props:
		var datos: Dictionary = Prop.DATOS[p.tipo]
		var tamano_col := _tamano_colision(p)
		var descripcion := "sin colisión" if tamano_col == Vector2.ZERO else "%.0f x %.0f" % [tamano_col.x, tamano_col.y]
		var dentro := 0
		var resultado := "ok"
		if p.tipo in Prop.PLANOS:
			if p.get_node_or_null("Cuerpo") != null and not p.get_node("Cuerpo").is_queued_for_deletion():
				_fallos.append("Nivel %d: %s es plano y tiene colisión" % [n, p.name])
				resultado = "FALLA"
			descripcion = "plano, sin colisión"
		elif p.tipo == "puerta_salida":
			descripcion = "en el hueco de la pared"
			dentro = _contar(p, _banda(p, true), alcanzable, columnas, filas)
		elif p.tipo == "mesa":
			for banda in _bandas_mesa(p):
				dentro += _contar(p, banda, alcanzable, columnas, filas)
				bandas.append(banda)
		else:
			var banda := _banda(p, false)
			bandas.append(banda)
			dentro = _contar(p, banda, alcanzable, columnas, filas)
		if dentro > 0:
			_fallos.append("Nivel %d: %d celdas alcanzables dentro de la base de %s (%s)" % [n, dentro, p.name, p.tipo])
			resultado = "FALLA"
		if bool(datos["colision"]) and p.tipo != "mesa" and tamano_col.y < FRACCION_MINIMA * _alto_visible(p) - 0.5 and p.tipo not in Prop.ALTO_COLISION_FIJO:
			_fallos.append("Nivel %d: la colisión de %s mide menos del 30 %% del alto visible" % [n, p.name])
			resultado = "FALLA"
		_lineas.append("| %s (%s) | %s | %d | %s |" % [p.name, p.tipo, descripcion, dentro, resultado])
	_lineas.append("")

	# mesa: hueco de abajo y zona de mantener E
	for p in _nivel.props:
		if p.tipo != "mesa":
			continue
		var segura := p.get_node_or_null("ZonaSegura") as Area2D
		if segura == null:
			_fallos.append("Nivel %d: la mesa no tiene zona segura" % n)
			continue
		var celdas_seguras := 0
		var por_delante := false
		for y in filas:
			for x in columnas:
				if alcanzable[y * columnas + x] == 0:
					continue
				var punto := Vector2(x, y) * PASO
				if punto.distance_to(p.global_position) > 90.0:
					continue
				if _toca_zona_segura(punto, segura):
					celdas_seguras += 1
					if punto.y >= p.global_position.y - 8.0:
						por_delante = true
		_lineas.append("Mesa: %d celdas alcanzables dentro de la zona segura (el hueco de abajo); se llega por delante: %s.\n" % [celdas_seguras, "sí" if por_delante else "NO"])
		if celdas_seguras == 0 or not por_delante:
			_fallos.append("Nivel %d: no se llega a la zona segura de la mesa por delante" % n)

	# --- 3. interactivos y zonas ---
	_lineas.append("| Interactivo | Lados desde los que se puede usar | Resultado |")
	_lineas.append("|---|---|---|")
	var objetivos: Array[Node2D] = []
	for p in _nivel.props:
		if p.interactuable:
			objetivos.append(p)
	for npc in _nivel.npcs:
		objetivos.append(npc)
	for o in _nivel.items:
		if is_instance_valid(o):
			objetivos.append(o)
	for o in objetivos:
		var lados := _lados_de_uso(o, alcanzable, columnas, filas, jugador)
		var ok := not lados.is_empty()
		if not ok:
			_fallos.append("Nivel %d: %s no se puede usar desde ningún lado" % [n, o.name])
		_lineas.append("| %s | %s | %s |" % [o.name, ", ".join(lados) if ok else "ninguno", "ok" if ok else "FALLA"])
	_lineas.append("")
	for nombre in _nivel.zonas:
		var z: Dictionary = _nivel.zonas[nombre]
		var alcanza := false
		for y in filas:
			for x in columnas:
				if alcanzable[y * columnas + x] == 1 and (Vector2(x, y) * PASO).distance_to(z["pos"]) <= float(z["radio"]):
					alcanza = true
					break
			if alcanza:
				break
		_lineas.append("- Zona `%s`: %s" % [nombre, "alcanzable" if alcanza else "NO ALCANZABLE"])
		if not alcanza:
			_fallos.append("Nivel %d: la zona %s no es alcanzable" % [n, nombre])
	_lineas.append("")

	# --- 4b. si se pone a Sami dentro de un mueble, lo saca ---
	await _probar_empuje(n, jugador)

	_guardar_mapa(n, libre, alcanzable, columnas, filas, bandas)
	_lineas.append("![Mapa de colisiones del nivel %d](../tools/capturas_colisiones/colisiones_nivel%d.png)\n" % [n, n])
	_nivel.queue_free()
	await get_tree().process_frame


# --- Consultas de física ---

func _libre(punto_pies: Vector2, jugador: Node2D) -> bool:
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = _forma_pies
	q.transform = Transform2D(0.0, punto_pies + Vector2(0, -4))
	q.collision_mask = 1
	q.exclude = [(jugador as CollisionObject2D).get_rid()]
	return _espacio.intersect_shape(q, 1).is_empty()


func _toca_zona_segura(punto_pies: Vector2, segura: Area2D) -> bool:
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = _forma_pies
	q.transform = Transform2D(0.0, punto_pies + Vector2(0, -4))
	q.collision_mask = Prop.CAPA_ZONA_SEGURA
	q.collide_with_areas = true
	q.collide_with_bodies = false
	for r in _espacio.intersect_shape(q, 8):
		if r["collider"] == segura:
			return true
	return false


## Desde qué lados se puede usar un objeto: celdas alcanzables en las que el círculo de interacción de Sami toca su zona.
func _lados_de_uso(o: Node2D, alcanzable: PackedByteArray, columnas: int, filas: int, jugador: Node2D) -> Array[String]:
	var lados: Array[String] = []
	var zona := o.get_node_or_null("Zona") as Area2D
	if zona == null:
		# los objetos del suelo (zapatos, mochila, linterna) crean su Area2D sin nombre
		for h in o.get_children():
			if h is Area2D:
				zona = h
				break
	if zona == null:
		return lados
	var centro := o.global_position
	for y in filas:
		for x in columnas:
			if alcanzable[y * columnas + x] == 0:
				continue
			var punto := Vector2(x, y) * PASO
			if punto.distance_to(centro) > 160.0:
				continue
			var q := PhysicsShapeQueryParameters2D.new()
			q.shape = _forma_circulo
			q.transform = Transform2D(0.0, punto + Vector2(0, -8))
			q.collision_mask = 3
			q.collide_with_areas = true
			q.collide_with_bodies = false
			var toca := false
			for r in _espacio.intersect_shape(q, 16):
				if r["collider"] == zona:
					toca = true
					break
			if not toca:
				continue
			var d := punto - centro
			var lado := ""
			if absf(d.x) > absf(d.y - 12.0):
				lado = "derecha" if d.x > 0 else "izquierda"
			else:
				lado = "abajo" if d.y > 0 else "arriba"
			if not lados.has(lado):
				lados.append(lado)
	return lados


# --- Geometría de las bases ---

func _caja_visible(p: Prop) -> Rect2:
	return p.rect_visible()


func _alto_visible(p: Prop) -> float:
	return _caja_visible(p).size.y


## Tamaño de la colisión que el objeto realmente tiene (suma de formas: ancho total y alto).
func _tamano_colision(p: Prop) -> Vector2:
	var cuerpo := p.get_node_or_null("Cuerpo") as StaticBody2D
	if cuerpo == null or cuerpo.is_queued_for_deletion():
		return Vector2.ZERO
	var caja := Rect2()
	var primero := true
	for h in cuerpo.get_children():
		if h is CollisionShape2D and (h as CollisionShape2D).shape is RectangleShape2D:
			var s := ((h as CollisionShape2D).shape as RectangleShape2D).size
			var r := Rect2((h as CollisionShape2D).position - s / 2.0, s)
			caja = r if primero else caja.merge(r)
			primero = false
	return caja.size


## Base sólida exigida: todo el ancho visible (el del tronco para árboles y postes) y el 30 % inferior del alto (10 px en el pie).
## Es un rectángulo para la posición de los pies de Sami: «alcanzable» ahí significa que Sami se pondría encima del objeto.
func _banda(p: Prop, _pared: bool) -> Rect2:
	var vis := _caja_visible(p)
	var base_y := p.global_position.y
	var cx := p.global_position.x
	var mitad := vis.size.x / 2.0
	var alto := FRACCION_MINIMA * vis.size.y
	if p.tipo in Prop.ALTO_COLISION_FIJO:
		mitad = vis.size.x * Prop.COLISION_TIPO[p.tipo].x / 2.0
		alto = 10.0
	# Los pies de Sami miden 14 x 8: solo cuentan los puntos cuyo cuerpo cae del todo dentro del ancho y la franja
	return Rect2(Vector2(cx - mitad + 3.0, base_y - alto + 8.0), Vector2(maxf(2.0 * mitad - 6.0, 1.0), maxf(alto - 8.0, 1.0)))


## Mesa: las dos patas (solo sus laterales) y el fondo.
func _bandas_mesa(p: Prop) -> Array[Rect2]:
	var vis := _caja_visible(p)
	var cx := p.global_position.x
	var base_y := p.global_position.y
	var tam := _tamano_colision(p)
	var alto_col := tam.y
	var mitad := tam.x / 2.0
	var lista: Array[Rect2] = []
	# patas: los pies de Sami (14 px) no caben sobre una pata de 8 px sin tocarla, así que se mira el punto central
	lista.append(Rect2(Vector2(cx - mitad + 1.0, base_y - alto_col + 1.0), Vector2(Prop.ANCHO_PATA - 2.0, alto_col - 1.0)))
	lista.append(Rect2(Vector2(cx + mitad - Prop.ANCHO_PATA + 1.0, base_y - alto_col + 1.0), Vector2(Prop.ANCHO_PATA - 2.0, alto_col - 1.0)))
	# fondo: la franja detrás de la zona segura, entre las patas
	lista.append(Rect2(Vector2(cx - mitad + Prop.ANCHO_PATA, base_y - alto_col), Vector2(2.0 * mitad - 2.0 * Prop.ANCHO_PATA, Prop.GROSOR_FONDO + 7.0)))
	return lista


## Celdas alcanzables cuyo punto de los pies cae dentro del rectángulo.
func _contar(_p: Prop, banda: Rect2, alcanzable: PackedByteArray, columnas: int, filas: int) -> int:
	var cuenta := 0
	var x0 := maxi(int(floor(banda.position.x / PASO)), 0)
	var x1 := mini(int(ceil(banda.end.x / PASO)), columnas - 1)
	var y0 := maxi(int(floor(banda.position.y / PASO)), 0)
	var y1 := mini(int(ceil(banda.end.y / PASO)), filas - 1)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if alcanzable[y * columnas + x] == 1 and banda.has_point(Vector2(x, y) * PASO):
				cuenta += 1
	return cuenta


func _celda_libre_cercana(c: Vector2i, libre: PackedByteArray, columnas: int, filas: int) -> Vector2i:
	for radio in range(0, 20):
		for dy in range(-radio, radio + 1):
			for dx in range(-radio, radio + 1):
				var v := Vector2i(c.x + dx, c.y + dy)
				if v.x >= 0 and v.y >= 0 and v.x < columnas and v.y < filas and libre[v.y * columnas + v.x] == 1:
					return v
	return c


# --- Empuje fuera de una colisión ---

func _probar_empuje(n: int, jugador: Player) -> void:
	var mueble: Prop = null
	for p in _nivel.props:
		if p.tipo in ["sofa", "cama", "nevera", "armario", "carro", "banca", "estante"]:
			mueble = p
			break
	if mueble == null:
		_lineas.append("Empuje: este nivel no tiene un mueble de prueba (se comprueba en los niveles 1 y 3).\n")
		return
	var centro := mueble.global_position + Vector2(0, -6)
	jugador.global_position = centro
	await get_tree().physics_frame
	var dentro := not _libre(jugador.global_position, jugador)
	jugador.sacar_de_colision()
	for i in 4:
		await get_tree().physics_frame
	var fuera := _libre(jugador.global_position, jugador)
	var movido := jugador.global_position.distance_to(centro)
	_lineas.append("Empuje: Sami puesto dentro de `%s`: dentro = %s; después de `sacar_de_colision()` libre = %s, movido %.0f px.\n" % [mueble.name, "sí" if dentro else "NO", "sí" if fuera else "NO", movido])
	if not dentro:
		_fallos.append("Nivel %d: el punto de prueba del empuje no estaba dentro de %s" % [n, mueble.name])
	if not fuera:
		_fallos.append("Nivel %d: sacar_de_colision no dejó a Sami libre junto a %s" % [n, mueble.name])
	elif movido > 80.0:
		_fallos.append("Nivel %d: sacar_de_colision movió a Sami demasiado (%.0f px)" % [n, movido])


# --- Imagen ---

func _guardar_mapa(n: int, libre: PackedByteArray, alcanzable: PackedByteArray, columnas: int, filas: int, bandas: Array[Rect2]) -> void:
	var img := Image.create(columnas * ESCALA_IMAGEN, filas * ESCALA_IMAGEN, false, Image.FORMAT_RGBA8)
	img.fill(Color("10202A"))
	for y in filas:
		for x in columnas:
			var idx := y * columnas + x
			var color := Color("3a4650")   # sólido
			if alcanzable[idx] == 1:
				color = Color("2A9D8F")
			elif libre[idx] == 1:
				color = Color("FF7A1A")
			img.fill_rect(Rect2i(x * ESCALA_IMAGEN, y * ESCALA_IMAGEN, ESCALA_IMAGEN, ESCALA_IMAGEN), color)
	for b in bandas:
		var r := Rect2i(int(b.position.x / PASO * ESCALA_IMAGEN), int(b.position.y / PASO * ESCALA_IMAGEN),
				maxi(int(b.size.x / PASO * ESCALA_IMAGEN), 1), maxi(int(b.size.y / PASO * ESCALA_IMAGEN), 1))
		for i in r.size.x:
			img.set_pixel(clampi(r.position.x + i, 0, img.get_width() - 1), clampi(r.position.y, 0, img.get_height() - 1), Color("4aa3ff"))
			img.set_pixel(clampi(r.position.x + i, 0, img.get_width() - 1), clampi(r.end.y, 0, img.get_height() - 1), Color("4aa3ff"))
		for j in r.size.y:
			img.set_pixel(clampi(r.position.x, 0, img.get_width() - 1), clampi(r.position.y + j, 0, img.get_height() - 1), Color("4aa3ff"))
			img.set_pixel(clampi(r.end.x, 0, img.get_width() - 1), clampi(r.position.y + j, 0, img.get_height() - 1), Color("4aa3ff"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CARPETA))
	img.save_png(ProjectSettings.globalize_path(CARPETA + "colisiones_nivel%d.png" % n))
