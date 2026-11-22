extends Node
## Saca una captura de pantalla de una escena (necesita ventana, no sirve con --headless):
##   godot --path . res://tools/captura.tscn -- res://Scenes/UI/Galeria.tscn salida.png [cuadros] [accion]
## Carga la escena, espera `cuadros` cuadros (60 por defecto), guarda el PNG a 640 x 360 y sale.
## accion: "dialogo" abre un diálogo de Lucía por radio; "globo" uno de Doña Rosa (para revisar los dos marcos).

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("Uso: captura.tscn -- ESCENA SALIDA.png [cuadros] [accion]")
		get_tree().quit(1)
		return
	var cuadros: int = int(args[2]) if args.size() > 2 else 60
	var accion := args[3] if args.size() > 3 else ""
	var escena: Node = (load(args[0]) as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(escena)
	await get_tree().process_frame
	if accion == "dialogo":
		Dialogo.mostrar_texto("Lucía", "Aquí Lucía, canal 3. Revisa primero lo que pueda caerse.", ["Entendido", "Repite, por favor"])
	elif accion == "globo":
		Dialogo.mostrar_texto("Doña Rosa", "Ay, mijo, ¿me ayudas con la bolsa?", ["Sí, con cuidado", "No puedo ahora"])
	elif accion == "globo_texto":
		Dialogo.mostrar_texto("Doña Rosa", "Ay, mijo, ¿me ayudas con la bolsa? Pesa mucho para mí.")
	elif accion == "radio_texto":
		Dialogo.mostrar_texto("Lucía", "Aquí Lucía, canal 3. Revisa primero lo que pueda caerse.")
	elif accion == "retro":
		Retroalimentacion.tarjeta("Ojo", "Dejaste el estante sin fijar.", "Fijar el estante a la pared.", "Un mueble alto sin fijar puede caerse durante un sismo.", true)
	elif accion == "libreta":
		Estado.registrar_decision("D1", true)
		Menus.libreta.abrir()
	elif accion == "pausa":
		Menus.abrir_pausa()
	elif accion == "banner":
		Notificacion.mostrar("Tarjeta de memoria desbloqueada", "Mira tu libreta para leerla.")
	elif accion == "banner3":
		Notificacion.mostrar("Memoria de 1999", "Nueva tarjeta en tu libreta (Tab). Cada nivel desbloquea una tarjeta en homenaje al terremoto del Eje Cafetero.")
		Notificacion.mostrar("Listo", "Zapatos cerrados, mochila y linterna contigo.")
		Notificacion.mostrar("Tarjeta de memoria desbloqueada", "Mira tu libreta para leerla.")
	elif accion == "libreta_avisos":
		Estado.segundos_juego = 125.0
		Estado.registrar_aviso("Memoria de 1999", "Nueva tarjeta en tu libreta (Tab).")
		Estado.segundos_juego = 301.0
		Estado.registrar_aviso("Listo", "Zapatos cerrados, mochila y linterna contigo.")
		Menus.libreta.abrir()
		Menus.libreta._elegir(4)
	elif accion == "acuerdo":
		Consentimiento.mostrar(get_tree())
	elif accion == "evaluacion":
		Cuestionario.mostrar(get_tree(), "pre")
	elif accion == "pregunta":
		Cuestionario.mostrar(get_tree(), "pre")
		var respondidas := 0
		for i in 4000:
			await get_tree().process_frame
			var c := get_tree().root.get_node_or_null("Cuestionario") as Cuestionario
			if c == null:
				for h in get_tree().root.get_children():
					if h is Cuestionario:
						c = h
			if c == null:
				continue
			if c._panel_intro.visible and not c._boton_seguir.disabled:
				c._boton_seguir.pressed.emit()
			elif c._panel_pregunta.visible and not c._respondida and c._panel_pregunta.modulate.a > 0.9:
				if respondidas < 3:
					c._botones[0].pressed.emit()
					respondidas += 1
				else:
					for k in 20:
						await get_tree().process_frame
					break
		cuadros = 0
	elif accion.begins_with("galeria"):
		Galeria.alternar(get_tree())
		if accion.length() > 7:
			Galeria.actual().ir_a_pagina(int(accion.substr(8)) - 1)
	elif accion == "kit":
		KitUI.mostrar(get_tree())
	elif accion == "retro_kit":
		var ids := ["agua", "alimentos", "linterna", "pilas", "silbato", "botiquin", "vela", "televisor"]
		Estado.registrar_decision("D5", false)
		Retroalimentacion.tarjeta("Ojo", "", "Medicinas de uso diario, Documentos en bolsa impermeable", str(Estado.datos_decision("D5")["retro"]), true, KitUI.lista_elegidos(ids))
	elif accion == "valoracion":
		Valoracion.mostrar(get_tree())
	elif accion == "creditos":
		Creditos.mostrar(get_tree())
	elif accion == "resultados":
		Estado.forzar_resultado(12)
		Resultados.mostrar(get_tree())
	elif accion == "indicador":
		Estado.nivel_actual = 1
	for i in cuadros:
		await get_tree().process_frame
	var imagen := get_viewport().get_texture().get_image()
	imagen.save_png(args[1])
	print("Captura guardada en ", args[1], " (", imagen.get_size(), ")")
	get_tree().quit()
