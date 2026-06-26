import SwiftUI
import VeliaCore
import VeliaDesignSystem

/// Simple on-device cycle statistics derived from logged history. No network, no account.
struct AnalysisView: View {
    @Environment(CycleStore.self) private var store

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.spacingLarge) {
                    let lengths = store.observedCycleLengths
                    if lengths.isEmpty {
                        ContentUnavailableView(
                            L2("Chưa đủ dữ liệu", "Not enough data"),
                            systemImage: "chart.bar.xaxis",
                            description: Text(L2(
                                "Ghi ít nhất hai kỳ kinh để Velia phân tích chu kỳ của bạn.",
                                "Log at least two periods for Velia to analyse your cycle."
                            ))
                        )
                        .padding(.top, 60)
                    } else {
                        statsGrid(lengths)
                        variabilityCard(lengths)
                    }
                }
                .padding()
            }
            .background(Theme.screen)
            .navigationTitle(L2("Phân tích", "Analysis"))
        }
    }

    private func statsGrid(_ lengths: [Int]) -> some View {
        let avg = store.averageCycleLength ?? 0
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.spacing) {
            stat(L2("Trung bình", "Average"), "\(avg)", L2("ngày", "days"))
            stat(L2("Số chu kỳ", "Cycles"), "\(lengths.count)", L2("đã ghi", "logged"))
            stat(L2("Ngắn nhất", "Shortest"), "\(lengths.min() ?? 0)", L2("ngày", "days"))
            stat(L2("Dài nhất", "Longest"), "\(lengths.max() ?? 0)", L2("ngày", "days"))
        }
    }

    private func stat(_ title: String, _ value: String, _ unit: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value).font(.system(.title, design: .rounded).weight(.bold)).foregroundStyle(Theme.accent)
                Text(unit).font(.caption).foregroundStyle(.secondary)
            }
        }
        .veliaCard()
    }

    private func variabilityCard(_ lengths: [Int]) -> some View {
        let spread = (lengths.max() ?? 0) - (lengths.min() ?? 0)
        let label: String = switch spread {
        case 0 ... 3: L2("Chu kỳ của bạn khá đều.", "Your cycle is fairly regular.")
        case 4 ... 7: L2("Chu kỳ dao động vừa phải.", "Your cycle varies moderately.")
        default: L2(
                "Chu kỳ khá thất thường — Velia sẽ giữ khoảng dự đoán rộng cho trung thực.",
                "Your cycle is quite irregular — Velia keeps a wider prediction range to stay honest."
            )
        }
        return VStack(alignment: .leading, spacing: Theme.spacingSmall) {
            Label(L2("Mức dao động", "Variability"), systemImage: "waveform.path.ecg")
                .font(.headline).foregroundStyle(Theme.accent)
            Text(L2(
                "Chênh lệch \(spread) ngày giữa chu kỳ ngắn nhất và dài nhất.",
                "\(spread) days between your shortest and longest cycle."
            ))
            .font(.subheadline)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .veliaCard()
    }
}

/// Placeholder for the education/content tab (PRD: Vietnamese fertility content — later phase).
struct ContentTabView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                L2("Nội dung sắp ra mắt", "Content coming soon"),
                systemImage: "book",
                description: Text(L2(
                    "Bài viết về sức khỏe chu kỳ bằng tiếng Việt sẽ có trong bản cập nhật sau.",
                    "Vietnamese cycle-health articles are coming in a future update."
                ))
            )
            .background(Theme.screen)
            .navigationTitle(L2("Nội dung", "Content"))
        }
    }
}
