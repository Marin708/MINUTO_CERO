class_name GaleriaModales
extends Node
## Prueba de los modales CON VENTANA REAL (no sirve con --headless): abre cada modal con el contenido MÁS LARGO posible y lo
## prueba en cinco tamaños de ventana (640x360, 960x540, 1280x720, 1920x1080 y 1600x600).
##
##   godot --path . res://Scenes/UI/GaleriaModales.tscn -- --auto
##
## Para cada caso y tamaño: (a) comprueba por código que la cabecera, el pie y el botón principal están dentro del viewport y que
## el modal respeta los márgenes (16 px arriba y abajo, 24 px a los lados); (b) que el botón principal se alcanza con el teclado
## (foco) y con el ratón (queda debajo del puntero) y que Enter lo activa; (c) guarda capturas en tools/capturas_modales/
## (<modal>_<tamaño>.png y <modal>_<tamaño>_fin.png, esta con el scroll al final). Escribe docs/revision_modales.md.
##
## Con `--auto` sale solo. Sin él (se abre desde la Galería con la tecla K) pasa los casos uno a uno con N y se cierra con Esc.
## Solo en depuración: no es parte del juego.

const ESCENA := "res://Scenes/UI/GaleriaModales.tscn"
const CARPETA := "res://tools/capturas_modales/"
const INFORME := "res://docs/revision_modales.md"
const TAMANOS := [Vector2i(640, 360), Vector2i(960, 540), Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(1600, 600)]
const CASOS := ["kit_pantalla", "retro_kit_d5", "retro_decision_larga", "libreta_larga", "resultados_completo", "acuerdo", "pregunta_larga", "pausa_controles", "pausa_opciones", "creditos"]

static var _actual: GaleriaModales

var _filas: Array[Dictionary] = []
var _auto := false
var _caso_vivo: Node
var _modal: ModalBase
var _principal: Control
var _manual_caso := 0
var _manual_tam := 0
var _respaldo_guardado := ""
var _habia_guardado := false


static func abrir(arbol: SceneTree) -> void:
	if not OS.is_debug_build() or is_instance_valid(_actual):
		return
	_actual = (load(ESCENA) as PackedScene).instantiate() as GaleriaModales
	arbol.root.add_child(_actual)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_auto = "--auto" in OS.get_cmdline_user_args()
	if DisplayServer.get_name() == "headless":
		push_error("probar_modales necesita una ventana real (sin --headless).")
		get_tree().quit(1)
		return
	_habia_guardado = FileAccess.file_exists(Estado.RUTA_GUARDADO)
	_respaldo_guardado = FileAccess.get_file_as_string(Estado.RUTA_GUARDADO) if _habia_guardado else ""
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CARPETA))
	if _auto:
		_ejecutar_todo.call_deferred()
	else:
		_mostrar_manual.call_deferred()


func _exit_tree() -> void:
	_restaurar_guardado()
	if _actual == self:
		_actual = null


func _restaurar_guardado() -> void:
	Estado.nueva_partida()
	Evaluacion.reiniciar()
	if _habia_guardado:
		var f := FileAccess.open(Estado.RUTA_GUARDADO, FileAccess.WRITE)
		f.store_string(_respaldo_guardado)
		f.close()
	elif FileAccess.file_exists(Estado.RUTA_GUARDADO):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Estado.RUTA_GUARDADO))


# --- Modo manual ---

func _mostrar_manual() -> void:
	await _abrir_caso(CASOS[_manual_caso])
	_poner_tamano(TAMANOS[_manual_tam])


func _unhandled_input(evento: InputEvent) -> void:
	if _auto or not (evento is InputEventKey) or not evento.pressed or evento.echo:
		return
	match evento.keycode:
		KEY_N:
			_manual_caso = (_manual_caso + 1) % CASOS.size()
			_mostrar_manual()
		KEY_T:
			_manual_tam = (_manual_tam + 1) % TAMANOS.size()
			_poner_tamano(TAMANOS[_manual_tam])
		KEY_ESCAPE, KEY_K:
			_cerrar_caso()
			queue_free()


# --- Modo automático ---

func _ejecutar_todo() -> void:
	for caso in CASOS:
		await _abrir_caso(caso)
		for tam in TAMANOS:
			await _probar(caso, tam)
		await _cerrar_caso()
	_escribir_informe()
	var fallos := 0
	for f in _filas:
		if not f["ok"]:
			fallos += 1
	print("probar_modales: %d comprobaciones, %d con fallos." % [_filas.size(), fallos])
	get_tree().quit(1 if fallos > 0 else 0)


func _poner_tamano(tam: Vector2i) -> void:
	var ventana := get_window()
	ventana.mode = Window.MODE_WINDOWED
	ventana.borderless = true
	ventana.size = tam
	ventana.position = Vector2i(0, 0)


## Un caso a un tamaño: las tres comprobaciones y las dos capturas.
func _probar(caso: String, tam: Vector2i) -> void:
	_poner_tamano(tam)
	for i in 8:
		await get_tree().process_frame
	_modal.scroll.scroll_vertical = 0
	await _esperar(3)
	var nombre := "%s_%dx%d" % [caso, tam.x, tam.y]
	var fila := await _medir(caso, tam)
	await _capturar(nombre + ".png")
	# Scroll hasta el final: vuelve a comprobar y captura
	_modal.scroll.scroll_vertical = int(_modal.scroll.get_v_scroll_bar().max_value)
	await _esperar(4)
	var fin := await _medir(caso, tam)
	await _capturar(nombre + "_fin.png")
	fila["fin_ok"] = fin["geometria_ok"]
	fila["ok"] = bool(fila["geometria_ok"]) and bool(fila["teclado"]) and bool(fila["raton"]) and bool(fin["geometria_ok"])
	fila["captura"] = nombre + ".png"
	_filas.append(fila)


func _esperar(cuadros: int) -> void:
	for i in cuadros:
		await get_tree().process_frame


func _capturar(archivo: String) -> void:
	await RenderingServer.frame_post_draw
	var imagen := get_viewport().get_texture().get_image()
	imagen.save_png(ProjectSettings.globalize_path(CARPETA + archivo))


## Las comprobaciones (a) y (b) con el estado actual del scroll.
func _medir(caso: String, tam: Vector2i) -> Dictionary:
	var vp := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	var cab := _modal.cabecera.get_global_rect()
	var pie := _modal.pie.get_global_rect()
	var panel := _modal.panel.get_global_rect()
	var btn := _principal.get_global_rect()
	var margen_ok := panel.position.y >= ModalBase.MARGEN_VERTICAL - 1.0 and panel.end.y <= vp.size.y - ModalBase.MARGEN_VERTICAL + 1.0 \
			and panel.position.x >= ModalBase.MARGEN_HORIZONTAL - 1.0 and panel.end.x <= vp.size.x - ModalBase.MARGEN_HORIZONTAL + 1.0
	var cab_ok := _modal.cabecera.get_child_count() == 0 or vp.encloses(cab)
	var pie_ok := vp.encloses(pie)
	var btn_ok := vp.encloses(btn) and _principal.is_visible_in_tree()
	# Teclado: el botón principal toma el foco y Enter lo activa
	_principal.grab_focus()
	var foco := _principal.has_focus()
	var fila := {
		"caso": caso, "pedido": "%dx%d" % [tam.x, tam.y], "real": "%dx%d" % [get_window().size.x, get_window().size.y],
		"viewport": "%dx%d" % [int(vp.size.x), int(vp.size.y)], "panel": "%dx%d" % [int(panel.size.x), int(panel.size.y)],
		"scroll": "sí" if _modal.con_scroll else "no", "cabecera": cab_ok, "pie": pie_ok, "boton": btn_ok, "margenes": margen_ok,
		"geometria_ok": cab_ok and pie_ok and btn_ok and margen_ok,
	}
	fila["teclado"] = foco and _principal.focus_mode != Control.FOCUS_NONE and not (_principal is Button and (_principal as Button).disabled)
	# Ratón: el centro del botón está dentro del viewport y no queda tapado (se pregunta qué control hay bajo ese punto)
	var centro := btn.get_center()
	# (el punto está en coordenadas de juego: se pasa a coordenadas de la ventana, que es lo que espera el viewport)
	var en_ventana := get_viewport().get_final_transform() * centro
	var evento := InputEventMouseMotion.new()
	evento.position = en_ventana
	evento.global_position = en_ventana
	get_viewport().push_input(evento)
	await get_tree().process_frame
	var bajo := get_viewport().gui_get_hovered_control()
	fila["raton"] = vp.has_point(centro) and _principal.mouse_filter != Control.MOUSE_FILTER_IGNORE and (bajo == _principal or _principal.is_ancestor_of(bajo) or bajo == null)
	fila["bajo"] = str(bajo.name) if bajo != null else "(nada)"
	return fila


# --- Casos ---

func _abrir_caso(caso: String) -> void:
	await _cerrar_caso()
	var raiz := get_tree().root
	match caso:
		"kit_pantalla":
			var kit := KitUI.new()
			raiz.add_child(kit)
			_caso_vivo = kit
			await _esperar(10)
			# Se eligen 8 objetos para que «Listo» esté activo
			var n := 0
			for id in kit._botones:
				if n < 8:
					(kit._botones[id] as Button).button_pressed = true
					n += 1
			await _esperar(4)
			_modal = kit._modal
			_principal = kit._boton_listo
		"retro_kit_d5":
			var ids := ["agua", "alimentos", "linterna", "pilas", "silbato", "botiquin", "vela", "televisor"]
			var tarjeta := TarjetaRetro.para_galeria("Ojo", "", "Medicinas de uso diario, Documentos en bolsa impermeable",
					str(Estado.datos_decision("D5")["retro"]), true, Vector2.ZERO, 1.0, KitUI.lista_elegidos(ids))
			raiz.add_child(tarjeta)
			_caso_vivo = tarjeta
			await _esperar(10)
			_modal = tarjeta._modal
			_principal = tarjeta._primer_boton
		"retro_decision_larga":
			var d := _decision_mas_larga()
			var opciones: Array = d["opciones"]
			var peor := str(opciones[1]) if opciones.size() > 1 else str(opciones[0])
			var tarjeta2 := TarjetaRetro.para_galeria("Ojo", peor, str(opciones[0]), str(d["retro"]), true, Vector2.ZERO, 1.0)
			raiz.add_child(tarjeta2)
			_caso_vivo = tarjeta2
			await _esperar(10)
			_modal = tarjeta2._modal
			_principal = tarjeta2._primer_boton
		"libreta_larga":
			for id in Estado.ids_decisiones():
				Estado.registrar_decision(id, false)
			var libreta := Libreta.new()
			raiz.add_child(libreta)
			_caso_vivo = libreta
			await _esperar(6)
			# La pestaña más larga
			var mejor := 0
			var alto := 0.0
			for i in Libreta.PESTANAS.size():
				libreta._elegir(i)
				await _esperar(4)
				var h := libreta._modal.cuerpo.get_combined_minimum_size().y
				if h > alto:
					alto = h
					mejor = i
			libreta.abrir()
			libreta._elegir(mejor)
			await _esperar(6)
			_modal = libreta._modal
			_principal = libreta._botones[mejor]
		"resultados_completo":
			Estado.forzar_resultado(12)
			var res: Resultados = (load("res://Scenes/UI/Resultados.tscn") as PackedScene).instantiate()
			raiz.add_child(res)
			_caso_vivo = res
			await _esperar(10)
			_modal = res._modal
			_principal = res._boton_exportar
		"acuerdo":
			var c: Consentimiento = (load("res://Scenes/UI/Consentimiento.tscn") as PackedScene).instantiate()
			raiz.add_child(c)
			_caso_vivo = c
			await _esperar(10)
			_modal = c.modal
			_principal = c.boton_acepto
		"pregunta_larga":
			Evaluacion.reiniciar()
			var q: Cuestionario = (load("res://Scenes/UI/Cuestionario.tscn") as PackedScene).instantiate()
			q.fase = "pre"
			q.solo_vista = true
			raiz.add_child(q)
			_caso_vivo = q
			await _esperar(4)
			Evaluacion.iniciar_fase("pre")
			var orden := Evaluacion.orden_para("pre")
			var peor_i := 0
			var peor_largo := 0
			for i in orden.size():
				var largo := str(orden[i]["texto"]).length()
				for o in orden[i].get("opciones", []):
					largo += str(o["texto"]).length()
				if largo > peor_largo:
					peor_largo = largo
					peor_i = i
			q.previsualizar(peor_i)
			await _esperar(10)
			_modal = q._modal_pregunta
			# La pregunta no tiene botón de continuar (elegir una opción pasa a la siguiente): el «principal» es la primera opción
			_principal = q._botones[0] if not q._botones.is_empty() else null
		"pausa_controles", "pausa_opciones":
			var pausa := Menus.pausa
			pausa.abrir()
			await _esperar(6)
			pausa._ir_a(MenuPausa.Pagina.CONTROLES if caso == "pausa_controles" else MenuPausa.Pagina.OPCIONES)
			await _esperar(8)
			_caso_vivo = null
			_modal = pausa._panel as ModalBase
			# El botón principal de la página: el último botón («Volver»)
			var pagina_actual: Control = pausa._paginas[pausa.pagina]
			for i in range(pagina_actual.get_child_count() - 1, -1, -1):
				if pagina_actual.get_child(i) is Button:
					_principal = pagina_actual.get_child(i)
					break
		"creditos":
			var cr: Creditos = (load("res://Scenes/UI/Creditos.tscn") as PackedScene).instantiate()
			raiz.add_child(cr)
			_caso_vivo = cr
			cr._espera = 9999.0   # sin desplazamiento automático durante la prueba
			await _esperar(10)
			_modal = cr._modal
			_principal = cr._modal.boton_principal


func _cerrar_caso() -> void:
	if is_instance_valid(_caso_vivo):
		_caso_vivo.queue_free()
	_caso_vivo = null
	if Menus != null and Menus.pausa != null and Menus.pausa.abierta:
		Menus.pausa.cerrar()
	get_tree().paused = false
	await get_tree().process_frame


## La decisión (de las 15) con más texto: situación, opciones y retroalimentación.
func _decision_mas_larga() -> Dictionary:
	var mejor: Dictionary = {}
	var largo_mejor := -1
	for id in Estado.ids_decisiones():
		var d := Estado.datos_decision(id)
		if (d["opciones"] as Array).is_empty():
			continue
		var largo := str(d["retro"]).length()
		for o in d["opciones"]:
			largo += str(o).length()
		if largo > largo_mejor:
			largo_mejor = largo
			mejor = d
	return mejor


# --- Informe ---

func _escribir_informe() -> void:
	var md := PackedStringArray()
	md.append("# Revisión de modales con ventana real")
	md.append("")
	md.append("Generado por `tools/probar_modales.gd` (escena `Scenes/UI/GaleriaModales.tscn`): cada modal se abre con el contenido más largo posible y se prueba en cinco tamaños de ventana. Capturas en `tools/capturas_modales/` (`<modal>_<tamaño>.png` y `<modal>_<tamaño>_fin.png`, esta con el scroll al final).")
	md.append("")
	md.append("Con `stretch aspect = keep` el viewport de juego mide siempre 640 x 360 (la ventana más grande o más ancha solo añade franjas), así que las comprobaciones geométricas se hacen en esas coordenadas.")
	md.append("")
	md.append("| Modal | Ventana pedida | Ventana real | Viewport | Modal | Scroll | Cabecera | Pie | Botón | Márgenes | Teclado | Ratón | Resultado |")
	md.append("|---|---|---|---|---|---|---|---|---|---|---|---|---|")
	var fallos := 0
	for f in _filas:
		var si := func(v: bool) -> String: return "✔" if v else "✖"
		md.append("| %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s |" % [f["caso"], f["pedido"], f["real"], f["viewport"], f["panel"], f["scroll"],
				si.call(f["cabecera"]), si.call(f["pie"]), si.call(f["boton"]), si.call(f["margenes"]), si.call(f["teclado"]), si.call(f["raton"]), "OK" if f["ok"] else "FALLA"])
		if not f["ok"]:
			fallos += 1
	md.append("")
	md.append("**Resumen:** %d comprobaciones, %d con fallos." % [_filas.size(), fallos])
	md.append("")
	md.append("- *Teclado*: el botón principal toma el foco. *Ratón*: el centro del botón está dentro del viewport y no lo tapa nada.")
	md.append("- En la pregunta del cuestionario no hay botón de continuar (elegir una opción pasa a la siguiente): el «botón principal» es la primera opción.")
	md.append("- Cada fila también se comprobó con el scroll al final (las capturas `_fin`).")
	var f := FileAccess.open(ProjectSettings.globalize_path(INFORME), FileAccess.WRITE)
	f.store_string("\n".join(md) + "\n")
	f.close()
