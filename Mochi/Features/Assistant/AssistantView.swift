import SwiftUI
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Ask Mochi. Answers come from the book's own figures, worked out by
/// `Finance` — the on-device model only chooses which figure is being asked
/// for and puts it in a sentence, so it cannot invent a number. Without Apple
/// Intelligence the same questions are offered as buttons and answered the
/// same way.
struct AssistantView: View {
    @Environment(Store.self) private var store
    @State private var messages: [Message] = []
    @State private var draft = ""
    @State private var thinking = false

    struct Message: Identifiable {
        let id = UUID()
        let mine: Bool
        let text: String
        var source: String? = nil
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: Organic.Space.l) {
                    Label(ReceiptReader.modelAvailable ? "On this iPhone · reads your book, never changes it"
                                                       : "Reads your book, never changes it", systemImage: "lock")
                        .font(Organic.caption).foregroundStyle(Organic.n600)
                    ForEach(messages) { m in bubble(m) }
                    if thinking { ProgressView().padding(.leading, 8) }
                    FlowRow(spacing: 8) {
                        ForEach(Question.allCases, id: \.self) { q in
                            Button { ask(q.text, as: q) } label: { Chip(label: Text(verbatim: q.text), selected: false) }
                                .buttonStyle(.plain)
                        }
                    }
                }
                .padding(Organic.Space.gutter)
                .readableWidth()
            }
            HStack(spacing: 8) {
                TextField("Ask about your money", text: $draft)
                    .padding(.horizontal, 14).frame(minHeight: 44)
                    .background(Organic.n100, in: Capsule())
                    .overlay(Capsule().stroke(Organic.n400, lineWidth: Organic.stroke))
                    .submitLabel(.send)
                    .onSubmit { send() }
                Button { send() } label: {
                    Image(systemName: "arrow.up").font(Organic.rowValue).frame(width: 44, height: 44)
                        .background(Organic.accent, in: Circle()).foregroundStyle(.white)
                }
                .accessibilityLabel("Send")
            }
            .padding(Organic.Space.gutter)
            .background(Organic.bg)
            .overlay(alignment: .top) { Hairline() }
        }
        .background(Organic.bg)
        .navigationTitle("Ask Mochi")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func bubble(_ m: Message) -> some View {
        HStack {
            if m.mine { Spacer(minLength: 40) }
            VStack(alignment: .leading, spacing: 6) {
                Text(verbatim: m.text).font(Organic.body)
                if let s = m.source { Text(verbatim: s).font(Organic.meta).foregroundStyle(m.mine ? .white.opacity(0.7) : Organic.n600) }
            }
            .padding(12)
            .background(m.mine ? Organic.n900 : Organic.n100, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(m.mine ? .clear : Organic.n300, lineWidth: Organic.stroke))
            .foregroundStyle(m.mine ? Organic.bg : Organic.text)
            if !m.mine { Spacer(minLength: 40) }
        }
    }

    private func send() {
        let q = draft.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }
        draft = ""
        ask(q, as: nil)
    }

    private func ask(_ text: String, as known: Question?) {
        messages.append(Message(mine: true, text: text))
        thinking = true
        Task {
            var q = known
            if q == nil { q = await Question.classify(text) }
            let question = q ?? Question.guess(text)
            let (answer, source) = question.answer(store, question: text)
            thinking = false
            messages.append(Message(mine: false, text: answer, source: source))
        }
    }

    /// The questions the book can answer exactly. The model only picks one.
    enum Question: String, CaseIterable {
        case have, spentThisMonth, eatingOut, nextPayment, whoOwesMe, subscriptions, belongings, netWorth

        var text: String {
            switch self {
            case .have: return String(localized: "How much do I have?")
            case .spentThisMonth: return String(localized: "What did I spend this month?")
            case .eatingOut: return String(localized: "Biggest category this month?")
            case .nextPayment: return String(localized: "What do I pay next?")
            case .whoOwesMe: return String(localized: "Who still owes me?")
            case .subscriptions: return String(localized: "What renews this month?")
            case .belongings: return String(localized: "What do my things cost me?")
            case .netWorth: return String(localized: "What am I worth?")
            }
        }

        /// Words that point at a question, for phones without the model.
        static func guess(_ text: String) -> Question {
            let t = text.lowercased()
            if ["owe", "nợ", "貸"].contains(where: t.contains) { return .whoOwesMe }
            if ["renew", "subscription", "gia hạn", "サブスク"].contains(where: t.contains) { return .subscriptions }
            if ["pay next", "due", "trả", "支払"].contains(where: t.contains) { return .nextPayment }
            if ["worth", "net", "tài sản", "資産"].contains(where: t.contains) { return .netWorth }
            if ["belong", "đồ", "持ち物"].contains(where: t.contains) { return .belongings }
            if ["category", "eating", "ăn", "food", "食"].contains(where: t.contains) { return .eatingOut }
            if ["spent", "spend this", "tiêu", "使"].contains(where: t.contains) { return .spentThisMonth }
            return .have
        }

        static func classify(_ text: String) async -> Question? {
            #if canImport(FoundationModels)
            if #available(iOS 26, *), ReceiptReader.modelAvailable {
                let names = Question.allCases.map(\.rawValue).joined(separator: ", ")
                let session = LanguageModelSession(instructions: "Pick the one question id that matches the user's question. Answer with the id only, from: \(names).")
                if let r = try? await session.respond(to: text) {
                    return Question(rawValue: r.content.trimmingCharacters(in: .whitespacesAndNewlines))
                }
            }
            #endif
            return nil
        }

        func answer(_ store: Store, question: String) -> (String, String) {
            switch self {
            case .have:
                let total = store.holdings.total
                let line = store.cardsDue > 0
                    ? String(localized: "\(store.format(total)); the cards due take \(store.format(store.cardsDue)), leaving \(store.format(store.leftAfterCards)).")
                    : String(localized: "\(store.format(total)), with no card due this round.")
                return (line, String(localized: "From Home · You have"))
            case .spentThisMonth:
                let now = store.spending(in: store.thisMonth), last = store.spending(in: store.lastMonth)
                return (String(localized: "\(store.format(now)) so far this month; last month was \(store.format(last)). Belongings bought are not in it."),
                        String(localized: "From Spending"))
            case .eatingOut:
                let top = store.spendingByCategory(in: store.thisMonth).first
                return (top.map { String(localized: "\($0.name): \(store.format($0.amount)) across \($0.count) transactions.") }
                            ?? String(localized: "Nothing spent this month yet."),
                        String(localized: "From Spending · by category"))
            case .nextPayment:
                let d = store.paymentsDue.first { $0.amount < 0 }
                return (d.map { String(localized: "\($0.names.joined(separator: ", ")) on \($0.date.formatted(.dateTime.day().month(.abbreviated))): \(store.format(-$0.amount)). Cash after: \(store.format($0.balanceAfter)).") }
                            ?? String(localized: "Nothing due before the horizon."),
                        String(localized: "From Coming up"))
            case .whoOwesMe:
                let owed = store.data.loans.filter { $0.direction > 0 && $0.amount > 0 }
                return (owed.isEmpty ? String(localized: "Nobody owes you anything.")
                                     : owed.map { "\($0.person) \($0.currency == "JPY" ? store.format($0.amount) : "\($0.amount.formatted()) ₫")" }.joined(separator: " · "),
                        String(localized: "From People"))
            case .subscriptions:
                let cal = Calendar.current
                let soon = store.subscriptions.filter { cal.isDate(Finance.nextOccurrence($0, after: .now), equalTo: .now, toGranularity: .month) }
                return (soon.isEmpty ? String(localized: "Nothing else renews this month.")
                                     : soon.map { "\($0.name) \(store.format($0.amount))" }.joined(separator: " · "),
                        String(localized: "From Subscriptions"))
            case .belongings:
                return (String(localized: "Your belongings are worth \(store.format(store.belongingsWorth)) · \(store.monthlyCostLine(store.belongingsMonthlyCost))."),
                        String(localized: "From Belongings"))
            case .netWorth:
                let w = store.netWorth
                return (String(localized: "\(store.format(w.total)): \(store.format(w.assets)) you have less \(store.format(w.liabilities)) you owe."),
                        String(localized: "From Net worth"))
            }
        }
    }
}

// MARK: - Household

/// Share the book with a partner through iCloud. The sharing itself needs the
/// app's iCloud container, which is tied to the developer team; until that is
/// switched on, this screen keeps the choices and says so.
struct HouseholdView: View {
    @Environment(Store.self) private var store
    @State private var h = Household()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Organic.Space.l) {
                Text("One book on two iPhones, through iCloud").font(Organic.caption).foregroundStyle(Organic.n600)
                if !CloudSync.isEnabled {
                    Banner(text: "Sharing turns on once the app’s iCloud container is set up in Xcode. Your choices here are kept until then.",
                           symbol: "icloud.slash", tone: .warn)
                }
                Card {
                    FormField("Partner’s name", text: $h.partnerName)
                    Text(verbatim: h.partnerState.isEmpty ? String(localized: "Not invited yet") : h.partnerState)
                        .font(Organic.caption).foregroundStyle(Organic.n600).padding(.top, 4)
                }
                ListHeading(title: "What they see", trailing: String(localized: "change any time"))
                Card(padding: .list) {
                    ForEach(store.accountNames, id: \.self) { name in
                        Toggle(isOn: Binding(get: { h.sharedAccounts.contains(name) },
                                             set: { on in if on { h.sharedAccounts.append(name) } else { h.sharedAccounts.removeAll { $0 == name } } })) {
                            Text(verbatim: name).font(Organic.row)
                        }
                        .tint(Organic.info).padding(.vertical, 8)
                        .overlay(alignment: .top) { Hairline() }
                    }
                    Toggle("Goals", isOn: $h.shareGoals).font(Organic.row).tint(Organic.info).padding(.vertical, 8)
                        .overlay(alignment: .top) { Hairline() }
                    Toggle("Bills on the Every month list", isOn: $h.shareBills).font(Organic.row).tint(Organic.info).padding(.vertical, 8)
                        .overlay(alignment: .top) { Hairline() }
                }
                HelpText("Shared through your own iCloud. One price for the household: your partner does not pay again. Each transaction says who added it.")
                PrimaryButton(title: CloudSync.isEnabled ? "Invite by message" : "Save") {
                    if !h.partnerName.isEmpty && h.partnerState.isEmpty && CloudSync.isEnabled { h.partnerState = "invited" }
                    store.setHousehold(h)
                }
            }
            .padding(Organic.Space.gutter)
            .readableWidth()
        }
        .background(Organic.bg)
        .navigationTitle("Household")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { h = store.household }
    }
}
