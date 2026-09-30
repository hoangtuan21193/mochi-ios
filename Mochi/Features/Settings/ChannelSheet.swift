import SwiftUI

// MARK: - Sales channel

struct ChannelEditorView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let channel: SalesChannel

    @State private var name = ""
    @State private var rate = ""
    @State private var isPoints = false
    @State private var confirmingDelete = false

    private var itemsUsing: Int {
        store.data.items.filter { $0.plannedChannel == channel.name && !$0.isSold }.count
    }

    var body: some View {
        SheetScaffold(title: "Edit channel") {
            FormField("Channel name", text: $name)
            HStack(spacing: 8) {
                FormField(isPoints ? "Bonus %" : "Fee %", text: $rate, decimal: true)
                ToggleChip(label: isPoints ? "Point" : "Cash",
                           tint: isPoints ? Organic.a600 : Organic.s600) { isPoints.toggle() }
            }
            HelpText(isPoints
                     ? "A point channel pays \(rate.isEmpty ? "0" : rate)% on top, in points. A sale here is a record; no wallet moves."
                     : "A cash channel keeps \(rate.isEmpty ? "0" : rate)% of the sale price. A sale here is a record; you type the payout into a wallet when it lands.")

            PrimaryButton(title: "Save") {
                guard !name.isEmpty else { return }
                var copy = channel
                copy.name = name
                copy.rate = Double(rate.replacingOccurrences(of: ",", with: ".")) ?? 0
                copy.isPoints = isPoints
                store.updateChannel(copy, oldName: channel.name)
                dismiss()
            }
            DeleteButton(title: "Delete channel") { confirmingDelete = true }
                .padding(.top, 4)
        }
        .onAppear {
            name = channel.name; rate = channel.rate.formatted()
            isPoints = channel.isPoints
        }
        .alert("Delete \(channel.name)?", isPresented: $confirmingDelete) {
            Button("Delete", role: .destructive) { store.deleteChannel(channel); dismiss() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(itemsUsing > 0
                 ? "\(itemsUsing) unsold item(s) plan to sell here; their estimate falls back to the full price."
                 : "This cannot be undone.")
        }
    }
}
