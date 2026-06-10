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
                            "Chưa đủ dữ liệu",
                            systemImage: "chart.bar.xaxis",
                            description: Text("Ghi ít nhất hai kỳ kinh để Velia phân tích chu kỳ của bạn.")
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
            .navigationTitle("Phân tích")
        }
    }

    private func statsGrid(_ lengths: [Int]) -> some View {
        let avg = store.averageCycleLength ?? 0
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.spacing) {
            stat("Trung bình", "\(avg)", "ngày")
            stat("Số chu kỳ", "\(lengths.count)", "đã ghi")
            stat("Ngắn nhất", "\(lengths.min() ?? 0)", "ngày")
            stat("Dài nhất", "\(lengths.max() ?? 0)", "ngày")
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
        let label: String
        switch spread {
        case 0...3: label = "Chu kỳ của bạn khá đều."
        case 4...7: label = "Chu kỳ dao động vừa phải."
        default: label = "Chu kỳ khá thất thường — Velia sẽ giữ khoảng dự đoán rộng cho trung thực."
        }
        return VStack(alignment: .leading, spacing: Theme.spacingSmall) {
            Label("Mức dao động", systemImage: "waveform.path.ecg")
                .font(.headline).foregroundStyle(Theme.accent)
            Text("Chênh lệch \(spread) ngày giữa chu kỳ ngắn nhất và dài nhất.")
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
                "Nội dung sắp ra mắt",
                systemImage: "book",
                description: Text("Bài viết về sức khỏe chu kỳ bằng tiếng Việt sẽ có trong bản cập nhật sau.")
            )
            .background(Theme.screen)
            .navigationTitle("Nội dung")
        }
    }
}
