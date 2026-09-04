import SwiftUI

/// Own screen because the list can get long; Wallet shows only a summary row.
struct LoanBookView: View {
    @Environment(Store.self) private var store
    @State private var adding = false
    @State private var repaying: Loan?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 11) {
                HelpText(summary).padding(.horizontal, 2)
                if store.data.loans.isEmpty {
                    Card(padding: .list) {
                        EmptyNote("No loans tracked. Money lent or borrowed sits outside your wallets until it comes back.")
                    }
                }
                ForEach(store.data.loans) { loan in
                    Button { repaying = loan } label: {
                    Card {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(loan.person).font(Organic.title)
                                Text(loan.direction > 0 ? "They owe you" : "You owe them")
                                    .font(Organic.captionStrong)
                                    .foregroundStyle(loan.direction > 0 ? Organic.s700 : Organic.a800)
                            }
                            Spacer()
                            Text(amount(loan)).font(Organic.display(18))
                                .foregroundStyle(loan.direction > 0 ? Organic.s700 : Organic.a800)
                        }
                        ForEach(loan.history) { e in
                            HStack {
                                Text("\(e.date.formatted(date: .numeric, time: .omitted)) · \(e.title)")
                                Spacer()
                                Text(e.amount).fontWeight(.semibold)
                            }
                            .font(Organic.caption).foregroundStyle(Organic.n600)
                            .padding(.top, 6)
                        }
                    }
                    .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).foregroundStyle(Organic.text)
                }
            }
            .padding(16)
        }
        .sheet(isPresented: $adding) { LoanEditorView() }
        .sheet(item: $repaying) { LoanRepayView(loan: $0) }
        .background(Organic.bg)
        .navigationTitle("Loan book")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { AddButton { adding = true } }
        }
    }

    private func amount(_ l: Loan) -> String {
        l.currency == "JPY" ? store.format(l.amount) : "\(l.amount.formatted()) ₫"
    }

    private var summary: String {
        let jpy = store.data.loans.filter { $0.currency == "JPY" }.reduce(0) { $0 + $1.direction * $1.amount }
        let vnd = store.data.loans.filter { $0.currency == "VND" }.reduce(0) { $0 + $1.direction * $1.amount }
        return "Net \(store.format(jpy)) · VND \(vnd.formatted()) ₫"
    }
}
