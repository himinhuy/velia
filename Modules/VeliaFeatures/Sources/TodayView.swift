import SwiftUI
import VeliaCore
import VeliaDesignSystem

/// Home screen. Shows the on-device prediction from day one with an honestly wide range that narrows
/// as the user logs (PRD §retention mechanic). All numbers come from VeliaCore — this view only renders.
struct TodayView: View {
    @Environment(CycleStore.self) private var store

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.spacingLarge) {
                    header
                    if let prediction = store.prediction {
                        predictionCard(prediction)
                        sharpenHint
                    } else {
                        emptyState
                    }
                    quickLog
                    Text(L.privacyFootnote)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .padding(.top, Theme.spacing)
                }
                .padding()
            }
            .background(Theme.screen)
            .navigationTitle(L.today)
        }
    }

    // MARK: - Header (current cycle day + phase)

    private var header: some View {
        VStack(spacing: Theme.spacingSmall) {
            if let day = store.cycleDay() {
                Text("Ngày \(day) của chu kỳ")
                    .font(.title3.weight(.semibold))
                Text(L.phase(store.displayPhase()))
                    .font(.subheadline)
                    .foregroundStyle(Theme.accent)
            } else {
                Text("Chưa có dữ liệu chu kỳ")
                    .font(.title3.weight(.semibold))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Theme.spacing)
    }

    // MARK: - Prediction card

    private func predictionCard(_ p: Prediction) -> some View {
        VStack(alignment: .leading, spacing: Theme.spacing) {
            Label("Kỳ kinh tiếp theo", systemImage: "drop.fill")
                .font(.headline)
                .foregroundStyle(Theme.accent)

            Text(Fmt.range(p.nextPeriod))
                .font(.system(.title, design: .rounded).weight(.bold))

            HStack(spacing: 8) {
                Circle()
                    .fill(Theme.color(forConfidence: p.confidence.rawValue))
                    .frame(width: 9, height: 9)
                Text(L.confidence(p.confidence))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("±\(max(Fmt.widthDays(p.nextPeriod) / 2, 1)) ngày")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if p.mode == .tooIrregularToPredict {
                Label("Chu kỳ đang khá thất thường — Velia chưa thể dự đoán chắc chắn. Cứ ghi nhật ký đều, dự đoán sẽ rõ dần.",
                      systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            if let ov = p.ovulation {
                Divider()
                Label("Cửa sổ rụng trứng", systemImage: "sparkles")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.fertile)
                Text(Fmt.range(ov))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .veliaCard()
    }

    private var sharpenHint: some View {
        let n = store.loggedCycleCount
        let msg = n < 2
            ? "Ghi thêm vài chu kỳ nữa để Velia thu hẹp khoảng dự đoán."
            : "Dựa trên \(n) chu kỳ đã ghi. Càng ghi nhiều, dự đoán càng sắc."
        return Label(msg, systemImage: "chart.line.uptrend.xyaxis")
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emptyState: some View {
        VStack(spacing: Theme.spacing) {
            Image(systemName: "calendar.badge.plus")
                .font(.largeTitle)
                .foregroundStyle(Theme.accent)
            Text("Ghi kỳ kinh đầu tiên để bắt đầu dự đoán.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .veliaCard()
    }

    // MARK: - Quick action

    private var quickLog: some View {
        Button {
            store.addPeriod(start: Date(), flow: .medium)
        } label: {
            Label("Ghi kỳ kinh bắt đầu hôm nay", systemImage: "plus.circle.fill")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
        }
        .buttonStyle(.borderedProminent)
        .tint(Theme.accent)
        .disabled(store.hasPeriod(on: Date()))
    }
}
