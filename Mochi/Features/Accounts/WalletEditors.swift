import SwiftUI

// The sheets behind a wallet row: edit a wallet or a point wallet, move money
// between wallets. Adding is inline on the Wallet screen.

/// The edit / pay / delete half of Wallet. Adding was already inline on the
/// screen; everything that changes or removes an existing row lives here so the
/// list rows stay one line tall.

/// Owner chip row, shared by the wallet and card editors.
struct OwnerPicker: View {
    @Environment(Store.self) private var store
    @Binding var selection: String
    var body: some View {
        let owners = store.data.owners
        ChipPicker(label: "Owner",
                   options: owners.map(\.name),
                   selection: owners.first { $0.id == selection }?.name ?? "",
                   onPick: { name in
                       if let o = owners.first(where: { $0.name == name }) { selection = o.id }
                   })
    }
}

// MARK: - Wallet

struct WalletEditorView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let wallet: Wallet

    @State private var name = ""
    @State private var note = ""
    @State private var balance = 0
    @State private var ownerID = "me"
    @State private var confirmingDelete = false

    var body: some View {
        SheetScaffold(title: "Edit wallet") {
            FormField("Wallet or account name", text: $name)
            FormField("Note (bank, not withdrawn…)", text: $note)
            MoneyField("Balance now", value: $balance)
            OwnerPicker(selection: $ownerID)

            if balance != store.balance(of: wallet) {
                HelpText("Type what the bank says. The \(store.format(balance - store.balance(of: wallet))) difference is booked as an adjustment, not as spending or income.")
            }

            PrimaryButton(title: "Save") {
                guard !name.isEmpty else { return }
                var copy = wallet
                copy.name = name; copy.note = note
                copy.balance = balance; copy.ownerID = ownerID
                store.updateWallet(copy, oldName: wallet.name)
                dismiss()
            }
            DeleteButton(title: "Delete wallet") { confirmingDelete = true }
                .padding(.top, 4)
        }
        .onAppear {
            name = wallet.name; note = wallet.note
            balance = store.balance(of: wallet); ownerID = wallet.ownerID
        }
        .alert("Delete \(wallet.name)?", isPresented: $confirmingDelete) {
            Button("Delete", role: .destructive) { store.deleteWallet(wallet); dismiss() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(store.balance(of: wallet) != 0
                 ? "Its \(store.format(store.balance(of: wallet))) leaves your cash total."
                 : "This cannot be undone.")
        }
    }
}

// MARK: - Point wallet

struct PointWalletEditorView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    /// nil = creating a new one.
    let pointWallet: PointWallet?

    @State private var name = ""
    @State private var note = ""
    @State private var points = 0

    var body: some View {
        SheetScaffold(title: pointWallet == nil ? "New point wallet" : "Edit point wallet") {
            FormField("Name (MapCamera points…)", text: $name)
            FormField("Note", text: $note)
            MoneyField("Points", value: $points, unit: .suffix("pt"))
            HelpText("Points are never counted as cash.")

            PrimaryButton(title: pointWallet == nil ? "Add point wallet" : "Save") {
                guard !name.isEmpty else { return }
                if let pointWallet {
                    var copy = pointWallet
                    copy.name = name; copy.note = note; copy.points = points
                    store.updatePointWallet(copy, oldName: pointWallet.name)
                } else {
                    store.addPointWallet(PointWallet(name: name, points: points, note: note))
                }
                dismiss()
            }
            if let pointWallet {
                DeleteButton(title: "Delete point wallet") {
                    store.deletePointWallet(pointWallet); dismiss()
                }
                .padding(.top, 4)
            }
        }
        .onAppear {
            guard let pointWallet else { return }
            name = pointWallet.name; note = pointWallet.note; points = pointWallet.points
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
    @State private var amount = 0
    @State private var fee = 210

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ChipPicker(label: "From", options: store.data.wallets.map(\.name), selection: from) { from = $0 }
                    ChipPicker(label: "To", options: store.data.wallets.map(\.name), selection: to) { to = $0 }
                    HStack(spacing: 8) {
                        MoneyField("Amount", value: $amount)
                        MoneyField("手数料", value: $fee)
                            .frame(width: 110)
                    }
                    HStack(spacing: 5) {
                        ForEach([0, 210, 250], id: \.self) { f in
                            Button { fee = f } label: {
                                Chip(label: f == 0 ? Text("No fee") : Text(verbatim: store.format(f)), selected: fee == f)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    if amount > 0 {
                        HelpText(verbatim: metaLine(
                            String(localized: "Arrives: \(store.format(max(0, amount - fee)))"),
                            fee > 0 ? String(localized: "Fee \(store.format(fee))") : ""))
                    } else {
                        HelpText("Bank withdrawals from Mercari / Rakuma usually cost ¥210 per transfer.")
                    }
                    PrimaryButton(title: "Move it") {
                        store.transfer(from: from, to: to, amount: amount, fee: fee)
                        dismiss()
                    }
                }
                .padding(16)
                .readableWidth()
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
