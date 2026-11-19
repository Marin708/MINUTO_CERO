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
	var cuadros := int(args[2]) if args.size() > 2 else 60
	var accion := args[3] if args.size() > 3 else ""
	var escena: Node = (load(args[0]) as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(escena)
	await get_tree().process_frame
	if accion == "dialogo":
		Dialogo.mostrar_texto("Lucía", "Aquí Lucía, canal 3. Revisa primero lo que pueda caerse.", ["Entendido", "Repite, por favor"])
	elif accion == "globo":
		Dialogo.mostrar_texto("Doña Rosa", "Ay, mijo, ¿me ayudas con la bolsa?", ["Sí, con cuidado", "No puedo ahora"])
	elif accion == "retro":
		Retroalimentacion.tarjeta("Ojo", "Dejaste el estante sin fijar.", "Fijar el estante a la pared.", "Un mueble alto sin fijar puede caerse durante un sismo.", true)
	elif accion == "libreta":
		Estado.registrar_decision("D1", true)
		Menus.libreta.abrir()
	elif accion == "pausa":
		Menus.abrir_pausa()
	elif accion == "banner":
		Notificacion.mostrar("Tarjeta de memoria desbloqueada", "Mira tu libreta para leerla.")
	elif accion == "indicador":
		Estado.nivel_actual = 1
	for i in cuadros:
		await get_tree().process_frame
	var imagen := get_viewport().get_texture().get_image()
	imagen.save_png(args[1])
	print("Captura guardada en ", args[1], " (", imagen.get_size(), ")")
	get_tree().quit()
