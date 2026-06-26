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
                            Label(L2("Đổi chế độ", "Switch mode"), systemImage: "arrow.triangle.2.circlepath")
                        }
                        Button { showProfile = true } label: {
                            Label(
                                L2("Hồ sơ & độ dài chu kỳ", "Profile & cycle length"),
                                systemImage: "person.crop.circle"
                            )
                        }
                        Button { trackDate = Calendar.current.startOfDay(for: Date()) } label: {
                            Label(L2("Ghi nhật ký hôm nay", "Log today"), systemImage: "plus.circle")
                        }
                        if lock.isEnabled {
                            Divider()
                            Button { lock.lock() } label: {
                                Label(L2("Khóa ngay", "Lock now"), systemImage: "lock.fill")
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
                ModePickerView(
                    current: store.mode,
                    isOnboarding: false,
                    onConfirm: { store.setMode($0); showModePicker = false },
                    onCancel: { showModePicker = false }
                )
            }
        }
    }

    private var navTitle: String {
        store.mode.predictsCycle ? L2("Chu kỳ của bạn", "Your cycle") : L2("Hôm nay", "Today")
    }

    // MARK: Cycle-length pill

    private var cycleLengthPill: some View {
        Button { showProfile = true } label: {
            HStack(spacing: 6) {
                Text(L2("Độ dài chu kỳ:", "Cycle length:")).foregroundStyle(.secondary)
                Text(L2(
                    "\(store.profile.typicalCycleLength ?? 28) ngày",
                    "\(store.profile.typicalCycleLength ?? 28) days"
                ))
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
                Label(L2("Cửa sổ dễ thụ thai", "Fertile window"), systemImage: "sparkles")
                    .font(.headline).foregroundStyle(Theme.fertile)
                Text(Fmt.range(ov)).font(.title3.weight(.semibold))
                Text(L2(
                    "Ước tính độ tin cậy thấp khi chu kỳ chưa ổn định. Ghi thêm BBT, dịch nhầy và que thử LH để rõ hơn.",
                    "Low-confidence estimate while your cycle is still settling. Log BBT, cervical mucus and LH tests to sharpen it."
                ))
                .font(.caption).foregroundStyle(.secondary)
                Divider()
                Text(L2(
                    "Velia không phải công cụ tránh thai hay chẩn đoán y khoa. Hãy tham khảo ý kiến bác sĩ.",
                    "Velia is not a contraceptive or medical-diagnosis tool. Please consult a doctor."
                ))
                .font(.caption2).foregroundStyle(.secondary)
            }
            .veliaCard()
        }
    }

    // MARK: Track-without-period — recent logs (no forecast)

    private var recentLogs: some View {
        let cal = Calendar.current
        let days: [Date] = (0 ..< 14).compactMap { cal.date(byAdding: .day, value: -$0, to: Date()) }
            .filter { store.hasAnyLog(on: $0) }
        return VStack(alignment: .leading, spacing: Theme.spacing) {
            Text(L2("Nhật ký gần đây", "Recent logs")).font(.title3.bold())
            if days.isEmpty {
                Text(L2(
                    "Chưa có gì được ghi. Nhấn “＋ Theo dõi” để bắt đầu.",
                    "Nothing logged yet. Tap “＋ Track” to begin."
                ))
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
                Text(L2("Hôm nay bạn cảm thấy thế nào?", "How do you feel today?"))
                    .font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.secondary)
            }
            .padding()
            .background(
                Color(.orange).opacity(0.18),
                in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
            )
            .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius).stroke(.orange.opacity(0.4), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
