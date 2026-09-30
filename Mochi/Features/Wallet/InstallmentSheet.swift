import SwiftUI

// MARK: - Instalment plan: progress, pay early, edit, delete

struct InstallmentSheetView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let plan: Installment

    @State private var editing = false
    @State private var confirmingDelete = false

    @State private var name = ""
    @State private var lender = ""
    @State private var months = ""
    @State private var firstAmount = 0
    @State private var monthly = 0
    @State private var startYear = 0
    @State private var startMonth = 0
    @State private var payDay = ""
    @State private var feeTotal = 0
    @State private var itemID: String? = nil
    @State private var closed = false

    /// The plan as it stands now, so the sheet keeps up with its own payments.
    private var live: Installment { store.installments.first { $0.id == plan.id } ?? plan }
    private var linkedItem: Item? { live.itemID.flatMap { id in store.data.items.first { $0.id == id } } }

    var body: some View {
        SheetScaffold(verbatimTitle: live.name) {
            summaryCard
            if editing { editBlock } else {
                SecondaryButton(title: "Edit plan details", style: .outlined) { editing = true }
            }
        }
        .onAppear {
            name = live.name; lender = live.lender
            let schedule = live.schedule
            months = String(schedule.months); firstAmount = schedule.firstAmount
            monthly = schedule.monthly
            startYear = schedule.startYear; startMonth = schedule.startMonth
            payDay = String(schedule.payDay)
            feeTotal = live.feeTotal
            itemID = live.itemID; closed = live.closed
        }
        .alert("Delete \(live.name)?", isPresented: $confirmingDelete) {
            Button("Delete", role: .destructive) { store.deleteInstallment(live); dismiss() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(live.remaining() > 0
                 ? "It still owes \(store.format(live.remaining())), which will disappear from your totals."
                 : "This cannot be undone.")
        }
    }

    // MARK: summary

    private var summaryCard: some View {
        let paid = live.principal - live.remaining()
        let ratio = live.principal > 0 ? Double(paid) / Double(live.principal) : 1
        return Card {
            Text(live.isSettled() ? "Paid off" : "Still owed")
                .font(Organic.caption).foregroundStyle(Organic.n600)
            Text(store.format(live.remaining()))
                .font(Organic.display(26))
                .foregroundStyle(live.isSettled() ? Organic.s700 : Organic.a800)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Organic.n200)
                    Capsule().fill(live.isSettled() ? Organic.s500 : Organic.a500)
                        .frame(width: geo.size.width * min(1, ratio))
                }
            }
            .frame(height: 6).padding(.vertical, 10)

            HStack(spacing: 8) {
                Metric(label: "Borrowed", value: store.format(live.principal))
                Metric(label: "Paid so far", value: store.format(paid))
                Metric(label: "Per month", value: store.format(live.regular))
            }
            HStack(spacing: 8) {
                Metric(label: "Months left", value: live.isSettled() ? "—" : "\(live.monthsLeft()) of \(live.months)")
                Metric(label: "Next debit", value: live.nextDue().map {
                    "\(store.format($0.amount)) · \($0.date.formatted(.dateTime.day().month(.abbreviated)))"
                } ?? "—")
                Metric(label: "Last payment", value: live.projectedEnd().formatted(.dateTime.month(.abbreviated).year()))
            }
            .padding(.top, 10)

            Text(metaLine(live.lender,
                          "first \(store.format(live.firstAmount)) on \(live.firstDate.formatted(date: .abbreviated, time: .omitted))",
                          linkedItem.map { $0.isSold ? "\($0.name) — sold" : $0.name } ?? "",
                          live.extraPaid > 0 ? "paid early \(store.format(live.extraPaid))" : ""))
                .font(Organic.meta).foregroundStyle(Organic.n600).padding(.top, 10)
            Text("Payments are counted from the calendar as their dates pass. Your bank balance is yours to correct in Wallets.")
                .font(Organic.meta).foregroundStyle(Organic.n500).padding(.top, 4)
        }
    }

    // MARK: edit

    private var typedSchedule: InstallmentSchedule {
        InstallmentSchedule(months: Int(months.filter(\.isNumber)) ?? 0, firstAmount: firstAmount,
                            monthly: monthly, startYear: startYear, startMonth: startMonth,
                            payDay: Int(payDay.filter(\.isNumber)) ?? 0)
    }

    /// What the typed lines add up to, so a wrong month is caught before Save.
    private var scheduleLine: LocalizedStringKey {
        guard let typed = typedSchedule.plan(name: name) else {
            return "Fill in the payments, the two amounts and the day it is debited."
        }
        return "Borrows \(store.format(typed.principal)) · first \(typed.firstDate.formatted(.dateTime.day().month(.abbreviated).year())) · last \(typed.endDate.formatted(.dateTime.month(.abbreviated).year()))"
    }

    private var editBlock: some View {
        Card {
            Text("Plan details").font(Organic.title).padding(.bottom, 8)
            VStack(alignment: .leading, spacing: 8) {
                FormField("What it bought", text: $name)
                HStack(spacing: 8) {
                    FormField("Lender", text: $lender)
                    FormField("Payments (60)", text: $months, numeric: true).frame(width: 120)
                }
                HStack(spacing: 8) {
                    MoneyField("First payment", value: $firstAmount)
                    MoneyField("Then each month", value: $monthly)
                }
                HStack(spacing: 8) {
                    FormField { MonthPicker(label: "Starts", year: $startYear, month: $startMonth) }
                    FormField("Paid on day (26)", text: $payDay, numeric: true).frame(width: 120)
                }
                MoneyField("分割手数料 in total (0 at 0%)", value: $feeTotal)
                Text(scheduleLine).font(Organic.meta).foregroundStyle(Organic.n600)
                InlineMenu(label: "Item",
                           value: store.data.items.first { $0.id == itemID }
                               .map { Text(verbatim: $0.name) } ?? Text("Not linked")) {
                    Button("Not linked") { itemID = nil }
                    ForEach(store.data.items.sorted { !$0.isSold && $1.isSold }) { item in
                        Button { itemID = item.id } label: {
                            item.isSold ? Text("\(item.name) (sold)") : Text(verbatim: item.name)
                        }
                    }
                }
                ToggleChip(label: closed ? "Marked paid off" : "Still running",
                           tint: closed ? Organic.s600 : Organic.n900) { closed.toggle() }
                HelpText("Correct the figures here to match the lender's confirmation; the months paid are counted from the dates on their own.")
                PrimaryButton(title: "Save") {
                    guard !name.isEmpty, let typed = typedSchedule.plan(name: name) else { return }
                    var copy = live
                    copy.name = name; copy.lender = lender
                    copy.principal = typed.principal
                    copy.months = typed.months
                    copy.firstAmount = typed.firstAmount
                    copy.firstDate = typed.firstDate
                    copy.feeTotal = min(max(feeTotal, 0), copy.principal)
                    copy.itemID = itemID; copy.closed = closed
                    store.updateInstallment(copy)
                    editing = false
                }
                DeleteButton(title: "Delete plan") { confirmingDelete = true }
            }
        }
    }
}
