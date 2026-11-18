extends Node
## Dueño del menú de pausa (ESC). Decide cuándo se puede abrir y pausa el juego mientras está abierto
## (get_tree().paused). La libreta (TAB) se conectará aquí cuando exista su escena.
##
## Reglas:
##  - No se abre durante un diálogo ni un cuestionario, ni sin jugador en escena (título, introducción).
##  - ESC: la cancelación de conversaciones tiene prioridad (el balloon se la queda); si no hay
##    diálogo, abre la pausa. En la pausa, ESC retrocede o reanuda.

const ESCENA_PAUSA := preload("res://Scenes/UI/Pausa.tscn")
const ESCENA_TITULO := "res://Scenes/UI/PantallaTitulo.tscn"

var pausa: MenuPausa

## true mientras es este autoload quien mantiene el árbol en pausa.
var _pausando := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	pausa = ESCENA_PAUSA.instantiate()
	add_child(pausa)
	pausa.reanudar_pedido.connect(cerrar_pausa)
	pausa.volver_al_titulo_pedido.connect(volver_al_titulo)


## true si hay un menú abierto.
func hay_menu() -> bool:
	return pausa.abierta


## ¿Se puede abrir un menú ahora? (jugador en escena, sin diálogo ni cuestionario)
func puede_abrir() -> bool:
	if Dialogo.hay_dialogo() or not Dialogo.pausa_permitida():
		return false
	if Evaluacion.cuestionario_activo:
		return false   # la evaluación no se interrumpe con la pausa
	return get_tree().get_first_node_in_group("player") != null


func _input(evento: InputEvent) -> void:
	if evento is InputEventKey and evento.echo:
		return
	if evento.is_action_pressed("PAUSA"):
		if pausa.abierta:
			get_viewport().set_input_as_handled()
			if not pausa.atras():
				cerrar_pausa()
		elif puede_abrir():
			get_viewport().set_input_as_handled()
			abrir_pausa()


# --- Pausa ---

func abrir_pausa() -> void:
	if pausa.abierta or not puede_abrir():
		return
	pausa.abrir()
	_actualizar_pausa()


func cerrar_pausa() -> void:
	pausa.cerrar()
	_actualizar_pausa()


## Guarda y vuelve a la pantalla de título.
func volver_al_titulo() -> void:
	if Guardado.puede_guardar():
		Guardado.guardar_ahora()
	cerrar_pausa()
	get_tree().paused = false
	get_tree().change_scene_to_file(ESCENA_TITULO)


## El árbol está en pausa exactamente mientras haya un menú abierto.
func _actualizar_pausa() -> void:
	if hay_menu():
		_pausando = true
		get_tree().paused = true
	elif _pausando:
		_pausando = false
		get_tree().paused = false


func _process(_delta: float) -> void:
	# Red de seguridad: si no hay ningún menú abierto, el juego nunca se queda congelado por nosotros
	if _pausando and not hay_menu():
		_pausando = false
		get_tree().paused = false
