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
    @State private var accessories = ""
    @State private var condition = ""
    @State private var attributes: [AttributeRow] = []

    struct AttributeRow: Identifiable {
        let id = UUID()
        var name: String
        var value: String
        var kind: AttributeKind
        var options: [String] = []
    }

    private var cardsForOwner: [CreditCard] { store.data.cards.filter { $0.ownerID == ownerID } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    field("", text: $name, placeholder: "What is it?")

                    picker("Category", options: store.data.categories.map(\.name) + ["Other"],
                           selection: category) { applyCategory($0) }

                    HStack(spacing: 8) {
                        field("", text: $buy, placeholder: "Bought for", numeric: true)
                        field("", text: $estimate, placeholder: "Worth about", numeric: true)
                    }

                    picker("Owner", options: store.data.owners.map(\.name), selection: ownerName) { n in
                        if let o = store.data.owners.first(where: { $0.name == n }) {
                            ownerID = o.id
                            if !cardsForOwner.contains(where: { $0.name == cardName }) {
                                cardName = cardsForOwner.first?.name ?? ""
                            }
                        }
                    }
                    picker("Bought with (adds to that card's debt)",
                           options: cardsForOwner.map(\.name), selection: cardName) { cardName = $0 }
                    picker("Planned channel", options: store.data.channels.map(\.name),
                           selection: channel) { channel = $0 }

                    field("", text: $accessories, placeholder: "Accessories, box, extras")
                    field("", text: $condition, placeholder: "Condition notes")

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

    private var ownerName: String {
        store.data.owners.first { $0.id == ownerID }?.name ?? ""
    }

    private var attributeBlock: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text("Attributes").font(.system(size: 13, weight: .heavy))
                Spacer()
                Button {
                    attributes.append(AttributeRow(name: "", value: "", kind: .text))
                } label: {
                    Text("+ Add row").font(.system(size: 11, weight: .heavy))
                        .padding(.horizontal, 11).padding(.vertical, 5)
                        .background(Organic.n200, in: Capsule())
                        .foregroundStyle(Organic.n800)
                }
            }
            if attributes.isEmpty {
                Text("No attribute checklist for this category.")
                    .font(.system(size: 10.5)).foregroundStyle(Organic.n600)
            }
            ForEach($attributes) { $row in
                switch row.kind {
                case .text:
                    HStack(spacing: 6) {
                        TextField("Name", text: $row.name).textFieldStyle(.plain)
                            .frame(width: 110)
                        TextField("Value", text: $row.value).textFieldStyle(.plain)
                        deleteButton(row.id)
                    }
                    .font(.system(size: 12.5))
                    .padding(.horizontal, 11).padding(.vertical, 8)
                    .background(Organic.bg, in: RoundedRectangle(cornerRadius: Organic.rSmall))
                case .bool, .options:
                    HStack(spacing: 8) {
                        Text(row.name).font(.system(size: 12.5, weight: .semibold)).frame(width: 100, alignment: .leading)
                        ForEach(row.kind == .bool ? ["Yes", "No"] : row.options, id: \.self) { opt in
                            Button { row.value = opt } label: { Chip(label: opt, selected: row.value == opt) }
                                .buttonStyle(.plain)
                        }
                        Spacer()
                        deleteButton(row.id)
                    }
                }
            }
        }
        .padding(14)
        .background(Organic.n100, in: RoundedRectangle(cornerRadius: Organic.rInner, style: .continuous))
    }

    private func deleteButton(_ id: UUID) -> some View {
        Button { attributes.removeAll { $0.id == id } } label: {
            Image(systemName: "xmark").font(.system(size: 11, weight: .heavy))
                .frame(width: 28, height: 28)
                .background(Organic.n200, in: Circle()).foregroundStyle(Organic.n700)
        }
    }

    private func field(_ label: String, text: Binding<String>, placeholder: String, numeric: Bool = false) -> some View {
        TextField(placeholder, text: text)
            .keyboardType(numeric ? .numberPad : .default)
            .font(.system(size: 13.5))
            .padding(.horizontal, 14).padding(.vertical, 11)
            .background(Organic.n100, in: Capsule())
            .overlay(Capsule().stroke(Organic.n300, lineWidth: 1.5))
    }

    private func picker(_ label: String, options: [String], selection: String,
                        onPick: @escaping (String) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            if !label.isEmpty {
                Text(label).font(.system(size: 11, weight: .semibold)).foregroundStyle(Organic.n600)
            }
            FlowRow(spacing: 5) {
                ForEach(options, id: \.self) { opt in
                    Button { onPick(opt) } label: { Chip(label: opt, selected: selection == opt) }
                        .buttonStyle(.plain)
                }
            }
        }
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
        cardName = item.cardName; channel = item.plannedChannel
        accessories = item.accessories; condition = item.condition
        ownerID = store.data.cards.first { $0.name == item.cardName }?.ownerID ?? "me"
        attributes = item.attributes.map {
            AttributeRow(name: $0.first ?? "", value: $0.count > 1 ? $0[1] : "", kind: .text)
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
                                kind: spec.kind, options: spec.options)
        }
        let seededNames = Set(seeded.map(\.name))
        attributes = seeded + manual.filter { !seededNames.contains($0.name) }
    }

    private func save() {
        let buyPrice = Int(buy.filter(\.isNumber)) ?? 0
        let est = Int(estimate.filter(\.isNumber)) ?? buyPrice
        let attrs = attributes.filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { [$0.name, $0.value] }
        if var existing = item {
            existing.name = name; existing.categoryName = category
            existing.buyPrice = buyPrice; existing.estimatedPrice = est
            existing.cardName = cardName; existing.plannedChannel = channel
            existing.accessories = accessories; existing.condition = condition
            existing.attributes = attrs
            store.update(existing)
        } else {
            store.addItem(Item(name: name, categoryName: category, boughtOn: .now,
                               buyPrice: buyPrice, cardName: cardName, estimatedPrice: est,
                               plannedChannel: channel, accessories: accessories,
                               condition: condition, attributes: attrs))
        }
        dismiss()
    }
}

/// Wrapping row of chips — SwiftUI has no flex-wrap, so lay them out by hand.
struct FlowRow: Layout {
    var spacing: CGFloat = 5

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > maxWidth { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            x += s.width + spacing
            rowHeight = max(rowHeight, s.height)
        }
        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > bounds.maxX { x = bounds.minX; y += rowHeight + spacing; rowHeight = 0 }
            v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing
            rowHeight = max(rowHeight, s.height)
        }
    }
}
