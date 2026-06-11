import SwiftUI
import VeliaCore
import VeliaDesignSystem

/// Vertically scrolling multi-month calendar (reference screenshot 1). Logged period days render as
/// continuous rose bands; the predicted next period and fertile window are tinted; ovulation gets a
/// dot; today is outlined. Tap any day to open Track for that date.
struct CalendarView: View {
    @Environment(CycleStore.self) private var store
    @Binding var trackDate: Date?

    private var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 2 // Monday-first (VN)
        return c
    }
    private let weekdaySymbols = ["M", "T", "W", "T", "F", "S", "S"]

    /// Months from -6 … +6 around today.
    private var months: [Date] {
        let base = cal.startOfMonth(for: Date())
        return (-6...6).compactMap { cal.date(byAdding: .month, value: $0, to: base) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                topBar
                weekdayRow
                Divider()
                ScrollViewReader { proxy in
                    let model = makeModel() // one prediction, shared by every cell
                    ScrollView {
                        LazyVStack(spacing: Theme.spacingLarge, pinnedViews: []) {
                            ForEach(months, id: \.self) { month in
                                monthSection(month, model).id(cal.startOfMonth(for: month))
                            }
                        }
                        .padding(.vertical)
                    }
                    .onAppear { proxy.scrollTo(cal.startOfMonth(for: Date()), anchor: .center) }
                }
            }
            .background(Theme.screen)
            .navigationBarHidden(true)
        }
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack {
            Label("Bộ lọc", systemImage: "slider.horizontal.3")
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(Color(.secondarySystemBackground), in: Capsule())
            Spacer()
            Button { trackDate = cal.startOfDay(for: Date()) } label: {
                Image(systemName: "drop.fill")
                    .font(.title3)
                    .foregroundStyle(Theme.accent)
                    .padding(10)
                    .background(Color(.secondarySystemBackground), in: Circle())
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var weekdayRow: some View {
        HStack(spacing: 0) {
            ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, s in
                Text(s).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 6)
    }

    // MARK: Month

    private func monthSection(_ month: Date, _ model: CalModel) -> some View {
        VStack(spacing: 8) {
            Text(Fmt.monthTitle(month))
                .font(.headline)
                .frame(maxWidth: .infinity)
            grid(month, model)
        }
    }

    private func grid(_ month: Date, _ model: CalModel) -> some View {
        let days = monthDays(month)
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 4) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                if let day {
                    dayCell(day, model)
                } else {
                    Color.clear.frame(height: 44)
                }
            }
        }
        .padding(.horizontal, 4)
    }

    private func dayCell(_ day: Date, _ model: CalModel) -> some View {
        let s = state(for: day, model)
        return Button {
            trackDate = cal.startOfDay(for: day)
        } label: {
            ZStack(alignment: .topTrailing) {
                band(s)
                if s.ovulation {
                    Image(systemName: "circle.fill").font(.system(size: 7))
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(4)
                } else if s.hasLog && !s.period {
                    Circle().fill(Theme.accent).frame(width: 6, height: 6).padding(5)
                }
                Text("\(cal.component(.day, from: day))")
                    .font(.callout)
                    .fontWeight(s.today ? .bold : .regular)
                    .foregroundStyle(s.textColor)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(height: 44)
            .overlay {
                if s.today {
                    RoundedRectangle(cornerRadius: 10).stroke(Theme.accent, lineWidth: 2)
                }
            }
        }
        .buttonStyle(.plain)
    }

    /// The colored band behind a day, with rounded corners only at the ends of a contiguous run.
    @ViewBuilder
    private func band(_ s: DayState) -> some View {
        if s.period {
            UnevenRoundedRectangle(
                topLeadingRadius: s.runStart ? 16 : 0, bottomLeadingRadius: s.runStart ? 16 : 0,
                bottomTrailingRadius: s.runEnd ? 16 : 0, topTrailingRadius: s.runEnd ? 16 : 0
            ).fill(Theme.accent)
        } else if s.predictedPeriod {
            UnevenRoundedRectangle(
                topLeadingRadius: s.runStart ? 16 : 0, bottomLeadingRadius: s.runStart ? 16 : 0,
                bottomTrailingRadius: s.runEnd ? 16 : 0, topTrailingRadius: s.runEnd ? 16 : 0
            ).fill(Theme.accent.opacity(0.4))
        } else if s.fertile {
            UnevenRoundedRectangle(
                topLeadingRadius: s.runStart ? 16 : 0, bottomLeadingRadius: s.runStart ? 16 : 0,
                bottomTrailingRadius: s.runEnd ? 16 : 0, topTrailingRadius: s.runEnd ? 16 : 0
            ).fill(Theme.fertile.opacity(0.55))
        } else {
            Color.clear
        }
    }

    // MARK: Day state

    private struct DayState {
        var period = false
        var predictedPeriod = false
        var fertile = false
        var ovulation = false
        var today = false
        var hasLog = false
        var runStart = false
        var runEnd = false

        var textColor: Color {
            if period || predictedPeriod { return .white }
            if today { return Theme.accent }
            return .primary
        }
    }

    /// A day is part of the red "period band" if it's logged OR a predicted period day
    /// (the remaining expected days of the current period, or the predicted next period).
    private func isBandDay(_ day: Date, _ m: CalModel) -> Bool {
        store.isPeriodDay(on: day) || inRange(day, m.currentCompletion) || inRange(day, m.nextPeriod)
    }

    private func state(for day: Date, _ m: CalModel) -> DayState {
        var s = DayState()
        s.today = cal.isDateInToday(day)
        s.hasLog = store.hasAnyLog(on: day)

        // No-forecast mode: show only logged-day dots, never bands/predictions.
        guard store.mode.predictsCycle else { return s }

        let prev = cal.date(byAdding: .day, value: -1, to: day)!
        let next = cal.date(byAdding: .day, value: 1, to: day)!

        if store.isPeriodDay(on: day) {
            s.period = true
        } else if inRange(day, m.currentCompletion) || inRange(day, m.nextPeriod) {
            s.predictedPeriod = true
        } else if let ov = m.fertile, inInterval(day, ov) {
            s.fertile = true
            s.runStart = !inInterval(prev, ov)
            s.runEnd = !inInterval(next, ov)
            if let od = m.ovulationDay, cal.isDate(day, inSameDayAs: od) { s.ovulation = true }
            return s
        } else {
            return s
        }

        // Period / predicted-period bands round only at the ends of the combined band.
        s.runStart = !isBandDay(prev, m)
        s.runEnd = !isBandDay(next, m)
        return s
    }

    private func inInterval(_ day: Date, _ interval: DateInterval) -> Bool {
        let start = cal.startOfDay(for: day)
        let end = cal.date(byAdding: .day, value: 1, to: start)!
        return interval.intersects(DateInterval(start: start, end: end))
    }

    private func inRange(_ day: Date, _ range: ClosedRange<Date>?) -> Bool {
        guard let range else { return false }
        let d = cal.startOfDay(for: day)
        return d >= range.lowerBound && d <= range.upperBound
    }

    // MARK: Model — computed once (one prediction), shared by every cell

    struct CalModel {
        var currentCompletion: ClosedRange<Date>?  // remaining expected days of the current period
        var nextPeriod: ClosedRange<Date>?         // predicted next period, period-length band
        var fertile: DateInterval?
        var ovulationDay: Date?
    }

    private func makeModel() -> CalModel {
        var m = CalModel()
        guard store.mode.predictsCycle else { return m }
        let periodLen = max(store.typicalPeriodLength, 1)
        let today = cal.startOfDay(for: Date())

        // Complete the current period up to `độ dài hành kinh` (muted continuation).
        if let lastRun = store.periodRuns().last {
            let expectedEnd = cal.date(byAdding: .day, value: periodLen - 1, to: lastRun.lowerBound)!
            if expectedEnd > lastRun.upperBound && expectedEnd >= today {
                let from = cal.date(byAdding: .day, value: 1, to: lastRun.upperBound)!
                m.currentCompletion = from...expectedEnd
            }
        }

        guard let p = store.prediction else { return m }

        // Predicted next period: a period-length band starting at the expected start.
        let start = cal.startOfDay(for: p.pointDate)
        let end = cal.date(byAdding: .day, value: periodLen - 1, to: start)!
        m.nextPeriod = start...end

        if let ov = p.ovulation {
            m.fertile = ov
            m.ovulationDay = cal.startOfDay(for: Date(timeIntervalSince1970:
                (ov.start.timeIntervalSince1970 + ov.end.timeIntervalSince1970) / 2))
        }
        return m
    }

    // MARK: Grid days

    private func monthDays(_ month: Date) -> [Date?] {
        guard let interval = cal.dateInterval(of: .month, for: month),
              let range = cal.range(of: .day, in: .month, for: month) else { return [] }
        let first = interval.start
        let weekday = cal.component(.weekday, from: first)
        let lead = (weekday - cal.firstWeekday + 7) % 7
        var cells: [Date?] = Array(repeating: nil, count: lead)
        for offset in 0..<range.count {
            cells.append(cal.date(byAdding: .day, value: offset, to: first))
        }
        return cells
    }
}

private extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        dateInterval(of: .month, for: date)?.start ?? date
    }
}
