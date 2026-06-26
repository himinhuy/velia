import SwiftUI
import VeliaCore
import VeliaDesignSystem

/// Cycle history log: every recorded period start with flow, newest first. Add via the sheet,
/// swipe to delete. Each edit re-runs the on-device prediction (visible on Today/Calendar).
struct LogView: View {
    @Environment(CycleStore.self) private var store
    @State private var showingAdd = false

    private var entries: [PeriodRecord] {
        store.periods.sorted { $0.startDate > $1.startDate }
    }

    var body: some View {
        NavigationStack {
            Group {
                if entries.isEmpty {
                    ContentUnavailableView(
                        "Chưa có nhật ký",
                        systemImage: "drop",
                        description: Text("Ghi kỳ kinh để Velia bắt đầu học chu kỳ của bạn.")
                    )
                } else {
                    List {
                        Section {
                            ForEach(entries) { entry in
                                row(entry)
                            }
                            .onDelete(perform: delete)
                        } footer: {
                            Text("\(store.loggedCycleCount) chu kỳ đầy đủ · dữ liệu chỉ ở trên máy này.")
                        }
                    }
                }
            }
            .background(Theme.screen)
            .navigationTitle(L.log)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAdd = true } label: { Image(systemName: "plus") }
                        .tint(Theme.accent)
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddPeriodSheet(store: store)
                    .presentationDetents([.medium])
            }
        }
    }

    private func row(_ entry: PeriodRecord) -> some View {
        HStack {
            Circle()
                .fill(Theme.accent)
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(Fmt.dayMonth.string(from: entry.startDate))
                    .font(.body.weight(.medium))
                if let flow = entry.flow {
                    Text(L.flow(flow))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
    }

    private func delete(_ offsets: IndexSet) {
        for index in offsets {
            store.deletePeriod(id: entries[index].id)
        }
    }
}

/// Add-a-period sheet: date + flow intensity.
private struct AddPeriodSheet: View {
    let store: CycleStore
    @Environment(\.dismiss) private var dismiss

    @State private var date = Calendar.current.startOfDay(for: Date())
    @State private var flow: FlowIntensity = .medium

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Ngày bắt đầu", selection: $date, in: ...Date(), displayedComponents: .date)
                Picker("Lượng kinh", selection: $flow) {
                    ForEach(FlowIntensity.allCases, id: \.self) { f in
                        Text(L.flow(f)).tag(f)
                    }
                }
            }
            .navigationTitle("Ghi kỳ kinh")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Hủy") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Lưu") {
                        store.addPeriod(start: date, flow: flow)
                        dismiss()
                    }
                    .tint(Theme.accent)
                }
            }
        }
    }
}
