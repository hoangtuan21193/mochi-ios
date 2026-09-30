import SwiftUI

// MARK: - Recurring

/// Edit or pause one monthly line. Pausing keeps the history of what it was;
/// deleting is for a bill that is gone for good.
struct RecurringSheetView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let entry: Recurring

    @State private var name = ""
    @State private var amount = 0
    @State private var day = ""
    @State private var paidBy = ""
    @State private var category = "other"
    @State private var active = true
    @State private var confirmingDelete = false

    private var live: Recurring { store.recurring.first { $0.id == entry.id } ?? entry }
    private var dayValue: Int { min(max(Int(day.filter(\.isNumber)) ?? 0, 0), 31) }

    var body: some View {
        SheetScaffold(verbatimTitle: live.name) {
            Card {
                Text(live.isIncome ? "Monthly income" : "Monthly bill").font(Organic.title).padding(.bottom, 8)
                VStack(alignment: .leading, spacing: 8) {
                    FormField("What it is", text: $name)
                    HStack(spacing: 8) {
                        MoneyField("Amount a month", value: $amount)
                        FormField("Day", text: $day, numeric: true).frame(width: 90)
                    }
                    if !live.isIncome {
                        ChipPicker(label: "Kind", options: Recurring.expenseCategories,
                                   selection: category,
                                   display: { Text(Recurring.categoryName($0)) }) { category = $0 }
                    }
                    if !store.payers.isEmpty {
                        ChipPicker(label: live.isIncome ? "Lands in" : "Paid by", options: store.payers, selection: paidBy) { paidBy = $0 }
                    }
                    ToggleChip(label: active ? "Active" : "Paused",
                               tint: active ? Organic.s600 : Organic.n500) { active.toggle() }
                    HelpText(store.isCard(paidBy)
                             ? "Rides on \(paidBy)'s statement. Cash leaves on the card's due day, so it never shows on its own day in the forecast."
                             : (live.isIncome ? "Counted in Safe to spend when its day falls before the horizon."
                                              : "Leaves cash on the \(max(dayValue, 1))th every month."))
                    PrimaryButton(title: "Save") {
                        guard !name.isEmpty, amount > 0, dayValue > 0 else { return }
                        var copy = live
                        copy.name = name; copy.amount = amount; copy.day = dayValue
                        copy.paidBy = paidBy; copy.category = category; copy.active = active
                        store.updateRecurring(copy)
                        dismiss()
                    }
                    DeleteButton(title: "Delete") { confirmingDelete = true }
                }
            }
        }
        .onAppear {
            name = live.name; amount = live.amount; day = String(live.day)
            paidBy = live.paidBy; category = live.category; active = live.active
        }
        .alert("Delete \(live.name)?", isPresented: $confirmingDelete) {
            Button("Delete", role: .destructive) { store.deleteRecurring(live); dismiss() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("It leaves Safe to spend and the forecast. Pause it instead if it only stops for a while.")
        }
    }
}
