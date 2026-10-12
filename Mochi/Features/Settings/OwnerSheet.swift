import SwiftUI

// MARK: - Owner

struct OwnerEditorView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let owner: Owner

    @State private var name = ""
    @State private var refusal: String?

    var body: some View {
        SheetScaffold(title: "Edit owner") {
            FormField("Name", text: $name)
            PrimaryButton(title: "Save") {
                guard !name.isEmpty else { return }
                var copy = owner; copy.name = name
                store.updateOwner(copy)
                dismiss()
            }
            if owner.id != "me" {
                DeleteButton(title: "Delete owner") {
                    if let why = store.deleteOwner(owner) { refusal = why } else { dismiss() }
                }
                .padding(.top, 4)
            } else {
                HelpText("\"Me\" is built in — the card drawdown splits your bills from the ones you pay on behalf of others by it.")
            }
            if let refusal {
                Text(verbatim: refusal).font(Organic.value).foregroundStyle(Organic.a800)
            }
        }
        .onAppear { name = owner.name }
    }
}
