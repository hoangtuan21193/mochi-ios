import SwiftUI

@main
struct MochiApp: App {
    @State private var store = Store.shared

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
                // Every token has a light and a dark value, so the app follows
                // the system setting.
        }
    }
}

struct RootTabView: View {
    @Environment(Store.self) private var store
    @Environment(\.scenePhase) private var phase
    /// The phone's own light or dark, read here where nothing overrides it.
    @Environment(\.colorScheme) private var systemScheme
    @State private var router = Router()

    /// Debug-only: `-tab 3` picks the starting tab so screens can be captured
    /// without driving the UI. Always home in release builds.
    static var initialTab: Router.Tab {
        #if DEBUG
        return Router.Tab(rawValue: UserDefaults.standard.integer(forKey: "tab")) ?? .home
        #else
        return .home
        #endif
    }

    /// On an iPad (iOS 18 and later) the five places are a sidebar; on a
    /// phone, and on an iPad in Split View, they stay the tab bar.
    @ViewBuilder private var tabs: some View {
        if #available(iOS 18, *) {
            TabView(selection: $router.tab) {
                Tab("Home", systemImage: "house", value: Router.Tab.home) { HomeView() }
                Tab("Transactions", systemImage: "list.bullet", value: Router.Tab.transactions) { TransactionsView() }
                    .badge(store.reviewCount)
                Tab("Wallet", systemImage: "wallet.bifold", value: Router.Tab.wallet) { WalletView() }
                Tab("Belongings", systemImage: "shippingbox", value: Router.Tab.belongings) { InventoryView() }
                Tab("Plan", systemImage: "calendar", value: Router.Tab.plan) { PlanView() }
            }
            // iPadOS puts the tabs in a bar along the top, with the sidebar a
            // button away. Opening the sidebar by default was tried: in
            // portrait it covers half the screen it is meant to sit beside.
            .tabViewStyle(.sidebarAdaptable)
        } else {
            TabView(selection: $router.tab) {
                HomeView().tabItem { Label("Home", systemImage: "house") }.tag(Router.Tab.home)
                TransactionsView().tabItem { Label("Transactions", systemImage: "list.bullet") }.tag(Router.Tab.transactions)
                    .badge(store.reviewCount)
                WalletView().tabItem { Label("Wallet", systemImage: "wallet.bifold") }.tag(Router.Tab.wallet)
                InventoryView().tabItem { Label("Belongings", systemImage: "shippingbox") }.tag(Router.Tab.belongings)
                PlanView().tabItem { Label("Plan", systemImage: "calendar") }.tag(Router.Tab.plan)
            }
        }
    }

    /// A sheet cannot be shown over another one, and a file can arrive while
    /// any sheet is up (Export, a scan, a form), so whatever is up is put
    /// away first; nothing in it was saved, as with Close.
    private func openBookFile(_ url: URL) {
        let root = UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.keyWindow }.first?.rootViewController
        guard root?.presentedViewController != nil else { router.bookFile = url; return }
        router.capture = nil
        router.checkin = false
        root?.dismiss(animated: true) { router.bookFile = url }
    }

    var body: some View {
        // Five places, each a screen. Scanning was the middle (+) and is not a
        // place: it opens from Home, from Transactions, from the widget, the
        // Control Center, the Action button and Siri, and hands the user back
        // where they were.
        tabs
        .tint(Organic.accent)
        .background(Organic.bg)
        // Anything that does not name its own colour is ink, not the system
        // label colour.
        .foregroundStyle(Organic.text)
        .environment(router)
        // The camera takes the whole screen, a form is a sheet.
        .sheet(item: Binding(get: { router.capture == .scan ? nil : router.capture }, set: { router.capture = $0 })) { which in
            CaptureSheet(start: which).environment(store).environment(router)
        }
        .fullScreenCover(item: Binding(get: { router.capture == .scan ? router.capture : nil }, set: { router.capture = $0 })) { which in
            CaptureSheet(start: which, systemScheme: systemScheme).environment(store).environment(router)
        }
        .sheet(isPresented: $router.checkin) {
            WeeklyCheckinView().environment(store).environment(router)
        }
        .sheet(item: $router.bookFile) { url in
            BookImportView(url: url).environment(store)
        }
        // Rates for receipts in another currency, then gold and coin prices (decision #31).
        .task { await store.refreshRates(); await store.refreshPrices() }
        // Purchases saved from Share › Mochi before this launch.
        .task { store.takeSharedEntries() }
        .onAppear {
            router.tab = Self.initialTab
            #if DEBUG
            // Debug-only: `-open spending` / `-open buy` / `-open profit` / `-open networth` lands on a screen a tab
            // alone cannot reach, so design-check can capture it without taps.
            switch UserDefaults.standard.string(forKey: "open") {
            case "spending": router.transactionsFilter = .all; router.showSpending = true; router.tab = .transactions
            case "buy": router.openBuyAdvice()
            case "profit": router.openProfit()
            case "networth": router.tab = .wallet
            default: break
            }
            // `-bookFile /path/to/x.mochi`: the import sheet as if the file had been opened from outside.
            if let path = UserDefaults.standard.string(forKey: "bookFile") { router.bookFile = URL(fileURLWithPath: path) }
            switch UserDefaults.standard.string(forKey: "planPart") {
            case "goals": router.planPart = .goals
            case "recurring": router.planPart = .recurring
            default: break
            }
            #endif
        }
        .onChange(of: phase) { _, now in
            if now == .active {
                // What was saved from Share › Mochi while the app was away.
                store.takeSharedEntries()
                Task { await store.syncWithCloud() }
                Task { await store.refreshRates(); await store.refreshPrices() }
                if store.pendingCapture { store.pendingCapture = false; router.capture = .scan }
                if store.pendingBuyAdvice { store.pendingBuyAdvice = false; router.openBuyAdvice() }
            }
        }
        // The Buy advice shortcut while the app is already in front.
        .onChange(of: store.pendingBuyAdvice) { _, now in
            if now { store.pendingBuyAdvice = false; router.openBuyAdvice() }
        }
        // mochi://scan from the widget and the Control Center control.
        .onOpenURL { url in
            // A book file handed over by the share sheet, AirDrop or Files.
            if url.isFileURL { openBookFile(url); return }
            switch url.host {
            case "scan": router.capture = .scan
            case "add": router.capture = .type
            case "review": router.review()
            case "buy": router.openBuyAdvice()
            default: break
            }
        }
        // MoneyField reads the book's currency from here rather than from the
        // Store, so the share extension can draw it without a book. Last in
        // the chain, so every sheet above is inside it.
        .environment(\.bookCurrency, store.currency)
    }
}
