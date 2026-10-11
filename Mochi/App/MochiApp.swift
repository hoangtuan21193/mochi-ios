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
        .onAppear {
            router.tab = Self.initialTab
            #if DEBUG
            // Debug-only: `-open spending` / `-open buy` / `-open networth` lands on a screen a tab
            // alone cannot reach, so design-check can capture it without taps.
            switch UserDefaults.standard.string(forKey: "open") {
            case "spending": router.transactionsFilter = .all; router.showSpending = true; router.tab = .transactions
            case "buy": router.openBuyAdvice()
            case "networth": router.tab = .wallet
            default: break
            }
            switch UserDefaults.standard.string(forKey: "planPart") {
            case "goals": router.planPart = .goals
            case "recurring": router.planPart = .recurring
            default: break
            }
            #endif
        }
        .onChange(of: phase) { _, now in
            // Money moves on its day whether or not the app was open: salary,
            // bills, card payments are posted the moment it comes back.
            if now == .active {
                store.postDueSchedules()
                Task { await store.syncWithCloud() }
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
            switch url.host {
            case "scan": router.capture = .scan
            case "add": router.capture = .type
            case "review": router.review()
            case "buy": router.openBuyAdvice()
            default: break
            }
        }
    }
}
