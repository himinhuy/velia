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
                    ScrollView {
                        LazyVStack(spacing: Theme.spacingLarge, pinnedViews: []) {
                            ForEach(months, id: \.self) { month in
                                monthSection(month).id(cal.startOfMonth(for: month))
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

    private func monthSection(_ month: Date) -> some View {
        VStack(spacing: 8) {
            Text(Fmt.monthTitle(month))
                .font(.headline)
                .frame(maxWidth: .infinity)
            grid(month)
        }
    }

    private func grid(_ month: Date) -> some View {
        let days = monthDays(month)
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 4) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                if let day {
                    dayCell(day)
                } else {
                    Color.clear.frame(height: 44)
                }
            }
        }
        .padding(.horizontal, 4)
    }

    private func dayCell(_ day: Date) -> some View {
        let s = state(for: day)
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
            if period { return .white }
            if today { return Theme.accent }
            return .primary
        }
    }

    private func state(for day: Date) -> DayState {
        var s = DayState()
        s.today = cal.isDateInToday(day)
        s.hasLog = store.hasAnyLog(on: day)

        let prev = cal.date(byAdding: .day, value: -1, to: day)!
        let next = cal.date(byAdding: .day, value: 1, to: day)!

        s.period = store.isPeriodDay(on: day)
        if s.period {
            s.runStart = !store.isPeriodDay(on: prev)
            s.runEnd = !store.isPeriodDay(on: next)
            return s
        }

        if let p = store.prediction {
            // Don't tint days that already passed as "predicted".
            if inInterval(day, p.nextPeriod) {
                s.predictedPeriod = true
                s.runStart = !inInterval(prev, p.nextPeriod)
                s.runEnd = !inInterval(next, p.nextPeriod)
            } else if let ov = p.ovulation, inInterval(day, ov) {
                s.fertile = true
                s.runStart = !inInterval(prev, ov)
                s.runEnd = !inInterval(next, ov)
                // Mark the middle of the fertile window as ovulation.
                let mid = Date(timeIntervalSince1970:
                    (ov.start.timeIntervalSince1970 + ov.end.timeIntervalSince1970) / 2)
                if cal.isDate(day, inSameDayAs: mid) { s.ovulation = true }
            }
        }
        return s
    }

    private func inInterval(_ day: Date, _ interval: DateInterval) -> Bool {
        let start = cal.startOfDay(for: day)
        let end = cal.date(byAdding: .day, value: 1, to: start)!
        return interval.intersects(DateInterval(start: start, end: end))
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
