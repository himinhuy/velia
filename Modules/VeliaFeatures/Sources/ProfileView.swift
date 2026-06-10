import SwiftUI
import VeliaCore
import VeliaDesignSystem

/// Settings / profile. Lets the user change the inputs that seed the prediction prior — average
/// cycle length, cycle regularity (segment), and optional birth year — after onboarding.
struct ProfileView: View {
    let store: CycleStore
    @Environment(\.dismiss) private var dismiss

    @State private var cycleLength: Int
    @State private var segment: Segment
    @State private var includeAge: Bool
    @State private var birthYear: Int

    private let years = Array(1955...2012).reversed()

    init(store: CycleStore) {
        self.store = store
        _cycleLength = State(initialValue: store.profile.typicalCycleLength ?? 28)
        _segment = State(initialValue: store.profile.segment)
        _includeAge = State(initialValue: store.profile.birthYear != nil)
        _birthYear = State(initialValue: store.profile.birthYear ?? 1995)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper("Độ dài chu kỳ trung bình: \(cycleLength) ngày",
                            value: $cycleLength, in: 18...60)
                } header: {
                    Text("Chu kỳ")
                } footer: {
                    Text("Khoảng cách trung bình giữa hai lần bắt đầu kỳ kinh. Velia dùng số này khi chưa có đủ dữ liệu, rồi tự học từ nhật ký của bạn.")
                }

                Section {
                    Picker("Mức độ đều", selection: $segment) {
                        ForEach(Segment.allCases, id: \.self) { Text(L.segment($0)).tag($0) }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    Text("Tình trạng chu kỳ")
                } footer: {
                    Text("Chu kỳ càng thất thường, Velia càng để khoảng dự đoán rộng hơn cho trung thực.")
                }

                Section {
                    Toggle("Thêm năm sinh", isOn: $includeAge)
                    if includeAge {
                        Picker("Năm sinh", selection: $birthYear) {
                            ForEach(years, id: \.self) { Text(String($0)).tag($0) }
                        }
                    }
                } footer: {
                    Text("Tùy chọn. Dữ liệu chỉ ở trên máy này — không tài khoản, không gửi đi đâu cả.")
                }

                if let avg = store.averageCycleLength {
                    Section("Từ dữ liệu của bạn") {
                        LabeledContent("Độ dài chu kỳ thực tế", value: "\(avg) ngày")
                        LabeledContent("Số chu kỳ đã ghi", value: "\(store.loggedCycleCount)")
                    }
                }
            }
            .navigationTitle("Hồ sơ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Hủy") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Lưu") {
                        store.updateProfile(typicalCycleLength: cycleLength,
                                            segment: segment,
                                            birthYear: includeAge ? birthYear : nil)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .tint(Theme.accent)
                }
            }
        }
    }
}
