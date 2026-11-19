extends Node
## Sistema de audio de MINUTO CERO. Los archivos están en Assets/Audio/{Efectos,Ambiente,Musica}/ y el nombre
## del archivo (sin extensión) es el identificador del sonido; se aceptan .wav, .ogg y .mp3.
##
##   Audio.efecto("ui_aceptar")                 un efecto suelto (varias voces a la vez)
##   Audio.musica("musica_antes", 1.5)           música, con fundido cruzado de 1.5 s
##   Audio.ambiente("amb_casa")                 sonido ambiente en bucle (por el bus de efectos)
##
## Los efectos y ambientes salen por el bus "Efectos" y la música por "Musica" (ver Opciones). Todo
## sigue sonando con el juego en pausa (para los sonidos del menú).
##
## Escucha las señales del juego (decisiones, tarjetas de memoria, diálogos...) y suena sin que cada
## objeto tenga que saber de audio. Lo que depende de un lugar concreto (pasos, sismo,
## menús) llama a efecto() desde su propio script. Si falta un archivo, no pasa nada: se avisa una
## vez en la consola y aparece en el panel de depuración (tecla M).

const RAIZ := "res://Assets/Audio/"
const EXTENSIONES := ["wav", "ogg", "mp3"]
const CARPETAS := ["Efectos", "Ambiente", "Musica"]

const EFECTOS := [
	"dialogo_blip_guia", "dialogo_abrir", "dialogo_cerrar", "dialogo_opciones",
	"ui_mover", "ui_aceptar", "ui_elegir", "ui_cancelar", "diario_abrir", "diario_cerrar", "guardar", "pista",
	"sismo_aviso", "sismo_fin", "replica", "objeto_cae", "estante_cae", "vidrio_roto", "escombros",
	"radio_estatica", "radio_aviso", "valvula", "linterna_on", "item_recoge", "correcto", "ojo", "silbato",
	"ascensor_no", "puerta_abre", "paso_piso", "paso_calle", "llegada_punto",
	"reloj_tic", "sello", "lapiz_marca", "radio_squelch",
]
const AMBIENTES := ["amb_casa", "amb_sismo", "amb_calle"]
const MUSICAS := ["musica_titulo", "musica_antes", "musica_despues", "final_preparado", "final_encamino", "final_reforzar"]

## Volumen de cada efecto (dB) respecto a como quedó normalizado el archivo. Los que no estén aquí usan
## VOLUMEN_POR_DEFECTO. Se ajusta aquí, sin tocar el resto del código.
const VOLUMEN_POR_DEFECTO := -6.0
const VOLUMEN_DB := {
	"dialogo_blip_guia": -13.0,
	"paso_piso": -9.0, "paso_calle": -9.0,
	# La retroalimentación suena muy suave: nada de sonidos de error agresivos
	"correcto": -17.0, "ojo": -17.0, "silbato": -10.0,
	"reloj_tic": -12.0, "sello": -8.0, "lapiz_marca": -10.0, "radio_squelch": -12.0,
	"ui_mover": -9.0, "ui_aceptar": -6.0, "ui_elegir": -6.0, "ui_cancelar": -6.0,
}
const VOLUMEN_MUSICA_DB := -2.0
const VOLUMEN_AMBIENTE_DB := -4.0

const NUMERO_DE_VOCES := 14
## UN SOLO sonido de texto para todos los que hablan (Lucía, Mamá, Doña Rosa, cuestionarios...):
## el blip de dialogo_blip_guia, siempre con el mismo volumen y el mismo tono (sin variación por hablante).
const SONIDO_TEXTO := "dialogo_blip_guia"
## Cada cuántas letras escritas suena un blip del diálogo.
const LETRAS_POR_BLIP := 2

## Sonó un efecto (para depurar y probar).
signal efecto_reproducido(nombre: String)

## Nombres pedidos o del catálogo que no tienen archivo (lo muestra el panel de depuración).
var faltan: Array[String] = []
## Últimos efectos que sonaron: {"nombre", "tiempo"} (para el panel de depuración).
var historial: Array[Dictionary] = []

var _cache: Dictionary = {}          # nombre -> AudioStream (o null si no existe)
var _voces: Array[AudioStreamPlayer] = []
var _ultima_vez: Dictionary = {}     # nombre -> ms de la última vez que sonó
var _musica := Capa.new()
var _ambiente := Capa.new()
var _letras := 0
## La voz propia del blip de texto (así se puede cortar cuando el texto se completa de golpe).
var _voz_blip: AudioStreamPlayer
var _panel: CanvasLayer
var _texto_panel: Label
var _tiempo_panel := 0.0


## Una capa de audio con dos reproductores para poder hacer fundidos cruzados.
class Capa:
	var jugadores: Array[AudioStreamPlayer] = []
	var activo := 0
	var nombre := ""
	var tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in NUMERO_DE_VOCES:
		_voces.append(_crear_jugador("Efectos"))
	_voz_blip = _crear_jugador("Efectos")
	for i in 2:
		_musica.jugadores.append(_crear_jugador("Musica"))
		_ambiente.jugadores.append(_crear_jugador("Efectos"))
	_revisar_catalogo()
	_conectar_senales()
	_crear_panel()
	get_tree().auto_accept_quit = false   # al cerrar la ventana se sale con calma (ver salir())


func _notification(que: int) -> void:
	if que == NOTIFICATION_WM_CLOSE_REQUEST:
		salir()


## Cierra el juego con calma: para el audio y espera un instante antes de salir. Si el programa se cierra
## con un sonido a medias, el motor avisa en la consola de recursos "aún en uso".
func salir() -> void:
	_detener(_musica, 0.05)
	_detener(_ambiente, 0.05)
	for v in _voces:
		v.stop()
	await get_tree().create_timer(0.2, true, false, true).timeout
	get_tree().quit()


## Al cerrar el juego se sueltan los audios (si no, el motor avisa de recursos "aún en uso").
func _exit_tree() -> void:
	for capa in [_musica, _ambiente]:
		if capa.tween != null:
			capa.tween.kill()
		capa.jugadores.clear()
	for hijo in get_children():
		if hijo is AudioStreamPlayer:
			hijo.stop()
			hijo.stream = null
			hijo.free()   # liberar el reproductor suelta también su reproducción en curso
	_voces.clear()
	_cache.clear()


func _crear_jugador(bus: String) -> AudioStreamPlayer:
	var j := AudioStreamPlayer.new()
	j.bus = bus
	# Reproducción de Godot (no Web Audio): en la web el modo "Sample" no soporta bien buses, fundidos ni cambios de tono
	j.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	j.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(j)
	return j


## Mira qué archivos del catálogo existen y avisa (una vez) de los que faltan.
func _revisar_catalogo() -> void:
	faltan.clear()
	var todos: Array = EFECTOS + AMBIENTES + MUSICAS
	for nombre in todos:
		if _cargar(nombre) == null and not faltan.has(nombre):
			faltan.append(nombre)
	if not faltan.is_empty():
		push_warning("Audio: faltan %d archivos de audio: %s" % [faltan.size(), ", ".join(faltan)])
	# Registro visible (en la web sale en la consola del navegador): cuántos sonidos se cargaron y cómo está el audio
	print("Audio: %d de %d sonidos cargados%s" % [todos.size() - faltan.size(), todos.size(), "" if faltan.is_empty() else ". No se pudieron cargar: " + ", ".join(faltan)])
	print("Audio: Master %s a %.1f dB, Musica %.0f %%, Efectos %.0f %%, reproducción %s" % [
		"SILENCIADO" if AudioServer.is_bus_mute(0) else "activo", AudioServer.get_bus_volume_db(0),
		Opciones.volumen_musica * 100.0, Opciones.volumen_efectos * 100.0, "Stream (Godot)"])


## Busca el archivo por nombre (en Efectos, Ambiente y Musica; .wav, .ogg o .mp3). Guarda el resultado.
func _cargar(nombre: String) -> AudioStream:
	if _cache.has(nombre):
		return _cache[nombre]
	var recurso: AudioStream = null
	for carpeta in CARPETAS:
		for extension in EXTENSIONES:
			var ruta := "%s%s/%s.%s" % [RAIZ, carpeta, nombre, extension]
			if ResourceLoader.exists(ruta):
				recurso = load(ruta)
				break
		if recurso != null:
			break
	_cache[nombre] = recurso
	if recurso == null and not faltan.has(nombre):
		faltan.append(nombre)
		push_warning("Audio: no existe el audio '%s'." % nombre)
	return recurso


# --- Efectos ---

## El sonido de una pista suave (el aviso junto a una compuerta, la pista al interactuar con ella y la respuesta
## de Lucía): -6 dB, tono +-5 % y como mucho una vez cada 5 s (se repite mucho).
const SEGUNDOS_ENTRE_PISTAS := 5.0
var _ultima_pista := -INF


func pista() -> void:
	var ahora := Time.get_ticks_msec() / 1000.0
	if ahora - _ultima_pista < SEGUNDOS_ENTRE_PISTAS:
		return
	_ultima_pista = ahora
	efecto("pista", -6.0, 0.05)


## Reproduce un efecto. volumen_db sobreescribe el de VOLUMEN_DB; variacion = cuánto cambia el tono al azar
## (0.05 = un 5 % arriba o abajo). Dos veces el mismo efecto en menos de 40 ms cuentan como una.
func efecto(nombre: String, volumen_db: float = NAN, variacion: float = 0.0, retraso: float = 0.0) -> void:
	if nombre == "":
		return
	var ahora := Time.get_ticks_msec()
	if ahora - int(_ultima_vez.get(nombre, -1000)) < 40:
		return
	var flujo := _cargar(nombre)
	if flujo == null:
		return
	_ultima_vez[nombre] = ahora
	_anotar(nombre)
	if retraso > 0.0:
		await get_tree().create_timer(retraso, true, false, true).timeout
	var voz := _voz_libre()
	voz.stream = flujo
	voz.volume_db = volumen_db if not is_nan(volumen_db) else float(VOLUMEN_DB.get(nombre, VOLUMEN_POR_DEFECTO))
	voz.pitch_scale = 1.0 + randf_range(-variacion, variacion)
	voz.play()
	efecto_reproducido.emit(nombre)


func _voz_libre() -> AudioStreamPlayer:
	for v in _voces:
		if not v.playing:
			return v
	# Todas ocupadas: se reutiliza la que más avanzó
	var elegida := _voces[0]
	for v in _voces:
		if v.get_playback_position() > elegida.get_playback_position():
			elegida = v
	return elegida


func _anotar(nombre: String) -> void:
	historial.push_front({"nombre": nombre, "tiempo": Time.get_ticks_msec()})
	if historial.size() > 8:
		historial.pop_back()


## El paso del jugador: dentro del apartamento suena paso_piso; en la calle y el parque, paso_calle.
func paso(en_exterior: bool = false) -> void:
	efecto("paso_calle" if en_exterior else "paso_piso", NAN, 0.08)


# --- Música y ambiente ---

## Pone una música (con fundido cruzado). Si ya suena esa, no la reinicia.
func musica(nombre: String, fundido: float = 1.5) -> void:
	_reproducir(_musica, nombre, fundido, VOLUMEN_MUSICA_DB)


func detener_musica(fundido: float = 1.0) -> void:
	_detener(_musica, fundido)


func ambiente(nombre: String, fundido: float = 1.5, volumen_db: float = VOLUMEN_AMBIENTE_DB) -> void:
	_reproducir(_ambiente, nombre, fundido, volumen_db)


func detener_ambiente(fundido: float = 1.0) -> void:
	_detener(_ambiente, fundido)


func musica_actual() -> String:
	return _musica.nombre


func ambiente_actual() -> String:
	return _ambiente.nombre


## Música y ambiente de cada nivel (el nivel lo llama al mostrarse).
func ambientar_nivel(nivel: int) -> void:
	musica("musica_despues" if nivel == 3 else "musica_antes")
	ambiente("amb_calle" if nivel == 3 else "amb_casa")


func _reproducir(capa: Capa, nombre: String, fundido: float, volumen_db: float) -> void:
	if capa.nombre == nombre and capa.jugadores[capa.activo].playing:
		return
	var flujo := _cargar(nombre)
	if flujo == null:
		return
	if capa.tween != null:
		capa.tween.kill()
	var saliente := capa.jugadores[capa.activo]
	capa.activo = 1 - capa.activo
	var entrante := capa.jugadores[capa.activo]
	capa.nombre = nombre
	entrante.stream = flujo
	entrante.volume_db = -80.0 if fundido > 0.0 else volumen_db
	entrante.play()
	if fundido <= 0.0:
		saliente.stop()
		return
	capa.tween = create_tween().set_parallel(true)
	capa.tween.tween_property(entrante, "volume_db", volumen_db, fundido)
	if saliente.playing:
		capa.tween.tween_property(saliente, "volume_db", -80.0, fundido)
		capa.tween.chain().tween_callback(saliente.stop)


func _detener(capa: Capa, fundido: float) -> void:
	capa.nombre = ""
	if capa.tween != null:
		capa.tween.kill()
	capa.tween = create_tween().set_parallel(true)
	for j in capa.jugadores:
		if j.playing:
			capa.tween.tween_property(j, "volume_db", -80.0, maxf(fundido, 0.01))
	capa.tween.chain().tween_callback(func() -> void:
		for j in capa.jugadores:
			j.stop())


# --- Señales del juego ---

func _conectar_senales() -> void:
	Estado.decision_registrada.connect(_on_decision)
	Estado.tarjeta_desbloqueada.connect(func(_id: String) -> void: efecto("pista"))
	Dialogo.dialogo_abierto.connect(func() -> void: efecto("dialogo_abrir"))
	Dialogo.dialogo_cerrado.connect(func() -> void: efecto("dialogo_cerrar"))
	Dialogo.opciones_mostradas.connect(func() -> void: efecto("dialogo_opciones"))
	Dialogo.respuesta_elegida.connect(func() -> void: efecto("ui_elegir"))
	Dialogo.cancelado_por_jugador.connect(func() -> void: efecto("ui_cancelar"))
	Dialogo.letra_escrita.connect(_on_letra)
	Dialogo.linea_terminada.connect(cortar_blip)   # el texto se completó (solo o de golpe con INTERACTUAR): el blip se corta


## Una decisión recibe su retroalimentación: suena "correcto" si fue segura y "ojo" si no.
func _on_decision(_id: String, segura: bool, _primer_intento: bool) -> void:
	efecto("correcto" if segura else "ojo")


## El blip de texto: el MISMO para todos los que hablan. Suena una vez cada 2 letras, no en los espacios ni en la puntuación.
## Es la única función de sonido de letras del juego: el balloon (Dialogo.mostrar y mostrar_texto) y las etiquetas
## que se escriben solas (Dialogo.escribir_etiqueta) emiten Dialogo.letra_escrita y llegan aquí.
func _on_letra(_personaje: String, letra: String) -> void:
	if not _es_letra_o_cifra(letra):
		return
	_letras += 1
	if _letras % LETRAS_POR_BLIP != 0:
		return
	blip()


func _es_letra_o_cifra(letra: String) -> bool:
	return letra.length() > 0 and (letra.to_lower() != letra.to_upper() or letra.is_valid_int())


## Solo para pruebas: simula una letra escrita.
func letra_para_prueba(letra: String) -> void:
	_on_letra("", letra)


## Reproduce el blip de texto (mismo archivo, volumen y tono siempre).
func blip() -> void:
	var flujo := _cargar(SONIDO_TEXTO)
	if flujo == null:
		return
	_anotar(SONIDO_TEXTO)
	_voz_blip.stream = flujo
	_voz_blip.volume_db = float(VOLUMEN_DB.get(SONIDO_TEXTO, VOLUMEN_POR_DEFECTO))
	_voz_blip.pitch_scale = 1.0
	_voz_blip.play()
	efecto_reproducido.emit(SONIDO_TEXTO)


## Corta el blip (cuando el texto termina o se completa de golpe).
func cortar_blip() -> void:
	if _voz_blip != null and _voz_blip.playing:
		_voz_blip.stop()


# --- Panel de depuración ---

func _process(delta: float) -> void:
	if _panel.visible:
		_tiempo_panel -= delta
		if _tiempo_panel <= 0.0:
			_tiempo_panel = 0.25
			_actualizar_panel()


# --- Panel de depuración (tecla M, solo en compilaciones de depuración) ---

func _crear_panel() -> void:
	_panel = CanvasLayer.new()
	_panel.layer = 30
	_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	_panel.visible = false
	add_child(_panel)
	_texto_panel = EstiloUI.etiqueta("", 10, EstiloUI.CREMA)
	_texto_panel.position = Vector2(6, 4)
	_texto_panel.add_theme_color_override("font_outline_color", EstiloUI.PETROLEO_OSCURO)
	_texto_panel.add_theme_constant_override("outline_size", 4)
	_panel.add_child(_texto_panel)


func _unhandled_input(evento: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	if evento is InputEventKey and evento.pressed and not evento.echo and evento.keycode == KEY_M:
		_panel.visible = not _panel.visible
		_tiempo_panel = 0.0


## Cuántos audios del catálogo no tienen archivo (sin contar nombres sueltos que alguien pidió por error).
func faltan_del_catalogo() -> Array[String]:
	var lista: Array[String] = []
	for nombre in faltan:
		if EFECTOS.has(nombre) or AMBIENTES.has(nombre) or MUSICAS.has(nombre):
			lista.append(nombre)
	return lista


func _actualizar_panel() -> void:
	var total := EFECTOS.size() + AMBIENTES.size() + MUSICAS.size()
	var del_catalogo := faltan_del_catalogo()
	var lineas: Array[String] = ["SONIDO   [M] cerrar", ""]
	lineas.append("Archivos: %d de %d%s" % [total - del_catalogo.size(), total, "" if faltan.is_empty() else "   FALTAN %d" % faltan.size()])
	if not faltan.is_empty():
		lineas.append("Faltan: " + ", ".join(faltan.slice(0, 12)) + (" ..." if faltan.size() > 12 else ""))
	lineas.append("Música: %s    Ambiente: %s" % [_musica.nombre if _musica.nombre != "" else "-", _ambiente.nombre if _ambiente.nombre != "" else "-"])
	lineas.append("Volumen   Música %d%%   Efectos %d%%" % [roundi(Opciones.volumen_musica * 100.0), roundi(Opciones.volumen_efectos * 100.0)])
	lineas.append("Voces de efectos en uso: %d de %d" % [_voces.filter(func(v: AudioStreamPlayer) -> bool: return v.playing).size(), _voces.size()])
	lineas.append("")
	lineas.append("Últimos efectos:")
	var ahora := Time.get_ticks_msec()
	for h in historial:
		lineas.append("  %s   (hace %.1f s)" % [h["nombre"], (ahora - int(h["tiempo"])) / 1000.0])
	_texto_panel.text = "\n".join(lineas)
