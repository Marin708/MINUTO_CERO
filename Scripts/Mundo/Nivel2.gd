class_name Nivel2
extends Nivel
## Nivel 2 — Durante (el mismo apartamento, con daños leves).
##
## Un aviso de 2 s y luego el sismo fuerte (unos 20 s) con temblor de cámara moderado, polvo y objetos que caen.
## Mecánica «Agacharse, cubrirse y sujetarse» (D8): hay que llegar a la mesa del comedor (zona segura) y MANTENER E
## hasta que termine; tres íconos se encienden en orden. Si Sami sale de la zona, va a la puerta, se queda junto a la
## ventana o suelta E, la acción se marca como riesgosa, el sismo termina, sale la retroalimentación y se repite
## (el primer intento queda registrado). Después: zapatos y mochila (D9), olor a gas (D10) y la escalera sin ascensor (D11).
## [REVISAR] Los textos de este nivel los escribió el equipo (ver docs/textos_a_revisar.md).

const SEGUNDOS_AVISO := 2.0
const SEGUNDOS_FUERTE := 20.0
## Tiempo que se da para llegar a la mesa antes de exigir que Sami esté agachado.
const SEGUNDOS_LLEGADA := 6.0
## Cuánto se tolera soltar E o salir de la zona antes de marcar el error.
const TOLERANCIA := 0.7
const NOMBRES_ICONOS := ["Agacharse", "Cubrirse", "Sujetarse"]

enum Fase { ESPERA, AVISO, FUERTE, DESPUES }

var fase: Fase = Fase.ESPERA
var _t := 0.0
var _fuera := 0.0
var _icono_labels: Array[Label] = []
var _capa_iconos: CanvasLayer
var _mensaje: Label
var _objetos_caidos: Array[float] = [3.0, 5.0, 8.0, 12.0, 16.0]
var _siguiente_caida := 0
var _terminando := false
## Para pruebas: si es true, el sismo no se inicia solo.
var sin_inicio_automatico := false


func _init() -> void:
	numero = 2
	archivo_mapa = "res://Resources/Mundo/apartamento.txt"
	archivo_danos = "res://Resources/Mundo/apartamento_danos.txt"
	titulo_hud = "Nivel 2 · Durante"


func _es_interactuable(etiqueta: String) -> bool:
	# Los riesgos del nivel 1 ya no se tocan: solo el armario (D9), la estufa (D10) y la puerta (D11)
	return etiqueta in ["kit", "D3", "salida"]


func _preparar() -> void:
	hud.configurar(titulo_hud, [
		{"id": "D8", "texto": "Protegerte durante el sismo"},
		{"id": "D9", "texto": "Zapatos y mochila (armario)"},
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
	_crear_iconos()
	if not sin_inicio_automatico and not Estado.lograda("D8"):
		_inicio.call_deferred()
	else:
		fase = Fase.DESPUES


func _inicio() -> void:
	ocupado = true
	await esperar(0.6)
	await Dialogo.mostrar_texto("", "Es la tarde. Estás en casa y, de pronto, el piso empieza a vibrar.")
	iniciar_sismo()


# --- Sismo ---

func iniciar_sismo() -> void:
	fase = Fase.AVISO
	_t = 0.0
	_fuera = 0.0
	_siguiente_caida = 0
	ocupado = true
	_terminando = false
	for n in npcs:
		n.asustado = true
		n.interactuable = false
	temblar(1.5, SEGUNDOS_AVISO, false)
	Audio.efecto("sismo_aviso")
	_mostrar_mensaje("¡Está temblando! Ve a la mesa del comedor y mantén E.")


func _tick(delta: float) -> void:
	match fase:
		Fase.AVISO:
			_t += delta
			if _t >= SEGUNDOS_AVISO:
				_empezar_fuerte()
		Fase.FUERTE:
			_t += delta
			_vigilar(delta)


func _empezar_fuerte() -> void:
	fase = Fase.FUERTE
	_t = 0.0
	temblar(3.5, SEGUNDOS_FUERTE, false)
	polvo(true)
	Audio.ambiente("amb_sismo", 0.5)
	jugador.liberar()
	_actualizar_iconos(0)


## Revisa cada fotograma cómo se está protegiendo Sami.
func _vigilar(delta: float) -> void:
	if _terminando:
		return
	# Objetos que caen cerca de la ventana, el estante y la lámpara
	if _siguiente_caida < _objetos_caidos.size() and _t >= _objetos_caidos[_siguiente_caida]:
		_caida(_siguiente_caida)
		_siguiente_caida += 1
	var en_mesa := en_zona("Zona_Mesa")
	var sujeto := Input.is_action_pressed("INTERACTUAR")
	# Riesgos claros: ir a la puerta o quedarse junto a la ventana (sin estar bajo la mesa)
	if en_zona("Zona_Puerta"):
		_fallar("Correr a la puerta")
		return
	if en_zona("Zona_Ventana") and not en_mesa and _t > 1.0:
		_fallar("Quedarse junto a la ventana")
		return
	if _t < SEGUNDOS_LLEGADA:
		if en_mesa and sujeto:
			_agachar(true)
		else:
			_agachar(false)
		_actualizar_iconos(0)
		return
	# Desde aquí hay que estar en la mesa, agachado y sujeto hasta que termine
	if en_mesa and sujeto:
		_fuera = 0.0
		_agachar(true)
	else:
		_agachar(false)
		_fuera += delta
		if _fuera >= TOLERANCIA:
			_fallar("" if en_mesa else "Salir de la zona segura")
			return
	var avance := clampf((_t - SEGUNDOS_LLEGADA) / (SEGUNDOS_FUERTE - SEGUNDOS_LLEGADA), 0.0, 1.0)
	_actualizar_iconos(int(floor(avance * 3.0 + 0.001)))
	if _t >= SEGUNDOS_FUERTE:
		_terminar_bien()


## Sami se agacha junto a la mesa: se queda quieto y un poco más bajo.
func _agachar(agachado: bool) -> void:
	if agachado:
		jugador.bloquear()
	else:
		jugador.liberar()
	jugador.sprite.scale.y = 0.82 if agachado else 1.0


func _caida(indice: int) -> void:
	var sitios := ["Zona_Ventana", "Prop_Estante_D1", "Zona_Mesa", "Prop_Repisa_D4", "Zona_Ventana"]
	var sonidos := ["objeto_cae", "estante_cae", "objeto_cae", "vidrio_roto", "vidrio_roto"]
	var nombre: String = sitios[indice]
	var destino := pos_zona(nombre) if nombre.begins_with("Zona") else (objetos.get_node(nombre) as Node2D).global_position
	# Caen cerca del lugar, pero a un lado de la mesa para no tapar la zona segura
	objeto_cae(destino + Vector2(randf_range(-30.0, 30.0), 24.0), sonidos[indice])


func _fallar(que_hizo: String) -> void:
	_terminando = true
	fase = Fase.DESPUES
	_agachar(false)
	polvo(false)
	_actualizar_iconos(0)
	Audio.efecto("sismo_fin")
	Audio.ambiente("amb_casa", 0.5)
	temblar(0.0, 0.01)
	var d := Estado.datos_decision("D8")
	var opciones: Array = d["opciones"]
	var hecho := que_hizo if que_hizo != "" else "Soltar la posición antes de que terminara el sismo"
	Estado.registrar_decision("D8", false)
	await TarjetaRetro.mostrar(get_tree(), "Ojo", hecho, str(opciones[0]), str(d["retro"]), true)
	await esperar(0.4)
	await Dialogo.mostrar_texto("", "Vamos a intentarlo otra vez. Cuando empiece, ve a la mesa y mantén E.")
	# Se repite el sismo desde el principio (el primer intento ya quedó registrado)
	jugador.global_position = marcadores.get_node("Spawn").position
	await esperar(0.5)
	iniciar_sismo()


func _terminar_bien() -> void:
	_terminando = true
	fase = Fase.DESPUES
	_agachar(false)
	polvo(false)
	Audio.efecto("sismo_fin")
	Audio.ambiente("amb_casa", 1.0)
	temblar(0.0, 0.01)
	_mostrar_mensaje("")
	var d := Estado.datos_decision("D8")
	var opciones: Array = d["opciones"]
	var primero := Estado.registrar_decision("D8", true)
	for n in npcs:
		n.asustado = false
		n.interactuable = true
	await TarjetaRetro.mostrar(get_tree(), "Muy bien" if primero else "Casi", str(opciones[0]), str(opciones[0]), str(d["retro"]), false)
	hud.marcar("D8")
	_actualizar_iconos(0)
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
	_mensaje.position = Vector2(0, 60)
	_mensaje.size = Vector2(640, 20)
	_mensaje.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mensaje.add_theme_color_override("font_outline_color", Color("0f2d38"))
	_mensaje.add_theme_constant_override("outline_size", 5)
	_capa_iconos.add_child(_mensaje)
	_capa_iconos.visible = false


## Enciende los primeros `encendidos` íconos (en orden).
func _actualizar_iconos(encendidos: int) -> void:
	_capa_iconos.visible = fase == Fase.AVISO or fase == Fase.FUERTE
	for i in _icono_labels.size():
		_icono_labels[i].add_theme_color_override("font_color", EstiloUI.NARANJA if i < encendidos else EstiloUI.GRIS)


func _mostrar_mensaje(texto: String) -> void:
	if _mensaje != null:
		_mensaje.text = texto
		_capa_iconos.visible = texto != "" or fase == Fase.FUERTE


# --- Después del sismo ---

func _on_prop(prop: Prop) -> void:
	if ocupado or fase != Fase.DESPUES:
		return
	match prop.etiqueta:
		"kit":
			if Estado.lograda("D9"):
				await decir("", "Ya tienes los zapatos puestos y la mochila contigo.")
			else:
				await decir("", "Hay vidrios en el piso y tienes que salir.")
				await decidir("D9")
		"D3":
			if Estado.lograda("D10"):
				await decir("", "Ya te alejaste de la cocina. Avisa desde un lugar seguro.")
			else:
				await decir("", "Huele a gas en la cocina.")
				await decidir("D10")
		"salida":
			if not (Estado.lograda("D9") and Estado.lograda("D10")):
				await decir("", "Antes de salir, termina de revisar lo que falta: los zapatos y la mochila, y el olor a gas.")
				return
			await decir("", "Hay que bajar del 4.º piso. La puerta de salida da a la escalera y al ascensor.")
			if await decidir("D11") and hud.todas_hechas():
				await decir("Lucía", "¡Muy bien, Sami! Bajaste con calma y por la escalera.")
				await terminar_nivel()


func _on_npc(npc: Npc) -> void:
	if ocupado or fase != Fase.DESPUES:
		return
	if npc.personaje == "marta":
		await decir("Mamá", "Estoy bien, Sami. Vamos a salir con calma.")
