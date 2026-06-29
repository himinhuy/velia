import SwiftUI
import VeliaCore
import VeliaDesignSystem

/// Day logging sheet (PRD §logging; reference screenshot 2). Pick a day from the strip, then tap
/// tiles to log flow, feelings and pain. Everything is toggleable — tapping a selected tile clears
/// it — so nothing is an irreversible one-shot.
struct TrackSheet: View {
    let store: CycleStore
    @State var selectedDate: Date
    @Environment(HealthKitService.self) private var health
    @Environment(\.dismiss) private var dismiss

    private let cal = Calendar.current

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                dateStrip
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.spacingLarge) {
                        flowSection
                        if store.mode == .conceive { fertilitySection }
                        symptomSection(
                            L2("Cảm xúc", "Feelings"),
                            category: TrackCatalog.feelingCategory,
                            items: TrackCatalog.feelings
                        )
                        symptomSection(
                            L2("Cơn đau", "Pain"),
                            category: TrackCatalog.painCategory,
                            items: TrackCatalog.pains
                        )
                        exclusiveSection(
                            L2("Năng lượng", "Energy"),
                            category: TrackCatalog.energyCategory,
                            items: TrackCatalog.energy
                        )
                        exclusiveSection(
                            L2("Giấc ngủ", "Sleep"),
                            category: TrackCatalog.sleepCategory,
                            items: TrackCatalog.sleep
                        )
                        if store.mode != .conceive {
                            exclusiveSection(
                                L2("Dịch tiết", "Discharge"),
                                category: TrackCatalog.dischargeCategory,
                                items: TrackCatalog.discharge
                            )
                        }
                        exclusiveSection(
                            L2("Quan hệ", "Sex"),
                            category: TrackCatalog.sexCategory,
                            items: TrackCatalog.sex
                        )
                        noteField
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
                    Button(L2("Xong", "Done")) { dismiss() }.tint(Theme.accent).fontWeight(.semibold)
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button { dismiss() } label: {
                    Text(L2("Lưu", "Save")).frame(maxWidth: .infinity).padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .padding()
                .background(.ultraThinMaterial)
            }
        }
    }

    private var headerTitle: String {
        cal.isDateInToday(selectedDate) ? L2("Hôm nay", "Today") : Fmt.dayMonth.string(from: selectedDate)
    }

    // MARK: Date strip

    private var dateStrip: some View {
        let days = (-14 ... 7).compactMap { cal.date(byAdding: .day, value: $0, to: Date()) }
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
            sectionHeader(L2("Lượng kinh", "Flow"))
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
        case .spotting: "circle.hexagongrid.fill"
        case .light: "drop"
        case .medium: "drop.fill"
        case .heavy: "drop.fill"
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

    // MARK: Fertility signals (conceive mode) — logging only, Tier-1

    private var mucusOptions: [(String?, String)] {
        [
            (nil, L2("Không ghi", "Not logged")),
            ("dry", L2("Khô", "Dry")),
            ("sticky", L2("Dính", "Sticky")),
            ("creamy", L2("Kem", "Creamy")),
            ("eggwhite", L2("Trứng sống / dai", "Egg-white / stretchy")),
            ("watery", L2("Ướt", "Watery"))
        ]
    }

    private var lhOptions: [(String?, String)] {
        [
            (nil, L2("Không ghi", "Not logged")),
            ("negative", L2("Âm tính", "Negative")),
            ("peak", L2("Đỉnh (dương tính)", "Peak (positive)"))
        ]
    }

    private func entry() -> FertilityRecord? {
        store.fertilityEntry(on: selectedDate)
    }

    private var fertilitySection: some View {
        VStack(alignment: .leading, spacing: Theme.spacing) {
            sectionHeader(L2("Khả năng sinh sản", "Fertility"))

            // BBT
            VStack(alignment: .leading, spacing: 6) {
                Toggle(L2("Nhiệt độ cơ thể (BBT)", "Body temperature (BBT)"), isOn: Binding(
                    get: { entry()?.bbtCelsius != nil },
                    set: { on in writeBBT(on ? (entry()?.bbtCelsius ?? 36.50) : nil) }
                ))
                if let bbt = entry()?.bbtCelsius {
                    Stepper(String(format: "%.2f °C", bbt), value: Binding(
                        get: { bbt }, set: { writeBBT($0) }
                    ), in: 35.0 ... 38.5, step: 0.05)
                }
                if health.isAvailable {
                    Button {
                        Task {
                            await health.requestAuthorization()
                            if let celsius = await health.basalBodyTemperature(on: selectedDate) {
                                writeBBT((celsius * 20).rounded() / 20) // snap to 0.05°C
                            }
                        }
                    } label: {
                        Label(L2("Nhập từ Health", "Import from Health"), systemImage: "heart.text.square")
                            .font(.caption)
                    }
                    .tint(Theme.accent)
                }
            }
            .padding().background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 14))

            pickerRow(
                L2("Dịch nhầy cổ tử cung", "Cervical mucus"),
                options: mucusOptions,
                selected: entry()?.cervicalMucus
            ) { writeMucus($0) }
            pickerRow(
                L2("Que thử LH", "LH test"),
                options: lhOptions,
                selected: entry()?.lhTest
            ) { writeLH($0) }

            Text(L2(
                "Velia không phải công cụ tránh thai hay chẩn đoán y khoa. Hãy tham khảo ý kiến bác sĩ.",
                "Velia is not a contraceptive or medical-diagnosis tool. Please consult a doctor."
            ))
            .font(.caption2).foregroundStyle(.secondary)
        }
    }

    // MARK: Single-choice categories (energy / sleep / sex)

    private func exclusiveSection(_ title: String, category: String, items: [TrackItem]) -> some View {
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
                        store.selectExclusiveSymptom(category, item.id, on: selectedDate)
                    }
                }
            }
        }
    }

    // MARK: Daily note

    private var noteField: some View {
        VStack(alignment: .leading, spacing: Theme.spacing) {
            sectionHeader(L2("Ghi chú", "Notes"))
            TextField(L2("Điều gì đáng nhớ hôm nay?…", "Anything notable today?…"), text: Binding(
                get: { store.note(on: selectedDate) },
                set: { store.setNote($0, on: selectedDate) }
            ), axis: .vertical)
                .lineLimit(2 ... 5)
                .padding()
                .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
        }
    }

    private func pickerRow(
        _ title: String,
        options: [(String?, String)],
        selected: String?,
        set: @escaping (String?) -> Void
    ) -> some View {
        HStack {
            Text(title).font(.subheadline)
            Spacer()
            Menu {
                ForEach(options, id: \.1) { value, label in
                    Button(label) { set(value) }
                }
            } label: {
                let current = options.first { $0.0 == selected }?.1 ?? L2("Không ghi", "Not logged")
                Text(current).font(.subheadline.weight(.medium)).foregroundStyle(Theme.accent)
            }
        }
        .padding().background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private func writeBBT(_ v: Double?) {
        let e = entry()
        store.setFertility(on: selectedDate, bbtCelsius: v, cervicalMucus: e?.cervicalMucus, lhTest: e?.lhTest)
    }

    private func writeMucus(_ v: String?) {
        let e = entry()
        store.setFertility(on: selectedDate, bbtCelsius: e?.bbtCelsius, cervicalMucus: v, lhTest: e?.lhTest)
    }

    private func writeLH(_ v: String?) {
        let e = entry()
        store.setFertility(on: selectedDate, bbtCelsius: e?.bbtCelsius, cervicalMucus: e?.cervicalMucus, lhTest: v)
    }

    private func sectionHeader(_ t: String) -> some View {
        Text(t).font(.title3.bold()).frame(maxWidth: .infinity, alignment: .leading)
    }

    private func tint(_ c: TrackColor) -> Color {
        switch c {
        case .rose: Theme.accent
        case .amber: .orange
        case .blue: Color(red: 0.36, green: 0.55, blue: 0.85)
        case .teal: Theme.fertile
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
