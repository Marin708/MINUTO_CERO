class_name Introduccion
extends CanvasLayer
## Después del título: el consentimiento, el cuestionario inicial (14 preguntas) y la introducción de Lucía, que
## explica cómo se juega. Si el «pre» ya está hecho (partida cargada), no se repite. Termina pasando al nivel 1.
## [REVISAR] Los textos de Lucía los escribió el equipo (ver docs/textos_a_revisar.md).

const TEXTOS := [
	"¡Hola! Soy Lucía, brigadista de la comunidad de Villa Cafetal. Te acompañaré mientras aprendes qué hacer antes, durante y después de un sismo.",
	"Tú eres Sami. Muévete con las flechas o con W, A, S y D, y usa E para hablar y revisar las cosas.",
	"Con TAB abres tu libreta y con ESC, la pausa. Aquí no hay combate ni se pierde: si te equivocas, te explico y puedes intentarlo de nuevo.",
	"Prepararte hoy puede cambiar el minuto cero. ¡Empecemos!",
]

var lucia: AnimatedSprite2D


func _ready() -> void:
	layer = 1
	lucia = FondoEvaluacion.crear(self)
	lucia.scale = Vector2(3.5, 3.5)
	lucia.position = Vector2(110, 250)
	_secuencia.call_deferred()


func _secuencia() -> void:
	Audio.musica("musica_titulo", 1.0)
	if not Flujo.modo_prueba and not Evaluacion.pre_completo():
		if not Evaluacion.consentimiento_dado:
			await Consentimiento.mostrar(get_tree())
		if Evaluacion.valido:
			await Cuestionario.mostrar(get_tree(), "pre")
	if Flujo.modo_prueba:
		Evaluacion.consentimiento_dado = true
	lucia.play(&"hablar")
	await Dialogo.mostrar_texto("Lucía", TEXTOS)
	lucia.play(&"idle")
	await Flujo.ir_a_nivel(1)
