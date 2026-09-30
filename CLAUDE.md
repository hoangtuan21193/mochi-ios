# Mochi — working rules for Claude

Personal finance for someone in Japan who buys things and sells them on —
cameras, phones, a jacket bought to try — and the household around it: what is
owned, what it will sell for, what the cards and instalment plans still owe,
and whether cash covers the next bill. Nothing on screen names a category of
goods: the book holds items, and the user's own categories say what they are.
SwiftUI, iOS 17+, one target, no packages.

## Layout

```
Mochi/
  App/MochiApp.swift          entry, RootTabView (5 tabs), light-only
  Models/                     Codable domain, one file per family
    Money.swift               Owner, Wallet, PointWallet, CreditCard, SalesChannel
    Item.swift                Item, SaleRecord, Category, AttributeSpec
    Installment.swift         Installment + InstallmentSchedule
    Loan.swift · Recurring.swift (+ CashSnapshot) · Ledger.swift (LedgerEntry, ImportBatch)
    Preferences.swift         Currency, AppLanguage
    AppData.swift             the persisted document + .empty
  Engine/Finance.swift        pure functions over AppData + Date — every figure on screen
  Store/
    Store.swift               @Observable single source of truth; views read figures from here
    Store+Import.swift        sheet parsing, preview, commit, undo
    SampleData.swift          demo book (Settings → Load sample data; `-demo 1` at launch)
  DesignSystem/
    Tokens.swift              Organic: colours, type scale, radii, spacing — the only numbers
    Containers.swift · Buttons.swift · Selection.swift · Fields.swift (MoneyField, keypad)
    DataDisplay.swift · Layout.swift
  Features/                   one folder per screen; a screen file plus its sheets
    Overview/                 OverviewView, OverviewSheets (net worth)
    Inventory/                InventoryView, ItemDetailView, ItemEditorView, CategoryManagerView
    Stats/                    StatsView
    Wallet/                   WalletView, WalletEditors, CardSheet, InstallmentSheet,
                              RecurringSheet, LoanBookView, LoanSheets
    Import/                   ImportView, ImportHistoryView
    Settings/                 SettingsView, ChannelSheet, OwnerSheet, ExportView
  Localizable.xcstrings       String Catalog (en source; vi, ja declared)
MochiTests/FinanceTests.swift Swift Testing, one fixed "today", every formula
Resources/Info.plist          fonts, CFBundleLocalizations
design.md                     the design system: rules + component catalogue
docs/                         process (sdlc.md), product, architecture, finance
                              engine, decisions.md (what was dropped and why),
                              design/ docs per feature, templates/
```

Before proposing a change, read `docs/decisions.md`: several things below
were tried and removed, and it says which. A change sized L in
`docs/sdlc.md` (a new formula, a stored field, a screen, a rule here) gets a
design doc in `docs/design/` from `docs/templates/design-doc.md` first.

Screens split by tense, and a figure lives on exactly one of them.
**Overview is forward**: what is true now, and what happens before the
horizon. **Stats is backward**: selling over a chosen month or year, and the
month-by-month shape of the book drawn from the snapshots. So "profit this
month" is Overview's and "profit in July" is Stats's, and neither repeats the
other. **Inventory** is the browser: `Finance.items(_:status:period:sort:search:)`
is the one place a list is filtered and ordered, and nine orders plus every
month of every year are why its controls are menus rather than chips. The
search field lives behind the toolbar magnifier and docks above the keyboard,
narrows within those filters and says how many matches they hide;
`Finance.matches(_:search:)` anchors on the numbers typed and forgives half the
letters, so "200mmf2.8" finds "200 f2.8".

`Finance.Period` (`.all` / `.year` / `.month`) is the window both retrospective
screens use, so "September" means the same thing on either.

Shape: Models (plain structs) → Finance (pure) → Store (`@Observable`, the
one instance) → Views. No view models: a view reads `store.x` and calls
`store.doY()`. A new screen is a folder under `Features/`; its sheets sit
next to it, not in a shared sheets file.

The Xcode project uses synchronized folders: a new `.swift` anywhere under
`Mochi/` (or `MochiTests/`) is in its target automatically. No pbxproj edits
for files; moving one is a `git mv`.

## Non-negotiables

1. **Read `design.md` before touching any view.** No `.font(.system(size:))`,
   no `Color(hex:)`, no hand-drawn capsule/tag/divider/label-over-value in a
   view file. Use the tokens and components. A missing variant goes into the
   matching `DesignSystem/*.swift` family with a name and a doc comment, then
   into `design.md`.
2. **Numbers are derived in `Finance`, exposed by `Store`, never computed in
   a view.** A view reads `store.safeToSpend.total`, it does not subtract.
   `Finance` takes `AppData` and a `Date` and nothing else, so every figure
   has a test with a fixed "today". A new formula goes in Finance with a test
   before it gets a Store property.
3. **Persistence must stay backward compatible.** A new stored field is
   either Optional (`[T]? = nil`) or read in a hand-written `init(from:)`
   with `decodeIfPresent ?? default` — `AppData` and `Installment` have one.
   **A `var x: Int = 0` does not decode a book that lacks the key**: the
   synthesised decoder throws, and the whole book opens empty (this happened).
   Never rename a stored key. `Currency` stores its symbol, `AppLanguage` its
   code, for this reason. `CompatibilityTests.version1BookDecodes` holds a
   version-1 file; a new field goes into that fixture's expectations too.
4. **Every money movement writes a `LedgerEntry`** through `Store.log`.
   Buying and selling are logged too, as records (kind `"x"`), because they
   move nothing. **No screen shows the ledger at the moment** — the Activity
   list was removed as clutter — so the entries are written and kept and read
   by nobody. Keep writing them: they are the only record of *why* a typed
   balance changed, and they cannot be reconstructed later. Anything that
   surfaces them again reads `data.ledger` newest-first.
5. **Undo has to give back exactly what the action took.** Import batches
   record created channels and wallets; deleting a card unlinks its items;
   deleting an item keeps its instalment plan but drops the link.
6. **Name fields disable autocorrect.** `FormField(_:text:)` does it; a raw
   `TextField` for a proper noun is a bug. **Amounts go through `MoneyField`**,
   bound to an `Int`; a view never does `Int(text.filter(\.isNumber))`.
7. **Say what will happen before the button.** Inline forms end in a preview
   line (`Organic.meta`). Destructive actions go through `.alert` first.
8. **Controls only where there is a choice.** Never a menu with one option or
   a picker with one chip; state the outcome as text instead.
9. **English UI strings, sentence case, full words.** Vietnamese/Japanese come
   from the String Catalog, not from code. Copy explains *why* in one line
   ("Type what the statement says. Buying an item on this card never changes it").
10. **Comments explain why, not what.** Keep the existing rationale comments;
    a helper's removal takes its "what" comment with it.

## Domain facts that shape the code

- A `Wallet` is real cash (bank, marketplace balance, notes). A `PointWallet`
  is never cash. `Store.cash` sums wallets only.
- **Items never move money.** Adding, editing, selling or importing an item
  touches no wallet, point wallet or card debt; those are typed in by hand
  from the bank and the statement, because the book has many outgoings that
  are not resale stock. `Store.purchases(on:in:)` lists what a card was charged in
  a month so the typed debt can be checked against the statement.
- **Four numbers, never one.** `Finance.cashNow` (wallets); `safeToSpend`
  (cash + confirmed incoming before the horizon − cards, plans and cash-paid
  bills due before it − `safetyBuffer`) is the Overview headline;
  `monthlyCashFlow` (income + realised resale profit − bills − living
  estimate − instalment fees; plus actual Δcash / Δnet worth from monthly
  `CashSnapshot`s) says richer or poorer and is on no screen at present —
  see the Overview note below; `netWorth` (cash + stock at resale +
  yen receivables − card statements − unbilled card charges − instalment
  principal − yen loans owed) is long-term and sits in a small tile. Đồng
  loans stay out of all four. `Store.realCash` and `saleContribution` are gone.
- **Overview answers one question in words and no question with a chart.**
  "Can I pay?" is `paymentsDue` — the forecast as one row a day with the
  running balance — and `shortfall` names how much more has to be found and by
  when (worst day's amount, first day's date). The card leads with that
  verdict, then the rows.
  "Richer or poorer?" was a card here and is not any more. Until a second
  `CashSnapshot` exists the only figure it can show is `planned` — income less
  bills less a living estimate read off the cards — and a projection printed as
  this month's result is read as fact. The real month-on-month move is Stats's,
  drawn from the snapshots where one reading is visibly one point.
  `monthlyCashFlow` and its tests stay for whatever shows it next; `CashFlowSheet`
  and `Store.thisMonth` are gone.
  **Buying and selling on Overview is two figures**: `liquidation`
  (sell-all proceeds) and `realizedThisMonth`. Cost basis, expected margin,
  points and stock still on a card were beside them; they are workings, and
  each already sits where it can be read against something — above the
  Inventory list, or per month on Stats.
  A cash-balance *chart* was tried twice and removed twice: it answers "will I
  run short" only if the reader does the subtraction, and it looks like a
  wealth line while moving for reasons that are not wealth — paying a card
  drops it and leaves net worth untouched, selling at a loss lifts it and
  leaves you poorer. `projectedCashBalance` stays because `paymentsDue` and
  the Stats history are built from the same walk; do not put it back on
  screen. The "sell these to stay above the reserve" card is gone too.
- **A `Recurring` is a commitment, not a debt.** Salary, rent, subscriptions:
  amount, day, `paidBy` (a wallet or a **card** name). A card-paid bill is
  never a cash event on its own day — it is part of that card's next
  statement; cash leaves on the card's due day. Next year's rent is not in
  net worth.
- **A card has a cycle, and without a closing day it has no split.**
  `Finance.cycle(for:)` with a known `closingDay` splits charges into the typed
  statement (paid `statementDue`) and unbilled (paid `unbilledDue`, one due day
  later, never the same day), and a statement whose due day passed counts as
  paid. **With `closingDay == nil` the statement closes *today*:** `debt` is
  taken as everything the card is owed now, so both unbilled windows are empty
  and only `comingBills` project forward. That is not a nicety — the old
  "calendar month stands in" version counted a card-paid bill twice, once
  inside the typed figure and once as an unbilled charge, and it reached net
  worth and Safe to spend. Both halves have a test. The new-card form asks for
  the closing day, and a card without one says on its own sheet what it is
  giving up. `livingEstimate` =
  statement − resale stock in it − card-paid bills in it, and is what "everything
  else" costs; the projected next statement reuses it. Nothing is typed for it.
- **Points are reported, never added.** `Item.pointsEarned` is what a purchase
  paid back (PayPay, Rakuten, MapCamera). `Finance.pointsEarned(_:in:)` counts
  them on the day the item was *bought*; `pointsOnStock` for unsold stock.
  They appear beside the cash figures in the item, Inventory and Stats —
  a ¥785,266 lens paying ¥94,328 of points can lose ¥45,266 of cash and still
  be a good trade — and never in cash, profit or net worth. The point wallet
  is still typed by hand.
- `CreditCard.debt` is what the last statement said, typed in. Something bought
  on a card is stock (asset, at resale) and an unbilled charge (liability) at
  once, so net worth moves only by its expected margin; `liquidation` stays
  the gross marketplace payout (Inventory's "sell-all proceeds").
  `Installment` is a shopping-credit plan, usually 0%, typed in as the lender's
  confirmation prints it — 分割支払回数, 初回お支払金額, 2回目以降お支払金額,
  お支払期間 and 毎月のお支払日. `InstallmentSchedule` (Models) turns those five
  lines into the stored plan (principal = first + monthly × (n − 1)) and reads
  a plan back for an edit form, so the three plan forms cannot disagree.
  Months paid are counted from dates, not ticked. `feeTotal` (分割手数料) is
  the part of `principal` that is interest: only its per-payment slice is a
  cost in the cash flow; the rest is debt going down. `installmentDebt` is
  what will still leave the bank; `installmentPrincipal` (net worth) leaves
  the unaccrued fee out. Each debit is a dated event in the forecast — the
  total is never treated as due at once.
- **Backups are local.** There is no iCloud container (no entitlements); the
  old toggle never wrote anything. `Store.save` first copies the file on disk
  to `backups/mochi-YYYY-MM-DD.json` if today has none, keeps 30, and skips
  the write when nothing changed. Settings offers Export (share sheet),
  Import (file picker) and "Earlier copies" → `replaceBook(with:)`, which
  copies the current book into today's backup before replacing it. `load`
  failure copies the unreadable file to `mochi.unreadable.json` before any
  save can touch it. `autoBackup` / `lastBackup` are dead fields kept for decoding.
- `AppData.snapshots`: one `CashSnapshot` a month, taken on launch
  (`Store.takeMonthlySnapshotIfDue`), 36 kept. They are the *only* history of
  cash and net worth — the balances are typed, so a month the app never opened
  in can never be reconstructed — and `Finance.history` turns them into what
  Stats draws. A month with no snapshot reports its sales and no balance.
  `schemaVersion` marks the shape; books without it are 1. Every field added
  for the engine has a default, so a version-1 book decodes untouched.
- **Import reads a sheet by its header names, and skips what it does not
  know.** `Store.columnAliases` maps a header to a field; `Store.columnsIgnored`
  names the columns that look readable and must not be read — someone else's
  card (Thẻ vợ), a point *rate* beside the points themselves (% Point), what a
  thing cost new, the length of a loan. Both are folded (case, accents,
  full-width), the ignored ones are listed on screen as written, and an
  unrecognised column is passed over rather than shifting the others along. A
  row repeated inside one sheet, or matching something already in the book, is
  flagged and left off — **"Skip them" is where the chips start**; "Import
  anyway" brings the lot in, because two of the same thing bought twice is
  real. **A purchase is identified by three columns and no others: Item, 購入日
  and Buy on Market** (`Store.purchaseKey`) — not by Sell on, so the same row
  re-exported with a different channel is the same purchase, and not by price,
  since a re-typed figure does not make a second thing. The card is not a
  stand-in for a missing shop either. Only `.exact` and `.repeatedInFile` are
  duplicates (`DuplicateKind.isDuplicate`); a name match or a name-and-date
  match with another market is a badge on the row and comes in.
  **A sheet with no date column at all** (the original Google Sheet has none:
  Sold? · Item · Thẻ vợ · Buy · Buy on Market · % Point · Earn Point · New
  price · Sell Price · Sell on · Shipping Fee · Income · Profit) dates every
  row today, so that date is the app's, not the book's: two lines agreeing on
  name and market are then flagged "Same name" and **both come in**, because
  two of a thing and one line typed twice read alike. `ImportOldSheetTests`
  holds this format too — a battery sold and a battery held, two Z8s at
  different prices, two identical chairs, all landing.
  **What the sheet says beats what the app infers**: a blank Sell on means
  "Keeping" only when the status column is silent; with `Sold?` reading FALSE
  the row is stock with nowhere named yet.
  `commitImport` de-duplicates against the book **as it stood when the button
  was pressed** and never against rows written by the same paste — collapsing
  two sheet lines into one made a 5-row import write 3.
  **A duplicate row whose Sold column says TRUE overwrites instead of being
  skipped**: the sheet is ahead of the book, so `ImportRow.updates` carries the
  id of the item it lands on, `Store.merge(_:over:)` lays the row over it
  (keeping the id, and keeping condition, accessories and attributes, which no
  sheet column carries), and the batch keeps the item *as it was* in
  `ImportBatch.updatedItems` so undo puts it back. Added and overwritten are
  counted apart everywhere they are shown: `batch.count` is what was added.
  Rows are written in the sheet's order (`insert(contentsOf:at: 0)`), not one
  at a time at the front, which used to leave the book holding the sheet
  backwards. **The bar above the list has two lines, because there are two
  kinds of match**: Skip them / Import anyway for repeats, Mark them sold /
  Leave mine as they are for the sold rows. One pair could only tell the truth
  about one of them — "Skip them" sitting alone read as "nothing here changes
  the book" while the sold rows changed it anyway. `ImportOldSheetTests` holds a sheet in the
  original Google-Sheets format and every one of these rules.
- A `SalesChannel` has a fee % (cash) or bonus % (points). Its `destination`
  field is dead: kept only so old books decode, never read or shown.
- A fresh install (`AppData.empty`) is completely empty. Settings explains
  channels and offers the +.
- Language: `setLanguage` writes `AppleLanguages` and `AppleLocale`; effective
  next launch. `syncLanguageOverride` keeps the defaults in step with the book.

## Build & verify

```bash
xcodebuild -project Mochi.xcodeproj -scheme Mochi -destination 'generic/platform=iOS Simulator' -configuration Debug build 2>&1 | grep -E "error:|warning: .*Mochi/|BUILD"
xcodebuild -project Mochi.xcodeproj -scheme Mochi -destination "platform=iOS Simulator,id=<udid>" test 2>&1 | grep -E "error:|✘|Test run with"
```

A change to `Finance.swift` is not done until `FinanceTests` passes and, if a
rule changed, a test says so.

Warnings in `Mochi/` count as failures. After a UI change, run it on a
simulator with the demo book and look at the screen you changed:

```bash
xcrun simctl launch <udid> com.hoangtuan.mochi -demo 1 -tab 3   # tabs 0…4
```

`-demo 1` reloads the sample book (destroys the simulator's current data).
A fresh-install check is `xcrun simctl uninstall` then install.

The simulator keyboard may be Vietnamese Telex; type test data via
`xcrun simctl pbcopy <udid>` and the Paste button instead of `text`.

## Workflow

- Small, verified steps: edit → build → screenshot → next. Do not batch five
  screens and build once.
- Do not commit or push unless asked. Commit messages describe the user-visible
  change, not the files.
- When the user describes a problem, answer with the assessment first; fix on
  request. When they ask for a change, make the whole change, then report what
  was done, what was tested, and what was not.
