import SwiftUI
import VeliaCore
import VeliaDesignSystem

/// Circular cycle wheel (reference: Clue's "current cycle" ring). The full circle is one cycle:
/// day 1 at the top, going clockwise. The period sits at the top (red), the fertile window + an
/// ovulation dot on the lower-right (teal), the current day is marked, and the centre summarises
/// how long until the next period. Everything is derived from the on-device prediction.
struct CycleRingView: View {
    let model: CycleRingModel

    private let size: CGFloat = 300
    private let lineWidth: CGFloat = 24

    private var radius: CGFloat { (size - lineWidth) / 2 }
    private var center: CGPoint { CGPoint(x: size / 2, y: size / 2) }

    // Brighter palette to match the reference (independent of the app's rose accent).
    private let periodColor = Color(red: 0.95, green: 0.29, blue: 0.31)
    private let fertileColor = Theme.fertile
    private let ovulationDot = Color(red: 0.52, green: 0.81, blue: 0.95)
    private let track = Color.white.opacity(0.10)

    var body: some View {
        ZStack {
            // Base track
            Circle()
                .stroke(track, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))

            if model.hasData {
                arc(from: 0, days: model.periodLength, color: periodColor)
                if let ov = model.ovulationRange {
                    arc(fromDay: ov.lowerBound, toDay: ov.upperBound, color: fertileColor)
                }
                dayTicks
                if let ovDay = model.ovulationDay {
                    pointDot(day: ovDay, color: ovulationDot, diameter: 16, ringed: true)
                }
                currentDayMarker
            }

            centerText
        }
        .frame(width: size, height: size)
        .padding(.vertical, Theme.spacingLarge)
    }

    // MARK: Arcs

    private func arc(from startDay: Int, days: Int, color: Color) -> some View {
        arc(fromDay: startDay, toDay: startDay + days, color: color)
    }

    private func arc(fromDay: Int, toDay: Int, color: Color) -> some View {
        let from = fraction(fromDay)
        let to = fraction(toDay)
        return Circle()
            .trim(from: min(from, to), to: max(from, to))
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            .rotationEffect(.degrees(-90))
    }

    // MARK: Dots

    private var dayTicks: some View {
        ForEach(1...model.cycleLength, id: \.self) { day in
            Circle()
                .fill(.white.opacity(0.18))
                .frame(width: 3, height: 3)
                .position(point(day: day, atRadius: radius - lineWidth / 2 - 14))
        }
    }

    private func pointDot(day: Int, color: Color, diameter: CGFloat, ringed: Bool) -> some View {
        Circle()
            .fill(color)
            .frame(width: diameter, height: diameter)
            .overlay(ringed ? Circle().stroke(.white.opacity(0.6), lineWidth: 2) : nil)
            .position(point(day: day, atRadius: radius))
    }

    private var currentDayMarker: some View {
        VStack(spacing: 0) {
            Text(L2("Ngày", "Day")).font(.system(size: 9)).foregroundStyle(.secondary)
            Text("\(model.currentDay)").font(.system(size: 17, weight: .bold))
        }
        .frame(width: 46, height: 46)
        .background(Color(.tertiarySystemBackground), in: Circle())
        .overlay(Circle().stroke(.white.opacity(0.15), lineWidth: 1))
        .position(point(day: model.currentDay, atRadius: radius))
    }

    // MARK: Centre

    private var centerText: some View {
        VStack(spacing: 6) {
            if model.hasData {
                (Text(L2("Hôm nay", "Today")).bold() + Text(", \(model.todayString)"))
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                Text(model.headline)
                    .font(.system(.title, design: .rounded).weight(.bold))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Text(model.phaseName)
                    .font(.subheadline)
                    .foregroundStyle(fertileColor)
            } else {
                Text(L2("Chưa có dữ liệu", "No data yet"))
                    .font(.headline)
                Text(L2("Ghi kỳ kinh để xem chu kỳ của bạn", "Log a period to see your cycle"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(width: size - lineWidth * 2 - 24)
    }

    // MARK: Geometry — day 1 at top (12 o'clock), clockwise.

    private func fraction(_ day: Int) -> CGFloat {
        CGFloat(day - 1) / CGFloat(model.cycleLength)
    }

    private func point(day: Int, atRadius r: CGFloat) -> CGPoint {
        let angle = Double(fraction(day)) * 2 * .pi   // 0 at top
        return CGPoint(x: center.x + r * CGFloat(sin(angle)),
                       y: center.y - r * CGFloat(cos(angle)))
    }
}

/// Everything the ring needs, derived from the store + prediction in one place.
struct CycleRingModel {
    var hasData: Bool
    var cycleLength: Int
    var currentDay: Int
    var periodLength: Int
    var daysUntilNextPeriod: Int
    var ovulationDay: Int?
    var ovulationRange: ClosedRange<Int>?
    var phaseName: String
    var todayString: String

    var headline: String {
        if currentDay <= periodLength {
            let more = periodLength - currentDay
            if more <= 0 { return L2("Ngày cuối của kỳ kinh", "Last day of your period") }
            return L2("Còn \(more) ngày hành kinh", "\(more) more days of your period")
        }
        switch daysUntilNextPeriod {
        case 0: return L2("Kỳ kinh dự kiến hôm nay", "Period expected today")
        case 1: return L2("Còn 1 ngày đến kỳ kinh", "1 day until your next period")
        default: return L2("Còn \(daysUntilNextPeriod) ngày đến kỳ kinh",
                           "\(daysUntilNextPeriod) days until your next period")
        }
    }

    @MainActor
    static func from(_ store: CycleStore) -> CycleRingModel {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let todayStr = Fmt.dayMonth.string(from: today)
        let phase = L.phase(store.displayPhase())

        guard let prediction = store.prediction,
              let currentDay = store.cycleDay(),
              let lastStart = store.lastPeriodStart else {
            let len = store.profile.typicalCycleLength ?? 28
            return CycleRingModel(hasData: false, cycleLength: len, currentDay: 1, periodLength: 5,
                                  daysUntilNextPeriod: 0, ovulationDay: nil, ovulationRange: nil,
                                  phaseName: phase, todayString: todayStr)
        }

        // Predicted cycle length = day count from last start to the next predicted period start.
        let nextStart = prediction.nextPeriod.start
        let daysUntil = max(0, Int(DayMath.daysBetween(today, nextStart).rounded()))
        let predictedLen = max(currentDay + daysUntil, store.profile.typicalCycleLength ?? 28)
        let cycleLength = min(max(predictedLen, 14), 60)

        // Period length as set by the user (used for the red arc + "N more days" copy).
        let periodLength = min(max(store.typicalPeriodLength, 1), 10)

        // Ovulation as a day-of-cycle range.
        var ovDay: Int?
        var ovRange: ClosedRange<Int>?
        if let ov = prediction.ovulation {
            let lo = Int(DayMath.daysBetween(lastStart, ov.start).rounded()) + 1
            let hi = Int(DayMath.daysBetween(lastStart, ov.end).rounded()) + 1
            let clo = min(max(lo, 1), cycleLength), chi = min(max(hi, 1), cycleLength)
            ovRange = min(clo, chi)...max(clo, chi)
            ovDay = (clo + chi) / 2
        }

        return CycleRingModel(
            hasData: true, cycleLength: cycleLength, currentDay: min(currentDay, cycleLength),
            periodLength: periodLength, daysUntilNextPeriod: daysUntil,
            ovulationDay: ovDay, ovulationRange: ovRange,
            phaseName: phase, todayString: todayStr
        )
    }
}
