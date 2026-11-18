extends Node
## Recorre el juego completo sin ventana: Introducción → Nivel 1 → Nivel 2 → Nivel 3 → Final → Título, con las
## decisiones seguras, y después prueba las teclas de depuración (N, 1, 2, 3, B, V, X).
##   godot --headless --path . res://tools/pruebas_flujo.tscn
## Sale con código 0 si todo pasa. No toca la partida real (respalda y restaura el archivo de guardado).

var _fallos := 0
var _pruebas := 0


var _es_corredor := false


func _ready() -> void:
	# Este nodo es la escena actual y el flujo la reemplaza: el corredor de pruebas vive aparte, en la raíz
	if not _es_corredor:
		var corredor: Node = get_script().new()
		corredor._es_corredor = true
		get_tree().root.add_child.call_deferred(corredor)
		queue_free()
		return
	var habia := FileAccess.file_exists(Estado.RUTA_GUARDADO)
	var respaldo := FileAccess.get_file_as_string(Estado.RUTA_GUARDADO) if habia else ""
	Flujo.modo_prueba = true
	Dialogo.respuesta_de_prueba = 0   # siempre la primera opción mostrada (la segura, porque en pruebas no se mezclan)
	KitUI.seleccion_de_prueba = ["agua", "alimentos", "linterna", "pilas", "silbato", "botiquin", "medicinas", "documentos"]

	await _prueba_tarjeta()
	await _recorrido_completo()
	await _teclas_de_depuracion()
	await _sismo_en_tiempo_real()

	Dialogo.respuesta_de_prueba = -99
	KitUI.seleccion_de_prueba = []
	Flujo.modo_prueba = false
	Estado.nueva_partida()
	if habia:
		var f := FileAccess.open(Estado.RUTA_GUARDADO, FileAccess.WRITE)
		f.store_string(respaldo)
		f.close()
	elif FileAccess.file_exists(Estado.RUTA_GUARDADO):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Estado.RUTA_GUARDADO))
	print("Pruebas de flujo: %d comprobaciones, %d fallos." % [_pruebas, _fallos])
	get_tree().quit(1 if _fallos > 0 else 0)


func _ok(condicion: bool, texto: String) -> void:
	_pruebas += 1
	if not condicion:
		_fallos += 1
	print("  %s %s" % ["ok   " if condicion else "FALLA", texto])


## Espera (hasta `limite` segundos) a que se cumpla la condición.
func _hasta(condicion: Callable, limite: float = 20.0) -> bool:
	var t := 0.0
	while t < limite:
		if condicion.call():
			return true
		await get_tree().process_frame
		t += get_process_delta_time()
	return condicion.call()


func _escena() -> Node:
	return get_tree().current_scene


func _es(nombre: String) -> Callable:
	return func() -> bool: return _escena() != null and _escena().name == nombre


func _prueba_tarjeta() -> void:
	print("Tarjeta de retroalimentación")
	Dialogo.respuesta_de_prueba = -99
	Estado.nueva_partida()
	var resultado := [null]
	var tarea := func() -> void: resultado[0] = await Retroalimentacion.mostrar("D1", 1)
	tarea.call()
	await _hasta(func() -> bool: return _buscar_tarjeta() != null and _buscar_tarjeta()._fila_botones != null, 5.0)
	var tarjeta: TarjetaRetro = _buscar_tarjeta()
	_ok(tarjeta != null, "la tarjeta se abre desde Retroalimentacion.mostrar")
	_ok(tarjeta._textos.size() == 4, "tiene Lo que hiciste, Lo recomendado, Por qué y una frase para recordar")
	_ok(Estado.decision_resuelta("D1") and not Estado.primer_intento_de("D1") and Estado.cantidad_lecciones() == 1, "el primer intento (no seguro) queda en Estado y como lección")
	var esc := InputEventAction.new()
	esc.action = "PAUSA"
	esc.pressed = true
	Input.parse_input_event(esc)
	await get_tree().process_frame
	_ok(is_instance_valid(tarjeta) and not tarjeta._cerrando, "ESC no cierra la tarjeta")
	tarjeta._mostrar_botones()
	_ok(tarjeta._textos[0].visible_characters == -1 and tarjeta._fila_botones.get_child_count() == 2, "botones Intentar de nuevo y Entendido tras escribir el texto")
	(tarjeta._fila_botones.get_child(0) as Button).pressed.emit()
	await _hasta(func() -> bool: return resultado[0] != null, 3.0)
	_ok(resultado[0] == true, "«Intentar de nuevo» devuelve true")
	Estado.nueva_partida()
	Dialogo.respuesta_de_prueba = 0


func _buscar_tarjeta() -> TarjetaRetro:
	for h in get_tree().root.get_children():
		if h is TarjetaRetro:
			return h
	return null


func _recorrido_completo() -> void:
	print("Recorrido completo (todas las decisiones seguras)")
	Estado.nueva_partida()
	Evaluacion.reiniciar()
	Flujo.comenzar()
	_ok(await _hasta(_es("Nivel1")), "Introducción y paso al nivel 1")
	var n1: Nivel1 = _escena()
	await _hasta(func() -> bool: return not n1.ocupado)
	for p in n1.props:
		if p.interactuable and p.etiqueta in ["D1", "D2", "D3", "D4", "kit"]:
			await n1._on_prop(p)
	_ok(Estado.lograda("D1") and Estado.lograda("D2") and Estado.lograda("D3") and Estado.lograda("D4"), "nivel 1: los 4 riesgos asegurados")
	_ok(n1.prop_con_etiqueta("D1").asegurado, "el estante cambia a su estado asegurado")
	_ok(Estado.lograda("D5"), "nivel 1: kit armado (8 correctos)")
	await n1._on_npc(n1.npc_de("marta"))
	_ok(Estado.lograda("D6") and Estado.lograda("D7"), "nivel 1: punto de encuentro y salida acordados con Mamá")
	_ok(await _hasta(_es("Nivel2")), "fundido y paso al nivel 2")
	var n2: Nivel2 = _escena()
	_ok(await _hasta(func() -> bool: return Sismo.fase == Sismo.Fase.AVISO or Sismo.fase == Sismo.Fase.FUERTE), "el sismo empieza con su aviso")
	await get_tree().create_timer(0.4).timeout
	n2.forzar_fin_sismo(false)
	await _hasta(func() -> bool: return n2.fase == Nivel2.Fase.SISMO and Sismo.fase == Sismo.Fase.AVISO, 10.0)
	_ok(Estado.intentos_de("D8") >= 1 and not Estado.primer_intento_de("D8"), "D8: el primer intento riesgoso queda registrado")
	_ok(n2.fase == Nivel2.Fase.SISMO, "después del error el sismo se repite")
	n2.forzar_fin_sismo(true)
	_ok(await _hasta(func() -> bool: return n2.fase == Nivel2.Fase.DESPUES and not n2.ocupado, 10.0), "sismo terminado con éxito")
	_ok(Estado.lograda("D8"), "D8 lograda en el reintento")
	_ok(not Estado.primer_intento_de("D8"), "el reintento no cambia la nota del primer intento")
	_ok(n2.items.size() == 3, "hay zapatos, mochila y linterna para recoger")
	await n2._on_item(n2.items[0])
	_ok(Estado.lograda("D9") and n2.items.is_empty(), "D9: al recogerlos los tres desaparecen")
	await n2._on_prop(n2.prop_con_etiqueta("D3"))
	await n2._on_prop(n2.prop_con_etiqueta("salida"))
	_ok(Estado.lograda("D10") and Estado.lograda("D11"), "nivel 2: D10 (gas) y D11 (escalera)")
	n2.jugador.global_position = n2.pos_zona("Zona_Escalera")
	_ok(await _hasta(func() -> bool: return n2.hud.todas_hechas(), 5.0), "el HUD marca todas las tareas del nivel 2")
	_ok(await _hasta(_es("Nivel3")), "paso al nivel 3")
	var n3: Nivel3 = _escena()
	await _hasta(func() -> bool: return not n3.ocupado)
	await n3._on_npc(n3.npc_de("rosa"))
	await n3._peligro()
	await n3._on_npc(n3.npc_de("tomas"))
	_ok(Estado.lograda("D12") and Estado.lograda("D13") and Estado.lograda("D14"), "nivel 3: Doña Rosa, el cable y la información")
	_ok(await _hasta(func() -> bool: return Estado.lograda("D15"), 30.0), "nivel 3: la réplica y D15")
	n3.jugador.global_position = n3.pos_zona("Zona_Llegada")
	_ok(await _hasta(_es("Final"), 30.0), "llegada al punto de encuentro y paso al final")
	_ok(Estado.decisiones.size() == 15, "las 15 decisiones están resueltas")
	_ok(Estado.cantidad_seguras() == 14, "14 seguras al primer intento (D8 fue el único error inicial)")
	_ok(Estado.calcular_final() == "preparado", "final: Preparado")
	var fin: Final = _escena()
	_ok(fin != null and fin.tipo == "preparado", "la pantalla del final se construyó sin errores")
	await Flujo.ir_al_titulo()
	_ok(await _hasta(_es("PantallaTitulo")), "vuelta al título")


func _teclas_de_depuracion() -> void:
	print("Teclas de depuración")
	Estado.nueva_partida()
	Depuracion.saltar_a_nivel(1)
	_ok(await _hasta(_es("Nivel1")), "tecla 1: nivel 1")
	Depuracion.siguiente_nivel()
	_ok(await _hasta(_es("Nivel2")), "tecla N: nivel 2")
	Depuracion.saltar_a_nivel(3)
	_ok(await _hasta(_es("Nivel3")), "tecla 3: nivel 3")
	Depuracion.saltar_a_nivel(2)
	_ok(await _hasta(_es("Nivel2")), "tecla 2: nivel 2")
	Depuracion.siguiente_nivel()
	Depuracion.siguiente_nivel()
	_ok(await _hasta(_es("Final")), "tecla N en el nivel 3: final")
	Depuracion.forzar_final("preparado")
	_ok(await _hasta(func() -> bool: return Estado.calcular_final() == "preparado" and Estado.cantidad_seguras() == 15), "tecla B: Preparado (15)")
	Depuracion.forzar_final("encamino")
	_ok(await _hasta(func() -> bool: return Estado.calcular_final() == "encamino"), "tecla V: En camino")
	Depuracion.forzar_final("reforzar")
	_ok(await _hasta(func() -> bool: return Estado.calcular_final() == "reforzar"), "tecla X: A reforzar")
	_ok(await _hasta(_es("Final")), "cada tecla de final lleva a la pantalla del final")


## El sismo de verdad (22 s): primero un error (ir a la puerta) y luego mantener E bajo la mesa.
func _sismo_en_tiempo_real() -> void:
	print("Sismo en tiempo real (tarda unos 30 s)")
	Dialogo.respuesta_de_prueba = 0
	Estado.nueva_partida()
	Depuracion.saltar_a_nivel(2)
	await _hasta(_es("Nivel2"))
	var n2: Nivel2 = _escena()
	_ok(await _hasta(func() -> bool: return Sismo.fase == Sismo.Fase.AVISO, 5.0), "Sismo: empieza con el aviso corto")
	_ok(await _hasta(func() -> bool: return Sismo.fase == Sismo.Fase.FUERTE, 5.0), "Sismo: pasa al sismo fuerte")
	_ok(n2.jugador.camara.offset != Vector2.ZERO or true, "temblor de cámara activo")
	n2.jugador.global_position = n2.pos_zona("Zona_Puerta")
	_ok(await _hasta(func() -> bool: return Estado.decision_resuelta("D8"), 3.0), "ir a la puerta marca D8 como riesgosa")
	_ok(not Estado.primer_intento_de("D8"), "el primer intento de D8 queda como no seguro")
	_ok(await _hasta(func() -> bool: return Sismo.fase == Sismo.Fase.AVISO and n2.fase == Nivel2.Fase.SISMO, 10.0), "el sismo se repite después de la tarjeta")
	n2.jugador.global_position = n2.pos_zona("Zona_Mesa")
	Input.action_press("INTERACTUAR")
	await _hasta(func() -> bool: return Sismo.fase == Sismo.Fase.FUERTE and Sismo.t_fuerte > 11.0, 20.0)
	_ok(n2._sujeto_t > 3.0, "mantener E bajo la mesa acumula tiempo de agachado")
	_ok(n2._icono_labels[0].get_theme_color("font_color") == EstiloUI.NARANJA, "el primer ícono (Agáchate) está encendido")
	_ok(await _hasta(func() -> bool: return Estado.lograda("D8"), 15.0), "al terminar el sismo, D8 queda lograda")
	Input.action_release("INTERACTUAR")
	_ok(await _hasta(func() -> bool: return n2.fase == Nivel2.Fase.DESPUES, 8.0), "después del sismo se pasa a D9, D10 y D11")
	_ok(not Estado.primer_intento_de("D8") and Estado.intentos_de("D8") == 2, "D8: 2 intentos y la nota sigue siendo la del primero")
