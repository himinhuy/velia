import SwiftUI
import VeliaCore
import VeliaDesignSystem

/// Day logging sheet (PRD §logging; reference screenshot 2). Pick a day from the strip, then tap
/// tiles to log flow, feelings and pain. Everything is toggleable — tapping a selected tile clears
/// it — so nothing is an irreversible one-shot.
struct TrackSheet: View {
    let store: CycleStore
    @State var selectedDate: Date
    @Environment(\.dismiss) private var dismiss

    private let cal = Calendar.current

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                dateStrip
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.spacingLarge) {
                        flowSection
                        symptomSection("Cảm xúc", category: TrackCatalog.feelingCategory, items: TrackCatalog.feelings)
                        symptomSection("Cơn đau", category: TrackCatalog.painCategory, items: TrackCatalog.pains)
                    }
                    .padding()
                    .padding(.bottom, 80)
                }
            }
            .background(Theme.screen)
            .navigationTitle(headerTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Xong") { dismiss() }.tint(Theme.accent).fontWeight(.semibold)
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button { dismiss() } label: {
                    Text("Lưu").frame(maxWidth: .infinity).padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .padding()
                .background(.ultraThinMaterial)
            }
        }
    }

    private var headerTitle: String {
        cal.isDateInToday(selectedDate) ? "Hôm nay" : Fmt.dayMonth.string(from: selectedDate)
    }

    // MARK: Date strip

    private var dateStrip: some View {
        let days = (-14...7).compactMap { cal.date(byAdding: .day, value: $0, to: Date()) }
        return ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(days, id: \.self) { day in
                        dayChip(day).id(cal.startOfDay(for: day))
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
            }
            .onAppear { proxy.scrollTo(cal.startOfDay(for: selectedDate), anchor: .center) }
        }
    }

    private func dayChip(_ day: Date) -> some View {
        let selected = cal.isDate(day, inSameDayAs: selectedDate)
        let isPeriod = store.isPeriodDay(on: day)
        return Button {
            selectedDate = cal.startOfDay(for: day)
        } label: {
            VStack(spacing: 4) {
                Text(Fmt.weekdayLetter(day)).font(.caption2).foregroundStyle(.secondary)
                Text("\(cal.component(.day, from: day))")
                    .font(.callout.weight(selected ? .bold : .regular))
                    .foregroundStyle(isPeriod ? .white : .primary)
                    .frame(width: 36, height: 36)
                    .background(isPeriod ? Theme.accent : Color.clear, in: Circle())
                    .overlay(Circle().stroke(Theme.accent, lineWidth: selected ? 2 : 0))
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Flow

    private var flowSection: some View {
        VStack(alignment: .leading, spacing: Theme.spacing) {
            sectionHeader("Lượng kinh")
            HStack(spacing: 12) {
                ForEach(FlowIntensity.allCases, id: \.self) { flow in
                    TrackTile(
                        symbol: flowSymbol(flow),
                        label: L.flow(flow),
                        tint: Theme.accent,
                        selected: store.flow(on: selectedDate) == flow
                    ) {
                        let current = store.flow(on: selectedDate)
                        store.setFlow(on: selectedDate, flow: current == flow ? nil : flow)
                    }
                }
            }
        }
    }

    private func flowSymbol(_ f: FlowIntensity) -> String {
        switch f {
        case .spotting: return "circle.hexagongrid.fill"
        case .light: return "drop"
        case .medium: return "drop.fill"
        case .heavy: return "drop.fill"
        }
    }

    // MARK: Symptoms

    private func symptomSection(_ title: String, category: String, items: [TrackItem]) -> some View {
        VStack(alignment: .leading, spacing: Theme.spacing) {
            sectionHeader(title)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                ForEach(items) { item in
                    TrackTile(
                        symbol: item.symbol,
                        label: item.label,
                        tint: tint(item.color),
                        selected: store.isSymptomSelected(category, item.id, on: selectedDate)
                    ) {
                        store.toggleSymptom(category, item.id, on: selectedDate)
                    }
                }
            }
        }
    }

    private func sectionHeader(_ t: String) -> some View {
        Text(t).font(.title3.bold()).frame(maxWidth: .infinity, alignment: .leading)
    }

    private func tint(_ c: TrackColor) -> Color {
        switch c {
        case .rose: return Theme.accent
        case .amber: return .orange
        case .blue: return Color(red: 0.36, green: 0.55, blue: 0.85)
        case .teal: return Theme.fertile
        }
    }
}

/// A selectable icon tile.
private struct TrackTile: View {
    let symbol: String
    let label: String
    let tint: Color
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(selected ? tint.opacity(0.22) : Color(.tertiarySystemBackground))
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(tint, lineWidth: selected ? 2.5 : 1)
                    Image(systemName: symbol)
                        .font(.title2)
                        .foregroundStyle(tint)
                }
                .frame(height: 64)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .buttonStyle(.plain)
    }
}
