# Mochi — design system (namespace `Organic`)

A neutral page, white cards with a thin border, ink text, one warm accent,
green for money arriving, red for money owed, blue for belongings. Light and
dark from the same tokens. Every screen is assembled from the components in
`Mochi/DesignSystem/`. A view file never draws its own chrome.

The namespace kept its old name when the look changed (2026-09), so no call
site had to change; only the values did.

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
3. **One primary action per screen or sheet.** `PrimaryButton` is the accent
   and full width; everything else is `SecondaryButton`, `AddPill`,
   a chip or a link.
4. **Add is always the round `+` in a `SectionHeader`, outside the card.** It
   turns into × while the inline form is open. Never inside a card, never a
   full-width "Add …".
5. **Colour means something.**
   - Warm (`a*`): debt, urgency, destructive, "NEW". `a700` is the red an owed
     figure is printed in.
   - Green (`s*`): money in, settled, "cash covers it", positive.
   - Blue (`info*`): belongings, a place you have been, "not spending".
   - Amber (`warn*`): a field the scan was not sure of; something to look at.
   - Neutral (`n*`): everything else. `n600` is the default secondary text.
   - The accent is spent only on the primary button, the active tab, link
     labels and the "new thing" chip. **It never means "good"** — a green
     button read as "this is safe", which is why the primary is not green.
   - Charts take `Organic.chartColor(i)` (nine, differing in lightness as well
     as hue); a category keeps its `colorIndex` on every chart.
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
11. **Light and dark.** Every token is `Color.dynamic(light, dark)`; the app
    follows the system. A colour written outside `Tokens.swift` is wrong in one
    of the two, which is the practical reason for rule 1.
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

The system face throughout (it has every kana, kanji and Vietnamese tone mark);
figures use `monospacedDigit` so columns line up. The old display face was
Latin-1 only and has gone.

| Token | Size / weight | Use |
|---|---|---|
| `hero` | 36 bold | The one number a screen is about (Safe to spend, Net worth). |
| `display(n)` | n bold | Big numbers on sheets (an amount being typed, a receipt total). |
| `screenTitle` | 28 bold | Large navigation titles. |
| `title` | 15 semibold | Card titles, section headers, sheet headings. |
| `statValue` | 20 semibold | The figure in a `Tile`, `Metric(large:)`; the figure heading a second card under a hero (Home's cards to pay). |
| `body` | 14 regular | Paragraphs, field text. |
| `row` | 14 medium | List row labels. |
| `rowValue` | 14 semibold | Row figures, **every button label**. |
| `value` / `valueStrong` | 13 regular / semibold | Secondary figures, chip text. |
| `caption` / `captionStrong` | 12 regular / semibold | Help text, sublines, link labels. |
| `meta` / `metaStrong` | 11 regular / semibold | Labels over values, dates, preview lines. |
| `badge` | 10 bold | Uppercase tags. |
| `glyph` | 10 semibold | Chevrons and arrows inside controls. |
| `mono` | 12 monospaced | Receipt text, sheet previews. |

### Colour

Roles: `bg` page, `n100` card, `surface` a block inside a card, `text` ink,
`accent` primary; `accentFill` is the accent under white text (the primary button, Scan), the same in both themes so white on it stays readable. Ramps `n100…n900`, `a100…a900`, `s100…s900` — light to dark
in light mode; in dark mode each resolves to its own value, not an inversion.
`info`/`infoSoft`/`infoInk`, `warn`/`warnSoft`/`warnInk` for the two tinted
strips. Fill with `*100`/`*Soft`, text with `*700`/`*Ink`.

### Radius

`rCard` 16 (cards) · `rInner` 14 (tiles, buttons, blocks) · `rSmall` 10 (fields, strips).
`buttonHeight` for every full-width button.

### Spacing (`Organic.Space`)

`xs` 4 · `s` 6 · `m` 8 (between controls) · `row` 10 (row vertical padding) ·
`l` 12 (between cards) · `card` 16 (card padding) · `gutter` 16 (screen edge).

## 3. Components

### Containers
- `Card { }` — white card with a hairline border (dark: raised grey). `Card(padding: .list)` for a card whose rows carry
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
- `SecondaryButton(title:, icon:, style: .quiet | .warm | .outlined)` (outlined is border only, no fill) —
  quiet in a card (Restore, Edit details); warm for undoing money (Undo this
  sale); outlined when it sits on the page (Move money).
- `DeleteButton(title:)` — destructive, always after a confirm alert.
- `AddButton` / `AddPill` — the + and the confirm inside an inline form.
- `RemoveButton` — round × for a row in a form.
- `ExternalLinkButton(title:, url:)` — a site opened in Safari, an outlined
  pill with the leave-the-app arrow (Buy advice's sold-price searches).
- `HideFiguresButton(hidden:)` — a bare eye after a figure's caption label that swaps the figures for dots (Home's "You have", where tapping the hero figure does the same); remembered on the phone, not in the book.
- `IconMenu(symbol:, label:) { items }` — `IconButton`'s circle opening a menu, for the few things a screen keeps in reach but out of the way.
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
- `DropdownPill(value:) { menu items }` — for lists too long for chips; a small down chevron after the value, as everywhere a menu opens.
- `DropdownRow(label:, value:) { }` — Settings row with a pill on the right.
- `InlineMenu(label:, value:) { }` — "Item  Not linked ⌄" inside a form.
- `SegmentedTabs(…, detail:)` — a figure under each tab's name (Wallet: Accounts ¥311,400 · Cards and plans −¥893,000 · Invested).
- `SegmentedTabs(…, compact: true)` — the small one beside a card's title (Where it went | Categories Shops Places).
- `SegmentedTabs(options:, selection:, label:)` (chosen segment in `Organic.raised`, lighter than its track in light and dark) — two or three views of one
  screen (Transactions / Spending; Budget / Goals / Subscriptions). Exactly
  one always shows, so tabs, not chips.
- `PeriodStepper(title:, back:, forward:)` — `MonthStepper` for any period (a pay period, a year); `forward` nil greys ▶.
- `IconSegments(options:, selection:, symbol:, label:)` — a choice of *how to draw* the same figures (ring · columns · flow): symbols, the chosen one on a quiet square. A choice of data is `SegmentedTabs`.
- `MonthStepper(month:, allowsFuture:)` — ◀ September 2026 ▶, never past this
  month unless `allowsFuture` (Recurring looks ahead). The window for Spending,
  Budget and Recurring.
- `CalendarMonth(month:, marks:, labels:, selected:)` — a month grid, Monday
  first, a coloured dot per thing on a day, a short figure under it, today
  ringed, one day selectable. Recurring's calendar; name the dots with a
  `ChartLegend`.
- `FilterChips(options:, selection:, label:)` — a sideways-scrolling row of
  filters (All · To review · Uncategorised · Belongings · Split). Unlike
  `ChipPicker` the options are the app's own and fixed, so the count never
  turns it into a menu.

### Fields
- `FormField("Placeholder", text:, numeric:, decimal:)` — the capsule field
  for text and for plain counts (due day, months, a percentage).
  `FormField { any view }` to wrap a custom control.
- `MoneyField("Placeholder", value: $int, unit:, prominent:, alignment:, style:)` —
  `style: .hero` is the figure a screen is about, typed in place (a scanned
  total): `hero` size, no capsule, a small pencil beside it so it reads as
  editable. The default `.field` —
  **every amount**. `MoneyField("Paid", value: $double, unit:, fractionDigits:)`
  is the same field for a figure paid in another currency: the keypad gains
  the locale's decimal mark and keeps at most `fractionDigits` after it
  (`Currency.fractionDigits("USD")` is 2; yen and đồng stay whole). Groups digits as they are typed, shows the symbol inside
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
  clears the query as well as closing the dock. Belongings and Transactions have one each.
- `MonthPicker(label:, year:, month:)` — a month and its year, as a menu of
  years each holding its twelve. For a figure printed as a month ("2025/03"):
  a text field would take "2025/13", a `DatePicker` would ask for a day. Wrap
  it in `FormField { }` to sit in a row of capsules.
- `LineRow(label:, value:, tone:, onDark:, total:)` — one line of a breakdown,
  label left, figure right, no box: a stack of them reads as a sum (cash +
  incoming − committed = safe). `tone` colours the figure only. `total` for
  the line the others add up to. Not for a list of things — that is a row
  with a `Hairline`.
- `SuggestionBox { rows }` — what the book already knows, right under a field while it is typed in (names sold before); rows are buttons that fill the field.
- `FieldLabel("Owner")` (12 pt regular, `n600`) above a field or group; `HelpText("…", tone: .quiet | .warning | .positive)` below.

### Wide screens (iPad, foldable inner screen)
- `AdaptiveColumns { leading } trailing: { trailing }` — two columns at regular width, one at compact. Leading is what needs doing now, trailing what comes next and the overview. Split by size class, never by device name.
- `.readableWidth()` — lists, forms and sheets at regular width: at most 680 pt, centred. A screen is either two columns or readable width, never stretched edge to edge.
- iPad (iOS 18+): the five tabs become a sidebar (`.sidebarAdaptable`). Narrow screens (≤ 360 pt, a foldable's outer screen) use the phone layout; long lines wrap, they are never cut.

### Data display
- `Metric(label:, value:, valueColor:, labelColor:, large:, boxed:)` — the
  only label-over-value. `large` in heroes, `boxed` for a row of tiles inside a card. A boxed
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
- `RowButton(first:, padded: false, action:) { ListRow(…) }` — `padded: false` when the label is a `ListRow`, which pads itself.
- `RowButton(first:, action:) { row content }` — tappable list row with its hairline.
- `.copyOnLongPress(name)` — long press to put the user's own text on the
  clipboard, with a tap-back and a "Copied" badge that fades. On the item name
  in the Inventory row and on the item page: that name is what gets pasted into
  a listing, and retyping "SIGMA 200mm f2.8 APO" is how it comes out wrong. It
  is a high-priority gesture, so the row's tap still opens the item and a long
  press does not do both.
- `ShareRing(shares:, total:)` · `ShareColumns(shares:, short:)` · `FlowChart(sources:, targets:)` — one list of `ChartShare`s drawn three ways on Spending; columns carry a short figure (`Store.short`, "85k") and the symbol or initials, never names — the list under the chart has those. `FlowChart` follows income to where it went and is never a balance over time (decision #3).
- `NetWorthLine(points:)` — net worth drawn small at the head of Wallet: a line, a soft fill from the lowest reading, the latest ringed, a month every other month. Points sit on the first of the month so labels stand under them.
- `AsideStrip(lines:)` — figures beside a total and not in it, on the info tint in `infoInk` (Spending's belongings lines).
- `MonthBars(bars:, selected:, short:, onPick:)` — six months side by side, the one on screen in full colour, a tap picks one.
- `ChartLegend(.init("Cash", .line, Organic.s700), …)` — the key to a chart:
  a swatch and a word per mark (`.line` a series, `.dashed` a threshold, `.dot`
  a single reading, `.bar` a bar chart's colour). Any chart that hides its axes
  carries one; without it the chart is a shape nobody can name.

- `Tile(label:, value:, sub:, valueColor:, subColor:)` in a `TileGrid { }` —
  the 2×2 of figures at the top of Home, Spending, Net worth and Belongings.
  Two a row, same height. A figure with no label to compare against is a
  `ListRow`, not a tile.
- `LeadMark(glyph: .dated("TUE", 27))` — a calendar leaf for things that happen on a day (Recurring); "TODAY" on today, grey once gone by.
- `LeadMark(glyph: .symbol("cart") | .initials("SM"), tint:, ink:, size:, round:)` — `round` for a way in to a feature;
  the square at the start of a row. Tint says the kind (category colour,
  `infoSoft` for a belonging).
- `ListRow(title:, sub:, value:, valueSub:, valueColor:, mark:, chevron:, strong:)` — `strong` sets the title semibold (a total line, a way in);
  every list row in the redesign: transactions, accounts, subscriptions,
  people, settings links. `title` is the user's words (`String`) and wraps to a
  second line before it is cut — two lenses differ at the end of their names.
- `Verdict("Every bill before 25 Oct is covered", positive:)` — a mark and a
  sentence in the colour of what it means. Never a pill: a pill looks tappable.
- `ProgressBar(fraction:, tint:)` — budget used, goal saved. Past 1 it is full
  and the caller tints it `a700`.
- `Banner("3 came in from Apple Pay", action: "Review", symbol:, tone: .info | .warn | .positive | .accent, detail:)` (`.accent` is the alert tint, `alertSoft`/`alertInk`: something fails unless you act) — `detail` adds a smaller second line and sets the sentence bold (Home's "Move ¥66,000 from SMBC to MUFG" over its deadline)
  — one tinted strip, the whole strip is the button.
- `ListHeading(title:, trailing:)` — the name over a list card and a figure
  (or a hint) on the right. Replaces `SectionHeader` where there is no inline +.

### Camera (always dark: `Organic.Camera`)
The receipt camera sits over a live picture, so it keeps its own dark
palette whatever the phone is set to. Nothing else uses these.
- `CameraRoundButton(symbol:, label:, on:)` — close and flash over the picture.
- `CameraPill("Read on this iPhone · nothing uploaded", symbol:)` — a fact, not a button.
- `ViewfinderCorners()` — stroke it in `Camera.frame`; the lines read are
  outlined in the same colour, so the eye links "found" to the paper.
- `FoundChip(label:, value:)` — a tick, what it is, what it says, in the tray.
- `LineOutline(corners:)` — the outline round a line read, through its four
  corners, so a slanted receipt is outlined on its slant.
- `ShutterButton(enabled:)` — the one control that keeps the photo.
- `CameraTrayLabel(title:, symbol:)` — "Photos", "Type instead"; a label so a
  `PhotosPicker` can wear it.

### Layout
- `FlowRow(spacing:)` — wrapping chips.

## 4. Screen anatomy

Five tabs, each a screen: **Home** (forward: Safe to spend, what is due,
budget left, the Scan button) · **Transactions** (the ledger, with Spending as
its second segment, and a small scan button by search) · **Wallet** (net worth,
then every account, card, plan, Every month, People and investments) ·
**Belongings** (what is owned, real cost a month, worth, warranties) · **Plan**
(Budget, Goals, Recurring). Scanning is not a tab — a (+) in the middle was
tried and gave up a place for an action — it opens from Home, Transactions,
the Scan widget, Control Center, the Action button and Siri. Settings opens
from Home's gear and is configuration only.

```
NavigationStack
  ScrollView
    VStack(spacing: Organic.Space.l)        // 12 between cards
      [hero card or TileGrid]               // at most one Organic.hero
      [SegmentedTabs / MonthStepper / FilterChips]
      ListHeading + Card(padding: .list) { ListRow… }
      Card { Text(title).font(Organic.title); HelpText; rows… }
    .padding(.horizontal, Organic.Space.gutter)
  .background(Organic.bg)
```

A pushed screen does not open its own `NavigationStack`; it rides the tab's.
Content ends above the tab bar (the scroll view's safe area does it — no
fixed bottom padding).

Inline add form = `Card { Text(title).font(Organic.title); VStack(spacing: .m) {
FormField…; ChipPicker…; Text(preview).font(Organic.meta); HStack { Spacer(); AddPill } } }`.
Two fields side by side only when both fit at the narrowest phone; otherwise
stack them — a field that runs off the card is the bug the canvas caught.

A sheet = `SheetScaffold(title:, leading:) { summary Card; action Card(s); SecondaryButton("Edit …")
→ edit Card ending in PrimaryButton("Save") + DeleteButton }`.

## 5. Adding a component

1. Does an existing one fit with a parameter? Add the parameter.
2. Otherwise add the struct to the matching `DesignSystem/` family file, with a
   doc comment saying where it is used and why it exists.
3. Update section 3 of this file.
4. Replace the inline version everywhere it already appears — a component that
   exists in two places is not a component.
