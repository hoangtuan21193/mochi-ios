# Mochi — design system ("Organic")

One cream page, ink text, terracotta for money leaving, sage for money arriving.
Every screen is assembled from the components in `Mochi/DesignSystem/`. A view
file never draws its own chrome.

Source of truth: `Mochi/DesignSystem/Tokens.swift` (values) and
`Mochi/DesignSystem/Components.swift` (parts). This document says how to use them.

## 1. Rules

1. **No raw numbers for type, colour, radius.** `.font(.system(size:))`,
   `Color(hex:)`, `cornerRadius: 14` do not appear outside `Tokens.swift`.
   Use `Organic.title`, `Organic.n600`, `Organic.rInner`.
2. **No hand-drawn chrome.** A capsule with a stroke is a `FormField`, a
   `DropdownPill` or a `SecondaryButton`. A tiny uppercase tag is a `Badge`. A
   1-pt line is a `Hairline`. Label-over-value is a `Metric`. If none fits,
   add a variant to `Components.swift` with a name — never inline it.
3. **One primary action per screen or sheet.** `PrimaryButton` is accent
   orange and full width; everything else is `SecondaryButton`, `AddPill`,
   a chip or a link.
4. **Add is always the round `+`.** `SectionHeader` / `CardHeader` carry it; it
   turns into × while the inline form is open. Never a full-width "Add …".
5. **Colour means something.**
   - Terracotta (`a*`): debt, urgency, destructive, "NEW", warnings.
   - Sage (`s*`): money in, settled, "cash covers it", positive.
   - Neutral (`n*`): everything else. `n600` is the default secondary text.
   - Accent orange (`accent`) is spent only on the primary button, the active
     tab, link labels and the "new thing" chip.
6. **Hierarchy through weight and size from the scale, not through extra
   sizes.** Seven sizes exist. If two texts need to differ, change weight or
   colour first.
7. **Lists of the user's own things are never a wall of chips.** Go through
   `ChipPicker`; it turns into a dropdown past four options on its own.
8. **Controls appear only where there is a choice.** A `Menu` with one option,
   a picker with one chip, a "Change" link with nothing to change to — remove
   it and state the outcome as text.
9. **Say what happens before it happens.** Forms end with a preview line
   ("¥30,000 goes onto card debt now · in 5 days") in `Organic.meta`.
10. **Proper nouns are not prose.** Every name field uses `FormField(_:text:)`
   which disables autocorrect.
11. **Light only.** The palette has no dark counterpart; the app pins itself
    to light.

## 2. Tokens (`Organic`)

### Type scale

| Token | Size / weight | Use |
|---|---|---|
| `display(n)` | Caprasimo | Hero numbers, screen titles, sheet amounts. No Vietnamese glyphs. |
| `hero` | 32 heavy | The one number a screen is about (Wallet net worth). |
| `title` | 15 heavy | Card titles, section headers, sheet headings. |
| `statValue` | 16 heavy | Numbers in hero cards and `Metric(large:)`. |
| `body` | 13 regular | Paragraphs, field text, settings row labels. |
| `row` | 13 semibold | List row labels. |
| `rowValue` | 13 heavy | Row figures, **every button label**. |
| `value` / `valueStrong` | 12 regular / heavy | Secondary figures, chip text, empty notes. |
| `caption` / `captionStrong` | 11 regular / semibold | Help text, sublines, field labels, link labels. |
| `meta` / `metaStrong` | 10.5 regular / bold | Labels over values, dates, notes, preview lines. |
| `badge` | 9 bold | Uppercase tags. |
| `glyph` | 9 heavy | Chevrons and arrows inside controls. |
| `mono` | 11 monospaced | Sheet previews. |

### Colour

Roles: `bg` page, `n100` card, `text` ink, `accent` primary, `accent2` toggles.
Ramps `n100…n900`, `a100…a900`, `s100…s900` — light to dark. Fill with `*100`/`*200`,
text with `*700`–`*900`.

### Radius

`rCard` 20 (cards, hero) · `rInner` 18 (blocks, tiles inside a card) · `rSmall` 12 (callout strips).

### Spacing (`Organic.Space`)

`xs` 4 · `s` 6 · `m` 8 (between controls) · `row` 10 (row vertical padding) ·
`l` 12 (between cards) · `card` 13 (card padding) · `gutter` 16 (screen edge).

## 3. Components

### Containers
- `Card { }` — cream card. `Card(padding: .list)` for a card whose rows carry
  their own padding. `Card(fill: Organic.a100)` for a warning card,
  `Organic.s100` for a positive one.
- `InnerBlock { }` — a group inside a card (form block, nested list).
- `SheetScaffold(title:) { }` — every sheet. Close on the left, Done above the keyboard.

### Headers
- `SectionHeader(title:, subtitle:, isOpen:, onAdd:)` — outside cards (Wallet).
- `CardHeader(title:, subtitle:, isOpen:, onAdd:)` — inside a card (Settings).
- A card without an add button still starts with `Text(...).font(Organic.title)`
  and, if needed, `HelpText(...)`.

### Buttons
- `PrimaryButton(title:, icon:)` — one per screen.
- `SecondaryButton(title:, icon:, style: .quiet | .warm | .outlined)` —
  quiet in a card (Restore, Edit details); warm for undoing money (Undo this
  sale); outlined when it sits on the page (Move money).
- `DeleteButton(title:)` — destructive, always after a confirm alert.
- `AddButton` / `AddPill` — the + and the confirm inside an inline form.
- `RemoveButton` — round × for a row in a form.
- `LinkLabel("Change")` — the label of a `Menu` offering a correction.

### Selection
- `Chip(label:, selected:, tint:)` — the pill. Only for fixed, short sets the
  user knows by heart: Cash / Point, Full / Half, 12 / 24 / 36 / 48 / 60.
- `ChipPicker(label:, options:, selection:, accentOptions:, onPick:)` — the
  single-select for every data-driven list (wallets, cards, channels, owners,
  categories). Draws chips up to `ChipPicker.chipLimit` (4) options and a
  `DropdownPill` beyond that. Callers never choose the form; the count does,
  so the whole app switches at the same point. `accentOptions` marks the
  "create new" entry.
- `ToggleChip(label:, tint:)` — a two-state chip that is always "selected"
  (Cash / Point, Records only / Add to card debt).
- `DropdownPill(value:) { menu items }` — for lists too long for chips.
- `DropdownRow(label:, value:) { }` — Settings row with a pill on the right.
- `InlineMenu(label:, value:) { }` — "Item  Not linked ⌄" inside a form.

### Fields
- `FormField("Placeholder", text:, numeric:, decimal:)` — the capsule field.
  `FormField { any view }` to wrap a custom control.
- `FieldLabel("Owner")` above a group; `HelpText("…", tone: .quiet | .warning | .positive)` below.

### Data display
- `Metric(label:, value:, valueColor:, labelColor:, large:, boxed:)` — the
  only label-over-value. `large` in heroes, `boxed` for Stats tiles.
- `Badge("SOLD", tone: .accent | .sage | .neutral)` — uppercase tag.
- `Hairline()` — row separator. Rows use `.overlay(alignment: .top) { if !first { Hairline() } }`.
- `EmptyNote("No cards yet…")` — placeholder inside an empty card.
- `CalloutRow(label:, value:, positive:)` — tinted strip with a figure.
- `RowButton(first:, action:) { row content }` — tappable list row with its hairline.

### Layout
- `FlowRow(spacing:)` — wrapping chips.

## 4. Screen anatomy

```
NavigationStack
  ScrollView
    VStack(spacing: Organic.Space.l)        // 12 between cards
      [hero card]                           // at most one Organic.hero / display
      SectionHeader + optional inline form + Card(padding: .list)
      Card { Text(title).font(Organic.title); HelpText; rows… }
    .padding(.horizontal, Organic.Space.gutter)
  .background(Organic.bg)
```

Inline add form = `Card { Text(title).font(Organic.title); VStack(spacing: .m) {
FormField…; ChipPicker…; Text(preview).font(Organic.meta); HStack { Spacer(); AddPill } } }`.

A sheet = `SheetScaffold { summary Card; action Card(s); SecondaryButton("Edit …")
→ edit Card ending in PrimaryButton("Save") + DeleteButton }`.

## 5. Adding a component

1. Does an existing one fit with a parameter? Add the parameter.
2. Otherwise add the struct to `Components.swift` under the right MARK, with a
   doc comment saying where it is used and why it exists.
3. Update section 3 of this file.
4. Replace the inline version everywhere it already appears — a component that
   exists in two places is not a component.
