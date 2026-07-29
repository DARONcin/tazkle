# Design system

Tokens semánticos, componentes y estados accesibles compartibles entre la especificación visual, SwiftUI y la futura web.

## Color

- `TazkleBrandColors` contiene únicamente los cinco pigmentos físicos aprobados.
- `TazkleColors` es la API que deben consumir las vistas: acción principal,
  relación, propuesta de Tazki, advertencia y éxito.
- Los pigmentos de `TazkleBrandColors` permanecen exactos en activos de marca.
  Los colores de `TazkleColors` son derivados semánticos por tema: conservan
  la familia cromática y alcanzan contraste legible sobre paneles claros y
  oscuros.
- Las superficies y el contenido se resuelven por tema; no deben recrearse con
  opacidades o colores hexadecimales en cada pantalla.
- `tazkleHighContrast` viaja por el entorno SwiftUI y modifica canvas, paneles,
  superficies elevadas, contenido secundario y separadores en todos los módulos.
- Un riesgo crítico usa `TazkleColors.critical`, basado en el ámbar aprobado,
  acompañado siempre por texto e icono. No introduce rojo u otro pigmento.
- La fuente de referencia multiplataforma es
  `design/approved/brand/tazkle-palette.json`.
