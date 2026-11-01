import SwiftUI

/// Share › Mochi: a thing bought on Mercari (or any shop page) into the book
/// in three taps. Canvas: ShareItem, ShareItemReading, ShareItemFailed.
struct ShareSheetView: View {
    @Bindable var model: ShareModel
    let close: () -> Void

    var body: some View {
        SheetScaffold(title: "Add to Mochi", leading: ("Close", close)) {
            switch model.phase {
            case .noBook:
                Banner(text: "Open Mochi once first", symbol: "exclamationmark.triangle", tone: .warn,
                       detail: "There is no book on this iPhone yet for this to go into.")
            case .unread(let foreign):
                if let foreign {
                    Banner(text: "This page is in \(foreign)", symbol: "exclamationmark.triangle", tone: .warn,
                           detail: "Type what you paid in yours.")
                } else {
                    Banner(text: "Couldn’t read the page", symbol: "exclamationmark.triangle", tone: .warn,
                           detail: "No connection, or the page has no price on it. Type what you paid.")
                }
            default:
                EmptyView()
            }
            if let known = model.known {
                Banner(text: "Already in your book: \(known.name), bought \(known.date.formatted(date: .abbreviated, time: .omitted))",
                       symbol: "info.circle", tone: .info)
            }
            if model.snapshot != nil { form }
        }
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: Organic.Space.row) {
            Card {
                VStack(alignment: .leading, spacing: Organic.Space.l) {
                    HStack(alignment: .bottom, spacing: Organic.Space.l) {
                        thumbnail
                        VStack(alignment: .leading, spacing: Organic.Space.xs) {
                            FieldLabel("Name")
                            FormField("What is it?", text: $model.name)
                        }
                    }
                    ChipPicker(label: "Why you bought it", options: SharedEntry.Purpose.allCases.map(\.rawValue),
                               selection: model.purpose.rawValue, display: Self.purposeName) {
                        model.purpose = SharedEntry.Purpose(rawValue: $0) ?? .use
                    }
                    HStack(alignment: .bottom, spacing: Organic.Space.m) {
                        VStack(alignment: .leading, spacing: Organic.Space.xs) {
                            FieldLabel("Paid")
                            MoneyField("Paid", value: $model.price)
                        }
                        VStack(alignment: .leading, spacing: Organic.Space.xs) {
                            FieldLabel("Bought at")
                            FormField("Shop", text: $model.shop)
                        }
                    }
                    priceNote
                    if model.accounts.count > 1 {
                        ChipPicker(label: "Paid with", options: model.accounts, selection: model.account) { model.account = $0 }
                        if model.accountIsRemembered {
                            HelpText("What you paid \(model.shop) with last time.")
                        }
                    } else if let only = model.accounts.first {
                        HelpText("Paid with \(only), the only account in your book.")
                    }
                }
            }
            Text(model.preview).font(Organic.meta).foregroundStyle(Organic.n600)
                .padding(.horizontal, Organic.Space.xs)
            PrimaryButton(title: model.known == nil ? "Save" : "Add again") { if model.save() { close() } }
                .disabled(!model.canSave)
            if model.saveFailed {
                HelpText("Couldn’t save. Open Mochi once, then share the page again.", tone: .warning)
            }
            HelpText(footnote).padding(.horizontal, Organic.Space.xs)
        }
    }

    @ViewBuilder private var priceNote: some View {
        switch model.phase {
        case .reading:
            HStack(spacing: Organic.Space.s) {
                ProgressView().controlSize(.mini)
                HelpText("Reading the page for its name and price…")
            }
        case .ready:
            if let listed = model.listed {
                HelpText("Listed at \(model.currency.format(listed)). Change it if a coupon or points paid part of it.")
            }
        default:
            EmptyView()
        }
    }

    private var footnote: LocalizedStringKey {
        switch model.phase {
        case .off: "Reading links is off in Mochi › Settings › Your data, so nothing was opened."
        case .ready, .reading: "The page was read once on this iPhone, for its name and price. Nothing from your book was sent."
        default: "Nothing from your book was sent."
        }
    }

    private var thumbnail: some View {
        AsyncImage(url: model.image) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            Image(systemName: "photo").font(Organic.title).foregroundStyle(Organic.n600)
        }
        .frame(width: 64, height: 64)
        .background(Organic.surface)
        .clipShape(RoundedRectangle(cornerRadius: Organic.rSmall, style: .continuous))
        .accessibilityHidden(true)
    }

    private static func purposeName(_ raw: String) -> Text {
        switch SharedEntry.Purpose(rawValue: raw) {
        case .sell: Text("To sell")
        case .use: Text("To use")
        case .spend: Text("Just a spend")
        case nil: Text(verbatim: raw)
        }
    }
}
