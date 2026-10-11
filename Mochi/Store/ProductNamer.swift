import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Full product names for what is being typed into Buy advice, from the
/// on-device model, when the book has sold nothing like it. Names only: the
/// model has no idea what a thing sells for second-hand this month, and a
/// price it made up would be read as one looked up. Prices stay with the
/// sold searches in Safari.
enum ProductNamer {
    static var available: Bool { ReceiptReader.modelAvailable }

    /// Up to four names as a shop would list them ("70-200 z" →
    /// "Nikon NIKKOR Z 70-200mm f/2.8 VR S"); empty when the model is not
    /// there or is not sure.
    static func names(for typed: String) async -> [String] {
        let t = typed.trimmingCharacters(in: .whitespaces)
        guard t.count >= 3 else { return [] }
        #if canImport(FoundationModels)
        if #available(iOS 26, *), available {
            do {
                let session = LanguageModelSession(instructions: """
                    You complete product names for someone buying second-hand goods in Japan:
                    cameras, lenses, phones, computers, watches, clothes. Given what they typed,
                    give the full official product names it most likely means, as a shop lists them,
                    with the maker first. Only real products you are sure exist. No prices, no descriptions.
                    If you are not sure, give none.
                    """)
                let answer = try await session.respond(to: "Typed: \(t)", generating: ProductNames.self)
                var seen = Set<String>()
                return answer.content.names
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty && $0.count <= 80 && seen.insert($0.lowercased()).inserted }
                    .prefix(4).map { $0 }
            } catch {
                return []
            }
        }
        #endif
        return []
    }
}

#if canImport(FoundationModels)
@available(iOS 26, *)
@Generable
struct ProductNames {
    @Guide(description: "Up to four full product names, maker first, exactly as sold; empty when unsure")
    var names: [String]
}
#endif
