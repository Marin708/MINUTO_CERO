# Revisión de modales con ventana real

Generado por `tools/probar_modales.gd` (escena `Scenes/UI/GaleriaModales.tscn`): cada modal se abre con el contenido más largo posible y se prueba en cinco tamaños de ventana. Capturas en `tools/capturas_modales/` (`<modal>_<tamaño>.png` y `<modal>_<tamaño>_fin.png`, esta con el scroll al final).

Con `stretch aspect = keep` el viewport de juego mide siempre 640 x 360 (la ventana más grande o más ancha solo añade franjas), así que las comprobaciones geométricas se hacen en esas coordenadas.

| Modal | Ventana pedida | Ventana real | Viewport | Modal | Scroll | Cabecera | Pie | Botón | Márgenes | Teclado | Ratón | Resultado |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| kit_pantalla | 640x360 | 640x360 | 640x360 | 520x250 | no | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ | OK |
| kit_pantalla | 960x540 | 960x540 | 640x360 | 520x250 | no | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ | OK |
| kit_pantalla | 1280x720 | 1280x720 | 640x360 | 520x250 | no | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ | OK |
| kit_pantalla | 1920x1080 | 1920x1080 | 640x360 | 520x250 | no | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ | OK |
| kit_pantalla | 1600x600 | 1600x600 | 640x360 | 520x250 | no | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ | OK |
| retro_kit_d5 | 640x360 | 640x360 | 640x360 | 420x328 | sí | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ | OK |
| retro_kit_d5 | 960x540 | 960x540 | 640x360 | 420x328 | sí | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ | OK |
| retro_kit_d5 | 1280x720 | 1280x720 | 640x360 | 420x328 | sí | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ | OK |
| retro_kit_d5 | 1920x1080 | 1920x1080 | 640x360 | 420x328 | sí | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ | OK |
| retro_kit_d5 | 1600x600 | 1600x600 | 640x360 | 420x328 | sí | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ | OK |
| retro_decision_larga | 640x360 | 640x360 | 640x360 | 420x328 | sí | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ | OK |
| retro_decision_larga | 960x540 | 960x540 | 640x360 | 420x328 | sí | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ | OK |
| retro_decision_larga | 1280x720 | 1280x720 | 640x360 | 420x328 | sí | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ | OK |
| retro_decision_larga | 1920x1080 | 1920x1080 | 640x360 | 420x328 | sí | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ | OK |
| retro_decision_larga | 1600x600 | 1600x600 | 640x360 | 420x328 | sí | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ | OK |
| libreta_larga | 640x360 | 640x360 | 640x360 | 540x328 | sí | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ | OK |
| libreta_larga | 960x540 | 960x540 | 640x360 | 540x328 | sí | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ | OK |
| libreta_larga | 1280x720 | 1280x720 | 640x360 | 540x328 | sí | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ | OK |
| libreta_larga | 1920x1080 | 1920x1080 | 640x360 | 540x328 | sí | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ | OK |
| libreta_larga | 1600x600 | 1600x600 | 640x360 | 540x328 | sí | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ | OK |
| resultados_completo | 640x360 | 640x360 | 640x360 | 608x328 | sí | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ | OK |
| resultados_completo | 960x540 | 960x540 | 640x360 | 608x328 | sí | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ | OK |
| resultados_completo | 1280x720 | 1280x720 | 640x360 | 608x328 | sí | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ | OK |
| resultados_completo | 1920x1080 | 1920x1080 | 640x360 | 608x328 | sí | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ | OK |
| resultados_completo | 1600x600 | 1600x600 | 640x360 | 608x328 | sí | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ | OK |
| acuerdo | 640x360 | 640x360 | 640x360 | 420x301 | no | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ | OK |
| acuerdo | 960x540 | 960x540 | 640x360 | 420x301 | no | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ | OK |
| acuerdo | 1280x720 | 1280x720 | 640x360 | 420x301 | no | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ | OK |
| acuerdo | 1920x1080 | 1920x1080 | 640x360 | 420x301 | no | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ | OK |
| acuerdo | 1600x600 | 1600x600 | 640x360 | 420x301 | no | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ | OK |
| pregunta_larga | 640x360 | 640x360 | 640x360 | 480x319 | no | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ | OK |
| pregunta_larga | 960x540 | 960x540 | 640x360 | 480x319 | no | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ | OK |
| pregunta_larga | 1280x720 | 1280x720 | 640x360 | 480x319 | no | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ | OK |
| pregunta_larga | 1920x1080 | 1920x1080 | 640x360 | 480x319 | no | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ | OK |
| pregunta_larga | 1600x600 | 1600x600 | 640x360 | 480x319 | no | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ | OK |
| pausa_controles | 640x360 | 640x360 | 640x360 | 440x325 | no | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ | OK |
| pausa_controles | 960x540 | 960x540 | 640x360 | 440x325 | no | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ | OK |
| pausa_controles | 1280x720 | 1280x720 | 640x360 | 440x325 | no | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ | OK |
| pausa_controles | 1920x1080 | 1920x1080 | 640x360 | 440x325 | no | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ | OK |
| pausa_controles | 1600x600 | 1600x600 | 640x360 | 440x325 | no | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ | OK |
| pausa_opciones | 640x360 | 640x360 | 640x360 | 440x279 | no | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ | OK |
| pausa_opciones | 960x540 | 960x540 | 640x360 | 440x279 | no | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ | OK |
| pausa_opciones | 1280x720 | 1280x720 | 640x360 | 440x279 | no | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ | OK |
| pausa_opciones | 1920x1080 | 1920x1080 | 640x360 | 440x279 | no | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ | OK |
| pausa_opciones | 1600x600 | 1600x600 | 640x360 | 440x279 | no | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ | OK |
| creditos | 640x360 | 640x360 | 640x360 | 476x328 | sí | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ | OK |
| creditos | 960x540 | 960x540 | 640x360 | 476x328 | sí | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ | OK |
| creditos | 1280x720 | 1280x720 | 640x360 | 476x328 | sí | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ | OK |
| creditos | 1920x1080 | 1920x1080 | 640x360 | 476x328 | sí | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ | OK |
| creditos | 1600x600 | 1600x600 | 640x360 | 476x328 | sí | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ | OK |

**Resumen:** 50 comprobaciones, 0 con fallos.

- *Teclado*: el botón principal toma el foco. *Ratón*: el centro del botón está dentro del viewport y no lo tapa nada.
- En la pregunta del cuestionario no hay botón de continuar (elegir una opción pasa a la siguiente): el «botón principal» es la primera opción.
- Cada fila también se comprobó con el scroll al final (las capturas `_fin`).
