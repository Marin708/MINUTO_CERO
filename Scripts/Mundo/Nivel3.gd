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

var _replica_hecha := false
var _replica_programada := false
var _en_peligro_espera := 0.0
var _aviso_llegada := 0.0
var _terminando := false


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


## La réplica: Sami está afuera y debe protegerse (D15). Se repite hasta elegir la opción segura.
func _replica() -> void:
	await esperar(SEGUNDOS_ANTES_REPLICA)
	while ocupado:
		await esperar(0.5)
	ocupado = true
	_replica_hecha = true
	Audio.efecto("replica")
	temblar(3.0, SEGUNDOS_REPLICA, false)
	for n in npcs:
		n.asustado = true
	await esperar(1.2)
	ocupado = false
	while not Estado.lograda("D15"):
		await decidir("D15")
	await esperar(0.8)
	for n in npcs:
		n.asustado = false
	temblar(0.0, 0.01)


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
	await terminar_nivel()
