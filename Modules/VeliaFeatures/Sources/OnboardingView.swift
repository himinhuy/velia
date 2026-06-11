import SwiftUI
import VeliaCore
import VeliaDesignSystem

/// First-run flow. Step 1 picks the tracking mode (it shapes what we ask next); step 2 is the intake
/// that seeds the engine's prior (PRD §4.4). For "track without a period" the cycle questions are
/// skipped, since there's no cycle to forecast.
struct OnboardingView: View {
    let store: CycleStore

    @State private var mode: TrackingMode?
    @State private var lastPeriod = Calendar.current.startOfDay(for: Date())
    @State private var knowsLastPeriod = true
    @State private var cycleLength = 28
    @State private var periodLength = 5
    @State private var segment: Segment = .typical
    @State private var includeAge = false
    @State private var birthYear = 1995

    private let years = Array(1955...2012).reversed()
    private var asksCycle: Bool { mode?.predictsCycle ?? true }

    var body: some View {
        if mode == nil {
            ModePickerView(current: nil, isOnboarding: true,
                           onConfirm: { mode = $0 },
                           onCancel: {})
        } else {
            intake
        }
    }

    private var intake: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Chào mừng đến với Velia")
                        .font(.title2.bold())
                    Text("Vài câu hỏi nhanh để Velia hữu ích ngay từ hôm nay. Bạn luôn có thể chỉnh lại sau.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if asksCycle {
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
                            .font(.caption).foregroundStyle(.secondary)
                    }

                    Section("Số ngày hành kinh") {
                        Stepper("\(periodLength) ngày", value: $periodLength, in: 1...10)
                        Text("Kỳ kinh của bạn thường kéo dài bao nhiêu ngày (thường 2–6 ngày).")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                Section("Tình trạng của bạn") {
                    Picker("Phân nhóm", selection: $segment) {
                        ForEach(Segment.allCases, id: \.self) { Text(L.segment($0)).tag($0) }
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
                    Button { finish() } label: {
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
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { mode = nil } label: { Label("Chế độ", systemImage: "chevron.left") }
                        .tint(Theme.accent)
                }
            }
        }
    }

    private func finish() {
        let profile = UserProfile(
            birthYear: includeAge ? birthYear : nil,
            typicalCycleLength: asksCycle ? cycleLength : nil,
            segment: segment
        )
        store.completeOnboarding(
            mode: mode ?? .period,
            profile: profile,
            lastPeriodStart: (asksCycle && knowsLastPeriod) ? lastPeriod : nil,
            periodLength: periodLength
        )
    }
}
