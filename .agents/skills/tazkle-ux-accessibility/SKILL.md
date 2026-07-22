---
name: tazkle-ux-accessibility
description: Design and review Tazkle flows for usability, macOS conventions, keyboard operation, VoiceOver, reduced motion, clear themes, offline feedback, and WCAG 2.2 AA readiness. Use when creating or changing navigation, the block canvas, forms, approvals, errors, onboarding, Tazki interactions, collaboration, synchronization states, shortcuts, or any user-facing behavior.
---

# Tazkle UX and Accessibility

Make every critical project operation understandable and recoverable across pointer, keyboard, and assistive-technology use.

## Workflow

1. Read `references/accessibility-contract.md` completely.
2. Read the relevant flow in `docs/product/` and `docs/ux/` before changing UI behavior.
3. Describe the user's goal, role, starting state, success state, and recoverable failures.
4. Map empty, loading, offline, syncing, conflict, permission, validation, and approval states as applicable.
5. For every pointer or drag interaction, define keyboard, menu, and semantic alternatives.
6. Verify focus order, focus restoration, labels, values, state announcements, and destructive-action recovery.
7. Check automatic, light, dark, increased-contrast, reduced-transparency, and reduced-motion behavior.
8. Run `scripts/check-accessibility-contract.sh` and perform manual checks appropriate to the changed surface.

## Canvas rule

The canvas is one projection of the project model. Maintain equivalent tree, list, or inspector operations so that drawing position is not required to understand or edit structure. A connection must expose source, relation type, target, status, and available actions as text.

## Error and AI rule

Explain what happened, what is affected, how to recover, and whether work was preserved. Tazki may explain or propose, but its face, color, motion, or sound must never be the only status channel.

## Review output

Report blockers first, then serious friction, then polish. For each issue include affected role, task, input method, expected behavior, observed behavior, and acceptance criterion. Do not claim VoiceOver or keyboard support unless it was actually exercised or the claim is explicitly marked as design-only.
