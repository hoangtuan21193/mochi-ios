import SwiftUI

/// "Move ¥66,000", pushed from Home's banner: what the move does to both
/// accounts, why that amount and that day, and a button that books it once
/// the user has made it in the bank's own app. Mochi never moves money.
struct MoveSuggestionView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let suggestion: Finance.TransferSuggestion

    @State private var amount = 0
    @State private var date = Date.now
    @State private var reminded = false

    private func short(_ d: Date) -> String { d.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)) }

    /// "your SMBC", "Linh’s MUFG": the account with whose it is.
    private func whose(_ account: String) -> String {
        guard let w = store.data.wallets.first(where: { $0.name == account }), w.ownerID != "me",
              let owner = store.owner(id: w.ownerID) else { return String(localized: "your \(account)") }
        return String(localized: "\(owner.name)’s \(account)")
    }

    /// The days between the deadline and the debit that are not business days,
    /// said the way a person would: "the 10th and 11th are a weekend and the
    /// 12th is a holiday".
    private var whyThatDay: String? {
        let cal = Calendar.current
        // Past the last business day: listing the weekend still ahead of a
        // deadline that is today would say nothing true.
        if suggestion.isLate, let last = suggestion.lastBusinessDay {
            return String(localized: "The last business day before the debit was \(short(last)). Move it today: most banks send transfers at weekends too.")
        }
        var d = cal.date(byAdding: .day, value: 1, to: suggestion.deadline)!
        var weekend: [Date] = [], holidays: [Date] = []
        while d < suggestion.debitDate {
            if BusinessCalendar.isHoliday(d) { holidays.append(d) }
            else if !BusinessCalendar.isBusinessDay(d) { weekend.append(d) }
            d = cal.date(byAdding: .day, value: 1, to: d)!
        }
        func days(_ list: [Date]) -> String {
            let n = list.map(ordinal)
            return n.count == 1 ? String(localized: "the \(n[0])")
                : String(localized: "the \(n.dropLast().joined(separator: ", ")) and \(n.last!)")
        }
        var parts: [String] = []
        if !weekend.isEmpty {
            parts.append(weekend.count == 1 ? String(localized: "\(days(weekend)) is a weekend day") : String(localized: "\(days(weekend)) are a weekend"))
        }
        if !holidays.isEmpty {
            parts.append(holidays.count == 1 ? String(localized: "\(days(holidays)) is a holiday") : String(localized: "\(days(holidays)) are holidays"))
        }
        guard !parts.isEmpty else { return nil }
        return String(localized: "By \(short(suggestion.deadline)): \(parts.joined(separator: String(localized: " and "))), when banks do not move money.")
    }

    private func ordinal(_ d: Date) -> String {
        let f = NumberFormatter(); f.numberStyle = .ordinal
        return f.string(from: NSNumber(value: Calendar.current.component(.day, from: d))) ?? ""
    }

    /// "SMBC bank · Tuấn": an account with the person it belongs to.
    private func owned(_ account: String) -> String {
        guard let w = store.data.wallets.first(where: { $0.name == account }),
              let owner = store.owner(id: w.ownerID),
              // "Me" is the book's placeholder, not a name worth printing.
              !(owner.id == "me" && owner.name == "Me") else { return account }
        return "\(account) · \(owner.name)"
    }

    var body: some View {
        let s = suggestion
        let fromNow = store.balance(ofAccount: s.from) ?? 0
        let toNow = store.balance(ofAccount: s.to) ?? 0
        ScrollView {
            VStack(alignment: .leading, spacing: Organic.Space.l) {
                Text("From \(whose(s.from)) to \(whose(s.to)), by \(short(s.deadline))")
                    .font(Organic.value).foregroundStyle(Organic.n600)
                Card(padding: .list) {
                    side(label: "From", name: s.from, before: fromNow, after: fromNow - amount)
                    Hairline()
                    side(label: "To", name: s.to, before: toNow, after: toNow + amount)
                }
                Card {
                    HStack(alignment: .bottom, spacing: Organic.Space.m) {
                        VStack(alignment: .leading, spacing: 4) {
                            FieldLabel("Amount")
                            MoneyField("Amount", value: $amount)
                        }
                        .frame(maxWidth: .infinity)
                        VStack(alignment: .leading, spacing: 4) {
                            FieldLabel("Moved on")
                            FormField {
                                DatePicker("Moved on", selection: $date, displayedComponents: .date)
                                    .labelsHidden()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    HelpText("Mochi does not move money. Do it in your bank’s app, then save it here so both balances follow.")
                        .padding(.top, Organic.Space.s)
                }
                InnerBlock {
                    Text("Why \(store.format(s.amount))").font(Organic.valueStrong)
                    Text("\(s.debitLabel) takes \(store.format(s.debitAmount)) from \(s.to) on \(short(s.debitDate)), and nothing comes into \(s.to) before then. \(s.to) has \(store.format(s.balanceNow)); \(store.format(s.amount)) is the gap rounded up to the next thousand, leaving \(store.format(s.leftAfter)) after the card.")
                        .font(Organic.caption).foregroundStyle(Organic.n600)
                    if let why = whyThatDay {
                        Text(verbatim: why).font(Organic.caption).foregroundStyle(Organic.n600)
                    }
                }
                Text("A move between your own accounts: not spending, and net worth stays \(store.format(store.netWorth.total)). \(s.from) goes to \(store.format(fromNow - amount)), \(s.to) to \(store.format(toNow + amount)).")
                    .font(Organic.meta).foregroundStyle(Organic.n600)
                PrimaryButton(title: "Save the move") {
                    store.transfer(from: s.from, to: s.to, amount: amount, fee: 0, on: date)
                    dismiss()
                }
                .disabled(amount <= 0)
                SecondaryButton(title: reminded ? "Reminder set for \(short(s.deadline))" : "Remind me on \(short(s.deadline))", style: .outlined) {
                    Task { reminded = await Notifier.schedule(for: store) }
                }
                .disabled(reminded)
            }
            .padding(.horizontal, Organic.Space.gutter).padding(.bottom, Organic.Space.gutter)
            .readableWidth()
        }
        .background(Organic.bg)
        .navigationTitle(Text(verbatim: String(localized: "Move \(store.format(amount))")))
        .onAppear { if amount == 0 { amount = s.amount } }
    }

    /// One side of the move: the label over the account, what it holds now
    /// over what it will hold.
    private func side(label: LocalizedStringKey, name: String, before: Int, after: Int) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(Organic.caption).foregroundStyle(Organic.n600)
                Text(verbatim: owned(name)).font(Organic.title)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(verbatim: store.format(before)).font(Organic.caption).foregroundStyle(Organic.n600)
                Text(verbatim: "→ \(store.format(after))").font(Organic.title)
            }
        }
        .frame(minHeight: 64)
    }
}
