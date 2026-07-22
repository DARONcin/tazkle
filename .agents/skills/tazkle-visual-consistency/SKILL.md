---
name: tazkle-visual-consistency
description: Preserve Tazkle's approved visual language across SwiftUI, web, documentation, screenshots, icons, charts, the block canvas, and Tazki. Use when creating or reviewing UI components, screens, visual assets, themes, design tokens, motion, responsive states, or implementation changes that could drift from the approved mockups and brand.
---

# Tazkle Visual Consistency

Mantener una interfaz sobria, modular y legible sin convertir cada pantalla en un tablero saturado.

## Workflow

1. Read `references/visual-contract.md` completely.
2. Inspect the relevant approved assets under `design/approved/`; do not use files under ignored exploration folders as implementation authority.
3. Identify the surface: navigation, canvas, data view, form, approval flow, Tazki, or marketing.
4. Reuse existing semantic tokens and component patterns before introducing a variant.
5. Check light, dark, increased-contrast, compact, empty, loading, error, disabled, selected, and keyboard-focus states as applicable.
6. Run `scripts/check-visual-tokens.sh` after token or UI-source changes.
7. Report deliberate deviations with rationale and affected screens. Never silently reinterpret the brand.

## Non-negotiable rules

- Treat blocks as structured records represented visually, not decorative puzzle pieces.
- Show the block catalog only in Project Map and Architecture.
- Keep feasibility, costs, and work plan progressively disclosed and less dense than the canvas.
- Use color as reinforcement, never as the only state or relationship signal.
- Keep one dominant action per context and place secondary detail in an inspector.
- Preserve native macOS hierarchy: sidebar, toolbar/content, and contextual inspector.
- Keep Tazki secondary to the task; animation must not compete with project content.
- Prefer semantic token names over raw colors in product code.

## Review output

Provide findings ordered by severity. For each finding include the surface, the violated rule, user impact, and the smallest consistent correction. Distinguish approved design decisions from implementation observations and unresolved proposals.
