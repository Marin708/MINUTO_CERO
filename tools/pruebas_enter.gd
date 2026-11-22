extends Node
## Prueba (sin ventana) que Enter avanza las conversaciones, simulando eventos de teclado y de ratón de verdad:
##   godot --headless --path . res://tools/pruebas_enter.tscn
## (a) Enter completa el texto y, con una segunda pulsación, avanza; Enter del teclado numérico, E y el clic hacen lo mismo.
## (b) Con opciones en pantalla Enter solo confirma la opción enfocada (y no salta nada); siempre hay una enfocada.
## (c) Mantener Enter (repetición) o pulsarlo muy rápido no pasa más de una línea por vez.
## (d) Cerrar la conversación con Enter no abre otra interacción del mundo (0.2 s de bloqueo).
## (e) Enter no cierra ni salta la retroalimentación obligatoria, el cuestionario ni el kit con menos de 8 objetos.
## Sale con código 0 si todo pasa.

var _fallos := 0
var _pruebas := 0
var _resultado := -99
var _termino := false
var _gm: DialogoBalloon
var _tm: TarjetaRetro


func _ready() -> void:
	await get_tree().process_frame
	await _prueba_accion()
	await _prueba_avanzar()
	await _prueba_opciones()
	await _prueba_rapido()
	await _prueba_mundo()
	await _prueba_tarjeta()
	await _prueba_kit()
	await _prueba_cuestionario()
	print("Pruebas de Enter: %d comprobaciones, %d fallos." % [_pruebas, _fallos])
	get_tree().quit(1 if _fallos > 0 else 0)


func _ok(condicion: bool, texto: String) -> void:
	_pruebas += 1
	if not condicion:
		_fallos += 1
	print("  %s %s" % ["ok   " if condicion else "FALLA", texto])


func _esperar(segundos: float) -> void:
	await get_tree().create_timer(segundos, true, false, true).timeout


func _hasta(condicion: Callable, limite: float = 6.0) -> bool:
	var t := 0.0
	while t < limite:
		if condicion.call():
			return true
		await get_tree().process_frame
		t += get_process_delta_time()
	return condicion.call()


# --- Entrada simulada ---

func _tecla(codigo: Key, eco: bool = false, soltar: bool = true) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = codigo
	e.keycode = codigo
	e.pressed = true
	e.echo = eco
	Input.parse_input_event(e)
	if soltar and not eco:
		var s := InputEventKey.new()
		s.physical_keycode = codigo
		s.keycode = codigo
		s.pressed = false
		Input.parse_input_event(s)
	await get_tree().process_frame


func _clic() -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = Vector2(300, 300)
	e.global_position = e.position
	Input.parse_input_event(e)
	await get_tree().process_frame
	var s := InputEventMouseButton.new()
	s.button_index = MOUSE_BUTTON_LEFT
	s.pressed = false
	s.position = e.position
	Input.parse_input_event(s)
	await get_tree().process_frame


func _globo() -> DialogoBalloon:
	var mejor: DialogoBalloon = null
	for h in Dialogo.get_children():
		if h is DialogoBalloon and not (h as DialogoBalloon)._cerrando:
			mejor = h
	return mejor


func _texto_de(globo: DialogoBalloon) -> String:
	return globo.linea.text if globo != null and globo.linea != null else ""


## Abre una conversación sin esperarla; el resultado queda en _resultado y _termino.
func _abrir(nombre: String, texto: Variant, opciones: Array = []) -> void:
	_resultado = -99
	_termino = false
	var f := func() -> void:
		_resultado = await Dialogo.mostrar_texto(nombre, texto, opciones)
		_termino = true
	f.call()


func _cerrar_todo() -> void:
	for i in 10:
		var g := _globo()
		if g == null:
			break
		g._cancelar() if g.cancelable else g._terminar()
		await _esperar(0.3)
	await _esperar(0.3)


const LARGA := "Esta es una línea bastante larga para poder completarla de golpe con la tecla Enter antes de que termine de escribirse."


func _prueba_accion() -> void:
	print("Acción AVANZAR_DIALOGO")
	_ok(InputMap.has_action("AVANZAR_DIALOGO"), "la acción existe en el Input Map")
	var teclas: Array[int] = []
	for e in InputMap.action_get_events("AVANZAR_DIALOGO"):
		if e is InputEventKey:
			teclas.append((e as InputEventKey).physical_keycode)
	_ok(teclas.has(KEY_ENTER) and teclas.has(KEY_KP_ENTER) and teclas.size() == 2, "solo Enter y Enter del teclado numérico (sin Espacio ni Esc)")


func _prueba_avanzar() -> void:
	print("(a) y (f) Enter completa el texto y la segunda pulsación avanza")
	for variante in ["enter", "kp", "e", "clic"]:
		_abrir("Mamá", [LARGA + " " + variante, "Segunda línea de " + variante + "."])
		var g: DialogoBalloon = null
		await _hasta(func() -> bool:
			_gm = _globo()
			return _gm != null and _gm.texto.is_typing)
		g = _gm
		await _esperar(0.3)   # pasa el margen de 0.15 s de una línea nueva
		_ok(g != null and g.texto.is_typing, "%s: el texto se está escribiendo" % variante)
		await _pulsar(variante)
		await get_tree().process_frame
		_ok(not g.texto.is_typing and _texto_de(g).ends_with(variante), "%s: la primera pulsación completa el texto de golpe, sin pasar de línea" % variante)
		await _esperar(0.3)
		await _pulsar(variante)
		var paso := await _hasta(func() -> bool: return _texto_de(g).begins_with("Segunda"))
		_ok(paso, "%s: la segunda pulsación pasa a la siguiente línea" % variante)
		await _esperar(0.3)
		await _pulsar(variante)   # completa la segunda línea
		await _esperar(0.3)
		await _pulsar(variante)   # cierra la conversación
		var cerro := await _hasta(func() -> bool: return _termino)
		_ok(cerro, "%s: la última pulsación cierra la conversación" % variante)
		await _esperar(0.4)


func _pulsar(variante: String) -> void:
	match variante:
		"enter":
			await _tecla(KEY_ENTER)
		"kp":
			await _tecla(KEY_KP_ENTER)
		"e":
			await _tecla(KEY_E)
		"clic":
			await _clic()


func _prueba_opciones() -> void:
	print("(b) Con opciones, Enter solo confirma la opción enfocada")
	_abrir("Mamá", "¿Qué haces?", ["Opción A", "Opción B"])
	var g: DialogoBalloon = null
	await _hasta(func() -> bool:
		_gm = _globo()
		return _gm != null and _gm._opciones_listas)
	g = _gm
	_ok(g != null and g._opciones_listas, "las opciones aparecen")
	var foco := get_viewport().gui_get_focus_owner()
	_ok(foco is Button and g.respuestas.is_ancestor_of(foco), "al mostrarse hay una opción enfocada (la primera)")
	# Una pulsación enseguida (dentro de los 0.15 s) se ignora
	await _tecla(KEY_ENTER)
	_ok(not _termino, "Enter en los primeros 0.15 s no elige nada")
	await _esperar(0.3)
	# Espera larga: nada avanza solo ni salta
	await _esperar(0.3)
	_ok(not _termino and g.linea.responses.size() == 2, "con opciones en pantalla la conversación sigue esperando")
	# Mantener Enter (repeticiones) no elige
	for i in 5:
		await _tecla(KEY_ENTER, true)
	_ok(not _termino, "mantener Enter (repetición) no elige la opción")
	# Flechas y W/S mueven el foco; Enter confirma la enfocada
	await _tecla(KEY_DOWN)
	await _esperar(0.05)
	var segundo := get_viewport().gui_get_focus_owner()
	_ok(segundo != foco and segundo is Button and g.respuestas.is_ancestor_of(segundo), "la flecha abajo pasa a la opción B")
	await _tecla(KEY_ENTER)
	var listo := await _hasta(func() -> bool: return _termino)
	_ok(listo and _resultado == 1, "Enter confirma la opción enfocada (B = 1), resultado %d" % _resultado)
	await _esperar(0.5)
	# Con la primera enfocada
	_abrir("Mamá", "¿Y ahora?", ["Opción A", "Opción B"])
	await _hasta(func() -> bool:
		_gm = _globo()
		return _gm != null and _gm._opciones_listas)
	g = _gm
	await _esperar(0.3)
	await _tecla(KEY_KP_ENTER)
	listo = await _hasta(func() -> bool: return _termino)
	_ok(listo and _resultado == 0, "Enter numérico confirma la opción enfocada (A = 0), resultado %d" % _resultado)
	await _esperar(0.5)
	# Con E sobre la opción enfocada (como antes)
	_abrir("Mamá", "¿Otra vez?", ["Opción A", "Opción B"])
	await _hasta(func() -> bool:
		_gm = _globo()
		return _gm != null and _gm._opciones_listas)
	g = _gm
	await _esperar(0.3)
	await _tecla(KEY_E)
	listo = await _hasta(func() -> bool: return _termino)
	_ok(listo and _resultado == 0, "E sigue eligiendo la opción enfocada, resultado %d" % _resultado)
	await _esperar(0.5)


func _prueba_rapido() -> void:
	print("(c) Mantener Enter o pulsarlo muy rápido no pasa más de una línea")
	_abrir("Mamá", [LARGA, "Línea dos de la prueba.", "Línea tres de la prueba."])
	var g: DialogoBalloon = null
	await _hasta(func() -> bool:
		_gm = _globo()
		return _gm != null and _gm.texto.is_typing)
	g = _gm
	await _esperar(0.3)
	# Una ráfaga de pulsaciones rápidas (cada una a menos de 0.15 s de la anterior) y repeticiones
	await _tecla(KEY_ENTER)   # completa
	await _tecla(KEY_ENTER)   # demasiado pronto: se ignora
	await _tecla(KEY_ENTER, true)
	await _tecla(KEY_ENTER, true)
	await _tecla(KEY_ENTER)
	_ok(_texto_de(g) == LARGA, "una ráfaga rápida solo completa el texto: sigue en la primera línea")
	await _esperar(0.3)
	await _tecla(KEY_ENTER)   # pasa a la línea dos
	await _hasta(func() -> bool: return _texto_de(g).begins_with("Línea dos"))
	await _tecla(KEY_ENTER)   # enseguida: se ignora
	await _tecla(KEY_ENTER, true)
	await _tecla(KEY_ENTER)
	_ok(_texto_de(g).begins_with("Línea dos"), "otra ráfaga rápida no pasa de la línea dos a la tres")
	# Mantenido: repeticiones durante un segundo no pasan nada
	var antes := _texto_de(g)
	for i in 20:
		await _tecla(KEY_ENTER, true)
		await get_tree().process_frame
	_ok(_texto_de(g) == antes, "mantener Enter pulsado (repetición) no pasa ninguna línea")
	await _cerrar_todo()


func _prueba_mundo() -> void:
	print("(d) Cerrar con Enter no abre otra interacción")
	_ok(not Dialogo.mundo_bloqueado(), "sin conversación el mundo no está bloqueado")
	var jugador: Player = (load("res://Scenes/Personajes/Player.tscn") as PackedScene).instantiate()
	add_child(jugador)
	await get_tree().process_frame
	var cuenta := [0]
	var falso := FalsoInteractuable.new()
	falso.al_interactuar = func() -> void: cuenta[0] += 1
	add_child(falso)
	jugador.interactuables = [falso]
	jugador.activo = falso
	# conversación corta cerrada con Enter
	_abrir("Mamá", "Hola.")
	var g: DialogoBalloon = null
	await _hasta(func() -> bool:
		_gm = _globo()
		return _gm != null and _gm.esperando_entrada)
	g = _gm
	await _esperar(0.3)
	await _tecla(KEY_ENTER)   # cierra
	await _hasta(func() -> bool: return _termino)
	_ok(Dialogo.mundo_bloqueado(), "justo al cerrar el mundo queda bloqueado")
	jugador.activo = falso
	await _tecla(KEY_E)
	_ok(cuenta[0] == 0, "la pulsación justo al cerrar NO abre otra interacción")
	await _esperar(0.35)
	_ok(not Dialogo.mundo_bloqueado(), "pasados 0.2 s el mundo responde otra vez")
	jugador.activo = falso
	await _tecla(KEY_E)
	_ok(cuenta[0] == 1, "E interactúa con normalidad")
	jugador.queue_free()
	falso.queue_free()
	await get_tree().process_frame


class FalsoInteractuable extends Node2D:
	var al_interactuar: Callable

	func puede_interactuar() -> bool:
		return true

	func interactuar() -> void:
		al_interactuar.call()


func _prueba_tarjeta() -> void:
	print("(e) Retroalimentación obligatoria")
	var cerrada := [false]
	var f := func() -> void:
		await TarjetaRetro.mostrar(get_tree(), "Ojo", "Dejaste el estante sin fijar.", "Fijar el estante a la pared.", "Un mueble alto sin fijar puede caerse durante un sismo.", true)
		cerrada[0] = true
	f.call()
	_tm = null
	await _hasta(func() -> bool:
		for h in get_tree().root.get_children():
			if h is TarjetaRetro:
				_tm = h
		return _tm != null)
	var tarjeta: TarjetaRetro = _tm
	await _esperar(0.4)
	_ok(tarjeta != null and tarjeta._fila_botones.modulate.a < 1.0, "la tarjeta escribe su texto: los botones aún no están")
	await _tecla(KEY_ENTER)
	_ok(not cerrada[0] and tarjeta._fila_botones.modulate.a >= 1.0, "Enter completa el texto y muestra los botones, sin cerrar la tarjeta")
	await _tecla(KEY_ENTER)   # enseguida
	await _tecla(KEY_ENTER, true)
	_ok(not cerrada[0], "una segunda pulsación rápida o mantenida no confirma nada")
	await _tecla(KEY_ESCAPE)
	await _tecla(KEY_TAB)
	_ok(not cerrada[0], "Esc y Tab no cierran la tarjeta")
	await _esperar(0.3)
	await _tecla(KEY_ENTER)   # confirma el botón enfocado
	var fin := await _hasta(func() -> bool: return cerrada[0])
	_ok(fin, "Enter confirma el botón enfocado cuando ya se pudo leer")
	await _esperar(0.3)


func _prueba_kit() -> void:
	print("(e) Kit: «Listo» solo con 8 objetos")
	var kit := KitUI.new()
	add_child(kit)
	await _esperar(0.5)
	var lista := [0]
	kit._boton_listo.pressed.connect(func() -> void: lista[0] += 1)
	_ok(kit._boton_listo.disabled, "con menos de 8 objetos el botón «Listo» está desactivado")
	await _tecla(KEY_ENTER)
	_ok(lista[0] == 0, "Enter no confirma el kit con menos de 8 objetos")
	var ids: Array = kit._botones.keys()
	for i in 8:
		kit._botones[ids[i]].button_pressed = true
	await get_tree().process_frame
	_ok(not kit._boton_listo.disabled, "con 8 objetos «Listo» se activa")
	await _tecla(KEY_ENTER, true)
	_ok(lista[0] == 0, "mantener Enter (repetición) no confirma")
	await _tecla(KEY_ENTER)
	_ok(lista[0] == 1, "Enter confirma «Listo» con 8 objetos")
	if is_instance_valid(kit):
		kit.queue_free()
	await _esperar(0.3)


func _prueba_cuestionario() -> void:
	print("(e) Cuestionario y resultados")
	var c := Cuestionario.new()
	c.solo_vista = true
	add_child(c)
	await _esperar(0.3)
	for codigo in [KEY_ESCAPE, KEY_TAB]:
		await _tecla(codigo)
	_ok(is_instance_valid(c) and c.is_inside_tree(), "Esc y Tab no cierran el cuestionario")
	_ok(Dialogo.debe_ignorarse(_evento_tecla(KEY_ENTER, true)), "una repetición de Enter se ignora en el cuestionario")
	c.queue_free()
	await get_tree().process_frame


func _evento_tecla(codigo: Key, eco: bool) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = codigo
	e.keycode = codigo
	e.pressed = true
	e.echo = eco
	return e
