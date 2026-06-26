import SwiftUI
import VeliaCore
import VeliaDesignSystem

/// Month calendar: logged period days, the predicted next-period window, and the fertile window —
/// the timeline view from PRD §IA. Tap a day to log/unlog a period start.
struct CalendarView: View {
    @Environment(CycleStore.self) private var store
    @State private var monthAnchor = Date()

    private var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 2 // Monday-first (VN convention)
        return c
    }
    private let weekdaySymbols = ["T2", "T3", "T4", "T5", "T6", "T7", "CN"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.spacingLarge) {
                    monthHeader
                    weekdayRow
                    grid
                    legend
                }
                .padding()
            }
            .background(Theme.screen)
            .navigationTitle(L.calendar)
        }
    }

    // MARK: Header

    private var monthHeader: some View {
        HStack {
            Button { shiftMonth(-1) } label: { Image(systemName: "chevron.left") }
            Spacer()
            Text(monthTitle)
                .font(.headline)
            Spacer()
            Button { shiftMonth(1) } label: { Image(systemName: "chevron.right") }
        }
        .tint(Theme.accent)
    }

    private var weekdayRow: some View {
        HStack(spacing: 0) {
            ForEach(weekdaySymbols, id: \.self) { s in
                Text(s)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var grid: some View {
        let days = monthDays()
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 6) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                if let day {
                    dayCell(day)
                } else {
                    Color.clear.frame(height: 40)
                }
            }
        }
    }

    private func dayCell(_ day: Date) -> some View {
        let isToday = cal.isDateInToday(day)
        let isPeriod = store.hasPeriod(on: day)
        let inPredicted = isInInterval(day, store.prediction?.nextPeriod)
        let inFertile = isInInterval(day, store.prediction?.ovulation)

        return Button {
            store.togglePeriod(on: day)
        } label: {
            Text("\(cal.component(.day, from: day))")
                .font(.callout)
                .fontWeight(isToday ? .bold : .regular)
                .foregroundStyle(isPeriod ? Color.white : Color.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(cellBackground(isPeriod: isPeriod, inPredicted: inPredicted, inFertile: inFertile))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Theme.accent, lineWidth: isToday ? 1.5 : 0)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func cellBackground(isPeriod: Bool, inPredicted: Bool, inFertile: Bool) -> some View {
        if isPeriod {
            Theme.accent
        } else if inPredicted {
            Theme.predicted
        } else if inFertile {
            Theme.fertile.opacity(0.35)
        } else {
            Color.clear
        }
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: Theme.spacingSmall) {
            legendRow(Theme.accent, "Đã ghi kỳ kinh")
            legendRow(Theme.predicted, "Dự đoán kỳ kinh tới")
            legendRow(Theme.fertile.opacity(0.35), "Cửa sổ dễ thụ thai")
            Text("Chạm vào một ngày để ghi hoặc xóa kỳ kinh.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .veliaCard()
    }

    private func legendRow(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 4).fill(color).frame(width: 16, height: 16)
            Text(label).font(.caption)
            Spacer()
        }
    }

    // MARK: Date math

    private var monthTitle: String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "vi_VN")
        df.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        return df.string(from: monthAnchor).capitalized
    }

    private func shiftMonth(_ delta: Int) {
        if let d = cal.date(byAdding: .month, value: delta, to: monthAnchor) {
            monthAnchor = d
        }
    }

    /// Days of the displayed month, padded with leading nils to align the first weekday.
    private func monthDays() -> [Date?] {
        guard let interval = cal.dateInterval(of: .month, for: monthAnchor),
              let range = cal.range(of: .day, in: .month, for: monthAnchor) else { return [] }
        let first = interval.start
        let weekday = cal.component(.weekday, from: first)
        // Leading blanks before day 1 (Monday-first).
        let lead = (weekday - cal.firstWeekday + 7) % 7
        var cells: [Date?] = Array(repeating: nil, count: lead)
        for offset in 0..<range.count {
            if let d = cal.date(byAdding: .day, value: offset, to: first) {
                cells.append(d)
            }
        }
        return cells
    }

    private func isInInterval(_ day: Date, _ interval: DateInterval?) -> Bool {
        guard let interval else { return false }
        let start = cal.startOfDay(for: day)
        let end = cal.date(byAdding: .day, value: 1, to: start) ?? start
        return interval.intersects(DateInterval(start: start, end: end))
    }
}
