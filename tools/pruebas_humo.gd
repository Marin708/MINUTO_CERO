extends Node
## Pruebas de humo de las pantallas, sin ventana: título, consentimiento, cuestionario inicial y final (contestados
## de verdad con los botones), resultados, código de resultados y créditos.
##   godot --headless --path . res://tools/pruebas_humo.tscn
## (El recorrido de los niveles y los finales está en pruebas_flujo.tscn y el estado en pruebas_estado.tscn;
## tools/ejecutar_pruebas.py corre las tres y cuenta las comprobaciones.)
## Respalda y restaura el archivo de guardado. Sale con código 0 si todo pasa.

var _fallos := 0
var _pruebas := 0


func _ready() -> void:
	var habia := FileAccess.file_exists(Estado.RUTA_GUARDADO)
	var respaldo := FileAccess.get_file_as_string(Estado.RUTA_GUARDADO) if habia else ""
	Estado.nueva_partida()
	Evaluacion.reiniciar()
	Dialogo.respuesta_de_prueba = -99

	await _titulo()
	await _consentimiento()
	await _cuestionarios_y_resultados()
	await _creditos()

	Estado.nueva_partida()
	Evaluacion.reiniciar()
	if habia:
		var f := FileAccess.open(Estado.RUTA_GUARDADO, FileAccess.WRITE)
		f.store_string(respaldo)
		f.close()
	elif FileAccess.file_exists(Estado.RUTA_GUARDADO):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Estado.RUTA_GUARDADO))
	print("Pruebas de humo: %d comprobaciones, %d fallos." % [_pruebas, _fallos])
	get_tree().quit(1 if _fallos > 0 else 0)


func _ok(condicion: bool, texto: String) -> void:
	_pruebas += 1
	if not condicion:
		_fallos += 1
	print("  %s %s" % ["ok   " if condicion else "FALLA", texto])


func _hasta(condicion: Callable, limite: float = 20.0) -> bool:
	var t := 0.0
	while t < limite:
		if condicion.call():
			return true
		await get_tree().process_frame
		t += get_process_delta_time()
	return condicion.call()


func _buscar(clase: Variant) -> Node:
	for h in get_tree().root.get_children():
		if is_instance_of(h, clase):
			return h
	return null


func _textos(nodo: Node) -> String:
	var s := ""
	if nodo is Label:
		s += (nodo as Label).text + "\n"
	elif nodo is Button:
		s += (nodo as Button).text + "\n"
	for h in nodo.get_children():
		s += _textos(h)
	return s


func _boton_con_texto(nodo: Node, texto: String) -> Button:
	if nodo is Button and (nodo as Button).text.begins_with(texto):
		return nodo
	for h in nodo.get_children():
		var b := _boton_con_texto(h, texto)
		if b != null:
			return b
	return null


# --- Título ---

func _titulo() -> void:
	print("Título")
	var escena: Node = (load("res://Scenes/UI/PantallaTitulo.tscn") as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(escena)
	await get_tree().process_frame
	await get_tree().process_frame
	escena._saltar_intro()
	await get_tree().process_frame
	var t := _textos(escena)
	_ok(t.contains("Comenzar") and t.contains("Continuar") and t.contains("Salir"), "el título tiene Comenzar, Continuar y Salir")
	_ok(t.contains("Prepararte hoy puede cambiar el minuto cero."), "el subtítulo es la frase central")
	_ok(escena.menu.visible, "el menú se muestra al saltar la entrada")
	_ok(escena.boton_continuar.visible == Estado.hay_partida_guardada(), "«Continuar» solo aparece si hay partida guardada")
	escena.queue_free()
	await get_tree().process_frame


# --- Consentimiento ---

func _consentimiento() -> void:
	print("Consentimiento")
	Consentimiento.mostrar(get_tree())
	_ok(await _hasta(func() -> bool: return _buscar(Consentimiento) != null, 3.0), "se abre el consentimiento")
	var c := _buscar(Consentimiento)
	_ok(_textos(c).contains("MINUTO CERO es un juego educativo"), "el texto habla de MINUTO CERO")
	_ok(Evaluacion.cuestionario_activo, "mientras está abierto no se abren menús (cuestionario_activo)")
	await get_tree().create_timer(0.7).timeout
	_boton_con_texto(c, "Acepto").pressed.emit()
	_ok(await _hasta(func() -> bool: return _buscar(Consentimiento) == null, 4.0), "se cierra al aceptar")
	_ok(Evaluacion.consentimiento_dado and Evaluacion.consentimiento_guardar, "aceptar guarda las respuestas")
	Consentimiento.mostrar(get_tree())
	await _hasta(func() -> bool: return _buscar(Consentimiento) != null, 3.0)
	await get_tree().create_timer(0.7).timeout
	_boton_con_texto(_buscar(Consentimiento), "Jugar sin guardar").pressed.emit()
	await _hasta(func() -> bool: return _buscar(Consentimiento) == null, 4.0)
	_ok(Evaluacion.consentimiento_dado and not Evaluacion.consentimiento_guardar, "«Jugar sin guardar» no guarda respuestas")
	Evaluacion.consentimiento_guardar = true   # el resto de las pruebas guarda


# --- Cuestionarios, resultados y código ---

## Contesta todo el cuestionario de la fase pulsando botones (siempre la primera opción que se muestra).
func _contestar(fase: String) -> bool:
	Cuestionario.mostrar(get_tree(), fase)
	var t := 0.0
	var vio_cuestionario := false
	var cancelado := false
	while t < 150.0:
		var c := _buscar(Cuestionario) as Cuestionario
		if c != null:
			vio_cuestionario = true
			if t < 5.0 and not cancelado:
				# ESC no cancela el cuestionario
				var esc := InputEventAction.new()
				esc.action = "PAUSA"
				esc.pressed = true
				Input.parse_input_event(esc)
				cancelado = true
			if c._panel_intro.visible and not c._boton_seguir.disabled:
				c._boton_seguir.pressed.emit()
			elif c._panel_pregunta.visible and not c._respondida and not c._botones.is_empty() and c._panel_pregunta.modulate.a > 0.9:
				c._botones[0].pressed.emit()
		elif vio_cuestionario:
			return true
		await get_tree().process_frame
		t += get_process_delta_time()
	return false


func _cuestionarios_y_resultados() -> void:
	print("Cuestionario inicial (14 preguntas, tarda un rato)")
	_ok(Evaluacion.valido, "el banco de preguntas es válido")
	_ok(await _contestar("pre"), "se contesta el cuestionario inicial hasta el final")
	_ok(Evaluacion.pre_completo(), "el cuestionario inicial queda completo")
	_ok(Evaluacion.pre["respuestas"].size() == 14, "se registran las 14 respuestas")
	var pre := Evaluacion.pre["puntajes"] as Dictionary
	_ok(int(pre["trivia"]) <= 7 and int(pre["situaciones"]) <= 5 and int(pre["escala"]) >= 2, "puntajes dentro de rango %s" % str(pre))
	Estado.forzar_resultado(12)
	print("Cuestionario final")
	_ok(await _contestar("post"), "se contesta el cuestionario final hasta el final")
	_ok(Evaluacion.post_completo(), "el cuestionario final queda completo")
	print("Resultados y código")
	Resultados.mostrar(get_tree())
	_ok(await _hasta(func() -> bool: return _buscar(Resultados) != null, 3.0), "se abre la pantalla de resultados")
	var r := _buscar(Resultados) as Resultados
	await get_tree().process_frame
	var t := _textos(r)
	_ok(t.contains("Tu viaje en números") and t.contains("Conocimiento"), "muestra los bloques con sus barras")
	_ok(t.contains("Tus 15 decisiones") and t.contains("Seguras al primer intento: 12 de 15"), "resume las 15 decisiones y las seguras al primer intento")
	_ok(t.contains("D1") and t.contains("D15"), "lista de D1 a D15")
	_ok(t.contains("Lo recomendado") and t.contains("Para reforzar") or t.contains("Segura al primer intento"), "muestra lo recomendado y el estado de cada decisión")
	_ok(r._codigo.begins_with("MC1:") and r._campo_codigo.text == r._codigo, "muestra el código MC1")
	var d := CodigoResultados.decodificar(r._codigo)
	_ok(bool(d["ok"]) and int(d["datos"]["s"]) == 12 and d["datos"]["fin"] == "p", "el código se decodifica (12 seguras, final preparado)")
	_ok(t.contains("Esto no es un examen oficial"), "texto neutro sin reproches")
	_ok(_boton_con_texto(r, "Copiar código") != null, "tiene el botón de copiar el código")
	_ok(_boton_con_texto(r, "Ver créditos") != null, "tiene el botón de créditos")
	r.queue_free()
	await get_tree().process_frame
	Evaluacion.cuestionario_activo = false


# --- Créditos ---

func _creditos() -> void:
	print("Créditos")
	Creditos.mostrar(get_tree())
	_ok(await _hasta(func() -> bool: return _buscar(Creditos) != null, 3.0), "se abren los créditos")
	var c := _buscar(Creditos)
	await get_tree().process_frame
	var t := _textos(c)
	_ok(t.contains("MINUTO CERO") and t.contains("Godot") and t.contains("Pixelify Sans"), "créditos: juego, Godot y la fuente")
	_ok(t.contains("ElevenLabs") and t.contains("no reemplaza los simulacros"), "créditos: sonido y la nota final")
	c.queue_free()
	await get_tree().process_frame
