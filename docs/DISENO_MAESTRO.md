# MINUTO CERO — Documento maestro

Versión 1.0 · noviembre de 2026 · Se guarda en `docs/DISENO_MAESTRO.md` y es la referencia de todo el proyecto.

---

## 1. Resumen

**MINUTO CERO** es un juego educativo 2D, con vista desde arriba y pixel art, hecho en **Godot 4.7 (GDScript)**. Enseña qué hacer **antes, durante y después de un sismo**. Se juega en el navegador (Vercel) con teclado y dura 15 a 20 minutos.

El jugador es **Sami**, una persona estudiante que vive en un apartamento de un cuarto piso en **Villa Cafetal**, una ciudad **ficticia** del Eje Cafetero. No hay combate ni muerte: cada decisión recibe **retroalimentación inmediata**, se puede **intentar de nuevo**, y el juego guarda el **primer intento** para la evaluación.

Frase central: **«Prepararte hoy puede cambiar el minuto cero.»**

Homenaje: tarjetas de memoria sobre el terremoto del Eje Cafetero del 25 de enero de 1999.

**Base técnica:** el proyecto se construye a partir de ECOS. Se **reutiliza** (y solo se adapta) lo que ya funciona: caja de diálogo con efecto de escritura, notificaciones, sistema de audio, cuestionario inicial y final, pantalla de resultados con código, pausa, guardado, libreta (antes «diario»), créditos, exportación web con rama `web` en Vercel y scripts de análisis. Se **elimina** lo que era de ECOS: emociones, épocas, habilidades, bloqueos, compuertas, cofres y su arte.

---

## 2. Objetivos de aprendizaje

1. **Antes:** identificar riesgos en la vivienda y asegurarlos, armar un kit de emergencia y acordar un plan familiar con rutas y punto de encuentro.
2. **Durante:** aplicar «agacharse, cubrirse y sujetarse» y reconocer lo que no conviene hacer (correr a la salida, usar el ascensor, ponerse en el marco de una puerta, buscar el «triángulo de la vida»).
3. **Después:** revisar peligros (gas, cables, edificios dañados), esperar réplicas, ayudar con seguridad y usar solo información oficial.
4. **Actitud:** entender que la preparación reduce riesgos y que se puede practicar en familia.

Regla de contenido: no dar reglas absolutas. Usar frases como «las autoridades recomiendan» o «en una edificación sismorresistente». **[REVISAR]** con fuentes oficiales (UNGRD, Servicio Geológico Colombiano, Cruz Roja Colombiana, IDIGER) antes de publicar. Las recomendaciones pueden variar según el tipo de construcción.

---

## 3. Alcance (qué entra y qué no)

**Entra:** 3 niveles pequeños; 15 decisiones con retroalimentación; sismo con temblor de cámara, polvo, objetos que caen y un evento de réplica; kit de 8 espacios; 3 finales; libreta de lecciones, mitos y memoria; cuestionario inicial y final; resultados con código; web.

**No entra:** combate, enemigos, inventario complejo, IA de navegación, edificios destructibles por etapas, mapas grandes, voces habladas.

---

## 4. Flujo del juego

1. **Título** (Comenzar, Continuar, Salir).
2. **Consentimiento** (guardar respuestas o jugar sin guardar). Mismo texto de ECOS adaptado.
3. **Cuestionario inicial** (14 preguntas).
4. **Introducción de Lucía** (brigadista comunitaria): explica cómo se juega.
5. **Nivel 1: Antes** → **Nivel 2: Durante** → **Nivel 3: Después**.
6. **Final** (según el porcentaje de decisiones seguras al primer intento) y pantalla «Mi plan en 5 pasos».
7. **Cuestionario final** (las mismas 14 preguntas, opciones mezcladas).
8. **Resultados** (antes y después, explicaciones, código de resultados), **créditos** y volver al título.

El cuestionario inicial y final **no se puede cancelar** y **no dice si acertaste**. La retroalimentación explicativa va en los resultados. En los niveles, en cambio, la retroalimentación es **inmediata**.

---

## 5. Niveles

### Nivel 1 — Antes (apartamento, mañana)
Mapa pequeño (aprox. 32 x 20 tiles): sala-comedor, cocina, habitación, balcón, pasillo con puerta de salida, escalera y ascensor.
Tareas, en cualquier orden:
- Revisar **4 riesgos** (E sobre cada objeto): decisiones D1 a D4.
- **Armar el kit** en el armario (D5).
- Hablar con **Mamá** para acordar el punto de encuentro y las rutas (D6 y D7).
- Al terminar, pantalla «Minuto cero» y pasa al nivel 2.
Lucía aparece en un cuadro de radio/teléfono con la opción «¿Qué hago ahora?».

### Nivel 2 — Durante (mismo apartamento, con daños leves)
- Empieza un temblor corto de aviso (2 s) y luego el sismo fuerte (unos 20 s, con temblor de cámara moderado, polvo y objetos que caen cerca de ventanas, estante y lámpara).
- Mecánica **«Agacharse, cubrirse y sujetarse»**: llegar a la mesa del comedor (zona segura) y **mantener E** hasta que termine. Tres íconos se encienden en orden.
- Si el jugador sale de la zona, va a la puerta o se queda junto a la ventana, la acción se marca como riesgosa, el sismo termina, aparece la retroalimentación y se ofrece **intentar de nuevo** (primer intento registrado) (D8).
- Después: ponerse zapatos y tomar la mochila (D9); olor a gas en la cocina (D10); salir por la **escalera, no por el ascensor** (D11).

### Nivel 3 — Después (calle y parque, punto de encuentro)
Mapa exterior (aprox. 40 x 24 tiles): calle, andén, edificio vecino agrietado (zona bloqueada), poste con cable caído (zona bloqueada), carro, árboles y el **parque** con el punto de encuentro.
- **Doña Rosa** (vecina mayor) pide ayuda (D12).
- **Obstáculo**: cable caído y edificio agrietado (D13).
- **Información**: un mensaje de radio oficial y un rumor de cadena en un celular; elegir en qué confiar (D14).
- **Réplica**: evento con temblor; el jugador está afuera y debe protegerse (D15).
- Llegar al punto de encuentro y reunirse con Mamá y Lucía. Fin.

---

## 6. Decisiones (15)

La primera opción es la **segura**; en el juego las opciones se **mezclan**. «Retro» es el texto que ve el jugador.

| Id | Nivel | Situación | Opción segura | Opciones no seguras | Retroalimentación |
|---|---|---|---|---|---|
| D1 | 1 | Estante alto con libros y objetos pesados arriba, sin fijar | Fijarlo a la pared y dejar lo pesado abajo | Dejarlo así; poner más cosas arriba | Los muebles altos pueden caerse. Fíjalos y deja lo pesado en los niveles bajos. |
| D2 | 1 | Cuadro con marco pesado sobre la cama | Pasarlo a una pared lejos de camas y sillas | Dejarlo; colgarlo con más peso | Lo que cuelga sobre donde duermes o te sientas puede caerte encima. |
| D3 | 1 | Cilindro de gas suelto en la cocina | Asegurarlo y saber dónde está la llave | Dejarlo suelto; esconderlo detrás de la nevera | Un cilindro suelto puede caerse y causar una fuga. Asegúralo y conoce la llave. |
| D4 | 1 | Objetos pesados o de vidrio en una repisa alta | Bajarlos o guardarlos en un lugar bajo | Dejarlos; subirlos más | En un temblor, lo que está arriba cae. Lo pesado y frágil, abajo. |
| D5 | 1 | Armar el kit (elegir 8 de 12 objetos) | Correctos: agua potable, alimentos no perecederos, linterna, pilas de repuesto, silbato, botiquín, medicinas de uso diario, documentos en bolsa impermeable | Distractores: vela, televisor pequeño, perfume, videojuego | Sí cuenta si hay al menos 7 correctos y 1 distractor como máximo. Retro con la lista completa. |
| D6 | 1 | ¿Dónde reunirse con la familia tras evacuar? | Un espacio abierto cercano, lejos de edificios y cables, que todos conozcan | Dentro del apartamento; debajo de un edificio alto | El plan define rutas, qué hace cada quien y un punto de encuentro abierto y conocido. |
| D7 | 1 | ¿Cómo se organiza la salida? | Cada quien sabe qué hacer; salir por la escalera con calma | Improvisar; salir siempre por el ascensor | No uses el ascensor en un sismo. Practicar el plan hace que se recuerde bajo presión. |
| D8 | 2 | Sismo fuerte (mecánica) | Agacharse, cubrirse y sujetarse bajo la mesa, lejos de ventanas | Correr a la puerta; ponerse en el marco de la puerta; quedarse junto a la ventana | Las autoridades recomiendan agacharse, cubrirse y sujetarse. El marco de la puerta no es lo más seguro en construcciones actuales. |
| D9 | 2 | Terminó el movimiento y hay vidrios en el piso | Ponerse zapatos cerrados y tomar mochila y linterna | Salir descalzo corriendo; no revisar nada | Calzado cerrado evita cortes. Ten a mano linterna, documentos y medicinas. |
| D10 | 2 | Huele a gas en la cocina | No usar fuego ni interruptores, ventilar si es seguro y alejarse para avisar | Encender la luz para ver; encender un fósforo | Una chispa puede encender el gas. Usa solo linterna y avisa a emergencias desde un lugar seguro. |
| D11 | 2 | Hay que bajar del 4.º piso | Escalera, con calma, sin ascensor | Ascensor; quedarse esperando | No uses ascensores durante ni después de un sismo: pueden fallar. |
| D12 | 3 | Doña Rosa está asustada y no puede caminar bien | Acompañarla, tranquilizarla y avisar a los equipos de emergencia | Irse sin avisar; entrar a un edificio dañado a buscar ayuda | Ayuda sin ponerte en riesgo. No entres a edificios dañados. **[REVISAR primeros auxilios]** |
| D13 | 3 | Cable caído y edificio agrietado en el camino | Alejarse, rodear por la avenida abierta y avisar | Pasar por debajo del cable; entrar a recoger cosas | Los cables caídos y los edificios agrietados son peligrosos aunque «parezcan» estables. |
| D14 | 3 | Radio oficial y un mensaje de cadena («viene otro peor esta noche») | Confiar en canales oficiales y no reenviar la cadena | Reenviar la cadena «por si acaso»; llamar a emergencias a preguntar | Los terremotos no se pueden predecir. Verifica y no satures las líneas de emergencia. |
| D15 | 3 | Llega una réplica y estás afuera | Quedarte en el espacio abierto, lejos de edificios y cables, agacharte y proteger la cabeza | Correr hacia un edificio; pararte junto a una pared alta | Las réplicas pueden continuar. Prepárate para protegerte otra vez. |

---

## 7. Retroalimentación y puntaje

- **Tarjeta de retroalimentación** (siempre el mismo diseño): título («Muy bien», «Casi» u «Ojo»), «Lo que hiciste», «Lo recomendado», «Por qué» y una frase para recordar. Botón «Entendido» y, si no fue segura, «Intentar de nuevo».
- La decisión se puntúa **solo en el primer intento**: 1 punto si fue segura, 0 si no. D5 usa la regla de sus aciertos. Los reintentos no suman, pero **sí** se registran en la libreta como lección aprendida.
- Nunca hay pantalla de muerte ni burla. El tono es cálido y breve.

## 8. Finales

Porcentaje de decisiones seguras al primer intento (de 15):

| Final | Condición | Mensaje |
|---|---|---|
| **Preparado o preparada** | 12 o más | Tu minuto cero estuvo preparado. |
| **En camino** | de 8 a 11 | Ya sabes lo importante. Lo que falló se puede practicar. |
| **A reforzar** | 7 o menos | Aprendiste cosas valiosas. Vuelve a jugar y practica en familia. |

Los tres terminan con **«Mi plan en 5 pasos»**: (1) revisa y asegura los riesgos de tu casa; (2) arma el kit; (3) acuerda rutas y punto de encuentro con tu familia; (4) practica agacharte, cubrirte y sujetarte; (5) infórmate solo en fuentes oficiales. Opcional: botón «Descargar mi plan» (archivo de texto en la web).

## 9. Libreta (tecla Tab)

Cuatro pestañas: **Lecciones** (cada retroalimentación recibida), **Mitos y realidades**, **Memoria de 1999** y **Mi plan**.

Mitos y realidades (texto en `Resources/contenido/mitos.json`):
- **El marco de la puerta es el lugar más seguro.** Las entidades de gestión del riesgo no lo recomiendan en construcciones actuales: agáchate, cúbrete y sujétate bajo un mueble resistente.
- **El «triángulo de la vida» te salva.** No es la primera recomendación de los organismos especializados.
- **Hay que salir corriendo apenas empieza.** Durante el movimiento, protégete. Sal con calma cuando termine y sea seguro.
- **El ascensor es más rápido.** No se usa durante ni después de un sismo.
- **Si ya pasó lo fuerte, ya no hay peligro.** Pueden venir réplicas.
- **Se puede predecir cuándo temblará.** No es posible; sí se pueden reducir sus efectos.
- **Una cadena de mensajes es información confiable.** Verifica en canales oficiales.

Memoria de 1999 (se desbloquea una tarjeta por nivel) **[REVISAR cifras con fuentes oficiales]**:
1. El 25 de enero de 1999, a la 1:19 p. m., un terremoto de magnitud cercana a 6,2 sacudió el Eje Cafetero, con epicentro cerca de Córdoba (Quindío). Armenia fue una de las ciudades más afectadas. (Algunas fuentes lo reportan como 6,1.)
2. Murieron más de mil personas y miles de viviendas quedaron dañadas o destruidas. (Las cifras varían según la fuente.) Se creó un fondo para la reconstrucción de la región.
3. Los terremotos no se pueden predecir, pero sí se pueden reducir sus efectos con construcción sismorresistente, planes de evacuación y preparación.

---

## 10. Evaluación inicial y final (14 preguntas)

Mismos bloques que ECOS: **7 de conocimiento**, **5 de situaciones** y **2 de escala**. Opciones **mezcladas** en cada partida. La **primera opción es la correcta o más segura** en el archivo. Nunca se dice si acertó durante el cuestionario.

### Bloque «trivia» (una respuesta correcta)

- **t1** «Si estás dentro de una edificación y empieza un sismo, ¿qué recomiendan las autoridades?»
  Correcta: Agacharte, cubrirte y sujetarte bajo un mueble resistente, lejos de ventanas.
  Otras: Salir corriendo hacia las escaleras · Ponerte en el marco de una puerta · Usar el ascensor para bajar rápido.
  Explicación: Las autoridades recomiendan agacharse, cubrirse y sujetarse. Correr o usar el ascensor aumenta el riesgo.
- **t2** «¿Qué pasa con el “triángulo de la vida” y el marco de la puerta?»
  Correcta: No son lo más recomendado; es mejor agacharse, cubrirse y sujetarse.
  Otras: Son el lugar más seguro de cualquier casa · Solo sirven en casas de un piso · Los recomienda la Cruz Roja como primera opción.
  Explicación: En construcciones actuales no se puede anticipar cómo reaccionará la estructura, y por eso se recomienda protegerse bajo un mueble resistente.
- **t3** «¿Qué debe tener un kit de emergencia?»
  Correcta: Agua potable, alimentos no perecederos, linterna con pilas de repuesto, silbato, botiquín y documentos importantes protegidos.
  Otras: Solo dinero y el celular · Solo comida enlatada · Una vela y un televisor pequeño.
  Explicación: El kit debe estar en un lugar de fácil acceso y tener lo básico para las primeras horas.
- **t4** «¿Qué debe definir un plan familiar de emergencia?»
  Correcta: Las rutas de evacuación, qué hace cada persona y un punto de encuentro.
  Otras: Solo el número de teléfono del vecino · Quién se queda en casa pase lo que pase · El horario de las comidas.
  Explicación: El plan sirve para que todos sepan qué hacer y dónde reunirse.
- **t5** «Cuando termina el temblor principal, ¿qué es cierto?»
  Correcta: Pueden venir réplicas, y hay que estar listo para protegerse otra vez.
  Otras: Ya no hay ningún peligro · Las réplicas nunca causan daño · Es seguro volver de inmediato a un edificio dañado.
  Explicación: Las réplicas pueden dañar estructuras que ya estaban afectadas.
- **t6** «Si hueles gas después de un sismo, ¿qué es lo más seguro?»
  Correcta: Evitar chispas (nada de fósforos, velas ni interruptores), ventilar si es seguro y alejarte para avisar a emergencias.
  Otras: Encender una vela para ver mejor · Prender la luz para buscar la fuga · Usar el encendedor para comprobar si aún huele.
  Explicación: Una chispa puede encender el gas. Usa linterna.
- **t7** «¿Cómo te informas después de un sismo?»
  Correcta: Con canales oficiales (autoridades de gestión del riesgo, Servicio Geológico, radio oficial).
  Otras: Reenviando cadenas de mensajes sin verificar · Llamando a emergencias para preguntar qué pasó · Creyendo lo primero que veas.
  Explicación: La información oficial evita rumores, y las líneas de emergencia deben quedar libres para urgencias.

### Bloque «situaciones» (la opción más segura suma)

- **s1** «Estás en tu cuarto y empieza a temblar fuerte, ¿qué haces?» Correcta: Me agacho, me cubro bajo un mueble resistente y me sujeto. Otras: Corro a la puerta · Me quedo mirando por la ventana.
- **s2** «Estás en la calle cuando tiembla, ¿qué haces?» Correcta: Me alejo de edificios, postes y cables y busco un espacio abierto. Otras: Entro corriendo al edificio más cercano · Me paro junto a una pared alta.
- **s3** «Terminó de temblar y estás en el 4.º piso, ¿qué haces?» Correcta: Reviso cómo estoy, me pongo zapatos, tomo linterna y mochila y bajo por las escaleras con calma. Otras: Uso el ascensor para ser más rápido · Me quedo esperando sin revisar nada.
- **s4** «Huele a gas en la cocina, ¿qué haces?» Correcta: No uso fuego ni interruptores, ventilo si es seguro y me alejo para avisar. Otras: Enciendo la luz para ver · Prendo un fósforo para buscar la fuga.
- **s5** «Un amigo escribe: “viene un terremoto peor esta noche”, ¿qué haces?» Correcta: Verifico en canales oficiales antes de compartirlo. Otras: Lo reenvío a todos por si acaso · Lo creo y entro en pánico.

### Bloque «escala» (1 = nada de acuerdo, 5 = totalmente de acuerdo)
- **e1** «Sé qué hacer antes, durante y después de un sismo.»
- **e2** «Me siento capaz de ayudar a mi familia a prepararnos.»

Puntajes: trivia 0 a 7; situaciones 0 a 5; escala 2 a 10; total 0 a 12 (sin escala).

---

## 11. Personajes

| Nombre | Rol | Notas |
|---|---|---|
| **Sami** | Protagonista, estudiante de unos 20 años | Jean azul, camiseta naranja, tenis blancos. Caminar en 4 direcciones. |
| **Lucía** | Brigadista comunitaria, guía | Chaleco naranja con reflectivo y casco blanco. Voz amable. Acompaña la introducción y da pistas. |
| **Mamá (Marta)** | Familia | Cocina, plan familiar. Aparece en el punto de encuentro. |
| **Doña Rosa** | Vecina mayor | Pide ayuda en el nivel 3. |
| **Tomás** | Niño de unos 8 años | Está con su mamá; tiene un celular con la cadena de mensajes. |

---

## 12. Controles y diseño de pantalla

- **Flechas o WASD** moverse · **E** interactuar (en el sismo, **mantener E** para agacharse, cubrirse y sujetarse) · **Tab** libreta · **Esc** pausa.
- Resolución de diseño **640 x 360**, escalado con aspecto «keep» y color de fondo oscuro. Fuente Pixelify Sans, cajas con el estilo de ECOS pero con paleta propia: **azul petróleo y naranja de seguridad**.
- HUD discreto: lista de tareas del nivel y contador de lecciones.

---

## 13. Reglas técnicas y de trabajo

1. Todo el texto del juego en español, claro y amable. No afirmar reglas absolutas.
2. Datos en archivos editables: `Resources/contenido/*.json` (preguntas, decisiones, kit, mitos, memoria, finales). Si algo cambia, no se toca el código.
3. Un solo sistema de diálogo, un solo efecto de escritura y un solo sonido de letras para todos los personajes.
4. Zonas libres de props alrededor de puertas, NPC y objetos interactivos; los props altos se vuelven semitransparentes si tapan algo importante.
5. Todas las teclas de depuración solo existen con `OS.is_debug_build()`. No usar teclas F (chocan con el editor). Depuración: **N** siguiente nivel, **1/2/3** saltar de nivel, **B/V/X** forzar final preparado, en camino o a reforzar.
6. Después de cada tarea: prueba sin ventana (headless), commit propio y resumen de qué revisar. Los mensajes de commit solo llevan la autoría del equipo, sin líneas de atribución automática.
7. No editar escenas que puedan estar abiertas en el editor sin avisar.
8. Web: exportación sin hilos, renderizador Compatibility, `Audio` con `ResourceLoader.exists`, reproducción tipo «Stream», `aspect = keep`, sin `vercel.json`, rama `web` publicada en un proyecto de Vercel **propio**.

---

## 14. Arte y audio

**Arte** (cuadros de 64 x 64 salvo que se indique; fondo magenta `#ff00ff` al generar):
`sami.png` (4 x 4, orden abajo, izquierda, derecha, arriba) · `personajes.png` (fila 1 normales, fila 2 asustados: Lucía, Mamá, Doña Rosa, Tomás) · `riesgos.png` (128 x 128, 4 x 2: riesgo y arreglado) · `muebles.png` y `exterior.png` (128 x 128, 4 x 2) · `kit.png` (32 x 32, 4 x 3) · `fondo_titulo.png` (640 x 360) · `icono_juego.png` (256 x 256). El tileset y los mapas se generan con scripts de Python (como en ECOS).

**Audio** (formato `.wav` los efectos y `.ogg` la música y los ambientes). Los de interfaz y diálogo se **copian de ECOS**:
`ui_mover, ui_aceptar, ui_elegir, ui_cancelar, dialogo_abrir, dialogo_cerrar, dialogo_opciones, dialogo_blip_guia, guardar, pista`.
Nuevos: `musica_titulo, musica_antes, musica_despues, final_preparado, final_encamino, final_reforzar, amb_casa, amb_sismo, amb_calle, sismo_aviso, sismo_fin, replica, objeto_cae, estante_cae, vidrio_roto, escombros, radio_estatica, radio_aviso, valvula, linterna_on, item_recoge, correcto, ojo, silbato, ascensor_no, puerta_abre, paso_piso, paso_calle, llegada_punto`.

---

## 15. Rúbrica (40 % del curso): dónde se cubre

| Categoría | Peso | Cómo se cubre |
|---|---|---|
| Funcionamiento técnico y mecánicas | 30 % | Tres niveles jugables, sismo, decisiones, finales, guardado, web estable. |
| Diseño visual y sonoro | 10 % | Pixel art coherente, música y ambientes, efectos del sismo. |
| Propósito pedagógico e impacto social | 15 % | Objetivos claros, retroalimentación inmediata, mitos y realidades, «Mi plan en 5 pasos». |
| Evaluación del aprendizaje | 15 % | Cuestionario inicial y final con puntaje, resultados y análisis. |
| Experiencia de usuario y coevaluación | 10 % | Formulario de valoración y observación en las pruebas. |
| Creatividad e innovación | 10 % | Puntaje por primer intento, reintentos con aprendizaje y mecánica de sismo. |
| Documentación y presentación | 10 % | Documento de Word, capturas, créditos y análisis. |

## 16. Fuentes para citar y revisar
Unidad Nacional para la Gestión del Riesgo de Desastres (UNGRD), Servicio Geológico Colombiano (SGC), Cruz Roja Colombiana, IDIGER (Bogotá) y Alcaldía de Bogotá (recomendaciones sobre revisión de gas, agua y energía). Antes de publicar, **pedir revisión del contenido** por el docente o por una persona del área de gestión del riesgo.
