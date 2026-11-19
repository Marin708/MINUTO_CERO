extends SceneTree
## Escribe Resources/tema_minutocero.tres a partir de EstiloUI.construir_tema() (la identidad vive en EstiloUI.gd).
##   godot --headless --path . --script res://tools/generar_tema.gd

func _init() -> void:
	var tema := EstiloUI.construir_tema()
	var error := ResourceSaver.save(tema, EstiloUI.RUTA_TEMA)
	print("Tema guardado: ", EstiloUI.RUTA_TEMA, " (error ", error, ")")
	quit(0 if error == OK else 1)
