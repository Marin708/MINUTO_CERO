extends Node
## La retroalimentación de las decisiones. `mostrar(decision_id, opcion_elegida)` registra el intento en Estado
## (solo el primero puntúa; todos quedan como lección en la libreta), abre la tarjeta (Scenes/UI/TarjetaRetro.tscn)
## con «Muy bien» (segura al primer intento), «Casi» (segura en un reintento) u «Ojo» (no segura) y devuelve true
## si el jugador pidió «Intentar de nuevo».
##
## `opcion_elegida` es el índice de la opción en decisiones.json (0 = la segura), NO su posición en pantalla.

## Se emite al elegir una opción (para efectos del escenario, como el rechazo del ascensor).
signal opcion_elegida(decision_id: String, indice: int, segura: bool)


func mostrar(decision_id: String, indice_opcion: int) -> bool:
	var d := Estado.datos_decision(decision_id)
	var opciones: Array = d["opciones"]
	var segura := indice_opcion == int(d["segura"])
	var primero := Estado.registrar_decision(decision_id, segura)
	opcion_elegida.emit(decision_id, indice_opcion, segura)
	var titulo := "Ojo"
	if segura:
		titulo = "Muy bien" if primero else "Casi"
	return await tarjeta(titulo, str(opciones[indice_opcion]), str(opciones[int(d["segura"])]), str(d["retro"]), not segura)


## La tarjeta con textos propios (el kit, el sismo y la réplica registran su decisión por su cuenta).
func tarjeta(titulo: String, hecho: String, recomendado: String, por_que: String, permite_reintento: bool, lista_hecho: Array = []) -> bool:
	return await TarjetaRetro.mostrar(get_tree(), titulo, hecho, recomendado, por_que, permite_reintento, lista_hecho)
