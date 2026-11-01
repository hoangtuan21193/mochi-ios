import SwiftUI
import UIKit

/// The share extension's entry (`NSExtensionPrincipalClass`). It hosts the
/// SwiftUI sheet and hands it whatever the other app shared.
final class ShareViewController: UIViewController {
    private let model = ShareModel(snapshot: ShareInbox.readSnapshot())

    override func viewDidLoad() {
        super.viewDidLoad()
        Organic.applyNavigationBarAppearance()
        KeyboardDismiss.endEditing = { [weak self] in self?.view.endEditing(true) }

        let sheet = ShareSheetView(model: model) { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: nil)
        }
        .environment(\.bookCurrency, model.currency)
        .tint(Organic.accent)
        .foregroundStyle(Organic.text)
        let host = UIHostingController(rootView: sheet)
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        host.didMove(toParent: self)

        let items = extensionContext?.inputItems as? [NSExtensionItem] ?? []
        Task { await model.load(items) }
    }
}
