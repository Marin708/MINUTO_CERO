# Textos a revisar

Textos que escribió o adaptó el equipo de desarrollo y **no están literalmente en `docs/DISENO_MAESTRO.md`**. Están marcados con `[REVISAR]` en el código o el JSON. Falta además la revisión de contenido con fuentes oficiales (UNGRD, SGC, Cruz Roja, IDIGER).

| # | Dónde | Texto | Por qué se revisa |
|---|---|---|---|
| 1 | `Resources/contenido/memoria.json`, tarjeta `mem2` | Título «Lo que dejó el terremoto» | El maestro da el texto, no el título |
| 2 | `Resources/contenido/memoria.json`, tarjeta `mem3` | Título «Prepararse sí ayuda» | Ídem |
| 3 | `Resources/contenido/memoria.json`, tarjeta `mem1` | Título «25 de enero de 1999» | Ídem (cifras de 1999 marcadas [REVISAR] en el maestro) |
| 4 | `Resources/contenido/decisiones.json`, D5 | Segunda frase de la retroalimentación (lista del kit) | El maestro dice solo «Retro con la lista completa» |
| 5 | `Resources/contenido/decisiones.json`, D5 | Opciones vacías y tipo `kit` | D5 se resuelve con `kit.json` |
| 6 | `Resources/contenido/kit.json` | Nombres de los 12 objetos (por ejemplo «Documentos en bolsa impermeable») | Se tomaron del maestro, pero hay que confirmar el nombre visible |
| 7 | `Scripts/UI/Cuestionario.gd`, `INTRO` y `INTRO_POST` | Frases de Lucía antes de cada bloque | Adaptadas de ECOS |
| 8 | `Scripts/UI/Consentimiento.gd` | Texto de consentimiento | Adaptado de ECOS |
| 9 | `Scripts/UI/Valoracion.gd` | Texto de gracias y afirmación u6 | Adaptados de ECOS |
| 10 | `Scripts/UI/Resultados.gd` | Mensajes de «Tu avance en números» y nota «Esto no es un examen oficial…» | Adaptados de ECOS |
| 11 | `Scripts/UI/MenuPausa.gd` | Texto de controles | Nuevo |
| 12 | `Resources/creditos.txt` | Créditos y nota final | Nuevo (se quitaron las líneas sin datos) |
| 13 | `Scripts/UI/PantallaTitulo.gd` | Subtítulo «Prepararte hoy puede cambiar el minuto cero.» | Frase central del maestro |
| 14 | `docs/DISENO_MAESTRO.md`, D12 | «[REVISAR primeros auxilios]» | Ya marcado en el maestro |
| 15 | `Scripts/UI/Introduccion.gd` | Boletín de la brigada (5 mensajes de Lucía), texto de la inscripción y del cierre | Nuevos (voz de brigada) |
| 16 | `Scripts/Mundo/Nivel1.gd` | Narración inicial, diálogos de Mamá y de Lucía, pistas de «¿Qué hago ahora?» | Nuevos |
| 17 | `Scripts/Mundo/Nivel2.gd` | Narración del sismo, mensaje «¡Está temblando!…», textos de después del sismo | Nuevos |
| 18 | `Scripts/Mundo/Nivel3.gd` | Diálogos de Doña Rosa, Tomás, Mamá y Lucía; **mensaje de radio oficial** (`TEXTO_RADIO`) | Nuevos; el radio debe ser fiel a lo que dicen las autoridades |
| 19 | `Scripts/UI/TarjetaRetro.gd`, `Decisiones.gd` | Títulos «Muy bien» (segura al primer intento), «Casi» (segura en un reintento) y «Ojo» (no segura) | El maestro no dice cuándo va «Casi» |
| 20 | `Scripts/UI/TarjetaRetro.gd` | Falta «una frase para recordar»: la tarjeta usa la retroalimentación del JSON como «Por qué» | El maestro no da una frase aparte |
| 21 | `Scripts/Final/Final.gd` | «Decisiones seguras al primer intento: X de 15» y los botones | Nuevos |
| 23 | `Scripts/Mundo/Nivel3.gd` | Mensajes de la réplica («Mantén E: agacharte y proteger la cabeza»…) y texto de cierre `TEXTO_CIERRE` | Nuevos; en D15 «mantener E» reemplaza la elección entre opciones (la tarjeta usa las opciones del JSON) |
| 24 | `Scripts/Final/Final.gd` | Nota «no es un simulacro oficial…» | Nueva |
| 25 | `Scripts/Mundo/Nivel2.gd` | «Mantén E: agacharte, cubrirte y sujetarte», nombres de íconos y mensajes de D9 a D11 | Nuevos; D10 usa las opciones del maestro (no «linterna / interruptor / fósforo») |
| 26 | `Resources/contenido/mitos.json` | Campo `desbloqueo` (qué decisión desbloquea cada mito) | Elegido por el equipo |
| 27 | `Resources/contenido/preguntas.json`, campo `tema` | Títulos cortos de cada pregunta («Olor a gas», «El plan familiar»…) para la pantalla de resultados y el análisis | Escritos por el equipo |
| 28 | `Scripts/UI/Resultados.gd` | «Para reforzar», «Segura al primer intento» y los mensajes de la lista de 15 decisiones | Nuevos |
| 29 | `Resources/creditos.txt` | Créditos (plan gratuito de ElevenLabs, uso no comercial, etc.) | Según lo pedido |
| 22 | `Scripts/Mundo/Nivel1.gd` | **Lucía** aparece como personaje en el pasillo del nivel 1 (no como cuadro de radio) | Cambio de diseño: el maestro dice «cuadro de radio o teléfono» |
| 30 | `Scripts/UI/TarjetaNivel.gd` | Rótulos «NIVEL 1 · ANTES», «NIVEL 2 · DURANTE», «NIVEL 3 · DESPUÉS» y frases «Deja la casa lista.», «Actúa cuando tiembla.», «Revisa y ayuda con seguridad.» | Los rótulos vienen del maestro; las frases son nuevas |
| 31 | `Scripts/UI/Introduccion.gd` | «BOLETÍN DE LA BRIGADA», «INSCRIPCIÓN», «BIENVENIDO/A A LA BRIGADA» y el carné («Brigadista voluntario/a», «pendiente», «BRIGADISTA») | Nuevos |
| 32 | `Scripts/UI/Consentimiento.gd` | Título «Acuerdo de la brigada», frase «No es un test psicológico.» y «Sin nombre: tu respuesta es anónima.» | Nuevos; el resto del texto sigue igual |
| 33 | `Scripts/UI/Cuestionario.gd` | Sellos «EVALUACIÓN DE INGRESO», «EVALUACIÓN DE SALIDA» y «RECIBIDA»; «LUCÍA · CANAL 3 · BRIGADA» | Nuevos |
| 34 | `Scripts/UI/Resultados.gd` | «Tu avance en números», «Informe de la brigada» y su texto, sello «BRIGADISTA» | Nuevos |
| 35 | `Scripts/UI/PantallaTitulo.gd` | Subtítulo «Aprende a actuar ante un sismo» (la frase central pasa al pie) | Subtítulo pedido por el equipo |
| 36 | `Scripts/UI/IndicadorTecla.gd`, `Prop.gd`, `Npc.gd`, `ObjetoSuelo.gd` | Verbos junto a la tecla E: «Revisar», «Hablar», «Abrir», «Tomar», «Mantén» | Nuevos |
| 37 | `Scripts/UI/MenuPausa.gd` | Descripciones de los controles («Moverte», «Hablar, revisar y recoger…») | Reescritas con voz de brigada |
| 38 | `Assets/Audio/Efectos/despertador.wav` | Sonido de despertador **sintetizado por nosotros** (provisional) | Reemplazar por un sonido de ElevenLabs si se prefiere |
| 39 | `Resources/contenido/decisiones.json`, D5 | «Por qué» del kit: «Un kit de emergencia lleva agua potable, alimentos no perecederos, linterna con pilas de repuesto, silbato, botiquín, medicinas de uso diario y documentos importantes en una bolsa impermeable. Guárdalo en un lugar de fácil acceso.» (ya no dice «Sí cuenta si hay al menos 7 correctos…»: esa regla es interna, en `kit.json` y en el código) | Texto pedido por el equipo |
| 40 | `Scripts/UI/TarjetaRetro.gd`, `KitUI.gd` | Tarjeta del kit: «Lo que hiciste» lista lo elegido con ✔ (correcto) y ✖ (distractor); «Lo recomendado» solo trae lo que faltó y no aparece si no faltó nada; sin la nota «Para recordar» | Nuevo |
| 41 | `Scripts/UI/TarjetaRetro.gd` | Regla general: si «Lo que hiciste» y «Lo recomendado» son iguales, una sola sección con ✔ y sin la nota «Para recordar» repetida | Nuevo |
| 42 | `Scripts/UI/IndicadorScroll.gd` | Aviso «Sigue leyendo» sobre el pie de los modales que se desplazan | Nuevo |

