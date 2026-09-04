import SwiftUI

/// Add / edit an item. Picking a category loads that category's attribute
/// checklist, keeping any values already filled in for matching names.
struct ItemEditorView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    let item: Item?
    @State private var name = ""
    @State private var category = ""
    @State private var buy = ""
    @State private var estimate = ""
    @State private var ownerID = "me"
    @State private var cardName = ""
    @State private var channel = ""
    @State private var boughtFrom = ""
    @State private var boughtOn = Date.now
    @State private var accessories = ""
    @State private var condition = ""
    @State private var attributes: [AttributeRow] = []
    // Paid on shopping credit instead of a card. The plan is created with the
    // item; afterwards it is edited in Wallet like any other plan.
    @State private var onPlan = false
    @State private var planLender = ""
    @State private var planMonths = "24"
    @State private var planFirst = ""
    @State private var planFirstDate = Date.now

    struct AttributeRow: Identifiable {
        let id = UUID()
        var name: String
        var value: String
        var kind: AttributeKind
        var options: [String] = []
        var unit: String = ""
    }

    private var cardsForOwner: [CreditCard] { store.data.cards.filter { $0.ownerID == ownerID } }
    private static let planOption = "Instalments"
    /// An existing item already on a plan keeps it; the plan lives in Wallet.
    private var existingPlan: Installment? { item.flatMap { store.installment(for: $0) } }
    private var buyValue: Int { Int(buy.filter(\.isNumber)) ?? 0 }
    private var planMonthsValue: Int { max(1, Int(planMonths.filter(\.isNumber)) ?? 1) }
    private var planFirstSuggested: Int {
        guard buyValue > 0 else { return 0 }
        let even = buyValue / planMonthsValue
        return buyValue - even * (planMonthsValue - 1)
    }
    private var planFirstValue: Int {
        let typed = Int(planFirst.filter(\.isNumber)) ?? 0
        return typed > 0 ? typed : planFirstSuggested
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    FormField("What is it?", text: $name)

                    ChipPicker(label: "Category", options: categoryOptions,
                               selection: category) { applyCategory($0) }
                    if isLooseCategory {
                        Button {
                            store.addCategory(Category(name: category, attributes: []))
                        } label: {
                            Text("Add \"\(category)\" as a category")
                                .font(Organic.captionStrong)
                                .foregroundStyle(Organic.a700)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 2)
                    }

                    HStack(spacing: 8) {
                        FormField("Bought for", text: $buy, numeric: true)
                        FormField("Worth about", text: $estimate, numeric: true)
                    }

                    ChipPicker(label: "Owner", options: store.data.owners.map(\.name), selection: ownerName) { n in
                        if let o = store.data.owners.first(where: { $0.name == n }) {
                            ownerID = o.id
                            if !cardsForOwner.contains(where: { $0.name == cardName }) {
                                cardName = cardsForOwner.first?.name ?? ""
                            }
                        }
                    }
                    // What and when it was bought, and from whom — the three
                    // things an import matches on to spot the same purchase twice.
                    FormField("Bought from (shop or seller)", text: $boughtFrom)
                    HStack {
                        Text("Bought on").font(Organic.value).foregroundStyle(Organic.n700)
                        Spacer()
                        DatePicker("", selection: $boughtOn, displayedComponents: .date)
                            .labelsHidden()
                    }
                    .padding(.horizontal, 2)

                    if let existingPlan {
                        VStack(alignment: .leading, spacing: 5) {
                            FieldLabel("Bought with")
                            Chip(label: Self.planOption, selected: true, tint: Organic.a600)
                            Text("On a \(existingPlan.months)-month plan · \(store.format(existingPlan.remaining())) still owed. Edit the plan in Wallet.")
                                .font(Organic.meta).foregroundStyle(Organic.n600)
                        }
                    } else {
                        ChipPicker(label: "Bought with (a card adds to its debt)",
                                   options: cardsForOwner.map(\.name) + [Self.planOption],
                                   selection: onPlan ? Self.planOption : cardName) { pick in
                            onPlan = pick == Self.planOption
                            cardName = onPlan ? "" : pick
                        }
                        if onPlan { planFields }
                    }
                    ChipPicker(label: "Planned channel", options: store.data.channels.map(\.name),
                               selection: channel) { channel = $0 }

                    FormField("Accessories, box, extras", text: $accessories)
                    FormField("Condition notes", text: $condition)

                    attributeBlock
                    PrimaryButton(title: item == nil ? "Add item" : "Save changes") { save() }
                }
                .padding(16)
            }
            .background(Organic.bg)
            .navigationTitle(item == nil ? "New item" : "Edit item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } } }
        }
        .onAppear(perform: seed)
    }

    /// Term, first payment, first date. The total is the purchase price.
    private var planFields: some View {
        InnerBlock(fill: Organic.n100) {
            FormField("Lender (Orico, Jaccs, MapCamera credit…)", text: $planLender)
            HStack(spacing: 5) {
                ForEach([12, 24, 36, 48, 60], id: \.self) { m in
                    Button { planMonths = String(m) } label: { Chip(label: "\(m)", selected: planMonthsValue == m) }
                        .buttonStyle(.plain)
                }
                FormField("mo", text: $planMonths, numeric: true).frame(width: 64)
            }
            HStack {
                FormField(planFirstSuggested > 0 ? "First payment (≈ \(planFirstSuggested.formatted()))" : "First payment",
                          text: $planFirst, numeric: true)
                DatePicker("", selection: $planFirstDate, displayedComponents: .date).labelsHidden()
            }
            if buyValue > 0 {
                let preview = Installment(name: name, principal: buyValue, months: planMonthsValue,
                                          firstAmount: planFirstValue, firstDate: planFirstDate)
                Text("0% over \(planMonthsValue) months: then \(store.format(preview.regular)) a month until \(preview.endDate.formatted(.dateTime.month(.abbreviated).year())). No card debt is added.")
                    .font(Organic.meta).foregroundStyle(Organic.n600)
            }
        }
    }

    private var ownerName: String {
        store.data.owners.first { $0.id == ownerID }?.name ?? ""
    }

    private var attributeBlock: some View {
        InnerBlock(fill: Organic.n100) {
            HStack {
                Text("Attributes").font(Organic.rowValue)
                Spacer()
                MiniButton(title: "+ Add row") {
                    attributes.append(AttributeRow(name: "", value: "", kind: .text))
                }
            }
            if attributes.isEmpty {
                Text("No attribute checklist for this category.")
                    .font(Organic.meta).foregroundStyle(Organic.n600)
            }
            ForEach($attributes) { $row in
                switch row.kind {
                case .text:
                    HStack(spacing: 6) {
                        TextField("Name", text: $row.name).textFieldStyle(.plain)
                            .frame(width: 110)
                        TextField("Value", text: $row.value).textFieldStyle(.plain)
                        RemoveButton { attributes.removeAll { $0.id == row.id } }
                    }
                    .font(Organic.value)
                    .padding(.horizontal, 11).padding(.vertical, 8)
                    .background(Organic.bg, in: RoundedRectangle(cornerRadius: Organic.rSmall))
                case .number:
                    HStack(spacing: 8) {
                        Text(row.name).font(Organic.valueStrong)
                            .frame(width: 100, alignment: .leading)
                        FormField("0", text: $row.value, numeric: true)
                            .frame(maxWidth: 130)
                        if !row.unit.isEmpty {
                            Text(row.unit).font(Organic.caption).foregroundStyle(Organic.n600)
                        }
                        Spacer()
                        RemoveButton { attributes.removeAll { $0.id == row.id } }
                    }
                case .bool, .options:
                    HStack(spacing: 8) {
                        Text(row.name).font(Organic.valueStrong).frame(width: 100, alignment: .leading)
                        ForEach(row.kind == .bool ? ["Yes", "No"] : row.options, id: \.self) { opt in
                            Button { row.value = opt } label: { Chip(label: opt, selected: row.value == opt) }
                                .buttonStyle(.plain)
                        }
                        Spacer()
                        RemoveButton { attributes.removeAll { $0.id == row.id } }
                    }
                }
            }
        }
    }

    /// Categories this book defines, plus whatever this item already says —
    /// an imported label has to stay visible, or editing looks like it lost it.
    private var categoryOptions: [String] {
        var options = store.data.categories.map(\.name)
        if !category.isEmpty, !options.contains(category) { options.append(category) }
        return options + ["Other"]
    }

    private var isLooseCategory: Bool {
        !category.isEmpty && category != "Other"
            && !store.data.categories.contains { $0.name == category }
    }

    // MARK: - Behaviour

    private func seed() {
        guard let item else {
            cardName = store.data.cards.first { $0.ownerID == "me" }?.name ?? ""
            channel = store.data.channels.first?.name ?? ""
            return
        }
        name = item.name; category = item.categoryName
        buy = String(item.buyPrice); estimate = String(item.estimatedPrice)
        boughtFrom = item.boughtFrom; boughtOn = item.boughtOn
        cardName = item.cardName; channel = item.plannedChannel
        accessories = item.accessories; condition = item.condition
        ownerID = store.data.cards.first { $0.name == item.cardName }?.ownerID ?? "me"
        // Rows are stored as name/value pairs, so the kind comes back from the
        // category — otherwise a number would reopen as a free-text field.
        let specs = store.data.categories.first { $0.name == item.categoryName }?.attributes ?? []
        attributes = item.attributes.map { pair in
            let name = pair.first ?? ""
            let spec = specs.first { $0.name == name }
            return AttributeRow(name: name, value: pair.count > 1 ? pair[1] : "",
                                kind: spec?.kind ?? .text, options: spec?.options ?? [],
                                unit: spec?.unit ?? "")
        }
    }

    /// Loading a category preserves values the user already typed for
    /// same-named attributes, and keeps any free-text rows they added.
    private func applyCategory(_ name: String) {
        category = name
        let previous = Dictionary(attributes.map { ($0.name, $0.value) }, uniquingKeysWith: { a, _ in a })
        let manual = attributes.filter { $0.kind == .text }
        guard let cat = store.data.categories.first(where: { $0.name == name }) else {
            attributes = manual; return
        }
        let seeded = cat.attributes.map { spec -> AttributeRow in
            let carried = previous[spec.name] ?? ""
            let fallback = spec.kind == .bool ? "No" : (spec.kind == .options ? (spec.options.first ?? "") : "")
            return AttributeRow(name: spec.name, value: carried.isEmpty ? fallback : carried,
                                kind: spec.kind, options: spec.options, unit: spec.unit)
        }
        let seededNames = Set(seeded.map(\.name))
        attributes = seeded + manual.filter { !seededNames.contains($0.name) }
    }

    private func save() {
        let buyPrice = Int(buy.filter(\.isNumber)) ?? 0
        let est = Int(estimate.filter(\.isNumber)) ?? buyPrice
        let attrs = attributes.filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { row -> [String] in
                let value = row.kind == .number ? row.value.filter(\.isNumber) : row.value
                return [row.name, value]
            }
        if var existing = item {
            existing.name = name; existing.categoryName = category
            existing.buyPrice = buyPrice; existing.estimatedPrice = est
            existing.cardName = cardName; existing.plannedChannel = channel
            existing.boughtFrom = boughtFrom; existing.boughtOn = boughtOn
            existing.accessories = accessories; existing.condition = condition
            existing.attributes = attrs
            store.update(existing)
        } else {
            let fresh = Item(name: name, categoryName: category, boughtOn: boughtOn,
                             buyPrice: buyPrice, boughtFrom: boughtFrom, cardName: onPlan ? "" : cardName,
                             estimatedPrice: est, plannedChannel: channel,
                             accessories: accessories, condition: condition,
                             attributes: attrs)
            store.addItem(fresh)
            if onPlan, buyPrice > 0 {
                store.addInstallment(Installment(name: name, lender: planLender, principal: buyPrice,
                                                 months: planMonthsValue, firstAmount: planFirstValue,
                                                 firstDate: planFirstDate, itemID: fresh.id))
            }
        }
        dismiss()
    }
}
