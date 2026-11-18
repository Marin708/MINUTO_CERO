class_name Nivel3
extends Nivel
## Nivel 3 — Después (calle y parque, punto de encuentro).
##
## Doña Rosa pide ayuda (D12). Un cable caído y un edificio agrietado cierran el camino (D13): se rodea por la avenida
## abierta. Tomás tiene un rumor de cadena en el celular y hay un mensaje de radio oficial (D14). Llega una réplica
## y Sami está afuera (D15). Al llegar al punto de encuentro se reúne con Mamá y Lucía y termina el juego.
## [REVISAR] Los textos de este nivel (incluido el mensaje de radio) los escribió el equipo (ver docs/textos_a_revisar.md).

const TEXTO_RADIO := "Radio oficial: «Mantengan la calma. Las autoridades evalúan los daños. Infórmense solo por canales oficiales y no saturen las líneas de emergencia.»"
const SEGUNDOS_ANTES_REPLICA := 3.0
const SEGUNDOS_REPLICA := 6.0
const INTENSIDAD_REPLICA := 0.5
## Segundos del aviso de la réplica antes de exigir que Sami esté agachado.
const SEGUNDOS_AVISO_REPLICA := 1.0
const TOLERANCIA_REPLICA := 0.7
const TEXTO_PROTEGERSE := "Mantén E: agacharte y proteger la cabeza"
const TEXTO_CIERRE := "MINUTO CERO es un juego educativo. No es un simulacro oficial: practica tu plan en familia y consulta a las autoridades de gestión del riesgo."

var _replica_hecha := false
var _replica_programada := false
var _en_peligro_espera := 0.0
var _aviso_llegada := 0.0
var _terminando := false
var _replica_activa := false
var _r_fuera := 0.0
var _r_termino := false
var _capa_replica: CanvasLayer
var _mensaje: Label
var _iconos: Array[Label] = []


func _init() -> void:
	numero = 3
	archivo_mapa = "res://Resources/Mundo/calle.txt"
	titulo_hud = "Nivel 3 · Después"


func _preparar() -> void:
	hud.configurar(titulo_hud, [
		{"id": "D12", "texto": "Ayudar a Doña Rosa"},
		{"id": "D13", "texto": "Cable caído y edificio agrietado"},
		{"id": "D14", "texto": "Radio oficial y cadena (Tomás)"},
		{"id": "D15", "texto": "Réplica: protegerte"},
		{"id": "llegada", "texto": "Llegar al punto de encuentro"},
	])
	for id in ["D12", "D13", "D14", "D15"]:
		if Estado.lograda(id):
			hud.marcar(id)
	_inicio.call_deferred()


func _inicio() -> void:
	await esperar(0.6)
	await decir("", "Saliste del edificio. Afuera hay polvo, ruido y mucha gente asustada. El punto de encuentro está en el parque.")


func _tick(delta: float) -> void:
	if _replica_activa:
		_vigilar_replica(delta)
		return
	if ocupado or _terminando:
		return
	if _en_peligro_espera > 0.0:
		_en_peligro_espera -= delta
	# Cable caído y edificio agrietado: al acercarse se decide qué hacer
	if not Estado.lograda("D13") and _en_peligro_espera <= 0.0 and en_zona("Zona_Peligro_D13"):
		_peligro.call_deferred()
	# Réplica: unos segundos después de resolver la información
	if Estado.lograda("D14") and not _replica_hecha and not _replica_programada:
		_replica_programada = true
		_replica.call_deferred()
	# Llegada al punto de encuentro
	if en_zona("Zona_Llegada"):
		_aviso_llegada -= delta
		_llegar.call_deferred()


func _peligro() -> void:
	if ocupado:
		return
	await decir("", "Más adelante hay un cable caído y un edificio con grietas grandes que cierran el camino.")
	var lograda := await decidir("D13")
	if not lograda:
		# Se aparta a Sami para que no vuelva a saltar de inmediato
		jugador.global_position = pos_zona("Zona_Peligro_D13") + Vector2(-110, 40)
		_en_peligro_espera = 4.0
	else:
		_en_peligro_espera = 999.0


func _on_npc(npc: Npc) -> void:
	if ocupado:
		return
	match npc.personaje:
		"rosa":
			await _con_rosa()
		"tomas":
			await _con_tomas()
		"marta":
			await decir("Mamá", "¡Sami! Qué alivio verte. Espera a Lucía y a mí aquí, en el punto de encuentro.")
		"lucia":
			await decir("Lucía", "Aquí estamos todos. Buen trabajo.")


func _con_rosa() -> void:
	if Estado.lograda("D12"):
		await decir("Doña Rosa", "Gracias, mijo. Ya me siento más tranquila.")
		return
	await decir("Doña Rosa", ["¡Ay, mijo! Me asusté mucho y no puedo caminar bien.", "No sé qué hacer."])
	if await decidir("D12"):
		await decir("Doña Rosa", "Qué Dios te bendiga. Ya me siento más segura.")


func _con_tomas() -> void:
	if Estado.lograda("D14"):
		await decir("Tomás", "Ya no voy a reenviar el mensaje. Le voy a decir a mi mamá.")
		return
	await decir("Tomás", ["Mira, Sami, me llegó este mensaje al celular: «viene otro terremoto peor esta noche». Todos lo están reenviando.", "Pero en la radio dijeron otra cosa."])
	Audio.efecto("radio_estatica")
	await esperar(0.5)
	Audio.efecto("radio_aviso")
	await decir("", TEXTO_RADIO)
	await decidir("D14")


## La réplica (D15): el sistema Sismo con intensidad menor. Sami está afuera, sin mesa: debe quedarse en el espacio
## abierto, lejos de edificios y cables, MANTENER E (agacharse y proteger la cabeza) hasta que termine. Si no lo hace,
## sale la tarjeta con «Intentar de nuevo» y la réplica se repite hasta lograrlo (el primer intento queda registrado).
func _replica() -> void:
	await esperar(SEGUNDOS_ANTES_REPLICA)
	while ocupado:
		await esperar(0.5)
	_replica_hecha = true
	await decir("", "De pronto, el suelo vuelve a moverse: es una réplica.")
	while not Estado.lograda("D15"):
		_iniciar_replica()
		_r_termino = false
		while not _r_termino:
			await get_tree().process_frame
		await esperar(0.4)
	temblar(0.0, 0.01)
	await esperar(0.5)


func _iniciar_replica() -> void:
	_crear_panel_replica()
	_replica_activa = true
	ocupado = true
	_r_fuera = 0.0
	_mostrar_mensaje("Estás afuera. Aléjate de edificios y cables y protégete.")
	Sismo.iniciar(self, INTENSIDAD_REPLICA, SEGUNDOS_REPLICA, SEGUNDOS_AVISO_REPLICA)


func _vigilar_replica(delta: float) -> void:
	if Sismo.fase not in [Sismo.Fase.AVISO, Sismo.Fase.FUERTE]:
		return
	var cerca_peligro := en_zona("Zona_Peligro_D13") or en_zona("Zona_Cable")
	var sujeto := Input.is_action_pressed("INTERACTUAR") and not cerca_peligro
	if sujeto:
		jugador.bloquear()
	else:
		jugador.liberar()
	jugador.sprite.scale.y = 0.82 if sujeto else 1.0
	_mostrar_mensaje(TEXTO_PROTEGERSE if not cerca_peligro else "Estás muy cerca de un edificio o un cable: aléjate.")
	_actualizar_iconos(2 if sujeto and Sismo.t_fuerte > SEGUNDOS_REPLICA * 0.5 else (1 if sujeto else 0))
	if cerca_peligro and Sismo.fase == Sismo.Fase.FUERTE and Sismo.t_fuerte > 0.8:
		_terminar_replica(false, "Correr hacia un edificio")
		return
	if Sismo.fase == Sismo.Fase.FUERTE and Sismo.t_fuerte > SEGUNDOS_AVISO_REPLICA:
		if sujeto:
			_r_fuera = 0.0
		else:
			_r_fuera += delta
			if _r_fuera >= TOLERANCIA_REPLICA:
				_terminar_replica(false, "No te agachaste ni protegiste la cabeza")
				return
	if Sismo.fase == Sismo.Fase.FUERTE and Sismo.t_fuerte >= SEGUNDOS_REPLICA:
		_terminar_replica(true, "")


func _terminar_replica(exito: bool, que_hizo: String) -> void:
	_replica_activa = false
	jugador.liberar()
	jugador.sprite.scale.y = 1.0
	_capa_replica.visible = false
	Sismo.detener()
	var d := Estado.datos_decision("D15")
	var opciones: Array = d["opciones"]
	var primero := Estado.registrar_decision("D15", exito)
	var titulo := "Ojo"
	if exito:
		titulo = "Muy bien" if primero else "Casi"
	await Retroalimentacion.tarjeta(titulo, str(opciones[0]) if exito else que_hizo, str(opciones[0]), str(d["retro"]), not exito)
	if exito:
		hud.marcar("D15")
	ocupado = false
	_r_termino = true


func _crear_panel_replica() -> void:
	if _capa_replica != null:
		_capa_replica.visible = true
		return
	_capa_replica = CanvasLayer.new()
	_capa_replica.layer = 6
	add_child(_capa_replica)
	var fila := HBoxContainer.new()
	fila.position = Vector2(220, 306)
	fila.add_theme_constant_override("separation", 10)
	_capa_replica.add_child(fila)
	for nombre in ["Agáchate", "Protege tu cabeza"]:
		var caja := PanelContainer.new()
		caja.add_theme_stylebox_override("panel", EstiloUI.caja(Color("0f2d38", 0.85), EstiloUI.GRIS, 2, 8, 4))
		var e := EstiloUI.etiqueta(nombre, 12, EstiloUI.GRIS)
		caja.add_child(e)
		fila.add_child(caja)
		_iconos.append(e)
	_mensaje = EstiloUI.etiqueta("", 13, EstiloUI.CREMA)
	_mensaje.position = Vector2(0, 280)
	_mensaje.size = Vector2(640, 20)
	_mensaje.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mensaje.add_theme_color_override("font_outline_color", Color("0f2d38"))
	_mensaje.add_theme_constant_override("outline_size", 5)
	_capa_replica.add_child(_mensaje)


func _actualizar_iconos(encendidos: int) -> void:
	for i in _iconos.size():
		_iconos[i].add_theme_color_override("font_color", EstiloUI.NARANJA if i < encendidos else EstiloUI.GRIS)


func _mostrar_mensaje(texto: String) -> void:
	if _mensaje != null:
		_mensaje.text = texto


func _llegar() -> void:
	if ocupado or _terminando:
		return
	var faltan := not (Estado.lograda("D12") and Estado.lograda("D13") and Estado.lograda("D14") and Estado.lograda("D15"))
	if faltan:
		if _aviso_llegada <= 0.0:
			_aviso_llegada = 12.0
			await decir("Lucía", "Aún tienes cosas pendientes en el camino. Mira la lista de tareas.")
		return
	_terminando = true
	hud.marcar("llegada")
	await decir("Mamá", "¡Sami! Aquí estamos, a salvo y lejos de los edificios y los cables.")
	await decir("Lucía", ["Llegaste al punto de encuentro. Lo hiciste con calma y pensando en los demás.", "Prepararte hoy puede cambiar el minuto cero."])
	await decir("", TEXTO_CIERRE)
	await terminar_nivel()
