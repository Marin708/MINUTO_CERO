class_name ConjuntoTiles
extends RefCounted
## Construye por código el TileSet de MINUTO CERO (Assets/Mundo/tileset.png, tiles de 32 px) y pinta los mapas de
## texto de Resources/Mundo/*.txt en un TileMapLayer. Los números de tile son los de tools/generar_tileset.py.

const RUTA_HOJA := "res://Assets/Mundo/tileset.png"
const LADO := 32
const COLUMNAS := 8

## carácter del .txt -> número de tile en la hoja
const TILE_DE := {
	".": 0, "F": 1, "K": 2, "B": 3, "P": 4, "V": 5, "D": 6, "S": 7, "A": 8, "c": 9, "l": 10, "a": 11,
	"g": 12, "p": 13, "x": 14, "m": 15,
}
## capa de daños: carácter -> número de tile
const TILE_DANOS := {"r": 16, "u": 17, "v": 18, "e": 19}
## Tiles que bloquean el paso: vacío, pared, ventana, borde y muro de edificio.
const SOLIDOS := [0, 4, 5, 14, 15]

static var _tileset: TileSet


## El TileSet (se crea una sola vez): una capa de física "mundo" (capa 1) y colisión completa en los sólidos.
static func tileset() -> TileSet:
	if _tileset != null:
		return _tileset
	var ts := TileSet.new()
	ts.tile_size = Vector2i(LADO, LADO)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)
	ts.set_physics_layer_collision_mask(0, 0)
	var fuente := TileSetAtlasSource.new()
	fuente.texture = load(RUTA_HOJA)
	fuente.texture_region_size = Vector2i(LADO, LADO)
	ts.add_source(fuente, 0)
	var total := TILE_DE.size() + TILE_DANOS.size()
	var cuadro := PackedVector2Array([Vector2(-16, -16), Vector2(16, -16), Vector2(16, 16), Vector2(-16, 16)])
	for i in total:
		var coords := Vector2i(i % COLUMNAS, i / COLUMNAS)
		fuente.create_tile(coords)
		if SOLIDOS.has(i):
			var datos := fuente.get_tile_data(coords, 0)
			datos.add_collision_polygon(0)
			datos.set_collision_polygon_points(0, 0, cuadro)
	_tileset = ts
	return ts


## Lee un .txt de mapa (ignora las líneas que empiezan con ';'). Devuelve una lista de filas.
static func leer_mapa(ruta: String) -> PackedStringArray:
	var filas := PackedStringArray()
	for linea in FileAccess.get_file_as_string(ruta).split("\n"):
		var l := linea.strip_edges(false, true)
		if l != "" and not l.begins_with(";"):
			filas.append(l)
	return filas


## Pinta las filas en una capa nueva y la devuelve. `tabla` es TILE_DE o TILE_DANOS; con `colision` falso la capa no bloquea.
static func pintar(filas: PackedStringArray, tabla: Dictionary, con_colision: bool = true) -> TileMapLayer:
	var capa := TileMapLayer.new()
	capa.tile_set = tileset()
	capa.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	capa.collision_enabled = con_colision
	for y in filas.size():
		for x in filas[y].length():
			var ch := filas[y][x]
			if tabla.has(ch):
				var i: int = tabla[ch]
				capa.set_cell(Vector2i(x, y), 0, Vector2i(i % COLUMNAS, i / COLUMNAS))
	return capa


## El tamaño en píxeles de un mapa de texto.
static func tamano(filas: PackedStringArray) -> Vector2:
	var ancho := 0
	for f in filas:
		ancho = maxi(ancho, f.length())
	return Vector2(ancho * LADO, filas.size() * LADO)
