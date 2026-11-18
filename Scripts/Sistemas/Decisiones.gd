class_name Decisiones
extends RefCounted
## Resuelve una decisión del juego (D1 a D15) con retroalimentación inmediata y reintentos.
##
## Muestra la situación con las opciones MEZCLADAS (la primera del JSON es la segura), anota el intento en Estado
## (solo el primero puntúa; todos quedan como lección) y muestra la tarjeta de retroalimentación. Si no fue segura,
## el jugador puede «Intentar de nuevo» o seguir con «Entendido» (la decisión queda pendiente en el nivel).
##
## Uso:  var lograda: bool = await Decisiones.resolver(get_tree(), "D1")
## Devuelve true cuando se eligió la opción segura (en el primer intento o en un reintento).

## Para las pruebas: una sola partida sin mezclar (Dialogo.respuesta_de_prueba = índice de la opción mostrada).
static func resolver(arbol: SceneTree, id: String) -> bool:
	var d := Estado.datos_decision(id)
	if d.is_empty():
		push_error("Decisiones: la decisión '%s' no existe." % id)
		return false
	if str(d.get("tipo", "")) == "kit":
		return await KitUI.mostrar(arbol)
	var opciones: Array = d["opciones"]
	var segura := int(d["segura"])
	while true:
		var orden := _orden(opciones.size())
		var textos: Array = []
		for i in orden:
			textos.append(opciones[i])
		var elegido: int = await Dialogo.mostrar_texto("", str(d["situacion"]), textos)
		if elegido < 0:
			if Dialogo.respuesta_de_prueba != -99:
				return false
			continue   # cancelar no es una decisión: se vuelve a preguntar
		var indice: int = orden[elegido]
		var es_segura := indice == segura
		var primero := Estado.registrar_decision(id, es_segura)
		var titulo := "Ojo"
		if es_segura:
			titulo = "Muy bien" if primero else "Casi"
		var reintentar: bool = await TarjetaRetro.mostrar(arbol, titulo, str(opciones[indice]), str(opciones[segura]), str(d["retro"]), not es_segura)
		if es_segura:
			return true
		if not reintentar:
			return false
	return false


## Un orden aleatorio de las opciones (en pruebas, el orden del archivo).
static func _orden(cantidad: int) -> Array:
	var orden: Array = range(cantidad)
	if Dialogo.respuesta_de_prueba == -99:
		orden.shuffle()
	return orden
