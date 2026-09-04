import Foundation

/// Batch import for inventory: the other half of Export. The columns it reads
/// are exactly the ones `Store.exportText` writes, so a sheet exported from
/// this app — or a Google Sheet built to match — goes straight back in.
///
/// Parsing never touches the store. It produces a preview the screen can show,
/// and only `commitImport` writes anything.

extension Store {

    /// Why a row looks like something you already have. Ordered by how sure it
    /// is: the same name, price and card is all but certain; a bare name match
    /// is worth a second look, because two of the same lens is a real thing.
    enum DuplicateKind: Int, Comparable {
        case none = 0
        /// Same name, but bought on a different day or somewhere else. Two of
        /// the same lens bought months apart are two lenses, so this one is
        /// flagged and still imported.
        case sameNameOnly
        /// Same name and the same purchase date.
        case sameNameAndDate
        /// Same name, same day, same shop — the same purchase.
        case exact
        case repeatedInFile

        static func < (a: DuplicateKind, b: DuplicateKind) -> Bool { a.rawValue < b.rawValue }

        var isDuplicate: Bool { self != .none }

        /// Whether it is sure enough to leave the row switched off.
        var blocksByDefault: Bool { self >= .sameNameAndDate }

        var tag: String {
            switch self {
            case .none: return ""
            case .sameNameOnly: return "SAME NAME"
            case .sameNameAndDate: return "SAME NAME + DATE"
            case .exact: return "ALREADY HERE"
            case .repeatedInFile: return "TWICE IN THIS SHEET"
            }
        }
    }

    /// One parsed row, with whatever the file could not make sense of.
    struct ImportRow: Identifiable {
        let id = UUID()
        var item: Item
        /// Line number in the source, for pointing at a bad row.
        var line: Int
        /// Things worth knowing but not fatal: a card or channel this book has
        /// never heard of, a date that would not parse.
        var warnings: [String] = []
        var duplicate: DuplicateKind = .none
        /// What it matched, in words, so the decision is not blind.
        var duplicateDetail = ""
        /// Whether this row will actually be written.
        var include = true

        var isDuplicate: Bool { duplicate.isDuplicate }
    }

    /// One channel name as the sheet writes it, and what the book made of it.
    struct ChannelUse: Identifiable {
        var id: String { written }
        /// The name as typed in the sheet.
        let written: String
        /// The channel in the book it was read as — nil when there is none yet.
        let matched: String?
        /// How many rows name it.
        var rows: Int = 0

        var isNew: Bool { matched == nil }
        /// Whether the book's name differs from what the sheet wrote.
        var wasRenamed: Bool { matched != nil && matched != written }
    }

    /// What to do with one channel name the sheet wrote, decided on the
    /// import screen. Keyed by the name as written.
    enum ImportChannelPlan {
        /// Read it as this channel of the book's, whatever the sheet called it.
        case use(String)
        /// Make a channel of that name. `destination` nil = make a wallet for
        /// it as well, the way Settings does.
        case create(rate: Double, isPoints: Bool, destination: String?)
    }

    struct ImportPreview {
        var rows: [ImportRow] = []
        /// Rows that could not be read at all: line number and why.
        var failures: [(line: Int, reason: String)] = []
        var recognisedHeader = false
        /// The columns this sheet actually supplied, in order.
        var usedColumns: [String] = []
        /// Header names that meant nothing to the app; their data is skipped.
        var ignoredHeaders: [String] = []
        /// Empty filler rows, passed over without comment.
        var blankRows = 0
        /// Every sales channel the sheet names, in the order it first names
        /// them: what it was matched to, or that it is new.
        var channels: [ChannelUse] = []

        var includedCount: Int { rows.filter(\.include).count }
        var duplicateCount: Int { rows.filter(\.isDuplicate).count }
        /// Rows the app is sure enough about to switch off on its own.
        var blockedCount: Int { rows.filter { $0.duplicate.blocksByDefault }.count }
        /// Blocked rows the user switched back on.
        var forcedDuplicateCount: Int { rows.filter { $0.duplicate.blocksByDefault && $0.include }.count }
        var warningCount: Int { rows.filter { !$0.warnings.isEmpty }.count }
        var isEmpty: Bool { rows.isEmpty && failures.isEmpty }
    }

    /// Header names this app answers to, folded. Only `Name` is required; any
    /// column that is missing is simply not read, and any column it does not
    /// recognise is ignored rather than shifting the others along.
    static let columnAliases: [String: String] = {
        let table: [String: [String]] = [
            "Name": ["name", "item", "title", "product", "ten", "tên", "san pham", "sản phẩm", "mon", "món"],
            "Category": ["category", "type", "kind", "loai", "loại", "phan loai", "phân loại"],
            "Status": ["status", "state", "sold", "sold?", "is sold", "trang thai", "trạng thái",
                       "tinh trang", "tình trạng", "da ban", "đã bán", "売却"],
            "Date": ["date", "bought on", "buy date", "purchase date", "ngay mua", "ngày mua", "ngay",
                     "購入日", "購入日付", "日付", "購入"],
            "Buy": ["buy", "buy price", "cost", "paid", "purchase price", "gia mua", "giá mua", "gia von", "giá vốn"],
            "Bought from": ["bought from", "from", "shop", "store", "seller", "source", "supplier",
                            "buy on market", "buy on", "buy at", "market", "購入先", "購入店",
                            "noi mua", "nơi mua", "cua hang", "cửa hàng", "nguoi ban", "người bán"],
            "Card": ["card", "paid with", "payment", "the", "thẻ", "the tin dung", "thẻ tín dụng",
                     "the vo", "thẻ vợ", "the chong", "thẻ chồng", "カード"],
            "Est": ["est", "estimate", "estimated", "value", "worth", "asking", "list price",
                    "sell price", "selling price", "asking price",
                    "gia ban", "giá bán", "gia uoc tinh", "giá ước tính"],
            "Channel": ["channel", "platform", "marketplace", "sell on", "kenh", "kênh", "noi ban", "nơi bán"],
            "Sold price": ["sold price", "sold for", "sale price", "gia da ban", "giá đã bán"],
            "Sold date": ["sold date", "date sold", "ngay ban", "ngày bán"],
            "Net": ["net", "received", "payout", "income", "thuc nhan", "thực nhận", "thu nhap", "thu nhập"],
            "Shipping": ["shipping", "shipping fee", "postage", "ship", "送料",
                         "phi ship", "phí ship", "phi van chuyen", "phí vận chuyển"],
            "Points": ["points", "point", "earn point", "earned point", "earned points", "point earned",
                       "diem", "điểm", "ポイント"],
            "Profit": ["profit", "margin", "loi nhuan", "lợi nhuận", "lai", "lãi"],
            "Accessories": ["accessories", "extras", "included", "phu kien", "phụ kiện", "kem theo", "kèm theo"],
            "Condition": ["condition", "grade", "tinh trang may", "tình trạng máy", "ghi chu", "ghi chú"],
            "Attributes": ["attributes", "specs", "details", "thuoc tinh", "thuộc tính"],
        ]
        var map: [String: String] = [:]
        for (canonical, names) in table {
            for name in names { map[name] = canonical }
        }
        return map
    }()

    // MARK: - Parsing

    /// Reads TSV or CSV. The delimiter is whichever of tab or comma appears more
    /// often in the first line — a file with tabs is never treated as CSV.
    func parseImport(_ text: String) -> ImportPreview {
        var preview = ImportPreview()
        let lines = text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")
            .enumerated()
            .filter { !$0.element.trimmingCharacters(in: .whitespaces).isEmpty }
        guard let first = lines.first else { return preview }

        let sep: Character = first.element.filter { $0 == "\t" }.count >= first.element.filter { $0 == "," }.count ? "\t" : ","

        // Map column name -> position. Without a recognisable header the file is
        // read positionally, in export order.
        var columnAt: [String: Int] = [:]
        var body = lines
        let headerCells = splitRow(first.element, sep: sep).map { normalise($0) }
        let mapped = headerCells.map { Store.columnAliases[$0] }

        if mapped.contains(where: { $0 == "Name" }) {
            // Headed sheet: each column is placed by what it is called, so a
            // sheet can carry three columns or all sixteen, in any order.
            preview.recognisedHeader = true
            for (i, canonical) in mapped.enumerated() {
                guard let canonical, columnAt[normalise(canonical)] == nil else { continue }
                columnAt[normalise(canonical)] = i
            }
            preview.usedColumns = Store.importColumns.filter { columnAt[normalise($0)] != nil }
            preview.ignoredHeaders = zip(headerCells, mapped)
                .filter { $0.1 == nil && !$0.0.isEmpty }
                .map { $0.0 }
            body = Array(lines.dropFirst())
        } else {
            // No header to go on: fall back to export order, and only claim the
            // columns the sheet actually has.
            let width = splitRow(first.element, sep: sep).count
            for (i, name) in Store.exportColumns.enumerated() where i < width {
                columnAt[normalise(name)] = i
            }
            preview.usedColumns = Array(Store.exportColumns.prefix(width))
        }

        // Only a sheet that actually carries the column can be read for what a
        // blank in it means.
        let hasChannelColumn = columnAt[normalise("Channel")] != nil

        // Keys are folded — case, accents, punctuation and doubled spaces all
        // ignored — so "Sigma 35mm F1.4" and "sigma  35mm f1,4" are one thing.
        var seenInFile: [String: SeenRow] = [:]

        for (index, raw) in body {
            let cells = splitRow(raw, sep: sep)
            func value(_ column: String) -> String {
                guard let i = columnAt[normalise(column)], i < cells.count else { return "" }
                return cells[i].trimmingCharacters(in: .whitespaces)
            }

            let name = isBlank(value("Name")) ? "" : value("Name")
            guard !name.isEmpty else {
                // A trailing row left behind by formulas carries no name and no
                // money. Reporting those as errors would bury the real ones.
                let carriesSomething = ["Buy", "Est", "Sold price", "Bought from", "Card", "Channel"]
                    .contains { !isBlank(value($0)) }
                if carriesSomething {
                    preview.failures.append((index + 1, "No name in this row."))
                } else {
                    preview.blankRows += 1
                }
                continue
            }

            var warnings: [String] = []
            var item = Item(name: name,
                            boughtOn: .now,
                            buyPrice: number(value("Buy")),
                            cardName: value("Card"),
                            estimatedPrice: number(value("Est")),
                            plannedChannel: value("Channel"))
            item.categoryName = value("Category")
            item.boughtFrom = value("Bought from")
            item.accessories = value("Accessories")
            item.condition = value("Condition")

            if let date = parseDate(value("Date")) { item.boughtOn = date }
            else if !value("Date").isEmpty { warnings.append("Could not read the date \"\(value("Date"))\".") }

            item.pointsEarned = number(value("Points"))
            item.shippingFee = optionalNumber(value("Shipping"))

            // Status is written a dozen ways. A "Sold?" column of TRUE/FALSE is
            // as common as the word itself, and "keep" wins over both.
            let status = value("Status").lowercased().trimmingCharacters(in: .whitespaces)
            item.keep = status.contains("keep") || status.contains("giu") || status.contains("giữ")

            let soldPrice = optionalNumber(value("Sold price"))
            let soldDate = parseDate(value("Sold date"))
            let saidSold = status.contains("sold") || status.contains("ban") || status == "true"
                || status == "yes" || status == "1" || status == "✓"
            let saidUnsold = status == "false" || status == "no" || status == "0"

            // A price in a "Sell Price" column is only a sale once something
            // says it sold — otherwise it is what you hope to get for it.
            if !item.keep, saidSold || (!saidUnsold && (soldPrice != nil || soldDate != nil)) {
                let channel = value("Channel")
                let price = soldPrice ?? item.estimatedPrice
                let net = optionalNumber(value("Net"))
                    ?? netProceeds({ var p = item; p.estimatedPrice = price; return p }(), channelName: channel)
                item.sale = SaleRecord(price: price, channel: channel, net: net,
                                       date: soldDate ?? item.boughtOn)
            }

            // Nowhere to sell it means it is not going up for sale. A sheet
            // that names a channel for the things it is selling is saying,
            // by the blank, that the rest are being kept.
            if !item.keep, !item.isSold, hasChannelColumn, item.plannedChannel.isEmpty {
                item.keep = true
                warnings.append("No channel — brought in as Keeping.")
            }

            // "Fungus=No; Hood=Yes" — the shape Export writes.
            let attributes = value("Attributes")
            if !attributes.isEmpty {
                item.attributes = attributes.components(separatedBy: ";").compactMap { pair in
                    let parts = pair.components(separatedBy: "=")
                    let key = parts[0].trimmingCharacters(in: .whitespaces)
                    guard !key.isEmpty else { return nil }
                    return [key, parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespaces) : ""]
                }
            }

            if !item.cardName.isEmpty {
                if let resolved = resolve(item.cardName, against: data.cards.map(\.name)) {
                    if resolved != item.cardName {
                        warnings.append("Read \"\(item.cardName)\" as your card \"\(resolved)\".")
                    }
                    item.cardName = resolved
                } else {
                    warnings.append("No card called \"\(item.cardName)\" — the item comes in without one.")
                    item.cardName = ""
                }
            }
            if !item.plannedChannel.isEmpty {
                let written = item.plannedChannel
                let matched = resolve(written, against: data.channels.map(\.name))
                if let index = preview.channels.firstIndex(where: { $0.written == written }) {
                    preview.channels[index].rows += 1
                } else {
                    preview.channels.append(ChannelUse(written: written, matched: matched, rows: 1))
                }
                if let resolved = matched {
                    if resolved != item.plannedChannel {
                        warnings.append("Read \"\(item.plannedChannel)\" as your channel \"\(resolved)\".")
                    }
                    if let sale = item.sale, sale.channel == item.plannedChannel {
                        item.sale?.channel = resolved
                    }
                    item.plannedChannel = resolved
                } else {
                    // Inventing the channel beats dropping the name: a sheet is
                    // usually the first thing a new book gets, and its channels
                    // are exactly the ones the book is missing.
                    warnings.append("New channel \"\(item.plannedChannel)\" — it will be created on import; its fee is set below.")
                }
            }
            if !item.categoryName.isEmpty, !data.categories.contains(where: { $0.name == item.categoryName }) {
                warnings.append("New category \"\(item.categoryName)\" — it stays as a label unless you add it in Categories.")
            }

            let key = Store.duplicateKey(name)
            var kind = DuplicateKind.none
            var detail = ""

            if let earlier = seenInFile[key], earlier.sameDay(as: item.boughtOn),
               earlier.samePlace(as: item) {
                kind = .repeatedInFile
                detail = "The same purchase is already on line \(earlier.line) of this sheet."
            } else if let match = bestMatch(for: item, key: key) {
                kind = match.kind
                detail = match.detail
            }
            seenInFile[key] = SeenRow(line: index + 1, boughtOn: item.boughtOn,
                                      place: Store.placeKey(item))

            preview.rows.append(ImportRow(item: item, line: index + 1,
                                          warnings: warnings,
                                          duplicate: kind,
                                          duplicateDetail: detail,
                                          include: !kind.blocksByDefault))
        }
        return preview
    }

    /// Writes the included rows.
    ///
    /// `addToCardDebt` is off by default on the screen: an import is usually a
    /// backfill of things already bought, and their debt is already sitting on
    /// the cards. Turning it on treats every row as a purchase made now.
    @discardableResult
    func commitImport(_ preview: ImportPreview, addToCardDebt: Bool, source: String = "Pasted",
                      channelPlans: [String: ImportChannelPlan] = [:]) -> Int {
        let rows = preview.rows.filter(\.include)
        guard !rows.isEmpty else { return 0 }

        // The preview was built at paste time. Anything could have been added
        // since — including by a previous tap of this button — so the guard is
        // applied again here, against what is actually in the book now.
        // A row the user switched back on deliberately still goes in; what this
        // stops is the same paste landing twice.
        var writtenKeys = Set(data.items.map { Store.purchaseKey($0) })

        // The preview already rewrote matched names to the book's own; what
        // the rows carry now is `matched ?? written`. The plan decided on
        // screen may point that somewhere else again — at a different existing
        // channel, or at a new one under the sheet's own name — so every name
        // the rows carry is mapped once, here, before anything is written.
        var rename: [String: String] = [:]
        var createdChannels: [String] = []
        var createdWallets: [String] = []
        for use in preview.channels {
            let carried = use.matched ?? use.written
            let plan = channelPlans[use.written]
                ?? (use.matched.map { .use($0) } ?? .create(rate: 0, isPoints: false, destination: nil))
            switch plan {
            case .use(let name):
                rename[carried] = name
            case .create(let rate, let isPoints, let destination):
                rename[carried] = use.written
                guard !data.channels.contains(where: { $0.name == use.written }) else { continue }
                var ch = SalesChannel(name: use.written, rate: rate, isPoints: isPoints)
                if let destination {
                    ch.destination = destination
                } else {
                    let name = SalesChannel.defaultDestinationName(for: use.written, isPoints: isPoints)
                    let existed = isPoints ? data.pointWallets.contains { $0.name == name }
                                           : data.wallets.contains { $0.name == name }
                    ch.destination = makeDestination(for: ch)
                    if !existed { createdWallets.append(name) }
                }
                data.channels.append(ch)
                createdChannels.append(use.written)
            }
        }

        // What actually landed, not what was offered: the count on screen, the
        // history entry and the undo all have to agree with the book.
        var written: [Item] = []
        for row in rows {
            var item = row.item
            if let to = rename[item.plannedChannel] { item.plannedChannel = to }
            if let sale = item.sale, let to = rename[sale.channel] { item.sale?.channel = to }
            let key = Store.purchaseKey(item)
            // A row the user switched back on deliberately still goes in; what
            // this stops is the same paste landing twice.
            if !row.duplicate.blocksByDefault && writtenKeys.contains(key) { continue }
            writtenKeys.insert(key)
            data.items.insert(item, at: 0)
            written.append(item)
            if addToCardDebt, !item.isSold,
               let ix = data.cards.firstIndex(where: { $0.name == item.cardName }) {
                data.cards[ix].debt += item.buyPrice
            }
        }
        guard !written.isEmpty else {
            // Nothing landed, so nothing should have been made for it.
            data.channels.removeAll { createdChannels.contains($0.name) }
            data.wallets.removeAll { createdWallets.contains($0.name) }
            data.pointWallets.removeAll { createdWallets.contains($0.name) }
            return 0
        }
        recordImport(written, addedToDebt: addToCardDebt, source: source,
                     createdChannels: createdChannels, createdWallets: createdWallets)
        save()
        return written.count
    }

    // MARK: - History

    /// Newest first, the way they were written.
    var importHistory: [ImportBatch] { data.importBatches ?? [] }

    /// The items one import wrote that are still in the book — what an undo
    /// would actually remove.
    func remainingItems(of batch: ImportBatch) -> [Item] {
        let ids = Set(batch.itemIDs)
        return data.items.filter { ids.contains($0.id) }
    }

    /// Undo an import: take back the items it wrote and drop the entry.
    ///
    /// Card debt is only handed back if this import is what put it there —
    /// a "records only" import never touched the cards, so undoing it must not
    /// either. A sale made after the import is left as it happened: the money
    /// really did land, which is how deleting an item by hand behaves too.
    @discardableResult
    func deleteImportBatch(_ batch: ImportBatch) -> Int {
        let ids = Set(batch.itemIDs)
        let going = data.items.filter { ids.contains($0.id) }
        if batch.addedToDebt {
            for item in going where !item.isSold {
                if let ix = data.cards.firstIndex(where: { $0.name == item.cardName }) {
                    data.cards[ix].debt -= item.buyPrice
                }
            }
        }
        data.items.removeAll { ids.contains($0.id) }
        // A channel this import invented goes back out with it — unless
        // something else has since been pointed at it, which makes it the
        // user's channel rather than the import's. The wallet made for it
        // follows, as long as it is still empty and nothing else pays into it.
        for name in batch.createdChannels ?? [] {
            let stillUsed = data.items.contains {
                $0.plannedChannel == name || $0.sale?.channel == name
            }
            guard !stillUsed else { continue }
            data.channels.removeAll { $0.name == name }
        }
        for name in batch.createdWallets ?? [] {
            guard !data.channels.contains(where: { $0.destination == name }) else { continue }
            data.wallets.removeAll { $0.name == name && $0.balance == 0 }
            data.pointWallets.removeAll { $0.name == name && $0.points == 0 }
        }
        if !going.isEmpty {
            data.ledger.insert(LedgerEntry(date: .now,
                                           label: "Removed \(going.count) imported item(s)",
                                           detail: batch.source, amount: 0, kind: "x"), at: 0)
        }
        data.importBatches?.removeAll { $0.id == batch.id }
        save()
        return going.count
    }

    /// Drop the entry and keep the items — for an import that is settled and
    /// no longer worth a line in the list.
    func forgetImportBatch(_ batch: ImportBatch) {
        data.importBatches?.removeAll { $0.id == batch.id }
        save()
    }

    // MARK: - Small readers

    /// Splits one line, honouring the quoting rules Export uses for CSV.
    private func splitRow(_ line: String, sep: Character) -> [String] {
        var cells: [String] = []
        var current = ""
        var inQuotes = false
        var chars = Array(line)
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if c == "\"" {
                if inQuotes, i + 1 < chars.count, chars[i + 1] == "\"" { current.append("\""); i += 1 }
                else { inQuotes.toggle() }
            } else if c == sep && !inQuotes {
                cells.append(current); current = ""
            } else {
                current.append(c)
            }
            i += 1
        }
        cells.append(current)
        return cells.map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "\"")) }
    }

    /// Matches a sheet's wording to something this book already has: exactly
    /// first, then folded, then as the start of exactly one name — so "PayPay"
    /// finds "PayPay Flea" but an ambiguous stub is left alone rather than
    /// guessed at.
    private func resolve(_ written: String, against names: [String]) -> String? {
        if names.contains(written) { return written }
        let key = Store.duplicateKey(written)
        guard !key.isEmpty else { return nil }
        if let exact = names.first(where: { Store.duplicateKey($0) == key }) { return exact }
        let starts = names.filter { Store.duplicateKey($0).hasPrefix(key) }
        if starts.count == 1 { return starts[0] }
        let contains = names.filter { Store.duplicateKey($0).contains(key) }
        return contains.count == 1 ? contains[0] : nil
    }

    /// Name, day and place together — one purchase.
    static func purchaseKey(_ item: Item) -> String {
        let day = ISO8601DateFormatter.string(from: item.boughtOn,
                                              timeZone: .current,
                                              formatOptions: [.withFullDate])
        return "\(duplicateKey(item.name))|\(day)|\(placeKey(item))"
    }

    /// A row already read from this sheet, for catching a paste that repeats
    /// itself.
    private struct SeenRow {
        let line: Int
        let boughtOn: Date
        let place: String

        func sameDay(as other: Date) -> Bool {
            Calendar.current.isDate(boughtOn, inSameDayAs: other)
        }
        func samePlace(as item: Item) -> Bool { place == Store.placeKey(item) }
    }

    /// The closest thing in the book to this row, graded on the three things
    /// that identify a purchase: what it is, when it was bought, and where from.
    private func bestMatch(for item: Item, key: String) -> (kind: DuplicateKind, detail: String)? {
        let sameName = data.items.filter { Store.duplicateKey($0.name) == key }
        guard !sameName.isEmpty else { return nil }

        let place = Store.placeKey(item)
        let calendar = Calendar.current

        // Same day and same shop: the same purchase, twice.
        if let hit = sameName.first(where: {
            calendar.isDate($0.boughtOn, inSameDayAs: item.boughtOn) && Store.placeKey($0) == place
        }) {
            let where_ = Store.placeLabel(hit)
            return (.exact, where_.isEmpty
                    ? "Already here: bought \(hit.boughtOn.formatted(date: .abbreviated, time: .omitted))."
                    : "Already here: bought \(hit.boughtOn.formatted(date: .abbreviated, time: .omitted)) from \(where_).")
        }

        // Same day, different shop — or one of them has no shop recorded.
        if let hit = sameName.first(where: {
            calendar.isDate($0.boughtOn, inSameDayAs: item.boughtOn)
        }) {
            let theirs = Store.placeLabel(hit)
            let mine = Store.placeLabel(item)
            let where_ = theirs.isEmpty || mine.isEmpty
                ? "one of the two has no shop recorded"
                : "yours says \(theirs), this row says \(mine)"
            return (.sameNameAndDate, "Same name and the same purchase date — \(where_).")
        }

        // Name alone. Two of the same lens bought at different times are two
        // lenses, so this is a flag rather than a block.
        let hit = sameName[0]
        return (.sameNameOnly,
                "You have one by this name, bought \(hit.boughtOn.formatted(date: .abbreviated, time: .omitted)).")
    }

    /// Where an item was bought, folded for comparison. The shop is the real
    /// answer; the card stands in when no shop was recorded, since for a
    /// backfill that is often all there is.
    static func placeKey(_ item: Item) -> String {
        let place = item.boughtFrom.isEmpty ? item.cardName : item.boughtFrom
        return duplicateKey(place)
    }

    static func placeLabel(_ item: Item) -> String {
        item.boughtFrom.isEmpty ? item.cardName : item.boughtFrom
    }

    /// Folds a name down to what two people would agree is "the same thing":
    /// no case, no accents, no punctuation, single spaces.
    static func duplicateKey(_ name: String) -> String {
        let folded = name.folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive],
                                 locale: Locale(identifier: "en_US_POSIX"))
        let kept = folded.map { $0.isLetter || $0.isNumber ? $0 : " " }
        return String(kept).split(separator: " ").joined(separator: " ")
    }

    /// Header names are matched with accents folded and spacing collapsed, so
    /// "Ngày mua", "ngay mua" and "NGAY  MUA" are all the same column.
    private func normalise(_ s: String) -> String {
        let folded = s.folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive],
                               locale: Locale(identifier: "en_US_POSIX"))
            .replacingOccurrences(of: "\"", with: "")
        return folded.split(whereSeparator: { $0 == " " || $0 == "\u{00A0}" })
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
    }

    /// A spreadsheet cell that carries nothing: empty, or one of the error and
    /// placeholder markers a formula leaves behind.
    private func isBlank(_ s: String) -> Bool {
        let t = s.trimmingCharacters(in: .whitespaces).lowercased()
        return t.isEmpty || ["#n/a", "n/a", "na", "-", "—", "#value!", "#ref!", "#div/0!", "null"].contains(t)
    }

    /// Digits only, so "¥151,636" and "151636" read the same. nil when the cell
    /// holds nothing usable — which is different from a genuine zero.
    private func optionalNumber(_ s: String) -> Int? {
        guard !isBlank(s) else { return nil }
        let negative = s.contains("-") || s.contains("−")
        let digits = s.filter(\.isNumber)
        guard !digits.isEmpty, let value = Int(digits) else { return nil }
        return negative ? -value : value
    }

    private func number(_ s: String) -> Int { optionalNumber(s) ?? 0 }

    /// Accepts what Export writes (d/M/yyyy) plus the usual sheet formats.
    private func parseDate(_ s: String) -> Date? {
        let text = s.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return nil }
        for format in ["d/M/yyyy", "M/d/yyyy", "yyyy-MM-dd", "yyyy/MM/dd", "dd/MM/yyyy"] {
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.dateFormat = format
            if let d = f.date(from: text) { return d }
        }
        return nil
    }

    private func recordImport(_ items: [Item], addedToDebt: Bool, source: String,
                              createdChannels: [String], createdWallets: [String]) {
        data.ledger.insert(LedgerEntry(date: .now, label: "Imported \(items.count) item(s)",
                                       detail: addedToDebt ? "Purchases added to card debt" : "Records only",
                                       amount: 0, kind: "x"), at: 0)
        let batch = ImportBatch(date: .now, itemIDs: items.map(\.id), itemNames: items.map(\.name),
                                addedToDebt: addedToDebt, source: source,
                                createdChannels: createdChannels.isEmpty ? nil : createdChannels,
                                createdWallets: createdWallets.isEmpty ? nil : createdWallets)
        data.importBatches = [batch] + (data.importBatches ?? [])
    }
}

// MARK: - Example sheet

extension Store {

    /// What each column means, in the order Export writes them. Shown on the
    /// import screen so a sheet can be built by hand without guesswork.
    static let importColumnHelp: [(column: String, help: String)] = [
        ("Name", "Required. Everything else can be left blank."),
        ("Category", "Free text. A category this book doesn't have stays a label."),
        ("Status", "for sale · keep · sold"),
        ("Date", "Bought on. 20/8/2026, 2026-08-20 and 8/20/2026 all read."),
        ("Buy", "What you paid. ¥ and commas are fine."),
        ("Bought from", "The shop or seller. Used with the name and date to spot the same purchase twice."),
        ("Card", "Must match a card in Wallet, or it comes in without one."),
        ("Est", "What you think it is worth now."),
        ("Channel", "Where you plan to sell. A name this book does not have is created on import. Left blank, the item comes in as Keeping."),
        ("Shipping", "What postage costs. Left out, the default in Settings is used."),
        ("Sold price", "Fills only for sold rows."),
        ("Sold date", "Fills only for sold rows."),
        ("Net", "What arrived after fees. Left blank, it is worked out from the channel."),
        ("Profit", "Ignored on import — it is always net minus buy."),
        ("Accessories", "Free text."),
        ("Condition", "Free text."),
        ("Attributes", "name=value pairs joined by ; — Fungus=No; Hood=Yes"),
    ]

    /// A two-row example built from this book's own cards, channels and
    /// categories, so pasting it imports cleanly instead of warning about names
    /// the app has never heard of.
    var importExample: String {
        let card = data.cards.first?.name ?? "Saison"
        let cashChannel = data.channels.first { !$0.isPoints }?.name ?? "Mercari"
        let category = data.categories.first?.name ?? "Camera lens"
        let today = Date.now
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "d/M/yyyy"
        let bought = formatter.string(from: today.addingTimeInterval(-60 * 60 * 24 * 30))
        let sold = formatter.string(from: today)

        let rows = [
            Store.exportColumns,
            ["Sigma 35mm F1.4", category, "for sale", bought, "48000", "MapCamera", card,
             "72000", cashChannel, "1000", "", "", "", "", "Hood, box", "Mint", "Fungus=No; Hood=Yes"],
            ["Nikon Z8 body", category, "sold", bought, "398000", "Hardoff", card,
             "430000", cashChannel, "1000", "432000", sold, "", "", "", "", ""],
        ]
        return rows.map { $0.joined(separator: "\t") }.joined(separator: "\n")
    }
}
