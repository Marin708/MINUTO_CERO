# Revisión de calidad de MINUTO CERO

Generada por `tools/revisar_proyecto.py`. Ordenada por gravedad: **Bloqueante** (impide entregar), **Alta** (arreglar antes de entregar), **Media**, **Baja** e **Informativa** (para revisar a mano).

| Gravedad | Hallazgos |
|---|---|
| Bloqueante | 0 |
| Alta | 0 |
| Media | 0 |
| Baja | 2 |
| Informativa | 10 |

## Baja (2)

### Posible falta de ortografía

- `Autoload/Audio.gd línea 414`: doble espacio: Música: %s    Ambiente: %s
- `Autoload/Audio.gd línea 415`: doble espacio: Volumen   Música %d%%   Efectos %d%%

## Informativa (10)

### Sonidos

- `Assets/Audio`: 46 archivos, 46 en el catálogo, 46 pedidos por el código; faltan: 0

### Tecla F8

- `Autoload/Reportes.gd`: F8 abre el reporte de problemas para jugadores (no es de depuración); se anuncia en los controles de la pausa

### Textos de seguridad

- `docs/DISENO_MAESTRO.md`: 160 comparaciones texto a texto con el maestro (decisiones, preguntas, mitos, memoria, finales, plan y kit)

### Palabra posiblemente absoluta

- `Resources/contenido/decisiones.json .decisiones[5].opciones[0]`: «todos» en: Un espacio abierto cercano, lejos de edificios y cables, que todos conozcan
- `Resources/contenido/decisiones.json .decisiones[6].opciones[2]`: «siempre» en: Salir siempre por el ascensor
- `Resources/contenido/preguntas.json .trivia[3].explicacion`: «todos» en: El plan sirve para que todos sepan qué hacer y dónde reunirse.
- `Resources/contenido/preguntas.json .trivia[4].opciones[2]`: «nunca» en: Las réplicas nunca causan daño
- `Resources/contenido/preguntas.json .situaciones[4].opciones[1]`: «todos» en: Lo reenvío a todos por si acaso
- `Scripts/Mundo/Nivel3.gd:103`: «todos» en: Aquí estamos todos. Buen trabajo.
- `Scripts/Mundo/Nivel3.gd:119`: «Todos» en: Mira, Sami, me llegó este mensaje al celular: «viene otro terremoto peor esta noche». Todos lo están
