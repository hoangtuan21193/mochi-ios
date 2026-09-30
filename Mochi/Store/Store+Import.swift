import Foundation
import SwiftUI

/// Batch import for inventory: the other half of Export. The columns it reads
/// are exactly the ones `Store.exportText` writes, so a sheet exported from
/// this app — or a Google Sheet built to match — goes straight back in.
///
/// Parsing never touches the store. It produces a preview the screen can show,
/// and only `commitImport` writes anything.

extension Store {

    /// Why a row looks like something you already have. Only one of these is a
    /// duplicate: Item, 購入日 and Buy on Market all equal. The other two are
    /// notes on the row — they say what to look at, they do not decide.
    enum DuplicateKind: Int, Comparable {
        case none = 0
        /// Same name, bought on a different day. Two of the same lens bought
        /// months apart are two lenses.
        case sameNameOnly
        /// Same name and the same purchase date, but bought somewhere else.
        /// Two shops on one day is unusual and not impossible, so this asks
        /// rather than decides.
        case sameNameAndDate
        /// Same name, same day, same market — the same purchase. What the row
        /// says it will sell on plays no part: a sheet re-exported with the
        /// Sell on column changed is the same purchase.
        case exact
        /// The same purchase written twice inside this one sheet.
        case repeatedInFile

        static func < (a: DuplicateKind, b: DuplicateKind) -> Bool { a.rawValue < b.rawValue }

        /// The same purchase, on the three columns that identify one. A name
        /// or a name-and-date match is not this: it is a row worth a glance,
        /// and it comes in unless the reader says otherwise.
        var isDuplicate: Bool { self == .exact || self == .repeatedInFile }

        /// Duplicates are off when the screen opens. Skipping them is the
        /// default because re-pasting a sheet is the ordinary case and
        /// doubling the book is never what was meant.
        var blocksByDefault: Bool { isDuplicate }

        /// The badge on the row. A `LocalizedStringKey`, not a `String`: it is
        /// copy, and a `String` here would never reach the catalogue.
        var tag: LocalizedStringKey {
            switch self {
            case .none: return ""
            case .sameNameOnly: return "Same name"
            case .sameNameAndDate: return "Same name and date, other market"
            case .exact: return "Already here"
            case .repeatedInFile: return "Twice in this sheet"
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
        /// Set when this row lands on an item the book already has instead of
        /// adding one: the same purchase, and this row says it sold. Sold wins
        /// — the sheet knows something the book does not, and a second copy of
        /// the item would be worse than either.
        var updates: String? = nil

        /// A row that overwrites is not a duplicate to skip: it is the reason
        /// the sheet was pasted. The chips above the list leave it alone.
        var isDuplicate: Bool { updates == nil && duplicate.isDuplicate }
        var isUpdate: Bool { updates != nil }
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
        /// Make a channel of that name with this fee.
        case create(rate: Double, isPoints: Bool)
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
        /// Rows that write a sale over an item the book already has, and how
        /// many of those are switched on. They have their own line above the
        /// list: "Skip them" is about repeats, and it would be a lie if it left
        /// these changing the book behind its back.
        var updateCount: Int { rows.filter(\.isUpdate).count }
        var includedUpdateCount: Int { rows.filter { $0.isUpdate && $0.include }.count }
        /// Rows the app is sure enough about to switch off on its own.
        var blockedCount: Int { rows.filter { $0.duplicate.blocksByDefault }.count }
        /// Blocked rows the user switched back on.
        var forcedDuplicateCount: Int { rows.filter { $0.duplicate.blocksByDefault && $0.include }.count }
        /// Flagged rows that will be written — what the two chips above the
        /// list are actually saying yes or no to.
        var includedDuplicateCount: Int { rows.filter { $0.isDuplicate && $0.include }.count }
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
            "Card": ["card", "paid with", "payment", "the", "thẻ", "the tin dung", "thẻ tín dụng", "カード"],
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

    /// Columns a sheet may carry that this book has no business reading, even
    /// where the words look close to something it knows. They are reported as
    /// ignored like any unrecognised column rather than quietly feeding a
    /// field: someone else's card is not the card this item was bought on, a
    /// point *rate* is not points earned, and what a thing costs new is not
    /// what it is worth now. Folded the way headers are.
    static let columnsIgnored: Set<String> = [
        "the vo", "the chong",              // Thẻ vợ / Thẻ chồng — another person's card
        "% point", "point %", "%point",     // the rate; the figure is "Earn Point"
        "new price", "gia moi",             // price new, not what it fetches now
        "loan time", "loan months",         // a plan's length lives in Wallet, not on the item
    ]

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
        // Kept as written as well as folded: the folded form is what columns
        // are matched on, but "Ignored: the vo" tells nobody which column of
        // their sheet was passed over.
        let rawHeaders = splitRow(first.element, sep: sep).map { $0.trimmingCharacters(in: .whitespaces) }
        let headerCells = rawHeaders.map { normalise($0) }
        let mapped = headerCells.map { Store.columnsIgnored.contains($0) ? nil : Store.columnAliases[$0] }

        if mapped.contains(where: { $0 == "Name" }) {
            // Headed sheet: each column is placed by what it is called, so a
            // sheet can carry three columns or all sixteen, in any order.
            preview.recognisedHeader = true
            for (i, canonical) in mapped.enumerated() {
                guard let canonical, columnAt[normalise(canonical)] == nil else { continue }
                columnAt[normalise(canonical)] = i
            }
            preview.usedColumns = Store.importColumns.filter { columnAt[normalise($0)] != nil }
            preview.ignoredHeaders = zip(rawHeaders, mapped)
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
        // Whether the sheet said *when* anything was bought. Without it every
        // row comes in dated today, and a date the app invented cannot be used
        // to tell two purchases apart.
        let hasDateColumn = columnAt[normalise("Date")] != nil

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
            else if !isBlank(value("Date")) { warnings.append("Could not read the date \"\(value("Date"))\".") }
            // An undated row still comes in, dated today — but say so: today is
            // the day Stats counts that purchase, and its points, under.
            else { warnings.append("No date in this row — it comes in dated today.") }

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
            //
            // Unless the sheet says otherwise in words: a "Sold?" column
            // reading FALSE is the book stating this is stock it still holds,
            // and a blank Sell on is then a price not decided yet, not a
            // decision to keep. What is said beats what is inferred.
            if !item.keep, !item.isSold, hasChannelColumn, item.plannedChannel.isEmpty {
                if saidUnsold {
                    warnings.append("No channel yet — it comes in for sale; add where it will sell from its own page.")
                } else {
                    item.keep = true
                    warnings.append("No channel — brought in as Keeping.")
                }
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
            var updates: String? = nil

            if let earlier = seenInFile[key], earlier.sameDay(as: item.boughtOn),
               earlier.samePlace(as: item) {
                // Two lines that agree on name, day and market. With a 購入日 in
                // the sheet that is one purchase written twice. Without one,
                // "the same day" is only today's date, which the app supplied
                // itself — and two of a thing is as likely as one typed twice,
                // so it is said and both come in.
                kind = hasDateColumn ? .repeatedInFile : .sameNameOnly
                detail = hasDateColumn
                    ? "The same purchase is already on line \(earlier.line) of this sheet."
                    : "The same name is on line \(earlier.line). With no purchase date in the sheet, two of a thing and one written twice read alike — both come in."
            } else if let match = bestMatch(for: item, key: key) {
                kind = match.kind
                detail = match.detail
                // The same purchase, and this row says it sold: the sheet is
                // ahead of the book, so it writes over the item rather than
                // being skipped as a repeat.
                if kind == .exact, item.isSold {
                    updates = match.id
                    detail = "This row says sold — it updates the one you already have."
                }
            }
            seenInFile[key] = SeenRow(line: index + 1, boughtOn: item.boughtOn,
                                      place: Store.placeKey(item))

            preview.rows.append(ImportRow(item: item, line: index + 1,
                                          warnings: warnings,
                                          duplicate: kind,
                                          duplicateDetail: detail,
                                          include: updates != nil || !kind.blocksByDefault,
                                          updates: updates))
        }
        return preview
    }

    /// Writes the included rows. Records only: card debt and wallets are
    /// typed in by hand, an import never touches them.
    @discardableResult
    func commitImport(_ preview: ImportPreview, source: String = "Pasted",
                      channelPlans: [String: ImportChannelPlan] = [:]) -> Int {
        let rows = preview.rows.filter(\.include)
        guard !rows.isEmpty else { return 0 }

        // The preview was built at paste time. Anything could have been added
        // since — including by a previous tap of this button — so the guard is
        // applied again here, against what is actually in the book now.
        // A row the user switched back on deliberately still goes in; what this
        // stops is the same paste landing twice.
        let writtenKeys = Set(data.items.map { Store.purchaseKey($0) })

        // The preview already rewrote matched names to the book's own; what
        // the rows carry now is `matched ?? written`. The plan decided on
        // screen may point that somewhere else again — at a different existing
        // channel, or at a new one under the sheet's own name — so every name
        // the rows carry is mapped once, here, before anything is written.
        var rename: [String: String] = [:]
        var createdChannels: [String] = []
        for use in preview.channels {
            let carried = use.matched ?? use.written
            let plan = channelPlans[use.written]
                ?? (use.matched.map { .use($0) } ?? .create(rate: 0, isPoints: false))
            switch plan {
            case .use(let name):
                rename[carried] = name
            case .create(let rate, let isPoints):
                rename[carried] = use.written
                guard !data.channels.contains(where: { $0.name == use.written }) else { continue }
                data.channels.append(SalesChannel(name: use.written, rate: rate, isPoints: isPoints))
                createdChannels.append(use.written)
            }
        }

        // What actually landed, not what was offered: the count on screen, the
        // history entry and the undo all have to agree with the book.
        var written: [Item] = []
        /// Items about to be overwritten, as they stand now, so undo can put
        /// them back untouched.
        var replaced: [Item] = []
        for row in rows {
            var item = row.item
            if let to = rename[item.plannedChannel] { item.plannedChannel = to }
            if let sale = item.sale, let to = rename[sale.channel] { item.sale?.channel = to }

            // A sold row on a purchase the book already holds writes over it.
            // The item keeps its id — everything pointing at it still points at
            // it — and keeps whatever the sheet had no column for.
            if let id = row.updates, let index = data.items.firstIndex(where: { $0.id == id }) {
                let before = data.items[index]
                replaced.append(before)
                data.items[index] = Store.merge(item, over: before)
                continue
            }

            // What this stops is the same paste landing twice — a row matching
            // something the book *already* held when the button was pressed.
            // It is checked against the book alone: two rows of one sheet that
            // look alike are two lines the reader wrote and the preview already
            // ruled on, and quietly dropping the second one made an import of
            // 5 rows write 3. A row switched back on deliberately still goes in.
            if !row.duplicate.blocksByDefault && writtenKeys.contains(Store.purchaseKey(item)) { continue }
            written.append(item)
        }
        // In one go, and in the sheet's own order: inserting each row at the
        // front as it was read left the book holding the sheet backwards.
        data.items.insert(contentsOf: written, at: 0)
        guard !written.isEmpty || !replaced.isEmpty else {
            // Nothing landed, so nothing should have been made for it.
            data.channels.removeAll { createdChannels.contains($0.name) }
            return 0
        }
        recordImport(written, replaced: replaced, source: source, createdChannels: createdChannels)
        save()
        return written.count + replaced.count
    }

    /// The sheet's row laid over the item the book already has. The row wins
    /// wherever it says anything — it is the newer reading — and every field a
    /// sheet has no column for, or left blank, keeps what the book knew:
    /// condition, accessories, the attribute checklist.
    static func merge(_ row: Item, over existing: Item) -> Item {
        var merged = row
        merged.id = existing.id
        if merged.categoryName.isEmpty { merged.categoryName = existing.categoryName }
        if merged.boughtFrom.isEmpty { merged.boughtFrom = existing.boughtFrom }
        if merged.cardName.isEmpty { merged.cardName = existing.cardName }
        if merged.accessories.isEmpty { merged.accessories = existing.accessories }
        if merged.condition.isEmpty { merged.condition = existing.condition }
        if merged.attributes.isEmpty { merged.attributes = existing.attributes }
        if merged.buyPrice == 0 { merged.buyPrice = existing.buyPrice }
        if merged.estimatedPrice == 0 { merged.estimatedPrice = existing.estimatedPrice }
        if merged.pointsEarned == 0 { merged.pointsEarned = existing.pointsEarned }
        if merged.plannedChannel.isEmpty { merged.plannedChannel = existing.plannedChannel }
        if merged.shippingFee == nil { merged.shippingFee = existing.shippingFee }
        if merged.pointRateOverride == nil { merged.pointRateOverride = existing.pointRateOverride }
        // Sold wins, and a sold item is not being kept.
        if merged.isSold { merged.keep = false }
        return merged
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
    /// Nothing else moved when they came in, so nothing else moves now.
    @discardableResult
    func deleteImportBatch(_ batch: ImportBatch) -> Int {
        let ids = Set(batch.itemIDs)
        let going = data.items.filter { ids.contains($0.id) }
        data.items.removeAll { ids.contains($0.id) }
        // An import that wrote a sale over an item did not add anything to
        // remove: undo puts the item back as it was instead.
        var restored = 0
        for before in batch.updatedItems ?? [] {
            guard let index = data.items.firstIndex(where: { $0.id == before.id }) else { continue }
            data.items[index] = before
            restored += 1
        }
        // A channel this import invented goes back out with it — unless
        // something else has since been pointed at it, which makes it the
        // user's channel rather than the import's.
        for name in batch.createdChannels ?? [] {
            let stillUsed = data.items.contains {
                $0.plannedChannel == name || $0.sale?.channel == name
            }
            guard !stillUsed else { continue }
            data.channels.removeAll { $0.name == name }
        }
        if !going.isEmpty || restored > 0 {
            data.ledger.insert(LedgerEntry(date: .now,
                                           label: "Removed \(going.count) imported item(s), put \(restored) back",
                                           detail: batch.source, amount: 0, kind: "x"), at: 0)
        }
        data.importBatches?.removeAll { $0.id == batch.id }
        save()
        return going.count + restored
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
        let chars = Array(line)
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

    /// Name, day and where it was bought together — one purchase. Deliberately
    /// three fields and no more: the planned channel ("Sell on") is never part
    /// of it, so the same purchase re-exported with a different channel is
    /// still the same purchase, and price is not either, since a re-typed
    /// figure does not make a second thing.
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
    /// that identify a purchase: what it is (Item), when it was bought (購入日)
    /// and where from (Buy on Market). Nothing else counts — a row that differs
    /// only in "Sell on" is the same purchase, flagged and left off.
    private func bestMatch(for item: Item, key: String) -> (kind: DuplicateKind, detail: String, id: String)? {
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
                    : "Already here: bought \(hit.boughtOn.formatted(date: .abbreviated, time: .omitted)) from \(where_).",
                    hit.id)
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
            return (.sameNameAndDate, "Same name and the same purchase date — \(where_).", hit.id)
        }

        // Name alone. Two of the same lens bought at different times are two
        // lenses, so this is a flag rather than a block.
        let hit = sameName[0]
        return (.sameNameOnly,
                "You have one by this name, bought \(hit.boughtOn.formatted(date: .abbreviated, time: .omitted)).",
                hit.id)
    }

    /// Where an item was bought — the sheet's "Buy on Market" — folded for
    /// comparison. The card used to stand in when no shop was recorded. It does
    /// not any more: a purchase is the same purchase by what it is, when it was
    /// bought and where from, and letting the card decide meant two rows with
    /// no shop on them were told apart by which card was typed against each,
    /// which is not what makes them two things.
    static func placeKey(_ item: Item) -> String { duplicateKey(item.boughtFrom) }

    static func placeLabel(_ item: Item) -> String { item.boughtFrom }

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

    private func recordImport(_ items: [Item], replaced: [Item] = [], source: String,
                              createdChannels: [String]) {
        data.ledger.insert(LedgerEntry(date: .now,
                                       label: "Imported \(items.count) item(s), updated \(replaced.count)",
                                       detail: source, amount: 0, kind: "x"), at: 0)
        // `addedToDebt` stays in the record for books written when imports
        // could raise card debt; new batches never do.
        let batch = ImportBatch(date: .now, itemIDs: items.map(\.id), itemNames: items.map(\.name),
                                addedToDebt: false, source: source,
                                createdChannels: createdChannels.isEmpty ? nil : createdChannels,
                                createdWallets: nil,
                                updatedItems: replaced.isEmpty ? nil : replaced)
        data.importBatches = [batch] + (data.importBatches ?? [])
    }
}

// MARK: - Example sheet

extension Store {

    /// What each column means, in the order Export writes them. Shown on the
    /// import screen so a sheet can be built by hand without guesswork.
    /// `column` is the header keyword a sheet is matched against, so it stays
    /// English whatever the app is showing; only the explanation is copy.
    static let importColumnHelp: [(column: String, help: LocalizedStringKey)] = [
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
        // Whatever this book actually holds — a lens, a coat, a synthesiser.
        // An example that names a camera teaches a vocabulary half the people
        // reading it do not use, and a blank cell is valid in every one of
        // these columns anyway.
        let category = data.categories.first?.name ?? ""
        let names = data.items.prefix(2).map(\.name)
        let firstName = names.first ?? "Something you bought"
        let secondName = names.count > 1 ? names[1] : "Something you sold"
        let shop = data.items.first { !$0.boughtFrom.isEmpty }?.boughtFrom ?? ""
        let attributes = (data.categories.first?.attributes ?? []).prefix(2)
            .map { "\($0.name)=\($0.kind == .bool ? "Yes" : "")" }
            .joined(separator: "; ")
        let today = Date.now
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "d/M/yyyy"
        let bought = formatter.string(from: today.addingTimeInterval(-60 * 60 * 24 * 30))
        let sold = formatter.string(from: today)

        let rows = [
            Store.exportColumns,
            [firstName, category, "for sale", bought, "48000", shop, card,
             "72000", cashChannel, "1000", "", "", "", "", "Box, spare", "Mint", attributes],
            [secondName, category, "sold", bought, "398000", shop, card,
             "430000", cashChannel, "1000", "432000", sold, "", "", "", "", ""],
        ]
        return rows.map { $0.joined(separator: "\t") }.joined(separator: "\n")
    }
}
