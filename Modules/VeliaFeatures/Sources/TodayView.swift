import SwiftUI
import VeliaCore
import VeliaDesignSystem

/// "Cycle" home screen. In period/conceive mode it shows the cycle ring; conceive adds a fertile-
/// window card + Tier-1 disclaimer. In track-without-period mode there's no forecast — just a recent-
/// logs summary. The ≡ menu opens Profile and "Đổi chế độ" (switch mode).
struct TodayView: View {
    @Environment(CycleStore.self) private var store
    @Environment(LockManager.self) private var lock
    @Binding var trackDate: Date?
    @State private var showProfile = false
    @State private var showModePicker = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.spacing) {
                    if store.mode.predictsCycle {
                        cycleLengthPill
                        CycleRingView(model: CycleRingModel.from(store))
                        if store.mode == .conceive { fertileCard }
                    } else {
                        recentLogs
                    }
                    feelCard
                    Text(L.privacyFootnote)
                        .font(.caption2).foregroundStyle(.tertiary)
                        .padding(.top, Theme.spacing)
                }
                .padding()
                .padding(.bottom, 90)
            }
            .background(Theme.screen)
            .navigationTitle(navTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { showModePicker = true } label: {
                            Label("Đổi chế độ", systemImage: "arrow.triangle.2.circlepath")
                        }
                        Button { showProfile = true } label: {
                            Label("Hồ sơ & độ dài chu kỳ", systemImage: "person.crop.circle")
                        }
                        Button { trackDate = Calendar.current.startOfDay(for: Date()) } label: {
                            Label("Ghi nhật ký hôm nay", systemImage: "plus.circle")
                        }
                        if lock.isEnabled {
                            Divider()
                            Button { lock.lock() } label: {
                                Label("Khóa ngay", systemImage: "lock.fill")
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal")
                    }
                    .tint(Theme.accent)
                }
            }
            .sheet(isPresented: $showProfile) { ProfileView(store: store) }
            .sheet(isPresented: $showModePicker) {
                ModePickerView(current: store.mode, isOnboarding: false,
                               onConfirm: { store.setMode($0); showModePicker = false },
                               onCancel: { showModePicker = false })
            }
        }
    }

    private var navTitle: String {
        store.mode == .conceive ? "Chu kỳ của bạn" : (store.mode.predictsCycle ? "Chu kỳ của bạn" : "Hôm nay")
    }

    // MARK: Cycle-length pill

    private var cycleLengthPill: some View {
        Button { showProfile = true } label: {
            HStack(spacing: 6) {
                Text("Độ dài chu kỳ:").foregroundStyle(.secondary)
                Text("\(store.profile.typicalCycleLength ?? 28) ngày")
                    .fontWeight(.semibold).foregroundStyle(Theme.accent)
                Image(systemName: "chevron.down").font(.caption2).foregroundStyle(Theme.accent)
            }
            .font(.subheadline)
            .padding(.horizontal, 16).padding(.vertical, 9)
            .background(Color(.secondarySystemBackground), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: Conceive — fertile window + Tier-1 disclaimer

    @ViewBuilder
    private var fertileCard: some View {
        if let ov = store.prediction?.ovulation {
            VStack(alignment: .leading, spacing: Theme.spacingSmall) {
                Label("Cửa sổ dễ thụ thai", systemImage: "sparkles")
                    .font(.headline).foregroundStyle(Theme.fertile)
                Text(Fmt.range(ov)).font(.title3.weight(.semibold))
                Text("Ước tính độ tin cậy thấp khi chu kỳ chưa ổn định. Ghi thêm BBT, dịch nhầy và que thử LH để rõ hơn.")
                    .font(.caption).foregroundStyle(.secondary)
                Divider()
                Text("Velia không phải công cụ tránh thai hay chẩn đoán y khoa. Hãy tham khảo ý kiến bác sĩ.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            .veliaCard()
        }
    }

    // MARK: Track-without-period — recent logs (no forecast)

    private var recentLogs: some View {
        let cal = Calendar.current
        let days: [Date] = (0..<14).compactMap { cal.date(byAdding: .day, value: -$0, to: Date()) }
            .filter { store.hasAnyLog(on: $0) }
        return VStack(alignment: .leading, spacing: Theme.spacing) {
            Text("Nhật ký gần đây").font(.title3.bold())
            if days.isEmpty {
                Text("Chưa có gì được ghi. Nhấn “＋ Theo dõi” để bắt đầu.")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .veliaCard()
            } else {
                ForEach(days, id: \.self) { day in
                    HStack {
                        Text(Fmt.dayMonth.string(from: day)).font(.subheadline.weight(.medium))
                        Spacer()
                        if let flow = store.flow(on: day) {
                            Text(L.flow(flow)).font(.caption).foregroundStyle(Theme.accent)
                        }
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.fertile)
                    }
                    .veliaCard()
                }
            }
        }
    }

    // MARK: "How do you feel today?"

    private var feelCard: some View {
        Button { trackDate = Calendar.current.startOfDay(for: Date()) } label: {
            HStack(spacing: 12) {
                Image(systemName: "face.smiling")
                    .font(.title3).foregroundStyle(.white)
                    .padding(8).background(.orange, in: Circle())
                Text("Hôm nay bạn cảm thấy thế nào?")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(.orange).opacity(0.18), in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius).stroke(.orange.opacity(0.4), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
