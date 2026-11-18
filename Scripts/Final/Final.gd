class_name Final
extends CanvasLayer
## La pantalla del final. Según las decisiones seguras al primer intento (Estado.calcular_final(), umbrales de
## Resources/contenido/finales.json) muestra «Preparado o preparada», «En camino» o «A reforzar», con su mensaje y
## su música, y «Mi plan en 5 pasos» (plan.json). En la web ofrece «Descargar mi plan» (archivo de texto).
## Después: el cuestionario final (las mismas 14 preguntas, opciones mezcladas), los resultados y los créditos.
## [REVISAR] La frase de puntaje y los textos de los botones los escribió el equipo.

signal secuencia_terminada

var tipo := ""
var _raiz: Control
var _terminando := false


func _ready() -> void:
	layer = 1
	tipo = Estado.calcular_final()
	FondoEvaluacion.crear(self)
	_construir()
	Audio.detener_ambiente(1.0)
	Audio.musica("final_%s" % tipo, 1.0)
	Estado.final_calculado.emit(tipo)
	if Flujo.modo_prueba:
		_terminar_prueba.call_deferred()


func _construir() -> void:
	var d := Estado.datos_final(tipo)
	var plan: Dictionary = _leer("plan.json")
	_raiz = Control.new()
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.theme = EstiloUI.tema()
	add_child(_raiz)
	var panel := PanelContainer.new()
	panel.position = Vector2(150, 24)
	panel.size = Vector2(470, 312)
	panel.add_theme_stylebox_override("panel", EstiloUI.caja(Color("0f2d38", 0.95), EstiloUI.NARANJA, 2, 14, 5))
	_raiz.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	v.add_child(EstiloUI.etiqueta(str(d.get("nombre", "")), 22, EstiloUI.NARANJA))
	var mensaje := EstiloUI.etiqueta(str(d.get("mensaje", "")), 14, EstiloUI.CREMA)
	mensaje.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mensaje.custom_minimum_size = Vector2(440, 0)
	v.add_child(mensaje)
	v.add_child(EstiloUI.etiqueta("Decisiones seguras al primer intento: %d de %d" % [Estado.cantidad_seguras(), Estado.TOTAL_DECISIONES], 11, EstiloUI.GRIS))
	v.add_child(EstiloUI.etiqueta(str(plan.get("titulo", "Mi plan en 5 pasos")), 15, EstiloUI.NARANJA))
	for p in plan.get("pasos", []):
		var e := EstiloUI.etiqueta("%d. %s" % [int(p["numero"]), str(p["texto"])], 12, EstiloUI.CREMA)
		e.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		e.custom_minimum_size = Vector2(440, 0)
		v.add_child(e)
	var fila := HBoxContainer.new()
	fila.alignment = BoxContainer.ALIGNMENT_END
	fila.add_theme_constant_override("separation", 10)
	v.add_child(fila)
	if OS.has_feature("web"):
		fila.add_child(_boton("Descargar mi plan", _descargar_plan))
	var seguir := _boton("Continuar", _continuar)
	fila.add_child(seguir)
	seguir.grab_focus.call_deferred()


func _boton(texto: String, accion: Callable) -> Button:
	var b := Button.new()
	b.text = texto
	b.custom_minimum_size = Vector2(130, 28)
	b.pressed.connect(func() -> void:
		Audio.efecto("ui_elegir")
		accion.call())
	b.focus_entered.connect(func() -> void: Audio.efecto("ui_mover"))
	return b


static func _leer(nombre: String) -> Dictionary:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://Resources/contenido/" + nombre))
	return d if typeof(d) == TYPE_DICTIONARY else {}


## El texto de «Mi plan en 5 pasos» (para descargar).
static func texto_del_plan() -> String:
	var plan := _leer("plan.json")
	var lineas: Array[String] = [str(plan.get("titulo", "Mi plan en 5 pasos")), ""]
	for p in plan.get("pasos", []):
		lineas.append("%d. %s" % [int(p["numero"]), str(p["texto"])])
	lineas.append("")
	lineas.append("Prepararte hoy puede cambiar el minuto cero.")
	return "\n".join(lineas) + "\n"


func _descargar_plan() -> void:
	var ruta := "user://mi_plan.txt"
	var archivo := FileAccess.open(ruta, FileAccess.WRITE)
	if archivo == null:
		return
	archivo.store_string(texto_del_plan())
	archivo.close()
	Exportacion.descargar(ruta, "mi_plan_minuto_cero.txt", "text/plain;charset=utf-8")


func _continuar() -> void:
	if _terminando:
		return
	_terminando = true
	if Evaluacion.valido:
		await Cuestionario.mostrar(get_tree(), "post")
		await Resultados.mostrar(get_tree())
	secuencia_terminada.emit()
	if Resultados.ultimo_destino == "":
		await Flujo.ir_al_titulo()


func _terminar_prueba() -> void:
	secuencia_terminada.emit()
