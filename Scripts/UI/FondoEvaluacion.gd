class_name FondoEvaluacion
extends RefCounted
## El fondo común de las pantallas de evaluación (consentimiento, cuestionarios y resultados): la ilustración
## del título (Assets/UI/fondo_titulo.png), oscurecida, y Lucía (la brigadista) a un lado. Se construye por
## código dentro de una CanvasLayer (viewport de 640x360).

const FONDO := "res://Assets/UI/fondo_titulo.png"
const PERSONAJES := "res://Assets/Personajes/personajes.png"
const POSICION_LUCIA := Vector2(78, 262)
const COLOR_VELO := Color(0.03, 0.12, 0.16, 0.55)


## Añade el fondo y devuelve el sprite de Lucía (animaciones "idle" y "hablar").
static func crear(capa: CanvasLayer) -> AnimatedSprite2D:
	if ResourceLoader.exists(FONDO):
		var fondo := TextureRect.new()
		fondo.texture = load(FONDO)
		fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
		fondo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		fondo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		fondo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		fondo.mouse_filter = Control.MOUSE_FILTER_STOP   # nada de debajo recibe clics
		capa.add_child(fondo)
	var velo := ColorRect.new()
	velo.color = COLOR_VELO
	velo.set_anchors_preset(Control.PRESET_FULL_RECT)
	velo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa.add_child(velo)
	var lucia := AnimatedSprite2D.new()
	lucia.sprite_frames = _frames_de_lucia()
	lucia.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	lucia.scale = Vector2(2.5, 2.5)
	lucia.position = POSICION_LUCIA
	lucia.play(&"idle")
	capa.add_child(lucia)
	# Lucía se mece suavemente
	var flote := lucia.create_tween().set_loops()
	flote.tween_property(lucia, "position:y", POSICION_LUCIA.y - 5.0, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	flote.tween_property(lucia, "position:y", POSICION_LUCIA.y, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return lucia


## Las animaciones de Lucía: el primer cuadro de personajes.png (normal). Mientras no exista la imagen, un cuadro
## de color (chaleco naranja sobre azul petróleo) hace de marcador temporal.
static func _frames_de_lucia() -> SpriteFrames:
	var textura: Texture2D
	if ResourceLoader.exists(PERSONAJES):
		var atlas := AtlasTexture.new()
		atlas.atlas = load(PERSONAJES)
		atlas.region = Rect2(0, 0, 64, 64)
		textura = atlas
	else:
		var imagen := Image.create(64, 64, false, Image.FORMAT_RGBA8)
		imagen.fill_rect(Rect2i(20, 8, 24, 52), Color("14414f"))
		imagen.fill_rect(Rect2i(20, 24, 24, 20), Color("ff8a2a"))
		imagen.fill_rect(Rect2i(24, 4, 16, 12), Color("fff4dc"))
		textura = ImageTexture.create_from_image(imagen)
	var frames := SpriteFrames.new()
	for nombre in [&"idle", &"hablar"]:
		if nombre != &"default":
			frames.add_animation(nombre)
		frames.set_animation_loop(nombre, true)
		frames.add_frame(nombre, textura)
	frames.remove_animation(&"default")
	return frames
