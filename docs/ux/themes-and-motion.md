# Apariencia, movimiento y sonido

## Temas

- Automático: sigue macOS y es la opción predeterminada.
- Claro.
- Oscuro.
- Mayor contraste.

Cada tema posee tokens propios para superficies, texto, bordes, foco, selección, estados y gráficas. No se genera mediante una simple inversión de colores.

Los cinco pigmentos de marca permanecen sin cambios en logo e iconografía. En
la interfaz, sus derivados semánticos se aclaran sobre superficies oscuras y se
profundizan sobre superficies claras para mantener contraste. Esta adaptación
no modifica el significado:

- Azul: acción principal, selección y trabajo en curso.
- Violeta: relaciones, arquitectura y responsabilidad.
- Cian: propuestas de Tazki, conexiones activas y alternativas.
- Ámbar: costo, condición, riesgo y decisión pendiente.
- Verde: resultado validado, viable o completado.

Mayor contraste se propaga mediante un único contexto de tema a contenido,
sidebar, tarjetas, canvas e inspectores. También se activa cuando macOS solicita
contraste aumentado. Ningún estado introduce colores directos del sistema.

## Preferencias del sistema

- Aumentar contraste.
- Reducir transparencias.
- Reducir movimiento.
- Diferenciar sin color.

Tazkle debe responder a estas preferencias sin exigir una configuración duplicada.

## Movimiento

- Las transiciones funcionales son cortas y conservan contexto.
- Reduce Motion reemplaza desplazamientos, escalados y rebotes por cambios discretos o fundidos.
- No se usan destellos ni movimiento repetitivo para llamar la atención.
- Las animaciones de Tazki son opcionales cuando no comunican progreso real.
- El símbolo de brillos del acceso flotante de Tazki permanece discreto en
  reposo y sólo se enfatiza al apuntar. Con Reduce Motion cambia de énfasis sin
  escala; la mascota animada aparece únicamente dentro del chat.
- Al mover un bloque, una elevación breve mediante escala y sombra conserva el
  vínculo entre puntero y objeto; el bloque sigue al cursor sin interpolar su posición
  y deja un hueco discontinuo estable en el origen. Una silueta de destino permanece
  fija en el encaje calculado para separar visualmente objeto flotante y resultado.
- Al crear una relación, la línea discontinua sigue al cursor y desaparece de forma
  breve al cancelar o completar. No hay rebote ni movimiento decorativo continuo.
- Con Reduce Motion, la elevación, el escalado y los fundidos se sustituyen por un
  cambio inmediato de borde y estado; el arrastre funcional permanece disponible.

## Sonido

- Sonidos de interfaz desactivables.
- Control independiente de animaciones y sonidos de Tazki.
- Ninguna alerta, aprobación o error depende solo del audio.
- La biblioteca de sonido se evaluará por licencia, mantenimiento, tamaño y compatibilidad nativa antes de adoptarla.
