import SwiftUI

/// Where the app is: which tab, and what a scan button (or a tile on Home)
/// asked to open. One instance in the environment, so a button on Home can land the
/// user on Transactions filtered to what needs a look.
@Observable
final class Router {
    enum Tab: Int, CaseIterable { case home, transactions, wallet, belongings, plan }

    /// What the capture sheet opens on.
    enum Capture: Identifiable, Equatable {
        case scan
        case type
        /// Quick add at a place the book knows.
        case here(Finance.Place)
        var id: String {
            switch self {
            case .scan: return "scan"
            case .type: return "type"
            case .here(let p): return "here-\(p.merchant)"
            }
        }
        static func == (a: Capture, b: Capture) -> Bool { a.id == b.id }
    }

    var tab: Tab = .home
    var capture: Capture?
    /// Transactions opens on this filter and view the next time it appears.
    var transactionsFilter: Finance.TransactionFilter = .all
    var showSpending = false
    /// The weekly check-in, opened from a notification or Home.
    var checkin = false
    /// Which part of Plan shows: kept here so Wallet's "Every month" row can
    /// land on Recurring.
    enum PlanPart: Hashable { case budget, goals, recurring }
    var planPart: PlanPart = .budget
    /// Belongings pushes Buy advice: from the widget, the shortcut, or its own card.
    var buyAdvice = false

    func openBuyAdvice() {
        tab = .belongings
        buyAdvice = true
    }

    func open(_ tab: Tab) { self.tab = tab }

    func review() {
        transactionsFilter = .review
        showSpending = false
        tab = .transactions
    }
}
