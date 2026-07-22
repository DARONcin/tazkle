# Accessibility and usability contract

## Baselines

- Follow native macOS patterns and Apple accessibility guidance for the desktop app.
- Target WCAG 2.2 AA for the future web surface.
- Treat automated checks as assistance, never proof of conformance.

## Task model

For each critical flow define:

1. Role and permission.
2. Entry point.
3. Primary action.
4. Required information.
5. Success confirmation.
6. Recoverable error.
7. Offline behavior.
8. Audit or approval consequence.

Critical flows include project creation, block creation, relation creation, feasibility evaluation, quotation, change review, approval, conflict resolution, export, and account security.

## Keyboard

- Operate all functions without a pointer.
- Use standard macOS menu commands and avoid overriding system shortcuts.
- Keep focus visible, ordered, and unobscured.
- Restore focus to the invoking control after dismissing a sheet, popover, or inspector.
- Provide shortcuts through menus and the searchable command palette.
- Avoid single-key destructive shortcuts without a standard modifier or confirmation.

## VoiceOver semantics

- Give controls concise labels and meaningful values.
- Announce status changes that are not obvious from focus movement.
- Group related content without hiding necessary child controls.
- Describe block type, title, state, responsibility, warnings, and relationship count.
- Describe each relation as source, typed relation, and target.
- Do not expose decorative Tazki facial elements as separate controls.

## Canvas alternatives

- Create a block from button, menu, command palette, or keyboard.
- Connect blocks through an origin → relation → destination workflow.
- Move or organize blocks through commands and auto-layout.
- Expose a project tree and relationship list backed by the same data.
- Never require line color or spatial position to understand a dependency.

## Perception

- Pair color with text, icon, line style, or pattern.
- Validate contrast for text, controls, focus, charts, and relation lines.
- Support text enlargement without clipped labels or hidden actions.
- Keep targets adequately sized and separated.
- Provide a text or table equivalent for charts and feasibility summaries.

## Motion and audio

- Respect Reduce Motion and Reduce Transparency.
- Avoid flashing, continuous decorative motion, and large parallax travel.
- Keep audio optional and provide an equivalent visible and semantic state.
- Make progress determinate when known and describe indefinite progress accessibly.

## Forms and errors

- Use persistent labels; placeholders are examples, not labels.
- Associate errors with the affected control and summarize multiple errors.
- Preserve entered data after recoverable failures.
- Explain assumptions and confidence next to estimates.
- Confirm destructive or difficult-to-reverse operations and provide Undo where possible.

## Offline and collaboration

Always distinguish saved locally, synchronizing, synchronized, conflict, rejected, and requires connection. Before closing, tell the user when changes exist only locally. Never resolve approved-scope, cost, architecture, or approval conflicts silently.

## Manual verification matrix

| Surface | Required checks |
|---|---|
| Every critical flow | Pointer, keyboard, VoiceOver |
| Every visual state | Light, dark, increased contrast |
| Animated surface | Normal motion and Reduce Motion |
| Data-heavy screen | Zoom, larger text, narrow window |
| Offline-capable flow | Disconnect, reconnect, conflict, close with pending data |
