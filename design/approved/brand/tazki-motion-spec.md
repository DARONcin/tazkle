# Tazki — pieza asimétrica y movimiento

## Silueta aprobada

Tazki adopta la orientación de una pieza clásica asimétrica:

- pestaña convexa superior;
- pestaña convexa izquierda;
- hueco cóncavo derecho;
- hueco cóncavo inferior;
- cuerpo azul grafito con contorno blanco;
- rostro centrado en la masa principal;
- un nodo cromático con contorno blanco por conector.

La pieza se construye dentro de un contorno invisible de `136 × 136` unidades. Sus cuatro extremos llegan exactamente a `±68`. Los cuatro conectores se trazan como circunferencias de radio `16`, con una apertura aproximada de `25` unidades y una profundidad o saliente de `26`. El cuerpo base se compensa hacia la derecha y abajo para equilibrar la masa añadida por las pestañas izquierda y superior con la masa retirada por los huecos derecho e inferior.

Los nodos indican la función de cada punto de acoplamiento:

- **Azul, arriba:** escucha y contexto.
- **Morado, izquierda:** relaciones y arquitectura.
- **Cian, derecha:** propuesta o alternativa.
- **Amarillo, abajo:** costo, riesgo o decisión.

Cada nodo se coloca dentro de su conector sin interrumpir el contorno. El centro de cada bolita coincide exactamente con el centro de la circunferencia que construye su pestaña o hendidura. De este modo, bolita y conector forman dos círculos concéntricos.

## Escala y legibilidad

- Lienzo vectorial: `230 × 210` unidades SVG.
- Fondo transparente y vista frontal, sin perspectiva.
- Uso recomendado: 160 px en bienvenida, 64–96 px en el panel de IA y 32 px como indicador.
- Por debajo de 48 px se elimina el rostro; se conservan silueta, contorno y nodos.
- La silueta debe seguir siendo reconocible en monocromático; el color complementa la lectura, no la sostiene.

## Estados

| Estado | Movimiento | Duración | Repetición |
|---|---|---:|---|
| Reposo | Pieza y rostro inmóviles; solo los nodos respiran suavemente | 2.8 s | Continua |
| Escucha | Ondas entran por el nodo superior; Tazki las sigue con la mirada, parpadea, levanta las cejas y abre ligeramente la boca mientras los cuatro nodos responden | 1.05 s | Mientras escucha |
| Analiza | El contorno se recorre, aparece `?`, la mirada sube y una ceja se concentra con boca pensativa | 1.2 s | Mientras procesa |
| Sugiere | Tazki mira hacia el nodo cian, hace un guiño, amplía la sonrisa y acompaña el destello de la propuesta | 1.5 s | Dos pulsos |
| Alerta | Vibración vertical, `!`, ojos abiertos y boca de sorpresa | 1.04 s | Una vez |
| Valida | La pieza se alinea con su ranura, sonríe ampliamente y produce un brillo breve | 0.92 s | Una vez |

## Reglas de animación

1. La pieza conserva su geometría; solo se traslada, rota o cambia de escala de forma mínima.
2. Los cuatro nodos permanecen ligados visualmente a sus conectores.
3. En escucha se mueven los cuatro nodos, con un desfase breve entre ellos.
4. La interrogación se reserva para análisis y la admiración para alertas.
5. No se agregan extremidades, accesorios, rebotes elásticos ni giros completos.
6. Con movimiento reducido, cada estado muestra directamente su pose final estática.
7. Análisis nunca usa una curva de boca descendente: la emoción debe leerse como concentración, no tristeza.
8. Validación conserva visible a Tazki y se expresa mediante sonrisa y brillo; no se reemplaza el rostro por una palomita.
9. El aro de validación se centra en `(13, 13)`, intersección estructural de los ejes de los conectores, nunca en el centro del rostro.
10. Escucha, análisis, sugerencia, alerta y validación incluyen movimiento facial propio; reposo mantiene el rostro completamente inmóvil.
