extends Node
## Pruebas sin ventana del estado, los finales y la evaluación.
##   godot --headless --path . res://tools/pruebas_estado.tscn
## Sale con código 0 si todo pasa y con 1 si algo falla. No toca la partida real: respalda y restaura el
## archivo de guardado.

var _fallos := 0
var _pruebas := 0


func _ready() -> void:
	var respaldo := ""
	var habia_guardado := FileAccess.file_exists(Estado.RUTA_GUARDADO)
	if habia_guardado:
		respaldo = FileAccess.get_file_as_string(Estado.RUTA_GUARDADO)

	_prueba_contenido()
	_prueba_finales()
	_prueba_intentos()
	_prueba_guardado()
	_prueba_evaluacion()
	_prueba_codigo()
	_prueba_audio()
	_prueba_identidad()

	# Deja todo como estaba
	Estado.nueva_partida()
	Evaluacion.reiniciar()
	if habia_guardado:
		var archivo := FileAccess.open(Estado.RUTA_GUARDADO, FileAccess.WRITE)
		archivo.store_string(respaldo)
		archivo.close()
	elif FileAccess.file_exists(Estado.RUTA_GUARDADO):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Estado.RUTA_GUARDADO))

	print("Pruebas: %d comprobaciones, %d fallos." % [_pruebas, _fallos])
	get_tree().quit(1 if _fallos > 0 else 0)


## Identidad visual: retratos (8, de 96 x 96 con filtro Nearest), fuentes con tildes y contraste mínimo de 4.5 en los textos.
func _prueba_identidad() -> void:
	for nombre in Retratos.NOMBRES:
		var r := Retratos.obtener(nombre) as AtlasTexture
		_comprobar(r != null and r.region.size == Vector2(96, 96), "retrato %s: AtlasTexture de 96 x 96" % nombre)
	_comprobar(Retratos.rostro("rosa").get_size() == Vector2(56, 56), "el rostro pequeño mide 56 x 56 (1x, sin escalar)")
	_comprobar(Retratos.de_hablante("Doña Rosa") == Retratos.obtener("rosa") and Retratos.de_hablante("Narrador") == null, "los hablantes se asocian con su retrato")
	_comprobar(EstiloUI.fuente_titulo() != null and EstiloUI.fuente_radio() != null and EstiloUI.fuente_texto() != null, "las tres fuentes cargan (Silkscreen, VT323, Pixelify Sans)")
	_comprobar(EstiloUI.tema() != null and ResourceLoader.exists(EstiloUI.RUTA_TEMA), "existe Resources/tema_minutocero.tres")
	var pares := [
		["crema sobre petróleo", EstiloUI.CREMA, EstiloUI.PETROLEO], ["crema sobre azul noche", EstiloUI.CREMA, EstiloUI.AZUL_NOCHE],
		["naranja sobre azul noche", EstiloUI.NARANJA, EstiloUI.AZUL_NOCHE], ["naranja sobre petróleo", EstiloUI.NARANJA, EstiloUI.PETROLEO],
		["gris sobre petróleo", EstiloUI.GRIS, EstiloUI.PETROLEO], ["tinta sobre crema", EstiloUI.TINTA, EstiloUI.CREMA],
		["tinta sobre papel", EstiloUI.TINTA, EstiloUI.PAPEL], ["nota a lápiz sobre papel", EstiloUI.TINTA_SUAVE, EstiloUI.PAPEL],
		["tinta sobre naranja", EstiloUI.TINTA, EstiloUI.NARANJA], ["turquesa oscuro sobre papel", EstiloUI.TURQUESA_TINTA, EstiloUI.PAPEL],
		["ámbar oscuro sobre papel", EstiloUI.AMBAR_TINTA, EstiloUI.PAPEL], ["rojo oscuro sobre papel", EstiloUI.ROJO_TINTA, EstiloUI.PAPEL],
		["naranja oscuro sobre papel", EstiloUI.NARANJA_TINTA, EstiloUI.PAPEL],
	]
	for par in pares:
		_comprobar(EstiloUI.contraste(par[1], par[2]) >= 4.5, "contraste mínimo 4.5: %s (%.1f)" % [par[0], EstiloUI.contraste(par[1], par[2])])


func _comprobar(condicion: bool, descripcion: String) -> void:
	_pruebas += 1
	if condicion:
		print("  ok   %s" % descripcion)
	else:
		_fallos += 1
		print("  FALLA %s" % descripcion)


# --- Contenido ---

func _prueba_contenido() -> void:
	print("Contenido")
	var errores := ValidadorContenido.validar()
	_comprobar(errores.is_empty(), "los JSON de contenido son válidos %s" % str(errores))
	_comprobar(Estado.ids_decisiones().size() == 15, "existen las 15 decisiones")
	var por_nivel := [Estado.ids_de_nivel(1).size(), Estado.ids_de_nivel(2).size(), Estado.ids_de_nivel(3).size()]
	_comprobar(por_nivel == [7, 4, 4], "decisiones por nivel 7, 4 y 4 %s" % str(por_nivel))


# --- Finales ---

func _prueba_finales() -> void:
	print("Finales")
	Estado.nueva_partida()
	Estado.forzar_resultado(15)
	_comprobar(Estado.cantidad_seguras() == 15, "todas seguras da 15")
	_comprobar(Estado.calcular_final() == "preparado", "todas seguras: final Preparado")
	_comprobar(str(Estado.datos_final()["nombre"]) == "Preparado o preparada", "nombre del final Preparado")
	_comprobar(str(Estado.datos_final()["mensaje"]) == "Tu minuto cero estuvo preparado.", "mensaje del final Preparado")
	var esperado := {15: "preparado", 12: "preparado", 11: "encamino", 10: "encamino", 8: "encamino", 7: "reforzar", 3: "reforzar", 0: "reforzar"}
	for seguras in esperado:
		Estado.forzar_resultado(seguras)
		_comprobar(Estado.calcular_final() == esperado[seguras], "%d seguras: %s" % [seguras, esperado[seguras]])
	Estado.forzar_resultado(8)
	_comprobar(str(Estado.datos_final()["nombre"]) == "En camino", "la mitad (8 seguras) da En camino")
	Estado.forzar_resultado(0)
	_comprobar(str(Estado.datos_final()["nombre"]) == "A reforzar", "ninguna segura da A reforzar")


# --- Intentos y lecciones ---

func _prueba_intentos() -> void:
	print("Intentos y lecciones")
	Estado.nueva_partida()
	var primero := Estado.registrar_decision("D1", false)
	_comprobar(primero and not Estado.primer_intento_de("D1"), "D1 fallada al primer intento")
	Estado.registrar_decision("D1", true)
	_comprobar(Estado.intentos_de("D1") == 2, "D1 lleva 2 intentos")
	_comprobar(not Estado.primer_intento_de("D1") and Estado.cantidad_seguras() == 0, "el reintento no suma puntos")
	_comprobar(Estado.cantidad_lecciones() == 1, "D1 queda como lección aprendida (una sola vez)")
	Estado.registrar_decision("D2", true)
	_comprobar(Estado.primer_intento_de("D2") and Estado.cantidad_seguras() == 1, "D2 segura al primer intento suma 1")
	_comprobar(Estado.desbloquear_tarjeta_de_nivel(1) == "mem1", "la tarjeta del nivel 1 se desbloquea")
	_comprobar(Estado.desbloquear_tarjeta_de_nivel(1) == "", "no se desbloquea dos veces")


# --- Guardado ---

func _prueba_guardado() -> void:
	print("Guardado")
	Estado.nueva_partida()
	Estado.registrar_decision("D1", false)
	Estado.registrar_decision("D1", true)
	Estado.registrar_decision("D3", true)
	Estado.desbloquear_tarjeta_de_nivel(1)
	Estado.ir_a_nivel(2)
	_comprobar(Estado.guardar(), "guardar() escribe user://minutocero_save.json")
	Estado.nueva_partida()
	_comprobar(Estado.cantidad_resueltas() == 0 and Estado.nivel_actual == 1, "nueva_partida() deja todo en blanco")
	_comprobar(Estado.diagnosticar_partida() == "ok", "el archivo guardado se reconoce")
	_comprobar(Estado.cargar(), "cargar() devuelve true")
	_comprobar(Estado.nivel_actual == 2 and Estado.intentos_de("D1") == 2 and Estado.primer_intento_de("D3"), "cargar() restaura nivel, intentos y primer intento")
	_comprobar(Estado.lecciones.size() == 2 and Estado.tarjetas == ["mem1"], "cargar() restaura lecciones y tarjetas")
	# Un archivo dañado no rompe nada
	var archivo := FileAccess.open(Estado.RUTA_GUARDADO, FileAccess.WRITE)
	archivo.store_string("{esto no es json")
	archivo.close()
	_comprobar(Estado.diagnosticar_partida() == "danada" and not Estado.cargar(), "un archivo dañado se detecta y no se carga")


# --- Evaluación ---

func _prueba_evaluacion() -> void:
	print("Evaluación")
	_comprobar(Evaluacion.valido, "el banco de preguntas es válido %s" % str(Evaluacion.errores))
	Evaluacion.reiniciar()
	Evaluacion.iniciar_fase("pre")
	var orden := Evaluacion.orden_para("pre")
	_comprobar(orden.size() == 14, "cada fase tiene 14 preguntas")
	_comprobar(Evaluacion.banco["trivia"].size() == 7 and Evaluacion.banco["situaciones"].size() == 5 and Evaluacion.banco["escala"].size() == 2, "7 de trivia, 5 de situaciones y 2 de escala")
	# Todas correctas (índice original 0) y escala máxima
	for p in orden:
		Evaluacion.registrar("pre", p["id"], 5 if p["bloque"] == "escala" else 0)
	var buenos := Evaluacion.calcular("pre")
	_comprobar(buenos["trivia"] == 7 and buenos["situaciones"] == 5 and buenos["escala"] == 10 and buenos["total"] == 12, "todo correcto: trivia 7, situaciones 5, escala 10, total 12 %s" % str(buenos))
	_comprobar(Evaluacion.pre_completo(), "el pre queda completo")
	# Todas incorrectas (índice original 1) y escala mínima
	Evaluacion.iniciar_fase("post")
	for p in Evaluacion.orden_para("post"):
		Evaluacion.registrar("post", p["id"], 1)
	var malos := Evaluacion.calcular("post")
	_comprobar(malos["trivia"] == 0 and malos["situaciones"] == 0 and malos["escala"] == 2, "todo incorrecto: 0, 0 y escala 2 %s" % str(malos))
	var c := Evaluacion.comparar()
	_comprobar(c["por_bloque"]["trivia"]["dif"] == -7 and c["por_bloque"]["escala"]["dif"] == -8, "la comparación resta pre y post")
	# Las opciones se barajan, pero el índice original se conserva
	var primera := Evaluacion.orden_para("pre")[0]
	var originales: Array = []
	for o in primera["opciones"]:
		originales.append(o["indice_original"])
	originales.sort()
	_comprobar(originales == [0, 1, 2, 3], "el barajado conserva los índices originales")


# --- Código de resultados ---

func _prueba_codigo() -> void:
	print("Código de resultados")
	Estado.nueva_partida()
	Evaluacion.reiniciar()
	Estado.forzar_resultado(10)
	for fase in ["pre", "post"]:
		Evaluacion.iniciar_fase(fase)
		for p in Evaluacion.orden_para(fase):
			Evaluacion.registrar(fase, p["id"], 4 if p["bloque"] == "escala" else (0 if fase == "post" else 1))
		Evaluacion.calcular(fase)
	var codigo := CodigoResultados.generar()
	_comprobar(codigo.begins_with("MC1:"), "el código empieza con MC1:")
	var r := CodigoResultados.decodificar(codigo)
	_comprobar(bool(r["ok"]), "el código se decodifica y el CRC cuadra")
	var d: Dictionary = r["datos"]
	_comprobar(int(d["s"]) == 10 and d["fin"] == "e" and str(d["dp"]).length() == 15, "trae seguras, final y las 15 decisiones")
	_comprobar(str(d["rp"]).length() == 14 and str(d["rq"]).length() == 14, "trae las 14 respuestas del antes y del después")
	_comprobar(not CodigoResultados.decodificar(codigo.substr(0, codigo.length() - 3))["ok"], "un código cortado se rechaza")
	var f := FileAccess.open("res://docs/analisis/codigo_godot_NO_REAL.txt", FileAccess.WRITE)
	if f != null:
		f.store_string(codigo)
		f.close()


# --- Audio ---

func _prueba_audio() -> void:
	print("Audio")
	_comprobar(Audio.faltan_del_catalogo().is_empty(), "no falta ningún archivo del catálogo %s" % str(Audio.faltan_del_catalogo()))
	var contados := {"n": 0}
	var contar := func(nombre: String) -> void:
		if nombre == "dialogo_blip_guia":
			contados["n"] += 1
	Audio.efecto_reproducido.connect(contar)
	for letra in ["H", "o", "l", "a", " ", "m", "u", "n"]:   # 7 letras (el espacio no cuenta): un blip cada 2
		Audio.letra_para_prueba(letra)
	Audio.efecto_reproducido.disconnect(contar)
	_comprobar(contados["n"] == 3, "un solo sonido de letras, una vez cada 2 letras (%d blips con 7 letras)" % contados["n"])
	var ruta_inexistente := "res://Assets/Audio/Efectos/no_existe_xyz.wav"
	_comprobar(not ResourceLoader.exists(ruta_inexistente), "ResourceLoader.exists dice que un sonido ausente no existe")
	Audio.efecto("no_existe_xyz")
	_comprobar(Audio.faltan.has("no_existe_xyz"), "un sonido ausente no da error y queda anotado una vez")
	Audio.faltan.erase("no_existe_xyz")
