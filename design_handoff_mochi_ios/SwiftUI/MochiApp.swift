import SwiftUI

@main
struct MochiApp: App {
    @State private var store = Store()
    var body: some Scene {
        WindowGroup { RootTabView().environment(store) }
    }
}

struct RootTabView: View {
    @Environment(Store.self) private var store
    var body: some View {
        TabView {
            OverviewView().tabItem { Label("Overview", systemImage: "house") }
            InventoryView().tabItem { Label("Inventory", systemImage: "shippingbox") }
            StatsView().tabItem { Label("Stats", systemImage: "chart.bar") }
            WalletView().tabItem { Label("Wallet", systemImage: "wallet.bifold") }
            SettingsView().tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .tint(Organic.accent)
        .background(Organic.bg)
    }
}
