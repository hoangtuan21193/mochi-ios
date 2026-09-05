import SwiftUI

/// Categories live here, opened from the Inventory header — not in Settings,
/// because a category describes an item.
struct CategoryManagerView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var editorFor: CategoryEditorTarget?

    /// Wraps the optional so "new category" is a presentable value too.
    struct CategoryEditorTarget: Identifiable {
        let category: Category?
        var id: String { category?.id ?? "new" }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    HelpText("Each category carries its own attribute checklist. Tap to edit.")
                        .padding(.horizontal, 2)
                    Card(padding: .list) {
                        if store.data.categories.isEmpty {
                            Text("No categories yet. The + above adds one.")
                                .font(Organic.value).foregroundStyle(Organic.n600)
                                .padding(.vertical, 8)
                        }
                        ForEach(store.data.categories) { cat in
                            RowButton(first: cat.id == store.data.categories.first?.id,
                                      action: { editorFor = CategoryEditorTarget(category: cat) }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(cat.name).font(Organic.row)
                                        Text(cat.attributes.map(\.name).joined(separator: " · "))
                                            .font(Organic.meta).foregroundStyle(Organic.n600)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right").font(Organic.captionStrong)
                                        .foregroundStyle(Organic.n500)
                                }
                            }
                        }
                    }
            if !store.looseCategoryNames.isEmpty { looseCategories }
                }
                .padding(16)
            }
            .background(Organic.bg)
            .navigationTitle("Categories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Close") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    AddButton { editorFor = CategoryEditorTarget(category: nil) }
                }
            }
            // One sheet slot: stacked .sheet modifiers on a single view do not
            // reliably coexist.
            .sheet(item: $editorFor) { CategoryEditorView(category: $0.category) }
        }
    }

    /// Labels items carry that are not categories — usually left by an import.
    private var looseCategories: some View {
        Card {
            Text("Used by items, not categories yet").font(Organic.rowValue)
            HelpText("Add one to give it an attribute checklist.")
                .padding(.bottom, 6)
            ForEach(store.looseCategoryNames, id: \.self) { name in
                HStack {
                    Text(name).font(Organic.row)
                    Spacer()
                    Text("\(store.data.items.filter { $0.categoryName == name }.count)")
                        .font(Organic.caption).foregroundStyle(Organic.n600)
                    MiniButton(title: "Add", style: .accent) { store.addCategory(Category(name: name, attributes: [])) }
                }
                .padding(.vertical, 6)
            }
        }
        .padding(.top, 4)
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
                    FormField("Category name", text: $name)

                    SectionHeader(title: "Attributes",
                                  subtitle: "What this category asks about every item in it") {
                        specs.append(AttributeSpec(name: "", kind: .bool))
                    }
                    ForEach($specs) { $spec in
                        Card(fill: Organic.n100) {
                            // × sits with the name, not after the kind chips: four
                            // chips plus a button broke "Options" in half on a phone.
                            HStack(spacing: 8) {
                                FormField("Attribute name", text: $spec.name)
                                RemoveButton { specs.removeAll { $0.id == spec.id } }
                            }
                            ChipPicker(options: AttributeKind.allCases.map(label), selection: label(spec.kind)) { pick in
                                if let k = AttributeKind.allCases.first(where: { label($0) == pick }) { spec.kind = k }
                            }
                            .padding(.top, 7)
                            if spec.kind == .number {
                                FormField("Unit (shots, %, cycles) — optional",
                                          text: Binding(get: { spec.unit }, set: { spec.unit = $0 }))
                            }
                            if spec.kind == .options {
                                FormField("Options, separated by |",
                                          text: Binding(get: { optionText[spec.id] ?? spec.options.joined(separator: " | ") },
                                                        set: { optionText[spec.id] = $0 }))
                                    .padding(.top, 6)
                            }
                        }
                    }

                    PrimaryButton(title: "Save") { save() }
            if let category {
                DeleteButton(title: "Delete category") {
                    store.deleteCategory(category); dismiss()
                }
                .padding(.top, 4)
            }
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
        switch k {
        case .bool: "Yes/No"
        case .options: "Options"
        case .number: "Number"
        case .text: "Text"
        }
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
