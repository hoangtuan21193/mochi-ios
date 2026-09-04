import SwiftUI

/// Tab 4. Cash, points, card debt, owners, loans. No physical goods.
/// Every "add" here follows one pattern: section header + round + button
/// that reveals an inline form.
struct WalletView: View {
    @Environment(Store.self) private var store
    @State private var addWallet = false
    @State private var addCard = false
    @State private var addOwner = false
    @State private var showTransfer = false
    @State private var showLoans = false

    // add-wallet form
    @State private var wName = ""; @State private var wBal = ""; @State private var wOwner = "me"
    // add-card form
    @State private var cName = ""; @State private var cDue = ""; @State private var cLimit = ""; @State private var cOwner = "me"
    // add-owner form
    @State private var oName = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    netWorthCard

                    SectionHeader(title: "Cash & wallets", isOpen: addWallet) { addWallet.toggle() }
                    if addWallet { addWalletForm }
                    Card(padding: EdgeInsets(top: 6, leading: 15, bottom: 9, trailing: 15)) {
                        ForEach(store.data.wallets) { w in
                            row(w.name, note: w.note, value: store.format(w.balance),
                                first: w.id == store.data.wallets.first?.id)
                        }
                        HStack {
                            Text("Total").font(.system(size: 13.5, weight: .heavy))
                            Spacer()
                            Text(store.format(store.cash)).font(.system(size: 13.5, weight: .heavy))
                        }
                        .padding(.vertical, 10)
                        .overlay(alignment: .top) { Divider().overlay(Organic.n300) }
                    }

                    Button { showTransfer = true } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.left.arrow.right")
                            Text("Move money").font(.system(size: 13, weight: .heavy))
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(Organic.n100, in: Capsule())
                        .overlay(Capsule().stroke(Organic.n300, lineWidth: 1.5))
                        .foregroundStyle(Organic.text)
                    }

                    pointsCard

                    SectionHeader(title: "Credit card debt",
                                  subtitle: "Total debt \(store.format(store.debt)) · closes at month end",
                                  isOpen: addCard) { addCard.toggle() }
                    if addCard { addCardForm }
                    Card(padding: EdgeInsets(top: 6, leading: 15, bottom: 9, trailing: 15)) {
                        ForEach(store.data.cards) { card in cardRow(card) }
                    }

                    SectionHeader(title: "Owners", subtitle: "Who a card or wallet belongs to",
                                  isOpen: addOwner) { addOwner.toggle() }
                    if addOwner { addOwnerForm }
                    Card(padding: EdgeInsets(top: 6, leading: 15, bottom: 9, trailing: 15)) {
                        ForEach(store.data.owners) { o in
                            row(o.name, note: "", value: ownerMeta(o), first: o.id == store.data.owners.first?.id)
                        }
                    }

                    Button { showLoans = true } label: {
                        Card {
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Personal loan book").font(.system(size: 14, weight: .heavy))
                                    Text("\(store.data.loans.count) people")
                                        .font(.system(size: 11)).foregroundStyle(Organic.n600)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.system(size: 12, weight: .heavy))
                                    .foregroundStyle(Organic.n500)
                            }
                        }
                    }
                    .buttonStyle(.plain).foregroundStyle(Organic.text)
                }
                .padding(.horizontal, 16).padding(.bottom, 16)
            }
            .background(Organic.bg)
            .navigationTitle("Wallet")
            .sheet(isPresented: $showTransfer) { TransferSheet() }
            .navigationDestination(isPresented: $showLoans) { LoanBookView() }
        }
    }

    private func ownerMeta(_ o: Owner) -> String {
        let cards = store.data.cards.filter { $0.ownerID == o.id }.count
        let wallets = store.data.wallets.filter { $0.ownerID == o.id }.count
        return "\(cards) cards · \(wallets) wallets"
    }

    private var netWorthCard: some View {
        Card {
            Text("Net worth").font(.system(size: 14, weight: .heavy)).padding(.bottom, 4)
            line("Cash & wallets", store.format(store.cash), Organic.text)
            line("Card debt", store.format(-store.debt), Organic.a800)
            line("Inventory for sale (est. net)", store.format(store.liquidation), Organic.s700)
            HStack {
                Text("Total").font(.system(size: 13, weight: .heavy))
                Spacer()
                Text(store.format(store.cashAfterSellingAll)).font(.system(size: 13, weight: .heavy))
            }
            .padding(.vertical, 9)
            .overlay(alignment: .top) { Divider().overlay(Organic.n300) }
        }
    }

    private func line(_ l: String, _ v: String, _ c: Color) -> some View {
        HStack {
            Text(l).font(.system(size: 12.5)).foregroundStyle(Organic.n700)
            Spacer()
            Text(v).font(.system(size: 12.5, weight: .heavy)).foregroundStyle(c)
        }
        .padding(.vertical, 6)
    }

    private var pointsCard: some View {
        Card(fill: Organic.a100) {
            HStack {
                Text("Point wallets").font(.system(size: 13, weight: .heavy))
                Text("NOT CASH").font(.system(size: 9.5, weight: .bold)).foregroundStyle(Organic.a900)
                Spacer()
                Text("\(store.data.pointWallets.reduce(0) { $0 + $1.points }) pt")
                    .font(.system(size: 13, weight: .heavy)).foregroundStyle(Organic.a900)
            }
            ForEach(store.data.pointWallets) { p in
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(p.name).font(.system(size: 13, weight: .semibold))
                        Text(p.note).font(.system(size: 10.5)).foregroundStyle(Organic.a900)
                    }
                    Spacer()
                    Text("\(p.points) pt").font(.system(size: 13, weight: .heavy))
                }
                .padding(.vertical, 9)
                .overlay(alignment: .top) { Divider().overlay(Organic.a200) }
            }
        }
    }

    private func row(_ name: String, note: String, value: String, first: Bool) -> some View {
        HStack {
            Text(name).font(.system(size: 13.5, weight: .semibold))
            if !note.isEmpty {
                Text(note).font(.system(size: 10)).foregroundStyle(Organic.n500)
            }
            Spacer()
            Text(value).font(.system(size: 13.5, weight: .heavy))
        }
        .padding(.vertical, 10)
        .overlay(alignment: .top) { if !first { Divider().overlay(Organic.n200) } }
    }

    /// One card: name, debt, limit bar, then the small due + headroom line.
    private func cardRow(_ card: CreditCard) -> some View {
        let ratio = card.limit > 0 ? Double(card.debt) / Double(card.limit) : 0
        return VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(card.name).font(.system(size: 13.5, weight: .semibold))
                if card.ownerID != "me", let o = store.data.owners.first(where: { $0.id == card.ownerID }) {
                    Text(o.name.uppercased()).font(.system(size: 9.5, weight: .bold))
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(Organic.s200, in: Capsule()).foregroundStyle(Organic.s900)
                }
                Spacer()
                Text(store.format(card.debt)).font(.system(size: 13.5, weight: .heavy))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Organic.n200)
                    Capsule().fill(ratio > 0.8 ? Organic.a600 : Organic.s500)
                        .frame(width: geo.size.width * min(1, ratio))
                }
            }
            .frame(height: 5)
            HStack {
                Text("Due on the \(card.dueDay)")
                Spacer()
                Text("Limit left \(store.format(card.limit - card.debt))")
            }
            .font(.system(size: 10.5)).foregroundStyle(Organic.n600)
        }
        .opacity(card.debt == 0 ? 0.45 : 1)
        .padding(.vertical, 10)
        .overlay(alignment: .top) { if card.id != store.data.cards.first?.id { Divider().overlay(Organic.n200) } }
    }

    // MARK: - Inline forms

    private var addWalletForm: some View {
        Card {
            Text("New wallet").font(.system(size: 14, weight: .heavy)).padding(.bottom, 8)
            VStack(spacing: 8) {
                pill(TextField("Wallet or account name", text: $wName))
                pill(TextField("Balance now", text: $wBal).keyboardType(.numberPad))
                ownerPicker(selected: $wOwner)
                PrimaryButton(title: "Add wallet") {
                    guard !wName.isEmpty else { return }
                    store.data.wallets.append(Wallet(name: wName,
                        balance: Int(wBal.filter(\.isNumber)) ?? 0, ownerID: wOwner))
                    store.save(); wName = ""; wBal = ""; addWallet = false
                }
            }
        }
    }

    private var addCardForm: some View {
        Card {
            Text("New credit card").font(.system(size: 14, weight: .heavy)).padding(.bottom, 8)
            VStack(spacing: 8) {
                pill(TextField("Card name", text: $cName))
                HStack(spacing: 8) {
                    pill(TextField("Due day", text: $cDue).keyboardType(.numberPad))
                    pill(TextField("Limit", text: $cLimit).keyboardType(.numberPad))
                }
                ownerPicker(selected: $cOwner)
                PrimaryButton(title: "Add card") {
                    guard !cName.isEmpty else { return }
                    store.data.cards.append(CreditCard(name: cName,
                        dueDay: Int(cDue.filter(\.isNumber)) ?? 1,
                        limit: Int(cLimit.filter(\.isNumber)) ?? 0, debt: 0, ownerID: cOwner))
                    store.save(); cName = ""; cDue = ""; cLimit = ""; addCard = false
                }
            }
        }
    }

    private var addOwnerForm: some View {
        Card {
            Text("New owner").font(.system(size: 14, weight: .heavy)).padding(.bottom, 8)
            VStack(spacing: 8) {
                pill(TextField("Name", text: $oName))
                PrimaryButton(title: "Add owner") {
                    guard !oName.isEmpty else { return }
                    store.data.owners.append(Owner(name: oName))
                    store.save(); oName = ""; addOwner = false
                }
            }
        }
    }

    private func pill<V: View>(_ field: V) -> some View {
        field.font(.system(size: 13))
            .padding(.horizontal, 13).padding(.vertical, 9)
            .background(Organic.bg, in: Capsule())
            .overlay(Capsule().stroke(Organic.n300, lineWidth: 1.5))
    }

    private func ownerPicker(selected: Binding<String>) -> some View {
        HStack(spacing: 6) {
            Text("Owner").font(.system(size: 11)).foregroundStyle(Organic.n600).frame(width: 52, alignment: .leading)
            ForEach(store.data.owners) { o in
                Button { selected.wrappedValue = o.id } label: {
                    Chip(label: o.name, selected: selected.wrappedValue == o.id)
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }
}

/// Wallet-to-wallet move with the 手数料 field. Mercari / Rakuma bank
/// withdrawals cost ¥210 a time, so the fee defaults to that.
struct TransferSheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var from = ""
    @State private var to = ""
    @State private var amount = ""
    @State private var fee = "210"

    private var amountValue: Int { Int(amount.filter(\.isNumber)) ?? 0 }
    private var feeValue: Int { Int(fee.filter(\.isNumber)) ?? 0 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text("From").font(.system(size: 11, weight: .semibold)).foregroundStyle(Organic.n600)
                    FlowRow(spacing: 5) {
                        ForEach(store.data.wallets) { w in
                            Button { from = w.name } label: { Chip(label: w.name, selected: from == w.name) }
                                .buttonStyle(.plain)
                        }
                    }
                    Text("To").font(.system(size: 11, weight: .semibold)).foregroundStyle(Organic.n600)
                    FlowRow(spacing: 5) {
                        ForEach(store.data.wallets) { w in
                            Button { to = w.name } label: { Chip(label: w.name, selected: to == w.name) }
                                .buttonStyle(.plain)
                        }
                    }
                    HStack(spacing: 8) {
                        TextField("Amount", text: $amount).keyboardType(.numberPad)
                            .padding(.horizontal, 14).padding(.vertical, 11)
                            .background(Organic.n100, in: Capsule())
                            .overlay(Capsule().stroke(Organic.n300, lineWidth: 1.5))
                        TextField("手数料", text: $fee).keyboardType(.numberPad)
                            .frame(width: 100)
                            .padding(.horizontal, 14).padding(.vertical, 11)
                            .background(Organic.n100, in: Capsule())
                            .overlay(Capsule().stroke(Organic.n300, lineWidth: 1.5))
                    }
                    HStack(spacing: 5) {
                        ForEach([0, 210, 250], id: \.self) { f in
                            Button { fee = String(f) } label: {
                                Chip(label: f == 0 ? "No fee" : "¥\(f)", selected: feeValue == f)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Text(amountValue > 0
                         ? "Arrives: \(store.format(max(0, amountValue - feeValue)))" +
                           (feeValue > 0 ? " · 手数料 \(store.format(feeValue))" : "")
                         : "Bank withdrawals from Mercari / Rakuma usually cost ¥210 per transfer.")
                        .font(.system(size: 11)).foregroundStyle(Organic.n600)
                    PrimaryButton(title: "Move it") {
                        store.transfer(from: from, to: to, amount: amountValue, fee: feeValue)
                        dismiss()
                    }
                }
                .padding(16)
            }
            .background(Organic.bg)
            .navigationTitle("Move money")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } } }
        }
        .onAppear {
            from = store.data.wallets.first?.name ?? ""
            to = store.data.wallets.dropFirst().first?.name ?? ""
        }
    }
}
