import SwiftUI

/// Categories live here, opened from the Inventory header — not in Settings,
/// because a category describes an item.
struct CategoryManagerView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var editing: Category? = nil
    @State private var creatingNew = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Each category carries its own attribute checklist. Tap to edit.")
                        .font(.system(size: 11.5)).foregroundStyle(Organic.n600).padding(.horizontal, 2)
                    Card(padding: EdgeInsets(top: 6, leading: 15, bottom: 9, trailing: 15)) {
                        ForEach(store.data.categories) { cat in
                            Button { editing = cat } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(cat.name).font(.system(size: 13, weight: .semibold))
                                        Text(cat.attributes.map(\.name).joined(separator: " · "))
                                            .font(.system(size: 10.5)).foregroundStyle(Organic.n600)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right").font(.system(size: 11, weight: .heavy))
                                        .foregroundStyle(Organic.n500)
                                }
                                .padding(.vertical, 10)
                                .overlay(alignment: .top) {
                                    if cat.id != store.data.categories.first?.id { Divider().overlay(Organic.n200) }
                                }
                            }
                            .buttonStyle(.plain).foregroundStyle(Organic.text)
                        }
                    }
                    PrimaryButton(title: "+ Add category") { creatingNew = true }
                }
                .padding(16)
            }
            .background(Organic.bg)
            .navigationTitle("Categories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Close") { dismiss() } } }
            .sheet(item: $editing) { CategoryEditorView(category: $0) }
            .sheet(isPresented: $creatingNew) { CategoryEditorView(category: nil) }
        }
    }
}

/// Name + a list of attribute rows. A category with no attributes is legal —
/// that is how "Other" behaves.
struct CategoryEditorView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let category: Category?

    @State private var name = ""
    @State private var specs: [AttributeSpec] = []
    /// Options are typed as one string separated by "|".
    @State private var optionText: [String: String] = [:]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    TextField("Category name", text: $name)
                        .font(.system(size: 13.5))
                        .padding(.horizontal, 14).padding(.vertical, 11)
                        .background(Organic.n100, in: Capsule())
                        .overlay(Capsule().stroke(Organic.n300, lineWidth: 1.5))

                    ForEach($specs) { $spec in
                        Card(fill: Organic.n100) {
                            TextField("Attribute name", text: $spec.name)
                                .font(.system(size: 13))
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .background(Organic.bg, in: Capsule())
                            HStack(spacing: 5) {
                                ForEach(AttributeKind.allCases, id: \.self) { kind in
                                    Button { spec.kind = kind } label: {
                                        Chip(label: label(kind), selected: spec.kind == kind)
                                    }
                                    .buttonStyle(.plain)
                                }
                                Spacer()
                                Button { specs.removeAll { $0.id == spec.id } } label: {
                                    Image(systemName: "trash").font(.system(size: 11, weight: .heavy))
                                        .frame(width: 28, height: 28)
                                        .background(Organic.n200, in: Circle()).foregroundStyle(Organic.n700)
                                }
                            }
                            .padding(.top, 7)
                            if spec.kind == .options {
                                TextField("Options, separated by |",
                                          text: Binding(get: { optionText[spec.id] ?? spec.options.joined(separator: " | ") },
                                                        set: { optionText[spec.id] = $0 }))
                                    .font(.system(size: 12.5))
                                    .padding(.horizontal, 12).padding(.vertical, 8)
                                    .background(Organic.bg, in: Capsule())
                                    .padding(.top, 6)
                            }
                        }
                    }

                    Button {
                        specs.append(AttributeSpec(name: "", kind: .bool))
                    } label: {
                        Text("+ Add attribute").font(.system(size: 13, weight: .heavy))
                            .frame(maxWidth: .infinity).padding(.vertical, 11)
                            .background(Organic.n200, in: Capsule()).foregroundStyle(Organic.n800)
                    }
                    PrimaryButton(title: "Save") { save() }
                }
                .padding(16)
            }
            .background(Organic.bg)
            .navigationTitle(category == nil ? "New category" : "Edit category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } } }
        }
        .onAppear {
            if let category { name = category.name; specs = category.attributes }
        }
    }

    private func label(_ k: AttributeKind) -> String {
        switch k { case .bool: "Yes / No"; case .options: "Options"; case .text: "Free text" }
    }

    private func save() {
        var cleaned = specs.filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
        for i in cleaned.indices where cleaned[i].kind == .options {
            let raw = optionText[cleaned[i].id] ?? cleaned[i].options.joined(separator: "|")
            cleaned[i].options = raw.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        }
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        if let category, let ix = store.data.categories.firstIndex(where: { $0.id == category.id }) {
            store.data.categories[ix] = Category(id: category.id, name: name, attributes: cleaned)
        } else {
            store.data.categories.append(Category(name: name, attributes: cleaned))
        }
        store.save()
        dismiss()
    }
}
