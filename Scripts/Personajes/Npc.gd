class_name Npc
extends Node2D
## Un personaje no jugable: Lucía, Marta (Mamá), Doña Rosa o Tomás.
##
## Usa Assets/Personajes/personajes.png (animaciones "normal" y "asustado", un cuadro cada una). Estará
## "asustado" durante el sismo y la réplica, y "normal" el resto del tiempo. El origen está en los pies
## (para el y-sort). Con E, Sami habla con él: emite `interactuado`.

signal interactuado(npc: Npc)

const FRAMES := {
	"lucia": "res://Resources/Personajes/frames_lucia.tres",
	"marta": "res://Resources/Personajes/frames_marta.tres",
	"rosa": "res://Resources/Personajes/frames_rosa.tres",
	"tomas": "res://Resources/Personajes/frames_tomas.tres",
}
const NOMBRES := {"lucia": "Lucía", "marta": "Mamá", "rosa": "Doña Rosa", "tomas": "Tomás"}

@export_enum("lucia", "marta", "rosa", "tomas") var personaje: String = "lucia"
## Si es falso, no se puede hablar con él (por ejemplo, mientras dura el sismo).
@export var interactuable: bool = true

var asustado: bool = false:
	set(valor):
		asustado = valor
		_actualizar_animacion()

@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _zona: Area2D = $Zona


func _ready() -> void:
	add_to_group("npc")
	_sprite.sprite_frames = load(FRAMES[personaje])
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_actualizar_animacion()


## El nombre que se muestra en el cuadro de diálogo.
func nombre() -> String:
	return str(NOMBRES[personaje])


func puede_interactuar() -> bool:
	return interactuable


## La llama Player al pulsar E.
func interactuar() -> void:
	interactuado.emit(self)


## Mira hacia un punto (voltea el sprite a la izquierda o a la derecha).
func mirar_a(punto: Vector2) -> void:
	_sprite.flip_h = punto.x < global_position.x


func _actualizar_animacion() -> void:
	if _sprite != null and _sprite.sprite_frames != null:
		_sprite.play(&"asustado" if asustado else &"normal")
