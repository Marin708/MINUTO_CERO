class_name ObjetoSuelo
extends Node2D
## Un objeto pequeño que Sami recoge del piso con E (los zapatos, la mochila y la linterna del nivel 2).
## Todavía no tienen arte propio: se dibujan con _draw (la linterna usa su ícono de kit.png y los otros dos, un cuadro
## de color con su nombre) hasta que haya imágenes. El origen está en la base.

signal interactuado(objeto: ObjetoSuelo)

const DATOS := {
	"zapatos": {"nombre": "Zapatos cerrados", "color": Color("ff8a2a"), "icono": -1},
	"mochila": {"nombre": "Mochila", "color": Color("1d5566"), "icono": -1},
	"linterna": {"nombre": "Linterna", "color": Color("ffd166"), "icono": 2},
}

@export_enum("zapatos", "mochila", "linterna") var tipo: String = "zapatos"

var _textura: AtlasTexture


func _ready() -> void:
	add_to_group("interactuables")
	var zona := Area2D.new()
	zona.collision_layer = 2
	zona.collision_mask = 0
	var forma := CollisionShape2D.new()
	var circulo := CircleShape2D.new()
	circulo.radius = 22.0
	forma.shape = circulo
	forma.position = Vector2(0, -8)
	zona.add_child(forma)
	add_child(zona)
	var icono: int = DATOS[tipo]["icono"]
	if icono >= 0:
		_textura = AtlasTexture.new()
		_textura.atlas = load("res://Assets/UI/kit.png")
		_textura.region = Rect2((icono % 4) * 32, (icono / 4) * 32, 32, 32)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _draw() -> void:
	draw_set_transform(Vector2(0, -1), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 12.0, Color(0, 0, 0, 0.25))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _textura != null:
		draw_texture(_textura, Vector2(-16, -30))
		return
	var color: Color = DATOS[tipo]["color"]
	draw_rect(Rect2(-12, -20, 24, 18), color)
	draw_rect(Rect2(-12, -20, 24, 18), Color("fff4dc"), false, 1.0)
	var fuente := EstiloUI.fuente()
	if fuente != null:
		draw_string(fuente, Vector2(-14, -24), str(DATOS[tipo]["nombre"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("fff4dc"))


func nombre() -> String:
	return str(DATOS[tipo]["nombre"])


func puede_interactuar() -> bool:
	return true


func interactuar() -> void:
	interactuado.emit(self)
