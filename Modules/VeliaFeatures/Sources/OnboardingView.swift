import SwiftUI
import VeliaCore
import VeliaDesignSystem

/// First-run intake. Seeds the engine's prior on day one (PRD §4.4): last period date, typical cycle
/// length, reproductive segment, optional birth year. The more honest the intake, the better the
/// cold-start prediction — and it visibly sharpens as the user logs.
struct OnboardingView: View {
    let store: CycleStore

    @State private var lastPeriod = Calendar.current.startOfDay(for: Date())
    @State private var knowsLastPeriod = true
    @State private var cycleLength = 28
    @State private var segment: Segment = .typical
    @State private var includeAge = false
    @State private var birthYear = 1995

    private let years = Array(1955...2012).reversed()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Chào mừng đến với Velia")
                        .font(.title2.bold())
                    Text("Vài câu hỏi nhanh để Velia dự đoán ngay từ hôm nay. Bạn luôn có thể chỉnh lại sau.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Section("Kỳ kinh gần nhất") {
                    Toggle("Tôi nhớ ngày bắt đầu", isOn: $knowsLastPeriod)
                    if knowsLastPeriod {
                        DatePicker("Ngày bắt đầu", selection: $lastPeriod,
                                   in: ...Date(), displayedComponents: .date)
                    }
                }

                Section("Độ dài chu kỳ thường gặp") {
                    Stepper("\(cycleLength) ngày", value: $cycleLength, in: 18...60)
                    Text("Khoảng cách giữa hai lần bắt đầu kỳ kinh. Mặc định 28 ngày.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Tình trạng của bạn") {
                    Picker("Phân nhóm", selection: $segment) {
                        ForEach(Segment.allCases, id: \.self) { seg in
                            Text(L.segment(seg)).tag(seg)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section {
                    Toggle("Thêm năm sinh (tùy chọn)", isOn: $includeAge)
                    if includeAge {
                        Picker("Năm sinh", selection: $birthYear) {
                            ForEach(years, id: \.self) { Text(String($0)).tag($0) }
                        }
                    }
                } footer: {
                    Text("Tuổi giúp tinh chỉnh dự đoán. Dữ liệu chỉ ở trên máy của bạn.")
                }

                Section {
                    Button {
                        finish()
                    } label: {
                        Text("Bắt đầu").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle(L.appName)
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func finish() {
        let profile = UserProfile(
            birthYear: includeAge ? birthYear : nil,
            typicalCycleLength: cycleLength,
            segment: segment
        )
        store.completeOnboarding(profile: profile,
                                 lastPeriodStart: knowsLastPeriod ? lastPeriod : nil)
    }
}
