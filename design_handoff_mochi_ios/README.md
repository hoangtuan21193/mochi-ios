# Handoff: Mochi — iOS (SwiftUI)

## Overview

Mochi is a personal asset tracker for someone who buys used gear on Japanese
credit cards and resells it across marketplaces. It answers four questions:

1. How much money do I really have right now? (wallet cash minus card debt)
2. What is due on which card, and will my cash cover it?
3. What do I own, what is it worth, and what would I clear if I sold it?
4. What did I actually make, month by month?

The distinguishing logic is that **inventory is not cash**, **points are not
cash**, and items you intend to keep are excluded from every resale projection.

## About the design files

`App Quan Ly Tai Chinh.dc.html` in this bundle is a **design reference built in
HTML** — an interactive prototype of the intended look and behaviour, not
production code. The task is to recreate it as a native SwiftUI app.

`SwiftUI/` contains a first-pass implementation written from that prototype:
tokens, models, the derivation layer, and one file per screen. It has **never
been compiled** — treat it as a detailed, opinionated starting point. Expect to
fix small type and API issues on first build (iOS 17+ / Swift 5.9+ assumed for
`@Observable`; iOS 18 for `URL: @retroactive Identifiable`).

## Fidelity

**High fidelity.** Colors, type sizes, radii, and spacing below are the exact
values used in the prototype. Match them.

## Project setup

- iOS 17.0 minimum (uses `@Observable`, `Layout`).
- Add the **Caprasimo** display font (Google Fonts, OFL) to the target and list
  it in Info.plist under `UIAppFonts`. It is used only for large numbers and
  screen titles; body copy is the system font.
- iCloud capability: **iCloud Documents** (key-value not required). Without it
  the app still works — backup silently no-ops and Restore reports "no backup".
- No third-party packages. Icons are SF Symbols, chosen to stand in for the
  Lucide icons in the prototype (stroke-heavy, rounded).

## Screens

### 1. Overview (tab 1)
Purpose: the money answer, top to bottom.

- **Hero card** — `Organic.n900` fill, radius 22, padding 18.
  - Kicker "REAL CASH", 10.5pt bold, letter-spacing 1, white at 65%.
  - Value: Caprasimo 34pt. Sage (`s300`) when ≥ 0, terracotta (`a300`) when negative.
  - Four stats in two rows of two, each label-over-value: label 10pt bold
    uppercase white/60%, value 16pt heavy. Row 1: Cash & wallets, Card debt.
    Divider (white 22%). Row 2: "If you sold it all" (sage, prefixed "≈ +"),
    "Cash after that".
- **Card bills next cycle** — cream card, tappable, chevron rotates 180° when open.
  Right column: total debt in Caprasimo 19pt `a800`, and under it
  "Next: {day} · {amount}".
  Expanded, for each due date in payment order:
  - 40pt circle with the day, filled `accent` for the nearest date, else `n200`.
  - Amount 14.5pt heavy; sub-line "{n} cards" plus "· mine X · on behalf Y" when
    another owner's cards are in that date.
  - Each card indented 51pt, name left, amount right.
  - A conclusion bar (radius 12, `s100` / `a100`): "Cash left after this date"
    or "Not enough — short by".
- **Sell these to cover the cards** — `s100` card, highest-net items first until
  the shortfall is covered. **Hidden entirely when cash already covers debt.**

### 2. Inventory (tab 2)
Purpose: what you own.

- Header: three 29pt circular icon buttons — categories (tag), export
  (arrow.up), add (plus, `accent` filled).
- Three summary tiles, radius 14: Spent (for sale) `n100`; Sell-all proceeds
  `s100`; Expected profit `s100` (value turns `a800` when negative).
- Note line: "Items marked Keeping are excluded from these numbers: N."
- Filter chips: For sale · Keeping · Sold.
- Rows: name 14pt heavy, category tag (9.5pt bold pill `n200`), "card · channel"
  11pt `n600`; right side estimate 14.5pt heavy and profit 11pt heavy, sage when
  positive and terracotta when negative.

### 3. Stats (tab 3)
Sold count, revenue, profit for the selected year, then the sold-item history
with per-item profit.

### 4. Wallet (tab 4)
Purpose: money and obligations only — no goods.

Order: Net worth card → **Cash & wallets** (flat list, "Total" row) → Move money
button → Point wallets (`a100`, labelled NOT CASH) → **Credit card debt** (flat
list; per card: name, owner tag, debt, 5pt limit bar — `a600` above 80% usage
else `s500` — and a small "Due on the N / Limit left ¥X" line) → **Owners** →
Personal loan book summary row (opens its own screen).

The three add-able sections share one pattern: section header, round `accent`
"+" button that rotates 45° when open, inline form card underneath. No inline
"Add" buttons anywhere else.

**Move money** sheet: from chips, to chips, amount + 手数料 field side by side,
fee quick-chips (No fee · ¥210 · ¥250, default 210), preview line
"Arrives: ¥X · 手数料 ¥210". The source loses the full amount; the destination
receives amount − fee. Rationale: withdrawing from Mercari or Rakuma to a bank
costs ¥210 a time.

### 5. Settings (tab 5)
Only real configuration: iCloud backup (toggle + last-backup line + Back up now
/ Restore), currency, sales channels. Categories are managed in Inventory;
wallets, cards and owners in Wallet — each thing is managed where its effect is
visible.

### Sheets
- **Item editor** — name, category chips, buy/estimate, owner, card ("adds to
  that card's debt"), planned channel, accessories, condition, attribute block.
- **Category manager / editor** — a category is a name plus an attribute
  checklist. Attribute kinds: Yes/No, Options (typed as `a | b | c`), Free text.
  A category with zero attributes is legal; that is how "Other" behaves.
- **Item detail** — tags, three metrics, Keep/For-sale toggle, sell planner,
  attributes, notes.
- **Export** — TSV/CSV × All/For sale/Sold, monospace preview, Copy everything,
  Share file, Save file. Filename `inventory-YYYY-MM-DD.tsv`.
- **Loan book** — full loan list with history.

## Business rules (get these exactly right)

- `cash` = sum of all wallet balances. Every wallet counts; there is no
  business/family split any more.
- `debt` = sum of card debts. `realCash = cash − debt`.
- `netProceeds(item, channel)`:
  - cash channel → `estimate × (1 − fee%)`
  - point channel → `estimate × (1 + bonus%)`, credited as points, never cash
- `liquidation` = Σ netProceeds over **unsold, non-keep** items only.
- `cashAfterSellingAll = realCash + liquidation`.
- `expectedProfit = liquidation − Σ buyPrice` over the same set.
- Due-date ordering: a day before the 15th belongs to next month, so sort by
  `day < 15 ? day + 31 : day`.
- Drawdown: start from `cash`, subtract each due date's total in order; the
  running value is what is left after that date.
- Sell suggestions: while `debt − cash > 0`, take the highest-net item and
  subtract. Empty list ⇒ hide the card.
- Buying an item raises its card's debt by the purchase price.
- Confirming a sale credits the channel's destination wallet, or the matching
  point wallet for a point channel.
- Profit-backward planner: `price = (targetProfit + buyPrice) / (1 ∓ rate)`
  (minus for cash channels, plus for point channels).

## State

One `@Observable Store` holding an `AppData` value, injected with
`.environment(store)`. Every derived number is a computed property on the store
so no screen can disagree with another. Persistence: `AppData` JSON-encoded to
Application Support, mirrored into the iCloud Documents container when auto
backup is on.

## Design tokens

Ground `#f5ead8` · surface `#ebddc5` · text `#201e1d` · accent `#c67139` ·
second accent `#7a8a5e`.

Neutral 100–900: `f9f4ed eee7db dcd3c4 c0b6a5 a19786 82796a 645c50 474238 2e2b25`
Accent 100–900: `fff2eb ffe1d0 ffc6a5 f6a06b d67f48 b2622d 8c491a 643312 402310`
Sage 100–900: `f0fae1 e1eecc ccdbb2 aebf92 8fa073 728157 56633f 3d472b 272e1b`

Radii: 22 hero, 20 cards, 18 inner blocks, 14 tiles, 12 small, capsule for every
button, input and chip. Type: Caprasimo for display numbers and titles; system
font elsewhere — 14 heavy section titles, 13.5 body rows, 12.5 secondary,
11–11.5 captions, 10–10.5 kickers. Shadow: soft, black 6%, radius 8, y 3.

Interaction: pressed states step one down the accent ramp (`a600`); selection is
`n900` fill with `bg` text; sage is the second voice for anything positive, and
terracotta for debt, shortfalls and negatives.

## What is not built yet

- Batch CSV import (the prototype has a JSON paste box).
- Card due-date notifications.
- ROI / annualised return.
- Localisation: the prototype ships EN + VI strings. The Swift files are
  English-only; move copy into a String Catalog and re-add Vietnamese.

## Files

- `App Quan Ly Tai Chinh.dc.html` — the HTML prototype (open in a browser).
- `SwiftUI/Theme.swift` — tokens and shared chrome (Chip, Card, SectionHeader, PrimaryButton).
- `SwiftUI/Models.swift` — domain types and the persisted `AppData`.
- `SwiftUI/Store.swift` — derivations, mutations, export, persistence, iCloud.
- `SwiftUI/SampleData.swift` — the prototype's seed data.
- `SwiftUI/MochiApp.swift` — entry point and tab bar.
- `SwiftUI/OverviewView.swift`, `InventoryView.swift`, `ItemDetailView.swift`,
  `ItemEditorView.swift`, `CategoryManagerView.swift`, `ExportView.swift`,
  `WalletView.swift`, `LoanBookView.swift`, `SettingsView.swift` (also holds StatsView).

## App Store metadata

- Name: `Mochi — Asset Tracker` (21 chars)
- Subtitle: `Cash, cards, resale inventory` (29)
- Keywords: `reseller,flip,mercari,inventory,networth,debt,payoff,ledger,portfolio,cashflow,jpy`
- Check the name is free in App Store Connect and clear of registered marks
  before committing to it.
