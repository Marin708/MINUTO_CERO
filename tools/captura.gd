extends Node
## Guarda una captura de un nivel: godot --path . res://tools/captura.tscn -- res://Scenes/Niveles/Nivel1.tscn C:/ruta/salida.png
## (necesita ventana; no sirve en modo headless). Opcional: tercer argumento "danos" no hace falta, el nivel 2 ya los trae.

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var escena: PackedScene = load(args[0])
	var nivel := escena.instantiate()
	get_tree().root.add_child.call_deferred(nivel)
	await get_tree().create_timer(0.45).timeout
	for i in range(1, args.size() - 1):
		pass
	var imagen := get_viewport().get_texture().get_image()
	imagen.save_png(args[1])
	print("captura guardada en ", args[1])
	get_tree().quit()

