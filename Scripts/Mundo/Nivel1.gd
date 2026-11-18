class_name Nivel1
extends Nivel
## Nivel 1 — Antes (apartamento, mañana). Tareas, en cualquier orden: revisar los 4 riesgos (D1 a D4), armar el
## kit en el armario (D5) y hablar con Mamá para acordar el punto de encuentro y las rutas (D6 y D7).
## Lucía ayuda con «¿Qué hago ahora?». Al terminar todo, pasa al nivel 2.
## [REVISAR] Los textos de las conversaciones de este nivel los escribió el equipo (ver docs/textos_a_revisar.md).

const RIESGOS := {"D1": "estante", "D2": "cuadro_cama", "D3": "gas_estufa", "D4": "repisa"}
const TEXTO_YA := "Ya lo dejaste asegurado."

var _terminando := false


func _init() -> void:
	numero = 1
	archivo_mapa = "res://Resources/Mundo/apartamento.txt"
	titulo_hud = "Nivel 1 · Antes"


func _preparar() -> void:
	hud.configurar(titulo_hud, [
		{"id": "D1", "texto": "Revisar el estante"},
		{"id": "D2", "texto": "Revisar el cuadro de la cama"},
		{"id": "D3", "texto": "Revisar el cilindro de gas"},
		{"id": "D4", "texto": "Revisar la repisa alta"},
		{"id": "D5", "texto": "Armar el kit (armario)"},
		{"id": "D6", "texto": "Punto de encuentro (Mamá)"},
		{"id": "D7", "texto": "Organizar la salida (Mamá)"},
	])
	for id in ["D1", "D2", "D3", "D4", "D5", "D6", "D7"]:
		if Estado.lograda(id):
			hud.marcar(id)
	for id in RIESGOS:
		var p := prop_con_etiqueta(id)
		if p != null:
			p.asegurado = Estado.lograda(id)
	_inicio.call_deferred()


func _inicio() -> void:
	await esperar(0.6)
	await decir("", "Es una mañana tranquila en Villa Cafetal. Antes de que pase cualquier cosa, vale la pena revisar la casa.")


func _on_prop(prop: Prop) -> void:
	if ocupado:
		return
	var id := prop.etiqueta
	if RIESGOS.has(id):
		if Estado.lograda(id):
			await decir("", TEXTO_YA)
			return
		if await decidir(id):
			prop.asegurar()
			await _revisar_fin()
	elif id == "kit":
		if Estado.lograda("D5"):
			await decir("", "Tu kit ya está armado y a mano.")
			return
		await decidir("D5")
		await _revisar_fin()
	elif id == "salida":
		await decir("", "Todavía no es momento de salir. Termina primero lo que tienes pendiente.")


func _on_npc(npc: Npc) -> void:
	if ocupado:
		return
	match npc.personaje:
		"marta":
			await _hablar_con_mama()
		"lucia":
			await _hablar_con_lucia()


func _hablar_con_mama() -> void:
	if Estado.lograda("D6") and Estado.lograda("D7"):
		await decir("Mamá", "Ya sabemos qué hacer. Gracias por ayudarme a organizar el plan.")
		return
	if not Estado.lograda("D6"):
		await decir("Mamá", ["Sami, ¿hablamos del plan de la familia?", "Si hay un sismo y tenemos que salir, ¿dónde nos reunimos?"])
		if await decidir("D6"):
			await _revisar_fin()
	if Estado.lograda("D6") and not Estado.lograda("D7"):
		await decir("Mamá", "Bien. Y para salir del edificio, ¿cómo lo hacemos?")
		if await decidir("D7"):
			await _revisar_fin()


func _hablar_con_lucia() -> void:
	var quiere := await decir("Lucía", "Hola, Sami. Soy Lucía, brigadista de la comunidad. Estoy por aquí si me necesitas.", ["¿Qué hago ahora?", "Nada, gracias"])
	if quiere == 0:
		await decir("Lucía", _pista())


## Una pista según lo que falte (sin dar la respuesta de las decisiones).
func _pista() -> String:
	for id in ["D1", "D2", "D3", "D4"]:
		if not Estado.lograda(id):
			return "Aún quedan cosas por revisar en la casa: el estante, el cuadro de la habitación, el cilindro de gas de la cocina y la repisa alta. Mira con calma lo que podría caerse."
	if not Estado.lograda("D5"):
		return "Falta el kit de emergencia. El armario de la habitación es un buen lugar para armarlo."
	if not Estado.lograda("D6") or not Estado.lograda("D7"):
		return "Habla con tu mamá, está en la cocina. El plan de la familia es importante."
	return "¡Ya lo hiciste todo! Puedes seguir."


func _revisar_fin() -> void:
	if _terminando or not hud.todas_hechas():
		return
	_terminando = true
	await decir("Lucía", "¡Muy bien, Sami! Dejaste la casa lista y tu familia tiene un plan.")
	await terminar_nivel()
