import Foundation
import Observation

/// Single source of truth. Everything the UI reads is derived here so the
/// numbers can never disagree between screens.
@Observable
final class Store {
    var data: AppData

    private let fileName = "mochi.json"

    init(data: AppData = .sample) {
        self.data = data
        load()
    }

    // MARK: - Money helpers

    func format(_ yen: Int) -> String {
        let sign = yen < 0 ? "-" : ""
        let n = abs(yen).formatted(.number.grouping(.automatic))
        return "\(sign)\(data.currency)\(n)"
    }

    func channel(named name: String) -> SalesChannel? {
        data.channels.first { $0.name == name }
    }

    /// What a sale of `item` through `channelName` actually puts in a wallet
    /// (or in points, for a point channel).
    func netProceeds(_ item: Item, channelName: String) -> Int {
        guard let ch = channel(named: channelName) else { return item.estimatedPrice }
        if ch.isPoints {
            let rate = item.pointRateOverride ?? ch.rate
            return Int(Double(item.estimatedPrice) * (1 + rate / 100))
        }
        return Int(Double(item.estimatedPrice) * (1 - ch.rate / 100))
    }

    // MARK: - Derived totals

    var unsold: [Item] { data.items.filter { !$0.isSold } }
    var forSale: [Item] { unsold.filter { !$0.keep } }
    var keeping: [Item] { unsold.filter { $0.keep } }

    /// Every wallet is cash. Points are not.
    var cash: Int { data.wallets.reduce(0) { $0 + $1.balance } }
    var debt: Int { data.cards.reduce(0) { $0 + $1.debt } }
    /// The headline number: what you would have if every card bill came due today.
    var realCash: Int { cash - debt }

    /// Proceeds if every item marked for sale sold at its estimate through its
    /// planned channel. Items marked "keep" are excluded.
    var liquidation: Int { forSale.reduce(0) { $0 + netProceeds($1, channelName: $1.plannedChannel) } }
    var cashAfterSellingAll: Int { realCash + liquidation }

    var inventoryCost: Int { forSale.reduce(0) { $0 + $1.buyPrice } }
    var expectedProfit: Int { liquidation - inventoryCost }

    /// Due dates in payment order, treating a day before the 15th as next month.
    var dueDays: [Int] {
        Set(data.cards.map(\.dueDay)).sorted {
            ($0 < 15 ? $0 + 31 : $0) < ($1 < 15 ? $1 + 31 : $1)
        }
    }

    struct DueCycle: Identifiable {
        var id: Int { day }
        let day: Int
        let cards: [CreditCard]
        let total: Int
        let mine: Int
        let onBehalf: Int
        /// Cash left after paying this date, running down from today's cash.
        let cashAfter: Int
        var isShort: Bool { cashAfter < 0 }
    }

    /// The Overview drawdown: cash minus each due date in turn.
    var dueCycles: [DueCycle] {
        var running = cash
        return dueDays.map { day in
            let cs = data.cards.filter { $0.dueDay == day }
            let mine = cs.filter { $0.ownerID == "me" }.reduce(0) { $0 + $1.debt }
            let other = cs.filter { $0.ownerID != "me" }.reduce(0) { $0 + $1.debt }
            let total = mine + other
            running -= total
            return DueCycle(day: day, cards: cs.filter { $0.debt > 0 }, total: total,
                            mine: mine, onBehalf: other, cashAfter: running)
        }
    }

    /// Highest-net items first, until the shortfall is covered. Empty when cash
    /// already covers every bill — the Overview hides the card in that case.
    var sellSuggestions: [Item] {
        var need = max(0, debt - cash)
        guard need > 0 else { return [] }
        var out: [Item] = []
        for item in forSale.sorted(by: { netProceeds($0, channelName: $0.plannedChannel) > netProceeds($1, channelName: $1.plannedChannel) }) {
            if need <= 0 { break }
            out.append(item)
            need -= netProceeds(item, channelName: item.plannedChannel)
        }
        return out
    }

    // MARK: - Mutations

    /// Buying on a card raises that card's debt by the purchase price.
    func addItem(_ item: Item) {
        data.items.insert(item, at: 0)
        if let ix = data.cards.firstIndex(where: { $0.name == item.cardName }) {
            data.cards[ix].debt += item.buyPrice
        }
        data.ledger.append(LedgerEntry(date: item.boughtOn, label: item.name,
                                       detail: item.cardName, amount: -item.buyPrice, kind: "out"))
        save()
    }

    func update(_ item: Item) {
        guard let ix = data.items.firstIndex(where: { $0.id == item.id }) else { return }
        data.items[ix] = item
        save()
    }

    /// Confirming a sale: record it, then credit the destination wallet
    /// (or the point wallet for a point channel).
    func sell(_ item: Item, channelName: String, price: Int? = nil) {
        guard let ix = data.items.firstIndex(where: { $0.id == item.id }) else { return }
        let listed = price ?? item.estimatedPrice
        var copy = item
        copy.estimatedPrice = listed
        let net = netProceeds(copy, channelName: channelName)
        let ch = channel(named: channelName)
        data.items[ix].sale = SaleRecord(price: listed, channel: channelName, net: net, date: .now)

        if ch?.isPoints == true {
            if let pix = data.pointWallets.firstIndex(where: { $0.name.contains(ch?.name.components(separatedBy: " ").first ?? "") }) {
                data.pointWallets[pix].points += net
            }
        } else {
            let dest = (ch?.destination.isEmpty == false ? ch!.destination : data.wallets.first?.name) ?? ""
            if let wix = data.wallets.firstIndex(where: { $0.name == dest }) {
                data.wallets[wix].balance += net
            }
        }
        data.ledger.append(LedgerEntry(date: .now, label: item.name,
                                       detail: channelName, amount: net, kind: "in"))
        save()
    }

    /// Wallet to wallet. The source loses the full amount, the destination
    /// receives amount − fee (¥210 for a Mercari/Rakuma bank withdrawal).
    func transfer(from: String, to: String, amount: Int, fee: Int) {
        guard from != to, amount > 0 else { return }
        if let f = data.wallets.firstIndex(where: { $0.name == from }) { data.wallets[f].balance -= amount }
        if let t = data.wallets.firstIndex(where: { $0.name == to }) { data.wallets[t].balance += (amount - fee) }
        let detail = fee > 0 ? "\(from) → \(to) · 手数料 \(format(fee))" : "\(from) → \(to)"
        data.ledger.append(LedgerEntry(date: .now, label: "Wallet transfer", detail: detail, amount: amount, kind: "x"))
        save()
    }

    // MARK: - Export

    enum ExportFormat: String, CaseIterable { case tsv, csv }
    enum ExportScope: String, CaseIterable { case all, forSale, sold }

    static let exportColumns = ["Name", "Category", "Status", "Date", "Buy", "Card", "Est",
                                "Channel", "Sold price", "Sold date", "Net", "Profit",
                                "Accessories", "Condition", "Attributes"]

    func exportText(format: ExportFormat, scope: ExportScope) -> String {
        let df = DateFormatter(); df.dateFormat = "d/M/yyyy"
        let rows = data.items.filter {
            switch scope {
            case .all: return true
            case .sold: return $0.isSold
            case .forSale: return !$0.isSold && !$0.keep
            }
        }
        let sep = format == .csv ? "," : "\t"
        func cell(_ v: Any) -> String {
            let s = String(describing: v)
            if format == .csv, s.contains(where: { ",\"\n".contains($0) }) {
                return "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
            }
            return s.replacingOccurrences(of: "\t", with: " ")
        }
        let body = rows.map { i -> String in
            let net = i.sale?.net ?? netProceeds(i, channelName: i.plannedChannel)
            let status = i.isSold ? "sold" : (i.keep ? "keep" : "for sale")
            let cells: [Any] = [i.name, i.categoryName, status, df.string(from: i.boughtOn),
                                i.buyPrice, i.cardName, i.estimatedPrice, i.plannedChannel,
                                i.sale?.price ?? "", i.sale.map { df.string(from: $0.date) } ?? "",
                                net, net - i.buyPrice, i.accessories, i.condition,
                                i.attributes.map { "\($0[0])=\($0.count > 1 ? $0[1] : "")" }.joined(separator: "; ")]
            return cells.map(cell).joined(separator: sep)
        }
        return ([Store.exportColumns.joined(separator: sep)] + body).joined(separator: "\n")
    }

    // MARK: - Persistence (local file + iCloud Documents copy)

    private var localURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(fileName)
    }

    /// nil when the user is not signed into iCloud or the container is missing.
    private var iCloudURL: URL? {
        FileManager.default.url(forUbiquityContainerIdentifier: nil)?
            .appendingPathComponent("Documents").appendingPathComponent(fileName)
    }

    func save() {
        guard let blob = try? JSONEncoder().encode(data) else { return }
        try? blob.write(to: localURL, options: .atomic)
        if data.autoBackup { backupToCloud(blob) }
    }

    func load() {
        guard let blob = try? Data(contentsOf: localURL),
              let decoded = try? JSONDecoder().decode(AppData.self, from: blob) else { return }
        data = decoded
    }

    func backupNow() {
        guard let blob = try? JSONEncoder().encode(data) else { return }
        backupToCloud(blob)
    }

    private func backupToCloud(_ blob: Data) {
        guard let url = iCloudURL else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try? blob.write(to: url, options: .atomic)
        data.lastBackup = .now
    }

    func restoreFromCloud() -> Bool {
        guard let url = iCloudURL, let blob = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(AppData.self, from: blob) else { return false }
        data = decoded
        save()
        return true
    }
}
