class_name ValidadorContenido
extends RefCounted
## Revisa los JSON de Resources/contenido/ (la misma lógica que tools/validar_contenido.py).
## Estado la llama al arrancar en modo de depuración. Devuelve la lista de errores (vacía = todo bien).

const CARPETA := "res://Resources/contenido/"


## Lee un JSON; devuelve {} si falta o no se puede entender (y anota el error).
static func _leer(nombre: String, errores: Array[String]) -> Dictionary:
	var ruta := CARPETA + nombre
	if not FileAccess.file_exists(ruta):
		errores.append("%s: no existe." % nombre)
		return {}
	var datos: Variant = JSON.parse_string(FileAccess.get_file_as_string(ruta))
	if typeof(datos) != TYPE_DICTIONARY:
		errores.append("%s: no se pudo leer." % nombre)
		return {}
	return datos


static func _texto_ok(valor: Variant) -> bool:
	return typeof(valor) == TYPE_STRING and str(valor).strip_edges() != ""


static func _lista(d: Dictionary, clave: String) -> Array:
	var valor: Variant = d.get(clave, [])
	return valor if typeof(valor) == TYPE_ARRAY else []


## Anota los ids repetidos o vacíos de una lista de diccionarios.
static func _ids_unicos(nombre: String, lista: Array, errores: Array[String], clave := "id") -> Dictionary:
	var vistos := {}
	for e in lista:
		var id: Variant = e.get(clave, null) if typeof(e) == TYPE_DICTIONARY else null
		if not _texto_ok(id):
			errores.append("%s: hay un elemento sin '%s'." % [nombre, clave])
		elif vistos.has(id):
			errores.append("%s: el id '%s' está repetido." % [nombre, id])
		else:
			vistos[id] = true
	return vistos


static func validar() -> Array[String]:
	var errores: Array[String] = []
	_preguntas(errores)
	_decisiones(errores)
	_kit(errores)
	_cantidad("mitos.json", "mitos", 7, ["id", "mito", "realidad"], errores)
	_cantidad("memoria.json", "tarjetas", 3, ["id", "titulo", "texto"], errores)
	_finales(errores)
	_cantidad("plan.json", "pasos", 5, ["texto"], errores)
	return errores


static func _preguntas(errores: Array[String]) -> void:
	var d := _leer("preguntas.json", errores)
	var esperado := {"trivia": 7, "situaciones": 5, "escala": 2}
	var todas: Array = []
	for bloque in esperado:
		var lista := _lista(d, bloque)
		if lista.size() != int(esperado[bloque]):
			errores.append("preguntas.json: '%s' debe tener %d y tiene %d." % [bloque, esperado[bloque], lista.size()])
		todas.append_array(lista)
		for p in lista:
			var pid := str(p.get("id", "?"))
			if not _texto_ok(p.get("texto", null)):
				errores.append("preguntas.json: '%s' no tiene texto." % pid)
			if bloque == "escala":
				if int(p.get("valores", 0)) < 2:
					errores.append("preguntas.json: '%s' necesita 'valores' de 2 o más." % pid)
				continue
			var opciones := _lista(p, "opciones")
			if opciones.size() < 2:
				errores.append("preguntas.json: '%s' necesita 2 o más opciones." % pid)
			for o in opciones:
				if not _texto_ok(o):
					errores.append("preguntas.json: '%s' tiene una opción vacía." % pid)
			var correcta: Variant = p.get("correcta", null)
			if typeof(correcta) not in [TYPE_INT, TYPE_FLOAT] or int(correcta) < 0 or int(correcta) >= opciones.size():
				errores.append("preguntas.json: '%s' tiene 'correcta' fuera de rango." % pid)
			if bloque == "trivia" and not _texto_ok(p.get("explicacion", null)):
				errores.append("preguntas.json: '%s' (trivia) no tiene explicación." % pid)
	_ids_unicos("preguntas.json", todas, errores)


static func _decisiones(errores: Array[String]) -> void:
	var lista := _lista(_leer("decisiones.json", errores), "decisiones")
	var ids := _ids_unicos("decisiones.json", lista, errores)
	for n in range(1, 16):
		if not ids.has("D%d" % n):
			errores.append("decisiones.json: falta D%d." % n)
	for e in lista:
		var did := str(e.get("id", "?"))
		if int(e.get("nivel", 0)) not in [1, 2, 3]:
			errores.append("decisiones.json: %s tiene un nivel no válido." % did)
		if not _texto_ok(e.get("situacion", null)) or not _texto_ok(e.get("retro", null)):
			errores.append("decisiones.json: %s necesita situación y retroalimentación." % did)
		if str(e.get("tipo", "")) == "kit":
			continue
		var opciones := _lista(e, "opciones")
		if opciones.size() < 2:
			errores.append("decisiones.json: %s necesita 2 o más opciones." % did)
		for o in opciones:
			if not _texto_ok(o):
				errores.append("decisiones.json: %s tiene una opción vacía." % did)
		var segura: Variant = e.get("segura", null)
		if typeof(segura) not in [TYPE_INT, TYPE_FLOAT] or int(segura) < 0 or int(segura) >= opciones.size():
			errores.append("decisiones.json: %s tiene 'segura' fuera de rango." % did)


static func _kit(errores: Array[String]) -> void:
	var d := _leer("kit.json", errores)
	var objetos := _lista(d, "objetos")
	_ids_unicos("kit.json", objetos, errores)
	var correctos := 0
	var distractores := 0
	var iconos: Array = []
	for o in objetos:
		if not _texto_ok(o.get("nombre", null)):
			errores.append("kit.json: '%s' no tiene nombre." % str(o.get("id", "?")))
		if o.get("correcto", null) == true:
			correctos += 1
		elif o.get("correcto", null) == false:
			distractores += 1
		iconos.append(int(o.get("icono", -1)))
	if objetos.size() != 12 or correctos != 8 or distractores != 4:
		errores.append("kit.json: debe haber 12 objetos (8 correctos y 4 distractores).")
	iconos.sort()
	if iconos != range(12):
		errores.append("kit.json: los iconos deben ser 0 a 11 sin repetir.")
	var regla: Variant = d.get("regla", {})
	if typeof(regla) != TYPE_DICTIONARY or int(regla.get("elegir", 0)) != 8 \
			or int(regla.get("minimo_correctos", 0)) != 7 or int(regla.get("maximo_distractores", -1)) != 1:
		errores.append("kit.json: la regla de D5 debe ser elegir 8, mínimo 7 correctos y máximo 1 distractor.")


static func _cantidad(nombre: String, clave: String, cantidad: int, campos: Array, errores: Array[String]) -> void:
	var lista := _lista(_leer(nombre, errores), clave)
	if lista.size() != cantidad:
		errores.append("%s: '%s' debe tener %d y tiene %d." % [nombre, clave, cantidad, lista.size()])
	for e in lista:
		for c in campos:
			if not _texto_ok(e.get(c, null)):
				errores.append("%s: un elemento no tiene '%s'." % [nombre, c])
	if "id" in campos:
		_ids_unicos(nombre, lista, errores)


static func _finales(errores: Array[String]) -> void:
	var d := _leer("finales.json", errores)
	var lista := _lista(d, "finales")
	_ids_unicos("finales.json", lista, errores)
	if lista.size() != 3:
		errores.append("finales.json: debe haber 3 finales.")
	var cubiertos: Array = []
	for e in lista:
		if not _texto_ok(e.get("nombre", null)) or not _texto_ok(e.get("mensaje", null)):
			errores.append("finales.json: '%s' necesita nombre y mensaje." % str(e.get("id", "?")))
		for n in range(int(e.get("minimo", 1)), int(e.get("maximo", 0)) + 1):
			cubiertos.append(n)
	cubiertos.sort()
	if cubiertos != range(int(d.get("total_decisiones", 15)) + 1):
		errores.append("finales.json: los rangos deben cubrir de 0 a 15 sin huecos ni repetir.")
