import SwiftUI

@main
struct MochiApp: App {
    @State private var store = Store()

    init() {
        Organic.applyNavigationBarAppearance()
        #if DEBUG
        // `-demo 1` seeds the sample book on launch, for screenshots and for
        // checking that what is written actually survives a relaunch.
        if UserDefaults.standard.bool(forKey: "demo") { store.loadDemoData() }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(store)
                // The Organic palette is a single light voice — cream ground,
                // ink text. There is no dark counterpart, so the app does not
                // follow the system: in dark mode the unstyled text would turn
                // white on a cream card.
                .preferredColorScheme(.light)
                .task { Organic.pinInterfaceStyleToLight() }
        }
    }
}

struct RootTabView: View {
    @Environment(Store.self) private var store
    @State private var tab = RootTabView.initialTab

    /// Debug-only: `-tab 3` picks the starting tab so screens can be captured
    /// without driving the UI. Always 0 in release builds.
    static var initialTab: Int {
        #if DEBUG
        let n = UserDefaults.standard.integer(forKey: "tab")
        return (0...4).contains(n) ? n : 0
        #else
        return 0
        #endif
    }

    var body: some View {
        // Five, and five only: iOS folds a sixth tab into a "More" list, which
        // buried Activity *and* Settings behind an extra tap. Activity is a
        // full screen opened from Wallet instead — one tap, next to the
        // balances it explains, the way the loan book already works.
        TabView(selection: $tab) {
            OverviewView().tabItem { Label("Overview", systemImage: "house") }.tag(0)
            InventoryView().tabItem { Label("Inventory", systemImage: "shippingbox") }.tag(1)
            StatsView().tabItem { Label("Stats", systemImage: "chart.bar") }.tag(2)
            WalletView().tabItem { Label("Wallet", systemImage: "wallet.bifold") }.tag(3)
            SettingsView().tabItem { Label("Settings", systemImage: "gearshape") }.tag(4)
        }
        .tint(Organic.accent)
        .background(Organic.bg)
        // Anything that does not name its own colour is ink, not the system
        // label colour.
        .foregroundStyle(Organic.text)
    }
}
