extends Node
## Atajos de depuración para recorrer el juego sin jugarlo entero. SOLO en compilaciones de depuración
## (OS.is_debug_build()). No se usan teclas F (chocan con el editor) ni las del movimiento (flechas y WASD),
## E, TAB ni ESC. La M abre el panel de audio.
##
##   N      siguiente nivel (del 3 pasa al final)
##   1 2 3  saltar al nivel 1, 2 o 3
##   B      forzar el final PREPARADO   (15 decisiones seguras)
##   V      forzar el final EN CAMINO   (10 decisiones seguras)
##   X      forzar el final A REFORZAR  (3 decisiones seguras)
##
## B, V y X dejan las 15 decisiones resueltas y llevan a la pantalla del final. Cada tecla muestra un aviso
## de 2 segundos. El recorrido de pantallas lo hace el autoload Flujo (si todavía no existe, solo avisa).

const SEGUNDOS_AVISO := 2.0

## Decisiones seguras que deja cada tecla de final: final -> cantidad.
const SEGURAS := {"preparado": 15, "encamino": 10, "reforzar": 3}

var _etiqueta: Label
var _tween: Tween


func _ready() -> void:
	if not OS.is_debug_build():
		set_process_unhandled_input(false)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	var capa := CanvasLayer.new()
	capa.layer = 30
	add_child(capa)
	_etiqueta = Label.new()
	_etiqueta.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_etiqueta.anchor_left = 0.0
	_etiqueta.anchor_right = 1.0
	_etiqueta.offset_top = 6.0
	_etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_etiqueta.add_theme_font_size_override("font_size", 12)
	_etiqueta.add_theme_color_override("font_color", Color("fff4dc"))
	_etiqueta.add_theme_color_override("font_outline_color", Color("0f2d38"))
	_etiqueta.add_theme_constant_override("outline_size", 4)
	_etiqueta.modulate.a = 0.0
	_etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa.add_child(_etiqueta)


func _unhandled_input(evento: InputEvent) -> void:
	if not OS.is_debug_build() or not (evento is InputEventKey) or not evento.pressed or evento.echo:
		return
	match evento.keycode:
		KEY_N:
			siguiente_nivel()
		KEY_1:
			saltar_a_nivel(1)
		KEY_2:
			saltar_a_nivel(2)
		KEY_3:
			saltar_a_nivel(3)
		KEY_B:
			forzar_final("preparado")
		KEY_V:
			forzar_final("encamino")
		KEY_X:
			forzar_final("reforzar")


## N: pasa al nivel siguiente; desde el 3 va al final.
func siguiente_nivel() -> void:
	if Estado.nivel_actual >= Estado.NIVELES:
		_avisar("N: al final del juego")
		_flujo("ir_al_final")
	else:
		saltar_a_nivel(Estado.nivel_actual + 1)


func saltar_a_nivel(nivel: int) -> void:
	_avisar("%d: nivel %d" % [nivel, nivel])
	_flujo("ir_a_nivel", [nivel])


## Deja las 15 decisiones con las seguras que pide el final y salta a la pantalla del final.
func forzar_final(id: String) -> void:
	Estado.forzar_resultado(int(SEGURAS[id]))
	_avisar("Final forzado: %s (%s)" % [Estado.datos_final().get("nombre", id), Estado.calcular_final()])
	_flujo("ir_al_final")


## Llama a un método del autoload Flujo si existe.
func _flujo(metodo: String, argumentos: Array = []) -> void:
	var flujo := get_node_or_null("/root/Flujo")
	if flujo != null and flujo.has_method(metodo):
		flujo.callv(metodo, argumentos)


func _avisar(texto: String) -> void:
	if _etiqueta == null:
		return
	_etiqueta.text = texto
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_etiqueta, "modulate:a", 1.0, 0.15)
	_tween.tween_interval(SEGUNDOS_AVISO - 0.45)
	_tween.tween_property(_etiqueta, "modulate:a", 0.0, 0.3)
