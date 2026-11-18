class_name Nivel2
extends Nivel
## Nivel 2 — Durante (el mismo apartamento, con daños leves).
##
## El escenario del sismo (aviso de 2 s, sismo fuerte de unos 20 s, polvo, objetos que caen y silencio final) lo da el
## autoload Sismo. Aquí está la mecánica «Agacharse, cubrirse y sujetarse» (D8): llegar a la mesa del comedor (zona
## segura) y MANTENER E hasta que termine; tres íconos (Agáchate, Cúbrete, Sujétate) se encienden en orden. Si Sami sale
## de la zona, va a la puerta, se queda junto a la ventana o suelta E, la acción se marca como riesgosa, el sismo
## termina, sale la tarjeta con «Intentar de nuevo» (el primer intento queda registrado) y el sismo se repite.
## Después, en este orden: zapatos, mochila y linterna (D9), olor a gas (D10) y la escalera sin ascensor (D11).
## [REVISAR] Los textos de este nivel los escribió el equipo (ver docs/textos_a_revisar.md).

## Tiempo que se da para llegar a la mesa antes de exigir que Sami esté agachado.
const SEGUNDOS_LLEGADA := 5.0
## Cuánto se tolera soltar E o salir de la zona antes de marcar el error.
const TOLERANCIA := 0.7
const NOMBRES_ICONOS := ["Agáchate", "Cúbrete", "Sujétate"]
const TEXTO_AGACHARSE := "Mantén E: agacharte, cubrirte y sujetarte"

enum Fase { ESPERA, SISMO, DESPUES }

var fase: Fase = Fase.ESPERA
var _fuera := 0.0
var _sujeto_t := 0.0
var _icono_labels: Array[Label] = []
var _capa_iconos: CanvasLayer
var _mensaje: Label
var _terminando := false
var _ir_escalera := false
var _nivel_terminado := false
## Para pruebas: si es true, el sismo no se inicia solo.
var sin_inicio_automatico := false


func _init() -> void:
	numero = 2
	archivo_mapa = "res://Resources/Mundo/apartamento.txt"
	archivo_danos = "res://Resources/Mundo/apartamento_danos.txt"
	titulo_hud = "Nivel 2 · Durante"


func _es_interactuable(etiqueta: String) -> bool:
	# Los riesgos del nivel 1 ya no se tocan: solo la estufa (D10) y la puerta de salida (D11)
	return etiqueta in ["D3", "salida"]


func _usa_items() -> bool:
	return true


func _preparar() -> void:
	hud.configurar(titulo_hud, [
		{"id": "D8", "texto": "Protegerte durante el sismo"},
		{"id": "D9", "texto": "Zapatos, mochila y linterna"},
		{"id": "D10", "texto": "Revisar el olor a gas (cocina)"},
		{"id": "D11", "texto": "Bajar por la escalera"},
	])
	for id in ["D8", "D9", "D10", "D11"]:
		if Estado.lograda(id):
			hud.marcar(id)
	for id in Nivel1.RIESGOS:
		var p := prop_con_etiqueta(id)
		if p != null:
			p.asegurado = Estado.lograda(id)
	if Estado.lograda("D9"):
		_quitar_items()
	_ir_escalera = Estado.lograda("D11")
	Retroalimentacion.opcion_elegida.connect(_on_opcion)
	_crear_iconos()
	if not sin_inicio_automatico and not Estado.lograda("D8"):
		_inicio.call_deferred()
	else:
		fase = Fase.DESPUES


func _exit_tree() -> void:
	if Retroalimentacion.opcion_elegida.is_connected(_on_opcion):
		Retroalimentacion.opcion_elegida.disconnect(_on_opcion)


func _inicio() -> void:
	ocupado = true
	await esperar(0.6)
	await Dialogo.mostrar_texto("", "Es la tarde. Estás en casa y, de pronto, el piso empieza a vibrar.")
	iniciar_sismo()


# --- Sismo ---

func iniciar_sismo() -> void:
	fase = Fase.SISMO
	ocupado = true
	_terminando = false
	_fuera = 0.0
	_sujeto_t = 0.0
	for n in npcs:
		n.interactuable = false
	jugador.liberar()
	_mostrar_mensaje("¡Está temblando! Ve a la mesa del comedor.")
	Sismo.iniciar(self, 1.0, Sismo.SEGUNDOS_FUERTE, Sismo.SEGUNDOS_AVISO)


func _tick(delta: float) -> void:
	if fase == Fase.SISMO and not _terminando and Sismo.fase in [Sismo.Fase.AVISO, Sismo.Fase.FUERTE]:
		_vigilar(delta)
	elif fase == Fase.DESPUES and _ir_escalera and not ocupado and not _nivel_terminado and en_zona("Zona_Escalera"):
		_llegar_a_la_escalera.call_deferred()


## Revisa cada fotograma cómo se está protegiendo Sami.
func _vigilar(delta: float) -> void:
	var en_mesa := en_zona("Zona_Mesa")
	var sujeto := Input.is_action_pressed("INTERACTUAR") and en_mesa
	_agachar(sujeto)
	# Aviso y primeros segundos: solo se marca el error si va a la puerta o se queda en la ventana
	if en_zona("Zona_Puerta"):
		_fallar("Correr a la puerta")
		return
	if en_zona("Zona_Ventana") and not en_mesa and Sismo.fase == Sismo.Fase.FUERTE and Sismo.t_fuerte > 1.0:
		_fallar("Quedarse junto a la ventana")
		return
	_mostrar_mensaje(TEXTO_AGACHARSE if en_mesa else "Ve a la mesa del comedor.")
	if sujeto:
		_sujeto_t += delta
	var total := Sismo.SEGUNDOS_FUERTE - SEGUNDOS_LLEGADA
	_actualizar_iconos(0 if not sujeto else mini(1 + int(_sujeto_t / (total / 3.0)), 3))
	if Sismo.fase != Sismo.Fase.FUERTE:
		return
	var t := Sismo.t_fuerte
	if t >= SEGUNDOS_LLEGADA:
		# Desde aquí hay que estar en la mesa, agachado y sujeto hasta que termine
		if sujeto:
			_fuera = 0.0
		else:
			_fuera += delta
			if _fuera >= TOLERANCIA:
				_fallar("" if en_mesa else "Salir de la zona segura")
				return
	if t >= Sismo.SEGUNDOS_FUERTE:
		_terminar_bien()


## Sami se agacha junto a la mesa: se queda quieto y un poco más bajo (todavía no hay dibujo de la pose agachada).
func _agachar(agachado: bool) -> void:
	if agachado:
		jugador.bloquear()
	else:
		jugador.liberar()
	jugador.sprite.scale.y = 0.82 if agachado else 1.0


func _fallar(que_hizo: String) -> void:
	_terminando = true
	_agachar(false)
	_actualizar_iconos(0)
	_mostrar_mensaje("")
	Sismo.detener()
	var d := Estado.datos_decision("D8")
	var opciones: Array = d["opciones"]
	var hecho := que_hizo if que_hizo != "" else "Soltar la posición antes de que terminara el sismo"
	Estado.registrar_decision("D8", false)
	await Retroalimentacion.tarjeta("Ojo", hecho, str(opciones[0]), str(d["retro"]), true)
	fase = Fase.ESPERA
	await esperar(0.4)
	await Dialogo.mostrar_texto("", "Vamos a intentarlo otra vez. Cuando empiece, ve a la mesa y mantén E.")
	# Se repite el sismo desde el principio (el primer intento ya quedó registrado)
	jugador.global_position = marcadores.get_node("Spawn").position
	await esperar(0.5)
	iniciar_sismo()


func _terminar_bien() -> void:
	_terminando = true
	_agachar(false)
	_mostrar_mensaje("")
	Sismo.detener()
	var d := Estado.datos_decision("D8")
	var opciones: Array = d["opciones"]
	var primero := Estado.registrar_decision("D8", true)
	for n in npcs:
		n.interactuable = true
	await Retroalimentacion.tarjeta("Muy bien" if primero else "Casi", str(opciones[0]), str(opciones[0]), str(d["retro"]), false)
	hud.marcar("D8")
	fase = Fase.DESPUES
	if _capa_iconos != null:
		_capa_iconos.visible = false
	ocupado = false
	await decir("", "El movimiento terminó. Hay vidrios en el piso y se siente un olor extraño. Con calma, revisa qué hacer.")


## Termina el sismo de golpe (solo para pruebas): éxito o fallo sin esperar los 20 s.
func forzar_fin_sismo(exito: bool) -> void:
	if exito:
		_terminar_bien()
	else:
		_fallar("Correr a la puerta")


# --- Íconos y mensajes ---

func _crear_iconos() -> void:
	_capa_iconos = CanvasLayer.new()
	_capa_iconos.layer = 6
	add_child(_capa_iconos)
	var fila := HBoxContainer.new()
	fila.position = Vector2(190, 306)
	fila.add_theme_constant_override("separation", 10)
	_capa_iconos.add_child(fila)
	for nombre in NOMBRES_ICONOS:
		var caja := PanelContainer.new()
		caja.add_theme_stylebox_override("panel", EstiloUI.caja(Color("0f2d38", 0.85), EstiloUI.GRIS, 2, 8, 4))
		var e := EstiloUI.etiqueta(nombre, 12, EstiloUI.GRIS)
		caja.add_child(e)
		fila.add_child(caja)
		_icono_labels.append(e)
	_mensaje = EstiloUI.etiqueta("", 13, EstiloUI.CREMA)
	_mensaje.position = Vector2(0, 280)
	_mensaje.size = Vector2(640, 20)
	_mensaje.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mensaje.add_theme_color_override("font_outline_color", Color("0f2d38"))
	_mensaje.add_theme_constant_override("outline_size", 5)
	_capa_iconos.add_child(_mensaje)
	_capa_iconos.visible = false


## Enciende los primeros `encendidos` íconos (en orden).
func _actualizar_iconos(encendidos: int) -> void:
	_capa_iconos.visible = fase == Fase.SISMO
	for i in _icono_labels.size():
		_icono_labels[i].add_theme_color_override("font_color", EstiloUI.NARANJA if i < encendidos else EstiloUI.GRIS)


func _mostrar_mensaje(texto: String) -> void:
	if _mensaje != null:
		_mensaje.text = texto
		_capa_iconos.visible = fase == Fase.SISMO


# --- Después del sismo ---

## Zapatos, mochila y linterna: al usar cualquiera sale la decisión D9; si es segura, los tres se recogen.
func _on_item(_item: ObjetoSuelo) -> void:
	if ocupado or fase != Fase.DESPUES or Estado.lograda("D9"):
		return
	await decir("", "Hay vidrios por todo el piso y hay que salir.")
	if await decidir("D9"):
		_quitar_items()
		Audio.efecto("item_recoge")
		await esperar(0.25)
		Audio.efecto("linterna_on")
		Notificacion.mostrar("Listo", "Zapatos cerrados, mochila y linterna contigo.")


func _quitar_items() -> void:
	for o in items:
		if is_instance_valid(o):
			o.queue_free()
	items.clear()


func _on_opcion(id: String, indice: int, _segura: bool) -> void:
	# El ascensor tiene el cartel «No usar» y suena el rechazo
	if id == "D11" and indice == 1:
		Audio.efecto("ascensor_no")


func _on_prop(prop: Prop) -> void:
	if ocupado or fase != Fase.DESPUES:
		return
	match prop.etiqueta:
		"D3":
			if Estado.lograda("D10"):
				await decir("", "Ya te alejaste de la cocina. Avisa desde un lugar seguro.")
			else:
				await decir("", "Huele a gas en la cocina.")
				await decidir("D10")
		"salida":
			if not (Estado.lograda("D9") and Estado.lograda("D10")):
				await decir("", "Antes de salir, termina lo que falta: los zapatos, la mochila y la linterna, y el olor a gas.")
				return
			if Estado.lograda("D11"):
				await decir("", "Baja por la escalera, al fondo del vestíbulo.")
				return
			await decir("", "Hay que bajar del 4.º piso. Junto a la puerta está la escalera y el ascensor, que tiene un cartel que dice «No usar».")
			if await decidir("D11"):
				_ir_escalera = true
				await decir("", "Camina hasta la escalera, al fondo del vestíbulo.")


func _llegar_a_la_escalera() -> void:
	if _nivel_terminado or ocupado:
		return
	_nivel_terminado = true
	await decir("Lucía", "¡Muy bien, Sami! Bajaste con calma y por la escalera.")
	await terminar_nivel()


func _on_npc(npc: Npc) -> void:
	if ocupado or fase != Fase.DESPUES:
		return
	if npc.personaje == "marta":
		await decir("Mamá", "Estoy bien, Sami. Vamos a salir con calma.")
