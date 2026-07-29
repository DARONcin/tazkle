# Visual contract

## Authority order

1. Corrected assets under `design/approved/`.
2. Product and UX decisions under `docs/`.
3. This contract.
4. New proposals explicitly marked as proposals.

Never implement from ignored exploratory images when an approved equivalent exists. When two approved assets conflict, prefer filenames marked `corregida` and record the conflict.

## Brand assets

- Product mark: `design/approved/brand/production/tazkle-mark.svg`.
- Monochrome marks: `design/approved/brand/production/tazkle-mark-mono-light.svg`
  and `tazkle-mark-mono-dark.svg`.
- Wordmarks: `design/approved/brand/production/tazkle-wordmark-light.svg`
  and `tazkle-wordmark-dark.svg`.
- macOS icon source: `design/approved/brand/production/tazkle-app-icon.svg`.
- Tazki: `design/approved/brand/tazki-mascot.svg`.
- Tazki motion: `design/approved/brand/tazki-motion-spec.md`.

The SVG files at the root of `design/approved/brand/` named `tazkle-mark.svg`
and `tazkle-wordmark.svg` are approved construction boards, not production
assets. Product bundles must use the isolated files under `production/`.

The mark must remain legible in monochrome. Do not redraw the internal T, alter node positions, add an enclosing circle, or remove white outlines from colored nodes without an approved brand revision.

## Semantic palette

| Token intent | Reference value | Use |
|---|---:|---|
| `surface.canvas.dark` | `#08131D` | Deep application background |
| `surface.panel.dark` | `#132430` | Panels, cards, sidebar |
| `action.primary` | `#4F7CFF` | Primary action and selection |
| `relationship` | `#8C6BFF` | Relationships and architecture |
| `assistant.proposal` | `#6DD6E7` | Tazki proposals and alternatives |
| `status.warning` | `#F1B84B` | Cost, risk, pending decision |
| `status.success` | `#75C66B` | Validated or viable state |
| `content.onDark` | `#EDF2F6` | Primary content on dark surfaces |

These are source references, not permission to scatter raw hex values through product code. Define light, dark, and increased-contrast semantic tokens in the design-system package. Validate contrast before freezing derived values.
The machine-readable authority is `design/approved/brand/tazkle-palette.json`.

## Typography and iconography

- Use the macOS system typeface and semantic text styles in the native app.
- Preserve text scaling; do not encode information in tiny fixed labels.
- Use SF Symbols for product controls when an appropriate symbol exists.
- Use custom SVG only for the Tazkle mark, Tazki, and truly brand-specific concepts.
- Pair unfamiliar icons with labels or accessible descriptions.

## Layout

- Use a 4-point base grid with common intervals of 8, 12, 16, 24, and 32 points.
- Align related values and labels; do not create arbitrary card sizes for visual novelty.
- Use sidebar for peer navigation, main content for the current task, and trailing inspector for selected-object detail.
- Permit sidebar and inspector collapse. Preserve the task when the window narrows.
- Keep critical actions away from a bottom edge that may be obscured.

## Density by surface

| Surface | Density rule |
|---|---|
| Project Map | May expose tools and the block catalog; keep canvas dominant |
| Architecture | May expose block catalog, layers, relations, and impact |
| Feasibility | Summary first, one dimension at a time, assumptions on demand |
| Costs | Totals and confidence first, detailed tables behind navigation |
| Work plan | Choose calendar, board, or backlog view; do not show all simultaneously |
| Account | Forms grouped by responsibility with explanatory copy only when needed |

## Component states

Every interactive component must define relevant states: default, hover, pressed, selected, keyboard focus, disabled, loading, error, and read-only. Selection, validation, and risk require text or icon support in addition to color.

## Motion

- Use motion to preserve spatial context or communicate progress.
- Respect Reduce Motion and replace nonessential travel, zoom, or bounce with a discrete transition.
- Keep Tazki motion local to the assistant area.
- Never use an animated border as a permanent decoration; reserve it for short-lived focus or processing feedback.
