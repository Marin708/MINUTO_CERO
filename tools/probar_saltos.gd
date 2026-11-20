class_name PruebaSaltos
extends Node
## Prueba de los SALTOS DE TAMAÑO de los modales, CON VENTANA REAL (no sirve con --headless). Abre cada modal con textos cortos,
## medianos y largos y, desde el primer fotograma tras abrirlo y durante todo el efecto de escritura, anota por fotograma el
## tamaño y la posición global del cuadro y de la etiqueta de texto.
##
##   godot --path . res://Scenes/UI/PruebaSaltos.tscn -- --auto [--capturas=CARPETA]
##
## Pasa un caso si: (a) desde el primer fotograma VISIBLE (opacidad > 0) el tamaño del cuadro y de la etiqueta no cambia;
## (b) en ningún fotograma el alto del cuadro supera su alto final; (c) la posición no cambia después de la entrada (la entrada
## solo puede mover el cuadro un desplazamiento vertical pequeño, `DESPLAZAMIENTO_MAXIMO`, y nunca en horizontal).
## Con `--capturas=CARPETA` guarda una captura por fotograma de los primeros 6 (para el diagnóstico).
## Guarda un gráfico del alto por fotograma de cada caso en tools/capturas_modales/ y escribe docs/revision_saltos.md.
## Falla (código de salida 1) si algún caso no se cumple. Solo en depuración: no es parte del juego.

const ESCENA := "res://Scenes/UI/PruebaSaltos.tscn"
const CARPETA := "res://tools/capturas_modales/"
const INFORME := "res://docs/revision_saltos.md"
const FOTOGRAMAS_MINIMOS := 40
const FOTOGRAMAS_MAXIMOS := 1500
## Segundos que se dejan a la animación de entrada (fundido y pequeño desplazamiento) antes de exigir posición fija.
const SEGUNDOS_ENTRADA := 0.5
## Lo que puede durar el cambio de alto entre dos mensajes de texto (tween de 0.15 s más la medición).
const SEGUNDOS_TRANSICION := 0.6
const DESPLAZAMIENTO_MAXIMO := 10.0
const TOLERANCIA := 0.6

const TEXTO_CORTO := "Hola, Sami."
const TEXTO_MEDIO := "Hola, Sami. Soy Lucía, brigadista de la comunidad. Estoy por aquí si me necesitas para lo que sea."
const TEXTO_LARGO := "Hola, Sami. Soy Lucía, brigadista de la comunidad. Antes de un sismo lo más importante es revisar la casa con calma: fijar los muebles altos, guardar lo pesado abajo, tener a mano una linterna, un silbato y el botiquín, y acordar con tu familia a dónde van a ir. Practicarlo en familia hace que todos sepan qué hacer."
const RETRO_CORTA := "Fijar el estante a la pared."
const RETRO_MEDIA := "Un mueble alto sin fijar puede caerse durante un sismo. Fijarlo a la pared reduce el riesgo para ti y para tu familia."
const RETRO_LARGA := "Un kit de emergencia lleva agua potable, alimentos no perecederos, linterna con pilas de repuesto, silbato, botiquín, medicinas de uso diario y documentos importantes en una bolsa impermeable. Guárdalo en un lugar de fácil acceso. Revísalo cada seis meses para cambiar lo que se haya vencido y que todos en la casa sepan dónde está."

const CASOS := [
	"radio_corto", "radio_medio", "radio_largo", "radio_dos_paginas", "globo_mama_medio", "globo_mama_largo",
	"retro_corta", "retro_media", "retro_larga", "banner_corto", "banner_largo",
	"cuestionario_intro", "cuestionario_pregunta", "libreta", "resultados", "acuerdo", "kit", "pausa", "creditos",
]

var _filas: Array[Dictionary] = []
var _carpeta_capturas := ""
var _respaldo_guardado := ""
var _habia_guardado := false
var _cierre: Callable
var _casos: Array = CASOS


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if DisplayServer.get_name() == "headless":
		push_error("probar_saltos necesita una ventana real (sin --headless).")
		get_tree().quit(1)
		return
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--casos="):
			_casos = a.trim_prefix("--casos=").split(",")
		if a.begins_with("--capturas="):
			_carpeta_capturas = a.trim_prefix("--capturas=")
			DirAccess.make_dir_recursive_absolute(_carpeta_capturas)
	_habia_guardado = FileAccess.file_exists(Estado.RUTA_GUARDADO)
	_respaldo_guardado = FileAccess.get_file_as_string(Estado.RUTA_GUARDADO) if _habia_guardado else ""
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CARPETA))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/"))
	_ejecutar_todo.call_deferred()


func _exit_tree() -> void:
	Estado.nueva_partida()
	Evaluacion.reiniciar()
	if _habia_guardado:
		var f := FileAccess.open(Estado.RUTA_GUARDADO, FileAccess.WRITE)
		f.store_string(_respaldo_guardado)
		f.close()
	elif FileAccess.file_exists(Estado.RUTA_GUARDADO):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Estado.RUTA_GUARDADO))


func _ejecutar_todo() -> void:
	var ventana := get_window()
	ventana.mode = Window.MODE_WINDOWED
	ventana.size = Vector2i(1280, 720)
	await get_tree().process_frame
	var fallos := 0
	for caso in _casos:
		var fila := await _probar(caso)
		_filas.append(fila)
		if not fila["ok"]:
			fallos += 1
		print("%s %-22s fv=%d  alto final %.0f  máx %.0f  tamaño %s  alto+ %s  posición %s" % [
				"ok   " if fila["ok"] else "FALLA", caso, fila["primer_visible"], fila["alto_final"], fila["alto_max"],
				"ok" if fila["a_tamano"] else "CAMBIA", "ok" if fila["b_alto"] else "SUPERA", "ok" if fila["c_posicion"] else "CAMBIA"])
	_escribir_informe()
	print("probar_saltos: %d casos, %d con fallos." % [_filas.size(), fallos])
	get_tree().quit(1 if fallos > 0 else 0)


# --- Un caso ---

func _probar(caso: String) -> Dictionary:
	get_tree().paused = false
	var finder := _abrir(caso)
	var filas: Array[Dictionary] = []
	var maximo := FOTOGRAMAS_MAXIMOS
	for f in maximo:
		await get_tree().process_frame
		var d: Dictionary = finder.call()
		var fila := {"f": f, "existe": false}
		if not d.is_empty() and is_instance_valid(d.get("cuadro")):
			var c: Control = d["cuadro"]
			var e: Control = d.get("etiqueta")
			var alfa := _alfa(c)
			fila = {
				"f": f, "existe": true, "alfa": alfa, "t": Time.get_ticks_msec() / 1000.0,
				"pos": c.get_global_rect().position, "tam": c.get_global_rect().size,
				"e_tam": e.get_global_rect().size if e != null and is_instance_valid(e) else Vector2.ZERO,
				"e_pos": e.get_global_rect().position if e != null and is_instance_valid(e) else Vector2.ZERO,
				"terminado": bool(d.get("terminado", false)), "pagina": int(d.get("pagina", 1)),
			}
		filas.append(fila)
		if _carpeta_capturas != "" and f < 6:
			get_viewport().get_texture().get_image().save_png("%s/%s_f%d.png" % [_carpeta_capturas, caso, f])
		if fila["existe"] and bool(fila["terminado"]) and f >= FOTOGRAMAS_MINIMOS:
			break
		if f >= 150 and not _alguna_existe(filas):
			break   # el modal no aparece: no se espera más
	_cerrar_caso()
	for i in 20:
		await get_tree().process_frame
	var espera := 0
	while (Notificacion.mostrando or _balloon() != null) and espera < 300:
		await get_tree().process_frame
		espera += 1
	return _analizar(caso, filas)


func _alguna_existe(filas: Array[Dictionary]) -> bool:
	for f in filas:
		if f["existe"]:
			return true
	return false


func _alfa(c: CanvasItem) -> float:
	var a := 1.0
	var n: Node = c
	while n != null:
		if n is CanvasItem:
			if not (n as CanvasItem).visible:
				return 0.0
			a *= (n as CanvasItem).modulate.a
		n = n.get_parent()
	return a


func _analizar(caso: String, filas: Array[Dictionary]) -> Dictionary:
	var existentes: Array[Dictionary] = []
	for f in filas:
		if f["existe"]:
			existentes.append(f)
	var res := {"caso": caso, "ok": false, "primer_visible": -1, "alto_final": 0.0, "alto_max": 0.0, "a_tamano": false,
			"b_alto": false, "c_posicion": false, "fotogramas": filas.size(), "detalle": []}
	if existentes.is_empty():
		res["detalle"].append("el modal nunca apareció")
		return res
	var final: Dictionary = existentes[existentes.size() - 1]
	var primero := -1
	for f in existentes:
		if float(f["alfa"]) > 0.01:
			primero = int(f["f"])
			break
	res["primer_visible"] = primero
	# Se agrupan los fotogramas por «página» (el mensaje de texto que se muestra): la transición entre dos mensajes es la única
	# excepción permitida y se mide aparte (el cuadro puede cambiar de alto con un tween suave de 0.15 s, nunca más de lo que mide el final)
	var grupos: Dictionary = {}
	for f in existentes:
		var g := int(f.get("pagina", 1))
		if not grupos.has(g):
			grupos[g] = []
		(grupos[g] as Array).append(f)
	var alto_max := 0.0
	var alto_final_max := 0.0
	var tam_ok := true
	var pos_ok := true
	for g in grupos:
		var filas_g: Array = grupos[g]
		var final_g: Dictionary = filas_g[filas_g.size() - 1]
		alto_final_max = maxf(alto_final_max, float((final_g["tam"] as Vector2).y))
		var transicion: bool = int(g) > 1
		var primero_g := -1
		var t_primero := 0.0
		for f in filas_g:
			if float(f["alfa"]) > 0.01 or transicion:
				primero_g = int(f["f"])
				t_primero = float(f["t"])
				break
		for f in filas_g:
			alto_max = maxf(alto_max, float((f["tam"] as Vector2).y))
			if primero_g < 0 or int(f["f"]) < primero_g:
				continue
			var en_entrada := float(f["t"]) - t_primero < (SEGUNDOS_TRANSICION if transicion else SEGUNDOS_ENTRADA)
			# (a) el tamaño del cuadro y de la etiqueta no cambia (en una transición de texto, solo durante su tween)
			var dif_tam: Vector2 = ((f["tam"] as Vector2) - (final_g["tam"] as Vector2)).abs()
			var dif_e: Vector2 = ((f["e_tam"] as Vector2) - (final_g["e_tam"] as Vector2)).abs()
			if not (transicion and en_entrada) and (dif_tam.x > TOLERANCIA or dif_tam.y > TOLERANCIA or dif_e.x > TOLERANCIA or dif_e.y > TOLERANCIA):
				if tam_ok:
					res["detalle"].append("el tamaño cambia después del primer fotograma visible (primer cambio en el fotograma %d)" % int(f["f"]))
				tam_ok = false
			# (c) la posición: en la entrada solo un desplazamiento vertical pequeño; después, fija
			var dif := (f["pos"] as Vector2) - (final_g["pos"] as Vector2)
			var mal := false
			if transicion and en_entrada:
				mal = false   # el cuadro crece o se encoge animado, anclado abajo
			elif en_entrada:
				mal = absf(dif.x) > TOLERANCIA or absf(dif.y) > DESPLAZAMIENTO_MAXIMO
			else:
				mal = absf(dif.x) > TOLERANCIA or absf(dif.y) > TOLERANCIA
			if mal:
				if pos_ok:
					res["detalle"].append("la posición cambia fuera de la entrada (primer cambio en el fotograma %d)" % int(f["f"]))
				pos_ok = false
	res["alto_final"] = float((final["tam"] as Vector2).y)
	res["alto_max"] = alto_max
	# (b) el alto nunca supera el final
	res["b_alto"] = alto_max <= alto_final_max + TOLERANCIA
	res["a_tamano"] = tam_ok
	res["c_posicion"] = pos_ok
	if not res["b_alto"]:
		res["detalle"].append("el alto llega a %.0f px y el final es %.0f px" % [alto_max, alto_final_max])
	res["ok"] = res["a_tamano"] and res["b_alto"] and res["c_posicion"]
	_grafico(caso, existentes, primero)
	# Muestra por fotograma: los 8 primeros y uno de cada 15 durante el resto (para el informe)
	var muestra: Array[Dictionary] = []
	for i in existentes.size():
		if i < 8 or i % 15 == 0:
			muestra.append(existentes[i])
	res["filas"] = muestra
	return res


## Gráfico del alto del cuadro (blanco) y de la etiqueta (naranja) por fotograma; la línea azul marca el primer fotograma visible
## y la roja el alto final.
func _grafico(caso: String, filas: Array[Dictionary], primero: int) -> void:
	var ancho := 720
	var alto := 200
	var img := Image.create(ancho, alto, false, Image.FORMAT_RGBA8)
	img.fill(Color("10202A"))
	var maximo := 1.0
	for f in filas:
		maximo = maxf(maximo, float((f["tam"] as Vector2).y))
	var n := filas.size()
	var escala_y := (alto - 20.0) / maximo
	var final_y := alto - 10 - int(float((filas[n - 1]["tam"] as Vector2).y) * escala_y)
	for x in ancho:
		img.set_pixel(x, clampi(final_y, 0, alto - 1), Color("D64B2A"))
	for i in n:
		var x := int(float(i) * (ancho - 1) / maxf(n - 1, 1))
		var f: Dictionary = filas[i]
		var y1 := clampi(alto - 10 - int(float((f["tam"] as Vector2).y) * escala_y), 0, alto - 1)
		var y2 := clampi(alto - 10 - int(float((f["e_tam"] as Vector2).y) * escala_y), 0, alto - 1)
		for dx in 2:
			img.set_pixel(clampi(x + dx, 0, ancho - 1), y1, Color("F3E9D2") if float(f["alfa"]) > 0.01 else Color("5b6b75"))
			img.set_pixel(clampi(x + dx, 0, ancho - 1), y2, Color("FF7A1A"))
		if primero >= 0 and int(f["f"]) == primero:
			for y in alto:
				img.set_pixel(x, y, Color("2A9D8F"))
	img.save_png(ProjectSettings.globalize_path(CARPETA + "saltos_%s.png" % caso))


# --- Apertura de cada caso: devuelve quien encuentra, en cada fotograma, el cuadro y la etiqueta ---

func _abrir(caso: String) -> Callable:
	var raiz := get_tree().root
	match caso:
		"radio_corto", "radio_medio", "radio_largo":
			Dialogo.mostrar_texto("Lucía", {"radio_corto": TEXTO_CORTO, "radio_medio": TEXTO_MEDIO, "radio_largo": TEXTO_LARGO}[caso])
			_cierre = _cerrar_balloon
			return _buscar_balloon
		"radio_dos_paginas":
			Dialogo.mostrar_texto("Lucía", [TEXTO_CORTO, TEXTO_LARGO])
			_cierre = _cerrar_balloon
			var estado := {"pagina": 1}
			return func() -> Dictionary:
				var d := _buscar_balloon()
				if d.is_empty():
					return d
				var b := _balloon()
				if b.esperando_entrada and estado["pagina"] == 1 and b.linea != null and b.linea.next_id != "":
					estado["pagina"] = 2
					b._siguiente(b.linea.next_id)
				d["pagina"] = estado["pagina"]
				if estado["pagina"] == 1:
					d["terminado"] = false
				return d
		"globo_mama_medio", "globo_mama_largo":
			Dialogo.mostrar_texto("Mamá", TEXTO_MEDIO if caso == "globo_mama_medio" else TEXTO_LARGO)
			_cierre = _cerrar_balloon
			return _buscar_balloon
		"retro_corta", "retro_media", "retro_larga":
			var por_que: String = {"retro_corta": RETRO_CORTA, "retro_media": RETRO_MEDIA, "retro_larga": RETRO_LARGA}[caso]
			TarjetaRetro.mostrar(get_tree(), "Ojo", "Dejaste el estante sin fijar a la pared.", "Fijar el estante a la pared.", por_que, true)
			_cierre = func() -> void:
				var t := _tarjeta()
				if t != null:
					t._cerrar(false)
			return func() -> Dictionary:
				var t := _tarjeta()
				if t == null or t._modal == null or t._textos.is_empty():
					return {}
				return {"cuadro": t._modal.panel, "etiqueta": t._textos[t._textos.size() - 1], "terminado": t._fila_botones.modulate.a >= 1.0}
		"banner_corto", "banner_largo":
			Notificacion.mostrar("Memoria de 1999" if caso == "banner_largo" else "Listo",
					TEXTO_LARGO if caso == "banner_largo" else "Zapatos cerrados, mochila y linterna contigo.")
			_cierre = func() -> void:
				Notificacion.cerrar()
			return func() -> Dictionary:
				return {"cuadro": Notificacion._tarjeta, "etiqueta": Notificacion._texto, "terminado": Notificacion.visible_listo}
		"cuestionario_intro":
			Evaluacion.reiniciar()
			var qi: Cuestionario = (load("res://Scenes/UI/Cuestionario.tscn") as PackedScene).instantiate()
			qi.fase = "pre"
			qi.solo_vista = true
			raiz.add_child(qi)
			Evaluacion.iniciar_fase("pre")
			qi._raiz.modulate.a = 1.0
			qi._intro("trivia")
			_cierre = qi.queue_free
			return func() -> Dictionary:
				return {"cuadro": qi._modal_intro.panel, "etiqueta": qi._texto_intro, "terminado": qi._modal_intro.panel.modulate.a >= 1.0}
		"cuestionario_pregunta":
			Evaluacion.reiniciar()
			var q: Cuestionario = (load("res://Scenes/UI/Cuestionario.tscn") as PackedScene).instantiate()
			q.fase = "pre"
			q.solo_vista = true
			raiz.add_child(q)
			Evaluacion.iniciar_fase("pre")
			q.previsualizar(3)
			_cierre = q.queue_free
			return func() -> Dictionary:
				return {"cuadro": q._modal_pregunta.panel, "etiqueta": q._texto_pregunta, "terminado": true}
		"libreta":
			for id in Estado.ids_decisiones():
				Estado.registrar_decision(id, false)
			var libreta := Libreta.new()
			raiz.add_child(libreta)
			libreta.abrir()
			_cierre = libreta.queue_free
			return func() -> Dictionary:
				return {"cuadro": libreta._modal.panel, "terminado": true}
		"resultados":
			Estado.forzar_resultado(12)
			var res: Resultados = (load("res://Scenes/UI/Resultados.tscn") as PackedScene).instantiate()
			raiz.add_child(res)
			_cierre = res.queue_free
			return func() -> Dictionary:
				return {"cuadro": res._modal.panel, "terminado": true}
		"acuerdo":
			var c: Consentimiento = (load("res://Scenes/UI/Consentimiento.tscn") as PackedScene).instantiate()
			raiz.add_child(c)
			_cierre = c.queue_free
			return func() -> Dictionary:
				return {"cuadro": c.modal.panel, "terminado": true}
		"kit":
			var kit := KitUI.new()
			raiz.add_child(kit)
			_cierre = func() -> void:
				kit.queue_free()
				get_tree().paused = false
			return func() -> Dictionary:
				return {"cuadro": kit._modal.panel, "terminado": true}
		"pausa":
			Menus.pausa.abrir()
			_cierre = func() -> void:
				Menus.cerrar_pausa()
			return func() -> Dictionary:
				return {"cuadro": (Menus.pausa._panel as ModalBase).panel, "terminado": true}
		"creditos":
			var cr: Creditos = (load("res://Scenes/UI/Creditos.tscn") as PackedScene).instantiate()
			cr._espera = 9999.0
			raiz.add_child(cr)
			_cierre = cr.queue_free
			return func() -> Dictionary:
				return {"cuadro": cr._modal.panel, "terminado": true}
	return func() -> Dictionary: return {}


func _cerrar_caso() -> void:
	if _cierre.is_valid():
		_cierre.call()
	_cierre = Callable()
	get_tree().paused = false


func _balloon() -> DialogoBalloon:
	var hallado: DialogoBalloon = null
	for h in Dialogo.get_children():   # el balloon cuelga del autoload Dialogo; el más nuevo que no se esté cerrando
		if h is DialogoBalloon and not (h as DialogoBalloon)._cerrando:
			hallado = h
	return hallado


func _tarjeta() -> TarjetaRetro:
	for h in get_tree().root.get_children():
		if h is TarjetaRetro:
			return h
	return null


func _buscar_balloon() -> Dictionary:
	var b := _balloon()
	if b == null:
		return {}
	return {"cuadro": b.caja, "etiqueta": b.texto, "terminado": b.esperando_entrada}


func _cerrar_balloon() -> void:
	var b := _balloon()
	if b != null:
		b._terminar()


# --- Informe ---

func _escribir_informe() -> void:
	var t := "# Revisión de saltos de tamaño de los modales\n\n"
	t += "Generado por `tools/probar_saltos.gd` (ventana real, 1280 x 720). Por caso se anota el tamaño y la posición global del cuadro y de la etiqueta en cada fotograma, desde que se abre hasta que termina la escritura.\n\n"
	t += "Criterios: **(a)** desde el primer fotograma visible el tamaño no cambia; **(b)** el alto nunca supera el alto final; **(c)** la posición no cambia después de la entrada (solo un desplazamiento vertical de hasta %d px en los primeros %.1f s visibles).\n\n" % [int(DESPLAZAMIENTO_MAXIMO), SEGUNDOS_ENTRADA]
	t += "| Caso | Primer fotograma visible | Alto final | Alto máximo | (a) tamaño | (b) alto | (c) posición | Resultado |\n|---|---|---|---|---|---|---|---|\n"
	for f in _filas:
		t += "| %s | %d | %.0f | %.0f | %s | %s | %s | %s |\n" % [f["caso"], f["primer_visible"], f["alto_final"], f["alto_max"],
				"ok" if f["a_tamano"] else "CAMBIA", "ok" if f["b_alto"] else "SUPERA", "ok" if f["c_posicion"] else "CAMBIA", "ok" if f["ok"] else "FALLA"]
	t += "\n## Detalles de los fallos\n\n"
	var hubo := false
	for f in _filas:
		for d in f["detalle"]:
			t += "- **%s**: %s\n" % [f["caso"], d]
			hubo = true
	if not hubo:
		t += "Ninguno.\n"
	t += "\n## Fotogramas medidos\n\n"
	for f in _filas:
		t += "### %s\n\n| Fotograma | Opacidad | Cuadro (ancho x alto) | Posición | Etiqueta (ancho x alto) |\n|---|---|---|---|---|\n" % f["caso"]
		for r in f.get("filas", []):
			t += "| %d | %.2f | %.0f x %.0f | %.0f, %.0f | %.0f x %.0f |\n" % [r["f"], r["alfa"], (r["tam"] as Vector2).x, (r["tam"] as Vector2).y,
					(r["pos"] as Vector2).x, (r["pos"] as Vector2).y, (r["e_tam"] as Vector2).x, (r["e_tam"] as Vector2).y]
		t += "\n"
	t += "\n## Gráficos\n\nAlto del cuadro (blanco; gris antes de ser visible) y de la etiqueta (naranja) por fotograma, con una línea azul en el primer fotograma visible y una roja en el alto final: `tools/capturas_modales/saltos_<caso>.png`.\n"
	var archivo := FileAccess.open(INFORME, FileAccess.WRITE)
	archivo.store_string(t)
	archivo.close()
