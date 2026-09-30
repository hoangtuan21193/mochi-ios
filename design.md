# Mochi — design system ("Organic")

One cream page, ink text, terracotta for money leaving, sage for money arriving.
Every screen is assembled from the components in `Mochi/DesignSystem/`. A view
file never draws its own chrome.

Source of truth: `Mochi/DesignSystem/Tokens.swift` (values) and
`Mochi/DesignSystem/*.swift` (parts, one file per family: Containers, Buttons, Selection, Fields, DataDisplay, Layout). This document says how to use them.

## 1. Rules

1. **No raw numbers for type, colour, radius.** `.font(.system(size:))`,
   `Color(hex:)`, `cornerRadius: 14` do not appear outside `Tokens.swift`.
   Use `Organic.title`, `Organic.n600`, `Organic.rInner`.
2. **No hand-drawn chrome.** A capsule with a stroke is a `FormField`, a
   `DropdownPill` or a `SecondaryButton`. A tiny uppercase tag is a `Badge`. A
   1-pt line is a `Hairline`. Label-over-value is a `Metric`. If none fits,
   add a variant to the matching `DesignSystem/` family file with a name — never inline it.
3. **One primary action per screen or sheet.** `PrimaryButton` is accent
   orange and full width; everything else is `SecondaryButton`, `AddPill`,
   a chip or a link.
4. **Add is always the round `+` in a `SectionHeader`, outside the card.** It
   turns into × while the inline form is open. Never inside a card, never a
   full-width "Add …".
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
12. **Money is typed through `MoneyField`.** It binds to the number, so a view
    never parses digits out of a string; the grouping, the symbol and the
    arithmetic come with it for free and look the same on every screen.
13. **Copy is `LocalizedStringKey`; the user's words are `String`.** A component
    parameter that carries the app's own words is typed `LocalizedStringKey`
    (or `String.LocalizationValue` where UIKit needs a resolved `String`, as in
    `MoneyField`), so the literal at the call site reaches
    `Localizable.xcstrings`. A parameter that carries a name the user typed —
    a wallet, a category, an owner, a formatted figure — stays `String` and is
    drawn with `Text(verbatim:)`, so it is never looked up as a key. Where one
    slot takes both (`Badge`, `SheetScaffold`, `Chip`, `DropdownPill`,
    `InlineMenu`) the component takes a `Text` or offers a `verbatim` init, and
    the caller says which it has. **A `String` holding copy never reaches the
    catalogue**: `Text(someString)` is the verbatim initialiser, so it renders
    in English and no build ever warns. A helper that returns a sentence
    returns `LocalizedStringKey`; one that joins pieces builds them with
    `String(localized:)` and joins after.
14. **A picker's options are identity, not words.** `ChipPicker.options` and
    `selection` are compared and written into the book, so they stay the stored
    English raw values; a picker whose options are the app's own words passes a
    `display:` closure that turns each one into a `Text`.

## 2. Tokens (`Organic`)

### Type scale

| Token | Size / weight | Use |
|---|---|---|
| `display(n)` | Caprasimo in English, else system black rounded | Hero numbers, screen titles, sheet amounts. Caprasimo is Latin-1 only — no Vietnamese tone marks, no kana, no kanji, not even ₫ — so outside English the face steps aside rather than splitting a word across two fonts. |
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

### Headers — two card shapes, and only two
- **List section**: `SectionHeader(title:, subtitle:, isOpen:, onAdd:)` *outside*
  the card, then the optional inline add form as its own `Card`, then
  `Card(padding: .list)` holding `RowButton` rows. Wallets, cards, plans,
  point wallets, owners, channels, attributes all look like this. The + lives
  in the `SectionHeader` and nowhere else.
- **Form card**: `Card { CardHeader(title:, subtitle:); controls… }` for
  prose and settings (Backup, General, Selling, Data). No +.

### Buttons
- `PrimaryButton(title:, icon:)` — one per screen.
- `SecondaryButton(title:, icon:, style: .quiet | .warm | .outlined)` —
  quiet in a card (Restore, Edit details); warm for undoing money (Undo this
  sale); outlined when it sits on the page (Move money).
- `DeleteButton(title:)` — destructive, always after a confirm alert.
- `AddButton` / `AddPill` — the + and the confirm inside an inline form.
- `RemoveButton` — round × for a row in a form.
- `LinkLabel("Change")` — the label of a `Menu` offering a correction.
  `LinkLabel("Cancel", chevron: false)` for a link that just does the thing;
  the chevron promises a menu.

### Selection
- `Chip(label:, selected:, tint:)` — the pill. Only for fixed, short sets the
  user knows by heart: Cash / Point, Full / Half.
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
- `FormField("Placeholder", text:, numeric:, decimal:)` — the capsule field
  for text and for plain counts (due day, months, a percentage).
  `FormField { any view }` to wrap a custom control.
- `MoneyField("Placeholder", value: $int, unit:, prominent:, alignment:)` —
  **every amount**. Groups digits as they are typed, shows the symbol inside
  the capsule, and evaluates `+ − × ÷` live ("12,000×3−1,500  = ¥34,500").
  While it has focus a rounded panel of five keys, `+ − × ÷ =`, floats a
  little above the number pad (`OperatorKeyRow`, a UIKit `inputAccessoryView`;
  the field is therefore a `UITextField`, `MoneyKeypadField`). It is drawn in
  the keyboard's own greys and key shape from `Organic.Keypad`, whose colours
  are dynamic and resolve against the keyboard's light or dark trait, so it
  reads as one more row of keys. `=` settles the sum and puts the keyboard
  away; `SheetScaffold` hides its Done for the duration (via
  `MoneyFieldFocusKey`) so there is never a second row.
  Binds to `Int` (0 = blank) or `Int?` (nil = blank, 0 = zero). `unit` is
  `.book` (default), `.currency(.vnd)` for a loan, `.suffix("pt")` for points,
  `.none` for a bare number. A `TextField` with `.numberPad` for money is a bug.
- `SearchField("Search by name", text:, autofocus:)` — the one search field: a
  magnifier, the query, a × to clear. A `FormField` capsule like every other
  field, with autocorrect and capitalisation off, because what gets typed into
  it is "200mm f2.8". The matching itself is `Finance.matches(_:search:)`,
  never a `contains` in a view.
- `SearchDock("Search by name", text:, note:, onCancel:)` — that field docked
  at the bottom through `.safeAreaInset(edge: .bottom)`, riding up with the
  keyboard, with an optional `note` under it and Cancel beside it. A screen
  only gives up room for searching while something is being looked for: the
  way in is a magnifier `IconButton` in the toolbar, `filled:` while a query
  is in force so the shortened list has something to explain it, and Cancel
  clears the query as well as closing the dock. Inventory has the only one.
- `MonthPicker(label:, year:, month:)` — a month and its year, as a menu of
  years each holding its twelve. For a figure printed as a month ("2025/03"):
  a text field would take "2025/13", a `DatePicker` would ask for a day. Wrap
  it in `FormField { }` to sit in a row of capsules.
- `LineRow(label:, value:, tone:, onDark:, total:)` — one line of a breakdown,
  label left, figure right, no box: a stack of them reads as a sum (cash +
  incoming − committed = safe). `tone` colours the figure only. `total` for
  the line the others add up to. Not for a list of things — that is a row
  with a `Hairline`.
- `FieldLabel("Owner")` above a group; `HelpText("…", tone: .quiet | .warning | .positive)` below.

### Data display
- `Metric(label:, value:, valueColor:, labelColor:, large:, boxed:)` — the
  only label-over-value. `large` in heroes, `boxed` for Stats tiles. A boxed
  metric stretches to the tallest in its row and holds its value along the
  bottom, so a label that wraps to two lines in Vietnamese and one in English
  does not leave a row of tiles at different heights.
- `SectionTotal(label:, value:, note:, tint:, hairline:)` — the closing line of
  a list card, under a hairline: what the rows above add up to. Every section
  that can be added up ends in one, and it is the only place rows a section
  collapses out of sight are still counted. `note` carries a second, quieter
  figure on the left where a section adds up two ways at once (instalments owe
  a debit next month and a total before they are done).
- `Badge("SOLD", tone: .accent | .sage | .neutral)` — uppercase tag.
- `Hairline()` — row separator. Rows use `.overlay(alignment: .top) { if !first { Hairline() } }`.
- `EmptyNote("No cards yet…")` — placeholder inside an empty card.
- `CalloutRow(label:, value:, positive:)` — tinted strip with a figure.
- `RowButton(first:, action:) { row content }` — tappable list row with its hairline.
- `.copyOnLongPress(name)` — long press to put the user's own text on the
  clipboard, with a tap-back and a "Copied" badge that fades. On the item name
  in the Inventory row and on the item page: that name is what gets pasted into
  a listing, and retyping "SIGMA 200mm f2.8 APO" is how it comes out wrong. It
  is a high-priority gesture, so the row's tap still opens the item and a long
  press does not do both.
- `ChartLegend(.init("Cash", .line, Organic.s700), …)` — the key to a chart:
  a swatch and a word per mark (`.line` a series, `.dashed` a threshold, `.dot`
  a single reading, `.bar` a bar chart's colour). Any chart that hides its axes
  carries one; without it the chart is a shape nobody can name.

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
2. Otherwise add the struct to the matching `DesignSystem/` family file, with a
   doc comment saying where it is used and why it exists.
3. Update section 3 of this file.
4. Replace the inline version everywhere it already appears — a component that
   exists in two places is not a component.
