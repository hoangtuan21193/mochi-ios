import SwiftUI

/// The + button. Scan opens the receipt camera, which reads while the
/// receipt is held up; the photo is read once more on the phone and lands in
/// a review with every field filled. Type opens the form; a place card on
/// Home opens the quick add for where the user is.
struct CaptureSheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let start: Router.Capture
    /// What the screens after the camera go back to. `preferredColorScheme(nil)`
    /// does not undo an earlier `.dark` inside a full-screen cover, so the
    /// phone's own setting is handed in.
    var systemScheme: ColorScheme? = nil

    @State private var stage: Stage = .scan
    @State private var nearby = NearbyPlace()
    /// Owned here, not by the camera screen: a photo still on its way when
    /// the screen goes has to land somewhere.
    @State private var camera = ScanCamera()
    @State private var reading = false
    /// The shutter's photo is on its way to disk. Nothing is read from it:
    /// saving only waits so the spend is not kept without its receipt.
    @State private var photoPending = false
    /// Which shot a reading belongs to. A retake starts a new one, and a
    /// reading of the old shot that arrives late is thrown away.
    @State private var shot = UUID()
    /// The part of a long receipt already read, while the rest is scanned:
    /// the next shot is joined to it rather than starting over.
    @State private var earlier: Store.CaptureGuess?

    enum Stage { case scan, review(Store.CaptureGuess), type, quick(Finance.Place) }

    var body: some View {
        Group {
            switch stage {
            case .scan:
                ScanView(camera: camera, continuing: earlier != nil, shutter: shoot,
                         picked: { review(photo: $0, live: ReceiptDraft()) },
                         typeInstead: { earlier = nil; stage = .type },
                         close: { if let e = earlier { earlier = nil; stage = .review(e) } else { dismiss() } })
            case .review(let g):
                // A new shot id on the way out, so a photo still being read
                // is thrown away with its file instead of landing later.
                CaptureReview(guess: g, reading: reading, photoPending: photoPending, done: { dismiss() }, again: { shot = UUID(); earlier = nil; stage = .scan },
                              cancel: { shot = UUID(); dismiss() },
                              scanRest: { earlier = g; stage = .scan })
            case .type: TransactionEditor(prefill: prefillHere())
            case .quick(let p): QuickAddView(place: p, latitude: nearby.location?.coordinate.latitude,
                                             longitude: nearby.location?.coordinate.longitude)
            }
        }
        // The camera is dark (status bar, Photos picker); what follows it
        // goes back to the phone's own setting.
        .preferredColorScheme(isScanning ? .dark : systemScheme)
        .onAppear {
            nearby.look(in: store)
            ReceiptReader.languages = store.receiptLanguages
            switch start {
            case .scan: stage = .scan
            case .type: stage = .type
            case .here(let p): stage = .quick(p)
            }
        }
        .onDisappear { camera.stop() }
    }

    private var isScanning: Bool { if case .scan = stage { return true } else { return false } }

    /// The shutter leaves the camera at once, for a review filled from what
    /// was read while aiming — and that reading is the answer. The photo is
    /// kept as the receipt, never read again: a second pass cost a second
    /// wait and could come back with a different total from the one the
    /// tray had just shown, which read as the app changing its mind.
    private func shoot() {
        let live = camera.draft
        let before = earlier
        let this = UUID()
        shot = this
        earlier = nil
        photoPending = true
        let draft = before.map { $0.draft.joined(with: live) } ?? live
        stage = .review(before.map { guess(draft, file: $0.transaction.receiptFile) } ?? guess(draft, file: nil))
        camera.takePhoto { image in
            guard shot == this else { return }
            guard let image else { photoPending = false; return }
            var photo = image
            if let before, let old = before.transaction.receiptFile, let first = store.receiptImage(old) {
                photo = before.draft.goesAbove(live) ? ReceiptReader.stacked(first, image) : ReceiptReader.stacked(image, first)
                store.deleteReceipt(old)
            }
            let file = store.saveReceipt(photo)
            // Only the file is new; fields the user already changed stay theirs.
            if case .review = stage { stage = .review(guess(draft, file: file)) }
            photoPending = false
        }
    }

    /// A photo from the library: straight to the review, filled as it is read.
    /// Here the photo is the only reading there is, so it is read in full.
    private func review(photo image: UIImage, live: ReceiptDraft) {
        let before = earlier
        let this = UUID()
        shot = this
        earlier = nil
        reading = true
        stage = .review(before.map { guess($0.draft, file: $0.transaction.receiptFile) } ?? guess(live, file: nil))
        refine(image, live: live, joining: before, shot: this)
    }

    /// A picked photo is read in full. The review takes the reading into the
    /// fields not touched yet. The on-device model, slower, comes last and
    /// may only add the lines and a category.
    /// `joining`: the part of the same receipt read before. The two
    /// readings are joined and the two photos stacked the way the paper
    /// runs, into one receipt photo.
    private func refine(_ image: UIImage, live: ReceiptDraft, joining before: Store.CaptureGuess? = nil, shot this: UUID) {
        Task {
            // Read carefully: the receipt straightened and read again, the
            // better reading kept with the picture it came from.
            let careful = await ReceiptReader.read(image)
            let lines = careful.lines
            let part = ReceiptParser.parse(lines).filled(from: live)
            guard shot == this else { return }
            var draft = before.map { $0.draft.joined(with: part) } ?? part
            let image = careful.image
            var photo = image
            if let before, let old = before.transaction.receiptFile, let first = store.receiptImage(old) {
                photo = before.draft.goesAbove(part) ? ReceiptReader.stacked(first, image) : ReceiptReader.stacked(image, first)
                store.deleteReceipt(old)
            }
            let file = store.saveReceipt(photo)
            stage = .review(guess(draft, file: file))
            reading = false

            guard ReceiptReader.modelAvailable,
                  let smart = await ReceiptReader.understand(lines, categories: store.spendingCategories.map(\.name)),
                  shot == this, case .review = stage else { return }
            if draft.lines.isEmpty { draft.lines = smart.items }
            var g = guess(draft, file: file)
            if g.transaction.category.isEmpty, let cat = smart.category {
                g.transaction.category = cat
                g.categoryReason = String(localized: "Suggested on this iPhone")
            }
            stage = .review(g)
        }
    }

    private func guess(_ draft: ReceiptDraft, file: String?) -> Store.CaptureGuess {
        store.guess(from: draft, receiptFile: file,
                    latitude: nearby.location?.coordinate.latitude, longitude: nearby.location?.coordinate.longitude)
    }

    private func prefillHere() -> Transaction? {
        guard let loc = nearby.location else { return nil }
        var t = Transaction(date: .now, amount: 0, kind: .spend, account: store.data.wallets.first?.name ?? "")
        t.latitude = loc.coordinate.latitude
        t.longitude = loc.coordinate.longitude
        return t
    }
}

/// Check and save: the amount, every field filled with where it came from,
/// and — when one line is costly — the offer to keep it as a
/// belonging instead of spending.
struct CaptureReview: View {
    @Environment(Store.self) private var store
    let guess: Store.CaptureGuess
    /// A picked photo is still being read: fields may fill in, and saving
    /// waits, so the transaction does not go without its receipt.
    let reading: Bool
    /// The shutter's photo is still being kept: saving waits, nothing changes.
    var photoPending = false
    let done: () -> Void
    /// Back to the camera: after a retake, or to scan the next receipt.
    let again: () -> Void
    /// Leave without saving: the photo is deleted, nothing is written.
    let cancel: () -> Void
    /// Back to the camera for the rest of a receipt too long for one photo.
    let scanRest: () -> Void
    @State private var t = Transaction(date: .now, amount: 0, kind: .spend, account: "")
    @State private var amount = 0
    @State private var keepPhoto = true
    @State private var asBelonging = false
    @State private var belongingName = ""
    @State private var worth = 0
    @State private var points = 0
    /// The reading the fields were last filled from, to tell a field the
    /// user changed (kept) from one still as read (updated).
    @State private var applied: Store.CaptureGuess?
    @State private var placeSource: Finance.PlaceNameSource?
    @State private var lookingUpPlace = false
    /// Where the shop's name came from when Apple Maps gave it; nil while the
    /// receipt's (or the book's) own reading stands.
    @State private var shopFromMaps: String?
    @State private var lookingUpShop = false
    /// A receipt in another currency: what it says, and the rate to the book's.
    @State private var foreignAmount = 0
    @State private var rateText = ""
    @State private var editingShop = false
    @State private var editingDate = false
    /// The receipt photo shown full screen, to check the figures against.
    @State private var viewing: UIImage?

    var body: some View {
        SheetScaffold(title: "Check and save", leading: ("Cancel", { discard(); cancel() }),
                      trailing: ("Retake", { discard(); again() })) {
            Card {
                HStack(alignment: .top, spacing: Organic.Space.l) {
                    if let file = guess.transaction.receiptFile, let img = store.receiptImage(file) {
                        // The paper, big enough to check the figures against.
                        Button { viewing = img } label: {
                            Image(uiImage: img).resizable().scaledToFill().frame(width: 64, height: 86)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .overlay(alignment: .bottomTrailing) {
                                    Image(systemName: "arrow.up.left.and.arrow.down.right").font(Organic.glyph)
                                        .padding(4).background(.ultraThinMaterial, in: Circle()).padding(3)
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text("Show the receipt photo"))
                    } else if reading || photoPending {
                        ProgressView().frame(width: 64, height: 86)
                            .background(Organic.surface, in: RoundedRectangle(cornerRadius: 6))
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(foreignMoney == nil ? "Amount" : "Paid").font(Organic.caption).foregroundStyle(Organic.n600)
                        if let money = foreignMoney {
                            MoneyField("Paid", value: $foreignAmount, unit: .currency(money), style: .hero)
                        } else {
                            MoneyField("Amount", value: $amount, style: .hero)
                        }
                        Text(reading ? "Reading the photo…" : totalNote)
                            .font(Organic.caption)
                            .foregroundStyle(reading ? Organic.n600 : guess.draft.total == nil ? Organic.warn : Organic.s700)
                    }
                }
            }
            if let money = foreignMoney { foreignCard(money) }
            // Only a missing total asks for another photo. A photo of just
            // the total is a normal way to use this; the shop's field says
            // when its name was not in the picture.
            if !reading, guess.draft.missingBottom {
                Button(action: scanRest) {
                    Banner(text: "No total found: the bottom of the receipt may be cut off",
                           action: "Scan the rest", symbol: "doc.viewfinder", tone: .warn)
                }
                .buttonStyle(.plain)
            }
            Card(padding: .list) {
                editable("Shop", value: t.merchant.isEmpty ? String(localized: "Unnamed") : t.merchant,
                         note: lookingUpShop ? String(localized: "Asking Apple Maps by the number on the receipt") : (shopFromMaps ?? guess.shopReason),
                         warn: t.merchant.isEmpty, editing: $editingShop) {
                    FormField("Shop", text: $t.merchant)
                }
                editable("When", value: t.date.formatted(date: .abbreviated, time: .shortened),
                         note: guess.draft.date == nil ? String(localized: "No date on the receipt · today") : String(localized: "Read from the receipt"),
                         warn: guess.draft.date == nil, editing: $editingDate) {
                    DatePicker("When", selection: $t.date, displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden().font(Organic.body)
                }
                VStack(alignment: .leading, spacing: 6) {
                    ChipPicker(label: "Paid with", options: store.accountNames, selection: t.account) { t.account = $0 }
                    if !guess.accountReason.isEmpty {
                        Text(verbatim: guess.accountReason).font(Organic.caption).foregroundStyle(Organic.n600)
                    }
                }
                .padding(.vertical, Organic.Space.row).overlay(alignment: .top) { Hairline() }
                if t.latitude != nil {
                    field("Where", value: t.placeName ?? (lookingUpPlace ? String(localized: "Looking up where this is…")
                                                                           : String(localized: "Where you were when you scanned")),
                          note: placeNote)
                }
                // Where the receipt says the shop is, which is not always
                // where the phone was when it was scanned.
                if let address = guess.draft.address {
                    field("Address", value: address, note: String(localized: "Printed on the receipt"))
                }
            }
            if !asBelonging {
                Card {
                    HStack {
                        Text("Category").font(Organic.caption).foregroundStyle(Organic.n600)
                        Spacer()
                        Text(verbatim: guess.categoryReason).font(Organic.caption).foregroundStyle(Organic.n600)
                    }
                    ChipPicker(options: store.spendingCategories.map(\.name), selection: t.category) { t.category = $0 }
                        .padding(.top, 6)
                }
            }
            // No list of the lines read: the total is what is saved, and
            // many photos are of the total alone. The lines still feed the
            // belonging suggestion and the check below the amount.
            if let line = guess.belongingLine {
                Card(fill: Organic.infoSoft) {
                    Toggle(isOn: $asBelonging) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Track as a belonging").font(Organic.row)
                            Text(verbatim: String(localized: "\(line.name) · \(store.format(line.price)) — not spending, it stays yours"))
                                .font(Organic.caption).foregroundStyle(Organic.infoInk)
                        }
                    }
                    .tint(Organic.info)
                    if asBelonging {
                        FormField("Name", text: $belongingName).padding(.top, 8)
                        HStack(spacing: 8) {
                            MoneyField("Worth now", value: $worth)
                            MoneyField("Points earned", value: $points, unit: .suffix("pt"))
                        }
                        .padding(.top, 8)
                        HelpText("Worth now is your figure — Mercari 持ち物査定 or a trade-in quote.").padding(.top, 4)
                    }
                }
            }
            Toggle("Keep the receipt photo", isOn: $keepPhoto).font(Organic.body).tint(Organic.accent)
                .padding(.horizontal, 4)
            HelpText(verbatim: preview)
            // A pile of receipts is the usual case at the end of a day.
            HStack(spacing: Organic.Space.m) {
                SecondaryButton(title: "Save and scan next", style: .outlined) { save(); again() }
                PrimaryButton(title: "Save") { save(); done() }
            }
            .disabled(!canSave)
            .opacity(canSave ? 1 : 0.5)
        }
        .onAppear { apply(guess) }
        .onChange(of: guess.id) { apply(guess) }
        .fullScreenCover(item: Binding(get: { viewing.map(PhotoItem.init) }, set: { viewing = $0?.image })) { item in
            ReceiptPhotoView(image: item.image)
        }
        // The spot is known once the location arrives, which may be after
        // the first reading; name it then, once.
        .task(id: t.latitude.map { "\($0),\(t.longitude ?? 0)" }) { await namePlace() }
        // The shop by its printed phone number or address, when the name
        // line could not say it surely. Once per reading.
        .task(id: guess.id) { await nameShop() }
    }

    /// Takes a reading into the form. A field still holding what the last
    /// reading said takes the new one; a field the user changed keeps theirs.
    private func apply(_ g: Store.CaptureGuess) {
        let was = applied
        let new = g.transaction
        func same<T: Equatable>(_ now: T, _ then: T?) -> Bool { then == nil || now == then! }
        if same(amount, was.map { abs($0.transaction.amount) }) { amount = abs(new.amount) }
        if same(t.merchant, was?.transaction.merchant) { t.merchant = new.merchant }
        if same(t.date, was?.transaction.date) { t.date = new.date }
        if same(t.account, was?.transaction.account) { t.account = new.account }
        if same(t.category, was?.transaction.category) { t.category = new.category }
        if same(belongingName, was?.belongingLine?.name ?? (was == nil ? nil : "")), let l = g.belongingLine { belongingName = l.name }
        if same(worth, was?.belongingLine?.price ?? (was == nil ? nil : 0)), let l = g.belongingLine { worth = l.price }
        if new.latitude != t.latitude || new.longitude != t.longitude { t.placeName = nil; placeSource = nil }
        if same(t.currency, was?.transaction.currency) { t.currency = new.currency }
        if same(foreignAmount, was.map { $0.transaction.foreignAmount ?? 0 }) { foreignAmount = new.foreignAmount ?? 0 }
        if rateText.isEmpty, let r = new.rate { rateText = r.formatted(.number.grouping(.never)) }
        // Not the user's to type: always the latest.
        t.kind = new.kind
        t.source = new.source
        t.registration = new.registration
        t.receiptFile = new.receiptFile
        t.latitude = new.latitude
        t.longitude = new.longitude
        applied = g
    }

    /// The receipt's money when it is not the book's.
    private var foreignMoney: Currency? { t.currency.flatMap(Currency.init(code:)) }

    private var rate: Double? { Double(rateText.replacingOccurrences(of: ",", with: ".")).flatMap { $0 > 0 ? $0 : nil } }

    /// What leaves the account, in the book's money.
    private var bookAmount: Int {
        guard foreignMoney != nil else { return amount }
        return rate.map { Finance.convert(foreignAmount, rate: $0) } ?? 0
    }

    private var canSave: Bool { !reading && !photoPending && (foreignMoney == nil || rate != nil) }

    /// The rate and what the receipt comes to in the book's money. The rate
    /// is the last one typed for that currency; the statement has the real one.
    private func foreignCard(_ money: Currency) -> some View {
        Card {
            HStack(alignment: .center, spacing: Organic.Space.m) {
                VStack(alignment: .leading, spacing: Organic.Space.xs) {
                    FieldLabel("Rate · \(money.symbol) per \(store.currency.symbol)1")
                    FormField("\(money.symbol) per \(store.currency.symbol)1", text: $rateText, decimal: true)
                }
                .frame(maxWidth: 170)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(verbatim: rate == nil ? "—" : store.format(bookAmount)).font(Organic.rowValue)
                    Text("in \(String(localized: store.currency.name))").font(Organic.meta).foregroundStyle(Organic.n600)
                }
            }
            HelpText(verbatim: rate == nil ? String(localized: "Type the rate: your card statement or exchange slip has it.")
                                           : (guess.currencyReason ?? ""))
                .padding(.top, 4)
            Button {
                // Read wrongly: the figures are the book's own money after all.
                amount = foreignAmount
                t.currency = nil; t.foreignAmount = nil; t.rate = nil
            } label: { LinkLabel("It was in \(String(localized: store.currency.name))", chevron: false) }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
    }

    private func nameShop() async {
        let before = t.merchant
        lookingUpShop = store.asksMapsForShop(guess)
        let found = await store.shopFromMaps(guess)
        lookingUpShop = false
        // A name the user typed meanwhile stays theirs.
        guard let found, t.merchant == before else { return }
        t.merchant = found.name
        shopFromMaps = found.byPhone ? String(localized: "From Apple Maps · matched by the phone number on the receipt")
                                     : String(localized: "From Apple Maps · at the address on the receipt")
    }

    private func namePlace() async {
        guard let lat = t.latitude, let lon = t.longitude, t.placeName == nil else { return }
        lookingUpPlace = true
        let found = await store.placeName(latitude: lat, longitude: lon)
        lookingUpPlace = false
        guard t.latitude == lat, t.longitude == lon else { return }
        t.placeName = found?.name
        placeSource = found?.source
    }

    /// What the total was checked against. 合計 on a Japanese receipt is
    /// the word printed there; anywhere else it is just the total.
    private var totalNote: LocalizedStringKey {
        let d = guess.draft
        if d.total == nil { return "No total found — type it" }
        if d.totalMatchesLines { return d.japanese ? "Read from 合計 · the lines add up to it" : "Read from the total · the lines add up to it" }
        return d.japanese ? "Read from 合計" : "Read from the total line"
    }

    /// Where the name came from, so a name from the network says so.
    private var placeNote: String {
        switch placeSource {
        case .saved: return String(localized: "A place you have saved here before")
        case .nearShop: return String(localized: "Near where you have paid before")
        case .maps: return String(localized: "From Apple Maps · kept with this spend")
        case nil:
            if lookingUpPlace { return String(localized: "Asking Apple Maps") }
            return store.lookUpPlaceNames ? String(localized: "No name found · the spot is still saved")
                                          : String(localized: "Naming new places is off in Your data")
        }
    }

    /// A field read from the receipt that the user may correct: the value
    /// with a small pencil, and a tap opens the control in its place.
    private func editable<Editor: View>(_ label: LocalizedStringKey, value: String, note: String, warn: Bool,
                                        editing: Binding<Bool>, @ViewBuilder editor: () -> Editor) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Button { editing.wrappedValue.toggle() } label: {
                HStack(alignment: .top, spacing: Organic.Space.l) {
                    Text(label).font(Organic.value).foregroundStyle(Organic.n600).frame(width: 80, alignment: .leading)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: value).font(Organic.row)
                        Text(verbatim: note).font(Organic.caption).foregroundStyle(warn ? Organic.warn : Organic.n600)
                    }
                    Spacer()
                    Image(systemName: editing.wrappedValue ? "checkmark" : "pencil")
                        .font(Organic.valueStrong).foregroundStyle(Organic.n500)
                        .accessibilityLabel(Text(editing.wrappedValue ? "Done" : "Edit"))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if editing.wrappedValue { editor() }
        }
        .padding(.vertical, Organic.Space.row)
        .overlay(alignment: .top) { Hairline() }
    }

    private func field(_ label: LocalizedStringKey, value: String, note: String, warn: Bool = false) -> some View {
        HStack(alignment: .top, spacing: Organic.Space.l) {
            Text(label).font(Organic.value).foregroundStyle(Organic.n600).frame(width: 80, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: value).font(Organic.row)
                Text(verbatim: note).font(Organic.caption).foregroundStyle(warn ? Organic.warn : Organic.n600)
            }
            Spacer()
        }
        .padding(.vertical, Organic.Space.row)
        .overlay(alignment: .top) { Hairline() }
    }

    private var preview: String {
        if foreignMoney != nil && rate == nil { return String(localized: "Type the rate to save it.") }
        guard bookAmount > 0 else { return String(localized: "Type the total the receipt shows.") }
        if let card = store.data.cards.first(where: { $0.name == t.account }) {
            let c = store.cycle(for: card)
            return String(localized: "\(store.format(bookAmount)) goes on \(card.name) · on the statement closing \(c.nextClosing.formatted(.dateTime.day().month(.abbreviated))) · paid \(c.unbilledDue.formatted(.dateTime.day().month(.abbreviated)))")
        }
        return String(localized: "\(store.format(bookAmount)) leaves \(t.account)")
    }

    private func discard() {
        if let f = guess.transaction.receiptFile { store.deleteReceipt(f) }
    }

    private func save() {
        var out = t
        out.amount = -abs(bookAmount)
        if let money = foreignMoney, let rate {
            out.foreignAmount = foreignAmount
            out.rate = rate
            store.setRate(money.code, rate)
        }
        out.needsReview = false
        if !keepPhoto, let f = out.receiptFile { store.deleteReceipt(f); out.receiptFile = nil }
        if asBelonging {
            let item = store.makeBelonging(from: out, name: belongingName.isEmpty ? out.merchant : belongingName,
                                           worth: worth, points: points, toResell: false)
            _ = item
        } else {
            store.addTransaction(out)
        }
    }
}

/// Quick add where you are: the place, its usual amount, its category and
/// the wallet used there, one tap to save.
struct QuickAddView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let place: Finance.Place
    let latitude: Double?
    let longitude: Double?
    @State private var amount = 0
    @State private var t = Transaction(date: .now, amount: 0, kind: .spend, account: "")

    var body: some View {
        SheetScaffold(title: "Add a spend") {
            Card {
                ListRow(title: place.merchant, sub: String(localized: "You’re here now · saved here \(place.visits) times"),
                        mark: LeadMark(glyph: .symbol("mappin"), tint: Organic.infoSoft, ink: Organic.info))
            }
            Card {
                MoneyField("Amount", value: $amount, prominent: true)
                FlowRow(spacing: 8) {
                    ForEach(usual, id: \.self) { a in
                        Button { amount = a } label: { Chip(label: Text(verbatim: store.format(a)), selected: amount == a) }
                            .buttonStyle(.plain)
                    }
                }
                .padding(.top, 8)
                ChipPicker(label: "Category", options: store.spendingCategories.map(\.name), selection: t.category) { t.category = $0 }
                    .padding(.top, 8)
                ChipPicker(label: "Paid with", options: store.accountNames, selection: t.account) { t.account = $0 }
                    .padding(.top, 8)
            }
            HelpText("Places are learned from your own saves. Your location stays on this iPhone.")
            PrimaryButton(title: "Save \(store.format(amount))") {
                var out = t
                out.amount = -abs(amount)
                store.addTransaction(out)
                dismiss()
            }
        }
        .onAppear {
            t = store.quickAddAt(place, latitude: latitude, longitude: longitude)
            amount = place.usualAmount
        }
    }

    /// The amounts saved here most often, most usual first.
    private var usual: [Int] {
        let here = store.transactions.filter { $0.merchant == place.merchant && $0.kind == .spend }.map { -$0.amount }
        let counts = Dictionary(grouping: here, by: { $0 }).mapValues(\.count)
        return Array(counts.sorted { $0.value > $1.value }.map(\.key).prefix(3))
    }
}

private struct PhotoItem: Identifiable {
    let image: UIImage
    var id: ObjectIdentifier { ObjectIdentifier(image) }
}

/// The receipt photo full screen: pinch to zoom, drag to move, double tap
/// to go back to the whole paper. For checking the total against the paper
/// before saving.
struct ReceiptPhotoView: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Organic.Camera.bg.ignoresSafeArea()
            Image(uiImage: image).resizable().scaledToFit()
                .scaleEffect(scale).offset(offset)
                .gesture(
                    MagnifyGesture()
                        .onChanged { scale = min(max(lastScale * $0.magnification, 1), 6) }
                        .onEnded { _ in lastScale = scale; if scale == 1 { offset = .zero; lastOffset = .zero } }
                        .simultaneously(with: DragGesture()
                            .onChanged { g in
                                guard scale > 1 else { return }
                                offset = CGSize(width: lastOffset.width + g.translation.width, height: lastOffset.height + g.translation.height)
                            }
                            .onEnded { _ in lastOffset = offset })
                )
                .onTapGesture(count: 2) {
                    withAnimation(.easeOut(duration: 0.2)) {
                        if scale > 1 { scale = 1; offset = .zero } else { scale = 2.5 }
                        lastScale = scale; lastOffset = offset
                    }
                }
                .accessibilityLabel(Text("Receipt photo"))
            // On a dark disc: the paper behind it is white.
            CameraRoundButton(symbol: "xmark", label: "Close") { dismiss() }
                .background(Organic.Camera.bg.opacity(0.75), in: Circle())
                .padding(Organic.Space.gutter)
        }
        .preferredColorScheme(.dark)
    }
}
