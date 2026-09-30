import SwiftUI
import Charts

/// Tab 1. Three questions, in the order they are asked: can I buy something
/// today (Safe to spend), what is in the bank and what am I worth, and can I
/// pay what is coming. Every figure comes from `Finance` through `Store`; the
/// view only lays them out.
struct OverviewView: View {
    @Environment(Store.self) private var store
    @State private var showNetWorth = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    heroCard
                    if store.isEmptyBook { startHereCard } else {
                        tiles
                        paymentsCard
                        resaleCard
                        debtCard
                    }
                }
                .padding(.horizontal, 16).padding(.top, 4).padding(.bottom, 16)
            }
            .background(Organic.bg)
            .navigationTitle("Mochi")
            .sheet(isPresented: $showNetWorth) { NetWorthSheet() }
        }
    }

    /// Shown until there is a book to draw on. The hero card above still reads
    /// zero honestly, so this only says where the numbers come from.
    private var startHereCard: some View {
        Card {
            Text("Start here").font(Organic.title)
            Text("""
                 Nothing is entered yet, so every number above is zero.

                 1. Wallet — add the bank accounts and cash you hold, the credit cards you buy on, any instalment plans, and what lands or leaves every month (salary, rent).
                 2. Settings — add the places you sell (Mercari, Rakuma…) with their fee.
                 3. Inventory — add what you own and what it should fetch.
                 4. Back here — this screen tells you what you can spend before the next bills, and whether the month is going up or down.
                 """)
                .font(Organic.value).foregroundStyle(Organic.n700)
                .padding(.top, 6)
            Text("Settings can load a sample book if you would rather look around first.")
                .font(Organic.caption).foregroundStyle(Organic.n600)
                .padding(.top, 8)
        }
    }

    // MARK: - Safe to spend

    /// Dark card, one number: cash after everything due before the horizon.
    /// Net worth used to sit here; it answered "what am I worth", not "can I
    /// buy this", and with most money on cards and in stock the two differ
    /// by a great deal.
    private var heroCard: some View {
        let s = store.safeToSpend
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("SAFE TO SPEND")
                    .font(Organic.metaStrong).kerning(1)
                    .foregroundStyle(.white.opacity(0.65))
                Spacer()
                horizonMenu
            }
            Text(store.format(s.total))
                .font(Organic.display(34))
                .foregroundStyle(s.total < 0 ? Organic.a300 : Organic.s300)
                .padding(.vertical, 4)
            Text(untilLine(s.end))
                .font(Organic.meta).foregroundStyle(.white.opacity(0.6))
                .padding(.bottom, 10)
            Hairline(color: .white.opacity(0.22)).padding(.bottom, 6)
            LineRow(label: "Cash available", value: store.format(s.cash), onDark: true)
            if s.incoming > 0 {
                LineRow(label: "Expected incoming", value: store.signed(s.incoming), tone: .positive, onDark: true)
            }
            LineRow(label: "Committed payments", value: store.signed(-s.committed), tone: .negative, onDark: true)
            if s.buffer > 0 {
                LineRow(label: "Safety reserve", value: store.signed(-s.buffer), tone: .quiet, onDark: true)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Organic.n900, in: RoundedRectangle(cornerRadius: Organic.rCard, style: .continuous))
    }

    /// How far the sum looks. Persisted, because the same person asks the same
    /// question every day.
    private var horizonMenu: some View {
        Menu {
            Button { store.setHorizon(.payday) } label: { horizonLabel("Until payday", .payday) }
            Button { store.setHorizon(.days(30)) } label: { horizonLabel("30 days", .days(30)) }
            Button { store.setHorizon(.days(60)) } label: { horizonLabel("60 days", .days(60)) }
        } label: {
            HStack(spacing: 4) {
                Text(horizonName(store.horizon)).font(Organic.valueStrong)
                Image(systemName: "chevron.up.chevron.down").font(Organic.glyph)
            }
            .foregroundStyle(.white.opacity(0.85))
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(.white.opacity(0.12), in: Capsule())
        }
    }

    @ViewBuilder
    private func horizonLabel(_ name: LocalizedStringKey, _ h: Finance.Horizon) -> some View {
        if store.horizon == h { Label(name, systemImage: "checkmark") } else { Text(name) }
    }

    private func horizonName(_ h: Finance.Horizon) -> LocalizedStringKey {
        switch h {
        case .payday: return "Until payday"
        case .days(let n): return "\(n) days"
        case .date: return "Custom"
        }
    }

    private func untilLine(_ end: Date) -> LocalizedStringKey {
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: .now), to: end).day ?? 0
        return "Until \(end.formatted(.dateTime.day().month(.abbreviated))) · \(days) days · what is left after every bill before then"
    }

    // MARK: - Tiles

    /// Two levels, at a glance: what is in the wallets and what the book is
    /// worth. Net worth is in neutral ink — it is a long-term figure, and a
    /// red one every morning teaches nothing.
    ///
    /// "Richer this month" sat under these as a card of its own. Until a
    /// second monthly snapshot exists it can only show the *planned* move —
    /// income less bills less a living estimate read off the cards — and a
    /// projection presented as this month's result is worse than no figure.
    /// The true month-on-month change is drawn from the snapshots on Stats,
    /// where a single reading is visibly a single point.
    private var tiles: some View {
        let worth = store.netWorth.total
        return HStack(spacing: 8) {
            Metric(label: "CASH NOW", value: store.format(store.cash), boxed: true)
            Button { showNetWorth = true } label: {
                Metric(label: "NET WORTH", value: store.format(worth),
                       valueColor: worth < 0 ? Organic.n700 : Organic.text, boxed: true)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Payments

    /// What has to be paid before the horizon, day by day, and whether the
    /// cash covers it.
    ///
    /// The verdict is the first thing on the card, not the last: "you are
    /// ¥200,000 short by the 26th" is the reason to open the app, and it used
    /// to sit under a chart and four rows. The chart is gone with it — a cash
    /// line answers "will I run short" only if you read the shape and do the
    /// subtraction yourself, and this says it in words.
    private var paymentsCard: some View {
        let days = store.paymentsDue
        let end = store.safeToSpend.end
        return Card {
            HStack(alignment: .firstTextBaseline) {
                Text("Paying the bills").font(Organic.title)
                Spacer()
                Text("Until \(end.formatted(.dateTime.day().month(.abbreviated)))")
                    .font(Organic.meta).foregroundStyle(Organic.n600)
            }
            if let short = store.shortfall {
                CalloutRow(label: "Short by \(short.from.formatted(.dateTime.day().month(.abbreviated)))",
                           value: store.format(short.amount), positive: false)
                    .padding(.top, 8)
                HelpText("That much more has to be in the bank by then, on top of what is there now, for every payment below to clear.",
                         tone: .warning)
                    .padding(.top, 6)
            } else if !days.isEmpty {
                CalloutRow(label: "Everything below is covered",
                           value: store.format(days.last?.balanceAfter ?? store.cash), positive: true)
                    .padding(.top, 8)
                HelpText("The cash you hold covers every payment before then, without selling anything.")
                    .padding(.top, 6)
            }
            if days.isEmpty {
                EmptyNote("Nothing due before then. Add cards, plans and monthly bills in Wallet so there is a schedule to draw.")
            }
            VStack(spacing: 0) {
                ForEach(days) { day in
                    dayRow(day)
                }
            }
            .padding(.top, 4)
        }
    }

    /// One day: the date, what is due, and what is left after it. The "left"
    /// column is the point — it is where you see the money run out.
    private func dayRow(_ day: Finance.DueDay) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(day.date.formatted(.dateTime.day().month(.abbreviated)))
                .font(Organic.captionStrong).foregroundStyle(Organic.n600)
                .frame(width: 48, alignment: .leading)
            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: dayNames(day)).font(Organic.row).lineLimit(1)
                Text(day.shortfall > 0
                     ? "short \(store.format(day.shortfall))"
                     : "left \(store.format(day.balanceAfter))")
                    .font(Organic.meta)
                    .foregroundStyle(day.shortfall > 0 ? Organic.a800 : Organic.n600)
            }
            Spacer(minLength: 8)
            Text(store.signed(day.amount))
                .font(Organic.rowValue)
                .foregroundStyle(day.amount > 0 ? Organic.s700 : Organic.text)
        }
        .padding(.vertical, Organic.Space.row)
        .overlay(alignment: .top) { Hairline() }
    }

    /// What is due that day. Money in has no payee, so a salary day says so
    /// rather than leaving the line blank. Two names and a count, because the
    /// 27th can hold five and the row is one line — the figure beside it is
    /// what the row is for.
    private func dayNames(_ day: Finance.DueDay) -> String {
        guard !day.names.isEmpty else { return String(localized: "Money in") }
        let shown = day.names.prefix(2).joined(separator: ", ")
        let rest = day.names.count - 2
        return rest > 0 ? String(localized: "\(shown) and \(rest) more") : shown
    }

    // MARK: - Buying and selling

    /// Reselling as a small business, whatever the thing is: a lens, a phone,
    /// a jacket bought to try and passed on. Two figures: what selling the
    /// stock would put in the bank, and what the sales confirmed this month
    /// actually made.
    ///
    /// Cost basis, expected margin, points and stock still on a card were here
    /// too. They are the workings, not the answer, and each already sits where
    /// it can be read against something — cost, proceeds and margin above the
    /// Inventory list, points and profit per month on Stats.
    private var resaleCard: some View {
        let c = store.resale
        return Card {
            HStack(alignment: .firstTextBaseline) {
                Text("Buying and selling").font(Organic.title)
                Spacer()
                Text("\(c.unsoldCount) for sale").font(Organic.meta).foregroundStyle(Organic.n600)
            }
            HStack(spacing: 8) {
                Metric(label: "Sell-all proceeds", value: store.format(c.liquidation), boxed: true)
                Metric(label: "Cash profit this month", value: store.signed(c.realizedThisMonth),
                       valueColor: c.realizedThisMonth < 0 ? Organic.a700 : Organic.s700, boxed: true)
            }
            .padding(.top, 10)
            HelpText("What the stock would fetch after fees if it all sold, and what this month's sales made after fees. Cost, margin and points are in Inventory and Stats.")
                .padding(.top, 8)
        }
    }

    // MARK: - Debt

    /// Everything owed, and separately what part of it is due soon. The whole
    /// is a weight; the near part is a bill. Reading the weight as a bill was
    /// the old mistake.
    private var debtCard: some View {
        let w = store.netWorth
        return Card {
            HStack(alignment: .firstTextBaseline) {
                Text("Debt").font(Organic.title)
                Spacer()
                Text(store.format(w.liabilities)).font(Organic.display(19)).foregroundStyle(Organic.a800)
            }
            VStack(spacing: 0) {
                LineRow(label: "Card statements", value: store.format(w.cardDebt))
                if w.unbilledCharges > 0 {
                    LineRow(label: "On cards, not yet billed", value: store.format(w.unbilledCharges), tone: .quiet)
                }
                if w.installmentPrincipal > 0 {
                    LineRow(label: "Instalment plans", value: store.format(w.installmentPrincipal))
                }
                if w.loansYouOwe > 0 {
                    LineRow(label: "People", value: store.format(w.loansYouOwe))
                }
            }
            .padding(.top, 8)
            // No "due in the next 30 days" line here any more. It was the same
            // arithmetic as the hero's Committed payments, and the card above
            // now lists it a line at a time — three places for one figure
            // taught the eye that none of them was worth reading. This card
            // answers what is owed; that one answers what leaves and when.
        }
    }
}
