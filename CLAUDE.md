# Mochi — working rules for Claude

Personal finance for a camera reseller in Japan: what is owned, what it will
sell for, what the cards and instalment plans still owe, and whether cash
covers the next bill. SwiftUI, iOS 17+, one target, no packages.

## Layout

```
Mochi/
  MochiApp.swift          entry, RootTabView (5 tabs), light-only
  Models.swift            Codable domain + AppData document + Currency/AppLanguage
  Store.swift             @Observable single source of truth; all derived numbers live here
  Import.swift            Store extension: sheet parsing, preview, commit, undo
  SampleData.swift        demo book (Settings → Load sample data; `-demo 1` at launch)
  DesignSystem/
    Tokens.swift          Organic: colours, type scale, radii, spacing — the only numbers
    Components.swift      Card, buttons, fields, chips, Metric, Badge, Hairline…
  *View.swift             one file per screen or sheet family
  Localizable.xcstrings   String Catalog (en source; vi, ja declared)
Resources/Info.plist      fonts, CFBundleLocalizations
design.md                 the design system: rules + component catalogue
```

The Xcode project uses a synchronized folder: a new `.swift` under `Mochi/`
is in the target automatically. No pbxproj edits for files.

## Non-negotiables

1. **Read `design.md` before touching any view.** No `.font(.system(size:))`,
   no `Color(hex:)`, no hand-drawn capsule/tag/divider/label-over-value in a
   view file. Use the tokens and components. A missing variant goes into
   `Components.swift` with a name and a doc comment, then into `design.md`.
2. **Numbers are derived in `Store`, never in a view.** A view reads
   `store.realCash`, it does not subtract. If two screens could disagree, the
   figure belongs in Store.
3. **Persistence must stay backward compatible.** New `AppData` fields are
   optional (`[T]? = nil`) or have defaults, so a book saved by an older build
   still decodes. Never rename a stored key. `Currency` stores its symbol,
   `AppLanguage` its code, for this reason.
4. **Every money movement writes a `LedgerEntry`** through `Store.log`. The
   Activity list is the only place a balance change is explained.
5. **Undo has to give back exactly what the action took.** Import batches
   record created channels and wallets; deleting a card unlinks its items;
   deleting an item keeps its instalment plan but drops the link.
6. **Name fields disable autocorrect.** `FormField(_:text:)` does it; a raw
   `TextField` for a proper noun is a bug.
7. **Say what will happen before the button.** Inline forms end in a preview
   line (`Organic.meta`). Destructive actions go through `.alert` first.
8. **Controls only where there is a choice.** Never a menu with one option or
   a picker with one chip; state the outcome as text instead.
9. **English UI strings, sentence case, full words.** Vietnamese/Japanese come
   from the String Catalog, not from code. Copy explains *why* in one line
   ("Without a destination, proceeds fall into your first wallet").
10. **Comments explain why, not what.** Keep the existing rationale comments;
    a helper's removal takes its "what" comment with it.

## Domain facts that shape the code

- A `Wallet` is real cash (bank, marketplace balance, notes). A `PointWallet`
  is never cash. `Store.cash` sums wallets only.
- `CreditCard.debt` is what the next statement takes; `Store.debt` sums them.
  `Installment` is a fixed 0% shopping-credit plan; months paid are counted
  from dates, not ticked. `Store.installmentDebt` is total remaining;
  `installmentMonthly` is next month's debits. Both are subtracted in
  `realCash`; only card debt drives the due-date drawdown.
- A `SalesChannel` has a fee % (cash) or bonus % (points) and a `destination`
  wallet. `Store.sell` credits `destination`; an empty destination falls to
  the first wallet — so channels are created with a wallet (`makeDestination`).
- A fresh install (`AppData.empty`) is completely empty. Settings explains
  channels and offers the +.
- Language: `setLanguage` writes `AppleLanguages` and `AppleLocale`; effective
  next launch. `syncLanguageOverride` keeps the defaults in step with the book.

## Build & verify

```bash
xcodebuild -project Mochi.xcodeproj -scheme Mochi -destination 'generic/platform=iOS Simulator' -configuration Debug build 2>&1 | grep -E "error:|warning: .*Mochi/|BUILD"
```

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
