class_name Retratos
extends Resource
## Los retratos de los personajes (Assets/Personajes/retratos.png: 384 x 192, retratos de 96 x 96, 4 columnas x 2 filas).
## Cada uno es un AtlasTexture de Resources/Personajes/retratos.tres. Se usan a 1x o 2x (múltiplos enteros), nunca suavizados.
##
##   Retratos.obtener("lucia_hablando")         el retrato por su nombre
##   Retratos.de_hablante("Doña Rosa")           el retrato normal del que habla en un diálogo (o null)

const RUTA := "res://Resources/Personajes/retratos.tres"
const NOMBRES: Array[String] = ["lucia_neutral", "lucia_hablando", "sami_neutral", "sami_preocupado", "marta", "rosa", "tomas", "lucia_alerta"]
## Nombre que sale en el cuadro de diálogo -> retrato normal.
const DE_HABLANTE := {"Lucía": "lucia_neutral", "Sami": "sami_neutral", "Mamá": "marta", "Doña Rosa": "rosa", "Tomás": "tomas"}

@export var lucia_neutral: AtlasTexture
@export var lucia_hablando: AtlasTexture
@export var sami_neutral: AtlasTexture
@export var sami_preocupado: AtlasTexture
@export var marta: AtlasTexture
@export var rosa: AtlasTexture
@export var tomas: AtlasTexture
@export var lucia_alerta: AtlasTexture

static var _recurso: Retratos


static func obtener(nombre: String) -> Texture2D:
	if _recurso == null and ResourceLoader.exists(RUTA):
		_recurso = load(RUTA)
	if _recurso == null or not (nombre in NOMBRES):
		return null
	return _recurso.get(nombre)


static func de_hablante(personaje: String) -> Texture2D:
	return obtener(DE_HABLANTE.get(personaje, ""))


## Recorte del rostro a 1x (sin escalar) para ponerlo junto a un nombre: 48 x 48 píxeles.
static func rostro(nombre: String) -> Texture2D:
	var base := obtener(nombre) as AtlasTexture
	if base == null:
		return null
	var r := AtlasTexture.new()
	r.atlas = base.atlas
	r.region = Rect2(base.region.position + Vector2(24, 6), Vector2(48, 48))
	return r
