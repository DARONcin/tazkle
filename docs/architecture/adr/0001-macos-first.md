# ADR-0001: macOS first

- Estado: aceptado
- Fecha: 2026-07-22

## Decisión

La primera aplicación será nativa para macOS. La experiencia debe aprovechar ventanas, menús, teclado, VoiceOver, Keychain y patrones de la plataforma. La versión web llegará después para Windows y Linux.

## Consecuencias

- SwiftUI será la base de interfaz; se permiten puentes a AppKit cuando el lienzo o la accesibilidad lo requieran.
- La lógica de dominio compartible vive en servicios y contratos, no acoplada a vistas SwiftUI.
- La versión web reutilizará contratos y design tokens, pero no intentará replicar literalmente cada comportamiento nativo.
