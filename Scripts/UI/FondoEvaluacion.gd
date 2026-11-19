class_name FondoEvaluacion
extends RefCounted
## El fondo común de las pantallas de la brigada (boletín, acuerdo, evaluaciones, resultados y créditos): una pantalla
## azul noche con grano de película y una viñeta suave. Se construye por código dentro de una CanvasLayer (viewport de 640x360).
## Ya no lleva a Lucía a un lado: ella habla por radio (marco de transmisión) en el cuadro de diálogo.

const COLOR_FONDO := EstiloUI.AZUL_NOCHE


## Añade el fondo. Devuelve un sprite oculto solo para mantener compatible a quien aún espera el de Lucía
## (Valoracion lo anima con play(); aquí no se ve nada).
static func crear(capa: CanvasLayer) -> AnimatedSprite2D:
	var fondo := ColorRect.new()
	fondo.color = COLOR_FONDO
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fondo.mouse_filter = Control.MOUSE_FILTER_STOP   # nada de debajo recibe clics
	capa.add_child(fondo)
	# Un velo más claro en el centro (viñeta) para que el papel destaque
	var vineta := ColorRect.new()
	vineta.color = Color(EstiloUI.PETROLEO, 0.35)
	vineta.set_anchors_preset(Control.PRESET_FULL_RECT)
	vineta.offset_left = 60
	vineta.offset_right = -60
	vineta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa.add_child(vineta)
	var grano := Grano.new()
	capa.add_child(grano)
	var fantasma := AnimatedSprite2D.new()
	fantasma.sprite_frames = SpriteFrames.new()
	fantasma.sprite_frames.add_animation(&"idle")
	fantasma.sprite_frames.add_animation(&"hablar")
	fantasma.visible = false
	capa.add_child(fantasma)
	return fantasma
