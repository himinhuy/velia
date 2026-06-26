import SwiftUI
import VeliaCore
import VeliaDesignSystem

/// Read-friendly summary of one day (tapped from the calendar): phase, flow, symptoms, fertility,
/// note. "Theo dõi / Edit" opens the Track sheet for the same day.
struct DayDetailView: View {
    let store: CycleStore
    let date: Date
    let onEdit: () -> Void
    @Environment(\.dismiss) private var dismiss

    private var hasAnything: Bool {
        store.flow(on: date) != nil
            || !selected(TrackCatalog.feelingCategory, TrackCatalog.feelings).isEmpty
            || !selected(TrackCatalog.painCategory, TrackCatalog.pains).isEmpty
            || !selected(TrackCatalog.energyCategory, TrackCatalog.energy).isEmpty
            || !selected(TrackCatalog.sleepCategory, TrackCatalog.sleep).isEmpty
            || !selected(TrackCatalog.sexCategory, TrackCatalog.sex).isEmpty
            || !selected(TrackCatalog.dischargeCategory, TrackCatalog.discharge).isEmpty
            || store.fertilityEntry(on: date) != nil
            || !store.note(on: date).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spacingLarge) {
                    if store.mode.predictsCycle {
                        Text(L.phase(store.displayPhase(asOf: date)))
                            .font(.subheadline).foregroundStyle(Theme.accent)
                    }

                    if let flow = store.flow(on: date) {
                        row(L2("Lượng kinh", "Flow"), [L.flow(flow)])
                    }
                    chipRow(L2("Cảm xúc", "Feelings"), selected(TrackCatalog.feelingCategory, TrackCatalog.feelings))
                    chipRow(L2("Cơn đau", "Pain"), selected(TrackCatalog.painCategory, TrackCatalog.pains))
                    chipRow(L2("Năng lượng", "Energy"), selected(TrackCatalog.energyCategory, TrackCatalog.energy))
                    chipRow(L2("Giấc ngủ", "Sleep"), selected(TrackCatalog.sleepCategory, TrackCatalog.sleep))
                    chipRow(
                        L2("Dịch tiết", "Discharge"),
                        selected(TrackCatalog.dischargeCategory, TrackCatalog.discharge)
                    )
                    chipRow(L2("Quan hệ", "Sex"), selected(TrackCatalog.sexCategory, TrackCatalog.sex))

                    if !fertilityBits.isEmpty {
                        row(L2("Khả năng sinh sản", "Fertility"), fertilityBits)
                    }

                    let note = store.note(on: date)
                    if !note.isEmpty { row(L2("Ghi chú", "Notes"), [note]) }

                    if !hasAnything {
                        Text(L2("Chưa ghi gì cho ngày này.", "Nothing logged for this day."))
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                .padding()
            }
            .background(Theme.screen)
            .navigationTitle(Fmt.dayMonth.string(from: date))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(hasAnything ? L2("Chỉnh sửa", "Edit") : L2("Theo dõi", "Track")) { onEdit() }
                        .tint(Theme.accent).fontWeight(.semibold)
                }
            }
        }
    }

    private func selected(_ category: String, _ items: [TrackItem]) -> [String] {
        items.filter { store.isSymptomSelected(category, $0.id, on: date) }.map(\.label)
    }

    private var fertilityBits: [String] {
        guard let f = store.fertilityEntry(on: date) else { return [] }
        var bits: [String] = []
        if let b = f.bbtCelsius { bits.append(String(format: "BBT %.2f°C", b)) }
        if let m = f.cervicalMucus { bits.append(L2("Dịch nhầy", "Mucus") + ": \(m)") }
        if let lh = f.lhTest { bits.append("LH: \(lh)") }
        return bits
    }

    private func row(_ title: String, _ values: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(values.joined(separator: " · ")).font(.body)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .veliaCard()
    }

    @ViewBuilder
    private func chipRow(_ title: String, _ values: [String]) -> some View {
        if !values.isEmpty { row(title, values) }
    }
}
