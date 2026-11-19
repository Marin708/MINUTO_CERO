class_name Sismografo
extends Control
## Una línea de sismógrafo que cruza la pantalla de lado a lado y se agita. Dibuja la traza que corre hacia la izquierda.
## `amplitud` (en píxeles) es el tamaño normal de la agitación; `sacudir()` la sube de golpe y la deja bajar.

@export var color := EstiloUI.NARANJA
@export var amplitud := 4.0
## Cuántos puntos tiene la traza (uno por cada 4 px de ancho aproximadamente).
const PASO_X := 4.0

var _muestras: PackedFloat32Array = PackedFloat32Array()
var _acumulado := 0.0
var _pico := 0.0   # agitación extra que decae sola


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Una sacudida corta: la línea se dispara y vuelve a su agitación normal.
func sacudir(fuerza: float = 26.0) -> void:
	_pico = fuerza


func _process(delta: float) -> void:
	var n := int(size.x / PASO_X) + 2
	if _muestras.size() != n:
		_muestras.resize(n)
	_acumulado += delta * 40.0   # unos 40 muestras por segundo
	while _acumulado >= 1.0:
		_acumulado -= 1.0
		for i in range(0, _muestras.size() - 1):
			_muestras[i] = _muestras[i + 1]
		var ruido := randf_range(-1.0, 1.0)
		# De vez en cuando, un tironcito más fuerte, como una traza real
		if randf() < 0.04:
			ruido *= 2.4
		_muestras[_muestras.size() - 1] = ruido * (amplitud + _pico)
	_pico = maxf(_pico - delta * 40.0, 0.0)
	queue_redraw()


func _draw() -> void:
	if _muestras.size() < 2:
		return
	var puntos := PackedVector2Array()
	for i in _muestras.size():
		puntos.append(Vector2(i * PASO_X, size.y / 2.0 + _muestras[i]))
	# Un borde oscuro por debajo para que se lea sobre el cielo naranja de la ilustración
	draw_polyline(puntos, Color(EstiloUI.AZUL_NOCHE, 0.85), 6.0)
	draw_polyline(puntos, color, 3.0)
