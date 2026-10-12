import SwiftUI

/// Own screen because the list can get long; Wallet shows only a summary row.
struct LoanBookView: View {
    @Environment(Store.self) private var store

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 11) {
                Text(summary).font(.system(size: 11.5)).foregroundStyle(Organic.n600).padding(.horizontal, 2)
                ForEach(store.data.loans) { loan in
                    Card {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(loan.person).font(.system(size: 15, weight: .heavy))
                                Text(loan.direction > 0 ? "They owe you" : "You owe them")
                                    .font(.system(size: 11, weight: .semibold))
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
                            .font(.system(size: 11.5)).foregroundStyle(Organic.n600)
                            .padding(.top, 6)
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(Organic.bg)
        .navigationTitle("Loan book")
        .navigationBarTitleDisplayMode(.inline)
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
