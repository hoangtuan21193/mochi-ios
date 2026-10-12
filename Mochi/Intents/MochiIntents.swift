import AppIntents
import SwiftUI

/// Siri, Shortcuts, Spotlight and the Action button. Each intent reads the
/// same `Store` the screens do, so what Siri says is what Home shows. Money
/// figures ask for Face ID on a locked phone; adding a spend works locked and
/// waits in To review.

/// What you have, as Home heads with it (decision #36). The type keeps its
/// old name so shortcuts made with it still run.
struct SafeToSpendIntent: AppIntent {
    static let title: LocalizedStringResource = "How much do I have"
    static let description = IntentDescription("What you have, from the places counted on Home, and what is left once the cards due are paid.")
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let store = Store.shared
        store.postDueSchedules()
        let total = store.holdings.total
        let line = store.cardsDue > 0
            ? String(localized: "Cards due \(store.format(store.cardsDue)) · \(store.format(store.leftAfterCards)) left after")
            : String(localized: "No card due this round")
        return .result(dialog: "\(store.format(total)). \(line).") {
            IntentSnippet(title: String(localized: "You have"), value: store.format(total), line: line)
        }
    }
}

struct NextPaymentIntent: AppIntent {
    static let title: LocalizedStringResource = "What do I pay next"
    static let description = IntentDescription("The next payments and the cash left after them.")
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let store = Store.shared
        let due = Array(store.paymentsDue.filter { $0.amount < 0 }.prefix(2))
        guard let first = due.first else {
            return .result(dialog: "Nothing is due before the horizon.") {
                IntentSnippet(title: String(localized: "Coming up"), value: "—", line: String(localized: "Nothing due"))
            }
        }
        let name = first.names.first ?? String(localized: "A payment")
        return .result(dialog: "\(name) on \(first.date.formatted(.dateTime.day().month(.abbreviated))): \(store.format(-first.amount)).") {
            IntentSnippet(title: String(localized: "Coming up"),
                          value: store.format(-first.amount),
                          line: due.map { "\($0.date.formatted(.dateTime.day().month(.abbreviated))) · \($0.names.first ?? "") \(store.format(-$0.amount))" }
                            .joined(separator: "\n") + "\n" + String(localized: "Cash after: \(store.format(due.last!.balanceAfter))"))
        }
    }
}

struct AddSpendIntent: AppIntent {
    static let title: LocalizedStringResource = "Add a spend"
    static let description = IntentDescription("Records a spend; the category comes from your rules or waits for you in To review.")

    @Parameter(title: "Amount") var amount: Int
    @Parameter(title: "Shop") var merchant: String?

    static var parameterSummary: some ParameterSummary { Summary("Add \(\.$amount) at \(\.$merchant)") }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = Store.shared
        var t = Transaction(date: .now, amount: -abs(amount), kind: .spend,
                            account: store.data.wallets.first?.name ?? "", merchant: merchant ?? "")
        store.fill(&t)
        t.needsReview = t.category.isEmpty
        store.addTransaction(t, applyRules: false)
        return .result(dialog: t.category.isEmpty
                       ? "Added \(store.format(amount)). It waits in To review for a category."
                       : "Added \(store.format(amount)) to \(t.category).")
    }
}

/// The Shortcuts "Transaction" automation hands over what Apple Pay just
/// charged. With Ask me on, Mochi shows the spend over whatever is on screen
/// and asks for the category: Save books it, Later (or no answer) leaves it in
/// To review with the category Auto-fill guessed. The type keeps its old name
/// so automations made with it still run.
struct LogApplePayIntent: AppIntent {
    static let title: LocalizedStringResource = "Add an Apple Pay spend"
    static let description = IntentDescription("For the Shortcuts Wallet automation: pass Amount, Merchant and Card.")
    static let isDiscoverable = true

    /// Text, not a number: the Wallet automation's Amount is a formatted
    /// currency ("¥1,200"), and Shortcuts' own conversion of it to a number
    /// can come through as nothing. `CardEmailParser.tapAmount` reads it.
    @Parameter(title: "Amount") var amount: String
    @Parameter(title: "Merchant") var merchant: String
    @Parameter(title: "Card") var card: String?
    @Parameter(title: "Ask me", description: "Show the spend and ask for its category. Off saves it quietly to To review.",
               default: true) var ask: Bool
    @Parameter(title: "Category") var category: String?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = Store.shared
        guard let paid = CardEmailParser.tapFigure(amount) else {
            return .result(dialog: "Mochi could not read an amount in “\(amount)”, so nothing was added.")
        }
        var t = Transaction(date: .now, amount: -Int(paid.rounded()), kind: .spend,
                            account: Self.account(for: card, store), merchant: merchant, source: .applePay)
        // Paid abroad: the figure is kept as charged and turned into the
        // book's at the day's rate, looked up if the book has none yet. The
        // card bills its own rate later; this is the estimate until then.
        var foreign: String?
        if let code = CardEmailParser.tapCurrency(amount), code != store.currency.code {
            foreign = code
            t.currency = code
            t.foreignAmount = paid
            t.rate = await store.rate(for: code)
            t.amount = -(t.rate.map { Finance.convert(paid, rate: $0) } ?? 0)
        }
        let charged = foreign.map { Currency.foreign(paid, code: $0) } ?? store.format(-t.amount)
        // The card's email may have booked this tap already.
        let already = if let foreign {
            Finance.sameSpend(store.data, paid: paid, currency: foreign, account: t.account, on: t.date)
        } else {
            Finance.sameSpend(store.data, amount: -t.amount, account: t.account, on: t.date)
        }
        if already != nil {
            return .result(dialog: "\(charged) at \(merchant) is already in Mochi.")
        }
        store.fill(&t)
        // No rate yet means no yen figure: nothing to confirm, only a rate to type.
        if let foreign, t.rate == nil {
            t.needsReview = true
            store.addTransaction(t, applyRules: false)
            return .result(dialog: "\(charged) at \(merchant) is in To review. Type the \(foreign) rate there to count it.")
        }
        let line = foreign == nil ? "\(charged) at \(merchant)" : "\(charged) (≈ \(store.format(-t.amount))) at \(merchant)"
        guard ask else {
            t.needsReview = true
            store.addTransaction(t, applyRules: false)
            return .result(dialog: "\(line) is in To review.")
        }
        do {
            if t.category.isEmpty {
                // Nothing to guess from: the list straight away.
                let names = store.spendingCategories.map(\.name)
                t.category = try await $category.requestDisambiguation(among: names, dialog: "Category for \(line)") ?? ""
            } else {
                try await requestConfirmation(
                    result: .result(dialog: "\(line) on \(t.account.isEmpty ? String(localized: "Apple Pay") : t.account). Save it as \(t.category)?") {
                        IntentSnippet(title: String(localized: "Just paid"), value: charged,
                                      line: "\(merchant) · \(t.account)\n" + String(localized: "Category \(t.category)"))
                    },
                    confirmationActionName: .custom(acceptLabel: "Save", acceptAlternatives: [],
                                                    denyLabel: "Later", denyAlternatives: []),
                    showPrompt: false)
            }
            t.needsReview = t.category.isEmpty
            store.addTransaction(t, applyRules: false)
            return .result(dialog: t.needsReview ? "\(line) is in To review." : "Saved \(line) as \(t.category).")
        } catch {
            // Later, or no answer: kept, waiting for a look.
            t.needsReview = true
            store.addTransaction(t, applyRules: false)
            return .result(dialog: "\(line) is in To review.")
        }
    }

    /// The card Apple Pay names, as the book calls it: "楽天カード" is the
    /// Rakuten Card. Empty when no card, or more than one, fits — the review
    /// asks then rather than booking it on the wrong one.
    @MainActor
    static func account(for name: String?, _ store: Store) -> String {
        guard let name, !name.isEmpty else { return "" }
        if let exact = store.accountNames.first(where: { name.localizedCaseInsensitiveContains($0) || $0.localizedCaseInsensitiveContains(name) }) {
            return exact
        }
        let lower = name.lowercased()
        guard let issuer = CardEmailParser.issuers.first(where: { $0.says.contains { lower.contains($0.lowercased()) } }) else { return "" }
        return CardEmailParser.card(for: CardEmail(date: nil, merchant: "", amount: 0, issuer: issuer.name),
                                    in: store.data.cards)?.name ?? ""
    }
}

/// The Shortcuts Mail automation hands over a card's usage email. It is read
/// on the phone and becomes a spend in To review; an email that is not a
/// card spend books nothing.
struct ReadCardEmailIntent: AppIntent {
    static let title: LocalizedStringResource = "Read a card email"
    static let description = IntentDescription("For the Shortcuts Email automation: pass the email’s Subject and Body.")
    static let isDiscoverable = true

    @Parameter(title: "Subject") var subject: String
    @Parameter(title: "Body") var body: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = Store.shared
        guard let t = store.addCardEmail(subject: subject, body: body) else {
            return .result(dialog: "This email has no card spend Mochi can read.")
        }
        return .result(dialog: "\(store.format(-t.amount)) at \(t.merchant) is in To review.")
    }
}

/// Buy advice from the Action button or Siri, standing in the shop.
struct BuyAdviceIntent: AppIntent {
    static let title: LocalizedStringResource = "Buy advice"
    static let description = IntentDescription("Opens Buy advice: the most to pay and still make what you want.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        Store.shared.pendingBuyAdvice = true
        return .result()
    }
}

struct ScanReceiptIntent: AppIntent {
    static let title: LocalizedStringResource = "Scan a receipt"
    static let description = IntentDescription("Opens the receipt camera.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        Store.shared.pendingCapture = true
        return .result()
    }
}

struct WhoOwesMeIntent: AppIntent {
    static let title: LocalizedStringResource = "Who owes me"
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = Store.shared
        let owed = store.data.loans.filter { $0.direction > 0 && $0.amount > 0 && $0.currency == "JPY" }
        if owed.isEmpty { return .result(dialog: "Nobody owes you anything.") }
        let list = owed.map { "\($0.person) \(store.format($0.amount))" }.joined(separator: ", ")
        return .result(dialog: "\(list).")
    }
}

struct MochiShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: SafeToSpendIntent(), phrases: ["How much do I have in \(.applicationName)",
                                                           "How much can I spend in \(.applicationName)"],
                    shortTitle: "You have", systemImageName: "yensign.circle")
        AppShortcut(intent: NextPaymentIntent(), phrases: ["What do I pay next in \(.applicationName)"],
                    shortTitle: "Next payment", systemImageName: "calendar")
        AppShortcut(intent: AddSpendIntent(), phrases: ["Add a spend in \(.applicationName)"],
                    shortTitle: "Add a spend", systemImageName: "plus.circle")
        AppShortcut(intent: ScanReceiptIntent(), phrases: ["Scan a receipt in \(.applicationName)"],
                    shortTitle: "Scan receipt", systemImageName: "doc.text.viewfinder")
        AppShortcut(intent: BuyAdviceIntent(), phrases: ["Buy advice in \(.applicationName)"],
                    shortTitle: "Buy advice", systemImageName: "lightbulb")
        AppShortcut(intent: WhoOwesMeIntent(), phrases: ["Who owes me in \(.applicationName)"],
                    shortTitle: "Who owes me", systemImageName: "person.2")
    }
}

/// What Siri shows under the spoken answer.
struct IntentSnippet: View {
    let title: String
    let value: String
    let line: String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(verbatim: "MOCHI · \(title.uppercased())").font(Organic.metaStrong).foregroundStyle(Organic.n600)
            Text(verbatim: value).font(Organic.hero)
            Text(verbatim: line).font(Organic.value).foregroundStyle(Organic.n600)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
