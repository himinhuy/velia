import SwiftUI
import VeliaDesignSystem
import VeliaCore

/// App root. Currently renders the on-device engine demo so a Release build has real, testable content
/// before tracking/storage UI lands (Phases 2–3). The prediction is computed on-device by VeliaCore.
public struct RootView: View {
    private let prediction = PredictionDemo.sample()

    public init() {}

    public var body: some View {
        VStack(spacing: Theme.spacing) {
            Text("Velia")
                .font(.largeTitle.bold())
            Text("Dự đoán chu kỳ chính xác — riêng tư, của riêng bạn.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                Text(window(prediction.nextPeriod))
                    .font(.title2.weight(.semibold))
                    .multilineTextAlignment(.center)
                Text("Confidence: \(prediction.confidence.rawValue)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if prediction.mode == .tooIrregularToPredict {
                    Text("Cycle too irregular to predict confidently")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))

            Text("On-device prediction · no account · no network")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding()
    }

    private func window(_ interval: DateInterval) -> String {
        let df = DateFormatter()
        df.dateFormat = "MMM d"
        return "Next period \(df.string(from: interval.start))–\(df.string(from: interval.end))"
    }
}
