extends Node
## Estado de la partida de MINUTO CERO (adaptado de GameState de ECOS).
##
## Guarda las decisiones (por id, con primer_intento e intentos), las lecciones aprendidas, el nivel actual y las
## tarjetas de memoria desbloqueadas. La nota de cada decisión es solo la del PRIMER intento: 1 punto si fue
## segura, 0 si no. Los reintentos no suman, pero sí quedan como lección aprendida en la libreta.
## El final se calcula con los umbrales de Resources/contenido/finales.json.

signal decision_registrada(id: String, segura: bool, primer_intento: bool)
signal leccion_aprendida(id: String)
signal nivel_cambiado(nivel: int)
signal tarjeta_desbloqueada(id: String)
signal final_calculado(id: String)
signal partida_reiniciada
signal partida_cargada

const RUTA_GUARDADO := "user://minutocero_save.json"
const CARPETA_CONTENIDO := "res://Resources/contenido/"
const NIVELES := 3
const TOTAL_DECISIONES := 15

## id ("D1"...) -> {"primer_intento": bool, "intentos": int}
var decisiones: Dictionary = {}
## ids de las decisiones cuya retroalimentación ya se recibió (sin repetir, en orden).
var lecciones: Array[String] = []
var nivel_actual: int = 1
## ids de las tarjetas de memoria desbloqueadas ("mem1"...).
var tarjetas: Array[String] = []

var _decisiones_datos: Dictionary = {}
var _finales: Array = []
var _tarjetas_datos: Array = []


func _ready() -> void:
	_cargar_contenido()
	nueva_partida()
	# Solo en depuración: revisa que los JSON de contenido estén completos y bien armados
	if OS.is_debug_build():
		for error in ValidadorContenido.validar():
			push_error("Contenido: %s" % error)


# --- Contenido ---

func _leer_json(nombre: String) -> Dictionary:
	var datos: Variant = JSON.parse_string(FileAccess.get_file_as_string(CARPETA_CONTENIDO + nombre))
	return datos if typeof(datos) == TYPE_DICTIONARY else {}


func _cargar_contenido() -> void:
	_decisiones_datos.clear()
	for d in _leer_json("decisiones.json").get("decisiones", []):
		_decisiones_datos[str(d["id"])] = d
	_finales = _leer_json("finales.json").get("finales", [])
	_tarjetas_datos = _leer_json("memoria.json").get("tarjetas", [])


## Los ids de las 15 decisiones, en orden (D1 a D15).
func ids_decisiones() -> Array[String]:
	var ids: Array[String] = []
	for n in range(1, TOTAL_DECISIONES + 1):
		ids.append("D%d" % n)
	return ids


## Los datos de una decisión del JSON ({} si no existe).
func datos_decision(id: String) -> Dictionary:
	return _decisiones_datos.get(id, {})


func ids_de_nivel(nivel: int) -> Array[String]:
	var ids: Array[String] = []
	for id in ids_decisiones():
		if int(datos_decision(id).get("nivel", 0)) == nivel:
			ids.append(id)
	return ids


# --- Decisiones ---

## Anota un intento de una decisión. El primero fija la nota (primer_intento); los demás solo suben "intentos".
## Toda retroalimentación recibida queda como lección aprendida. Devuelve true si este fue el primer intento.
func registrar_decision(id: String, segura: bool) -> bool:
	if not _decisiones_datos.has(id):
		push_warning("Estado: la decisión '%s' no existe." % id)
		return false
	var es_primero := not decisiones.has(id)
	if es_primero:
		decisiones[id] = {"primer_intento": segura, "intentos": 1}
	else:
		decisiones[id]["intentos"] = int(decisiones[id]["intentos"]) + 1
	decision_registrada.emit(id, segura, es_primero)
	if not lecciones.has(id):
		lecciones.append(id)
		leccion_aprendida.emit(id)
	return es_primero


func decision_resuelta(id: String) -> bool:
	return decisiones.has(id)


func intentos_de(id: String) -> int:
	return int(decisiones.get(id, {}).get("intentos", 0))


## true si la decisión se acertó al primer intento.
func primer_intento_de(id: String) -> bool:
	return bool(decisiones.get(id, {}).get("primer_intento", false))


## Cuántas decisiones fueron seguras al primer intento (0 a 15).
func cantidad_seguras() -> int:
	var n := 0
	for id in decisiones:
		if bool(decisiones[id]["primer_intento"]):
			n += 1
	return n


func cantidad_resueltas() -> int:
	return decisiones.size()


func cantidad_lecciones() -> int:
	return lecciones.size()


# --- Final ---

## El id del final según el puntaje: "preparado", "encamino" o "reforzar" (umbrales de finales.json).
func calcular_final() -> String:
	var puntos := cantidad_seguras()
	for f in _finales:
		if puntos >= int(f["minimo"]) and puntos <= int(f["maximo"]):
			return str(f["id"])
	return "reforzar"


## Los datos del final ({id, nombre, minimo, maximo, mensaje}); por defecto, el calculado.
func datos_final(id: String = "") -> Dictionary:
	var buscado := id if id != "" else calcular_final()
	for f in _finales:
		if str(f["id"]) == buscado:
			return f
	return {}


func terminar_juego() -> String:
	var id := calcular_final()
	final_calculado.emit(id)
	return id


## SOLO PRUEBAS Y DEPURACIÓN: deja las 15 decisiones resueltas con `seguras` aciertos al primer intento.
func forzar_resultado(seguras: int) -> void:
	decisiones.clear()
	lecciones.clear()
	var ids := ids_decisiones()
	for i in ids.size():
		decisiones[ids[i]] = {"primer_intento": i < seguras, "intentos": 1}
		lecciones.append(ids[i])


# --- Niveles y memoria ---

func ir_a_nivel(nivel: int) -> void:
	nivel_actual = clampi(nivel, 1, NIVELES)
	nivel_cambiado.emit(nivel_actual)


## Desbloquea la tarjeta de memoria del nivel (una por nivel). Devuelve su id, o "" si ya estaba.
func desbloquear_tarjeta_de_nivel(nivel: int) -> String:
	for t in _tarjetas_datos:
		if int(t["nivel"]) == nivel:
			var id := str(t["id"])
			if tarjetas.has(id):
				return ""
			tarjetas.append(id)
			tarjeta_desbloqueada.emit(id)
			return id
	return ""


func tarjeta_desbloqueada_id(id: String) -> bool:
	return tarjetas.has(id)


# --- Partida ---

## Reinicia todo el progreso.
func nueva_partida() -> void:
	decisiones.clear()
	lecciones.clear()
	tarjetas.clear()
	nivel_actual = 1
	partida_reiniciada.emit()


## Guarda la partida de forma segura: escribe un archivo temporal y lo renombra (así, si algo falla a
## medias, la partida anterior no se estropea). Devuelve true si se pudo guardar.
func guardar() -> bool:
	var contenido := {
		"version": 1,
		"nivel_actual": nivel_actual,
		"decisiones": decisiones,
		"lecciones": lecciones,
		"tarjetas": tarjetas,
		"evaluacion": Evaluacion.a_diccionario(),
	}
	# En la web se escribe directo al archivo final: el almacenamiento del navegador (IndexedDB) se sincroniza al
	# cerrar el archivo, y un renombrado posterior no lo dispararía. En escritorio se usa el archivo temporal.
	var en_web := OS.has_feature("web")
	var temporal := RUTA_GUARDADO if en_web else RUTA_GUARDADO + ".tmp"
	var archivo := FileAccess.open(temporal, FileAccess.WRITE)
	if archivo == null:
		push_error("Estado: no se pudo guardar (error %d)." % FileAccess.get_open_error())
		return false
	archivo.store_string(JSON.stringify(contenido, "\t"))
	archivo.close()
	if en_web:
		return true
	var error := DirAccess.rename_absolute(ProjectSettings.globalize_path(temporal), ProjectSettings.globalize_path(RUTA_GUARDADO))
	if error != OK:
		push_error("Estado: no se pudo terminar de guardar (error %d)." % error)
		return false
	return true


## true si existe un archivo de guardado (no carga nada; sirve para mostrar "Continuar").
func hay_partida_guardada() -> bool:
	return FileAccess.file_exists(RUTA_GUARDADO)


## Estado del archivo de guardado: "falta" (no existe), "danada" (no se puede leer) o "ok".
func diagnosticar_partida() -> String:
	if not FileAccess.file_exists(RUTA_GUARDADO):
		return "falta"
	var lectura: Variant = _leer_partida()
	if typeof(lectura) != TYPE_DICTIONARY or typeof(lectura.get("decisiones", null)) != TYPE_DICTIONARY:
		return "danada"
	return "ok"


## Lee y entiende el JSON del archivo de guardado. Devuelve null si no se puede (sin ensuciar la consola).
func _leer_partida() -> Variant:
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(RUTA_GUARDADO)) != OK:
		return null
	return json.data


## Carga la partida guardada. Devuelve true si se cargó. Si el archivo falta o está dañado no cambia nada y
## devuelve false. Cada dato se comprueba: lo que no tenga el tipo esperado se ignora en vez de romper el juego.
func cargar() -> bool:
	if diagnosticar_partida() != "ok":
		if FileAccess.file_exists(RUTA_GUARDADO):
			push_warning("Estado: el archivo de guardado está dañado.")
		return false
	var lectura: Dictionary = _leer_partida()
	nueva_partida()
	var nivel: Variant = lectura.get("nivel_actual", 1)
	nivel_actual = clampi(int(nivel), 1, NIVELES) if typeof(nivel) in [TYPE_INT, TYPE_FLOAT] else 1
	# Solo se aceptan decisiones que existen, con la forma esperada
	var guardadas: Dictionary = lectura["decisiones"]
	for id in guardadas:
		var d: Variant = guardadas[id]
		if _decisiones_datos.has(str(id)) and typeof(d) == TYPE_DICTIONARY:
			var intentos: Variant = d.get("intentos", 1)
			decisiones[str(id)] = {
				"primer_intento": typeof(d.get("primer_intento", false)) == TYPE_BOOL and d["primer_intento"],
				"intentos": maxi(int(intentos), 1) if typeof(intentos) in [TYPE_INT, TYPE_FLOAT] else 1,
			}
	for id in _lista(lectura, "lecciones"):
		if _decisiones_datos.has(str(id)) and not lecciones.has(str(id)):
			lecciones.append(str(id))
	for t in _tarjetas_datos:
		if _lista(lectura, "tarjetas").has(t["id"]) and not tarjetas.has(str(t["id"])):
			tarjetas.append(str(t["id"]))
	# La evaluación (pre, consentimiento...) vuelve a su sitio; el "pre" ya hecho no se repite
	Evaluacion.desde_diccionario(lectura.get("evaluacion", null))
	nivel_cambiado.emit(nivel_actual)
	partida_cargada.emit()
	return true


## El valor de `clave` si es una lista; si no, una lista vacía.
func _lista(datos: Dictionary, clave: String) -> Array:
	var valor: Variant = datos.get(clave, [])
	return valor if typeof(valor) == TYPE_ARRAY else []
