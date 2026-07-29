# Sistema de marca de Tazkle

Este directorio separa las decisiones aprobadas de los recursos listos para
producto. Las láminas `tazkle-mark.svg` y `tazkle-wordmark.svg` explican la
construcción; no deben incrustarse en una interfaz.

## Activos canónicos

| Archivo | Uso |
|---|---|
| `production/tazkle-mark.svg` | Isotipo a color sobre superficies oscuras. |
| `production/tazkle-mark-mono-light.svg` | Isotipo monocromático sobre fondos oscuros. |
| `production/tazkle-mark-mono-dark.svg` | Isotipo monocromático sobre fondos claros. |
| `production/tazkle-wordmark-light.svg` | Nombre sobre fondos oscuros. |
| `production/tazkle-wordmark-dark.svg` | Nombre sobre fondos claros. |
| `production/tazkle-app-icon.svg` | Fuente vectorial del icono de macOS. |
| `tazki-mascot.svg` | Mascota base; sus estados siguen la especificación de movimiento. |

## Reglas del isotipo

- La geometría representa una `t` minúscula ramificada.
- Los cuatro nodos viven dentro de una circunferencia invisible; esa
  circunferencia nunca se dibuja.
- Azul arriba, cian arriba-derecha, morado abajo-izquierda y ámbar abajo-derecha.
- Los nodos de la versión a color conservan contorno blanco.
- No se alteran longitud, grosor, posición, espejo de ramas o peso del gancho.
- Debajo de 24 pt se usa preferentemente una variante monocromática.
- El espacio libre mínimo es el radio de uno de los nodos alrededor del encuadre.

## Paleta

`tazkle-palette.json` es la referencia portable. El código Swift utiliza nombres
semánticos desde `TazkleColors`; los valores físicos están aislados en
`TazkleBrandColors`. No se usan colores hexadecimales, colores de sistema o
`accentColor` directamente en las vistas.

## Sincronización

`scripts/sync-brand-assets.sh` copia los activos aprobados al bundle de macOS.
El quality gate compara los archivos byte por byte y falla si una copia deriva.
