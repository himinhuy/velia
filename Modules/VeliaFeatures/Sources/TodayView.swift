import SwiftUI
import VeliaCore
import VeliaDesignSystem

/// "Cycle" home screen — a circular cycle wheel (reference design) plus a quick way to log how you
/// feel. The average cycle length is surfaced as a tappable pill, and a menu opens the full profile,
/// so changing your inputs is always one tap away.
struct TodayView: View {
    @Environment(CycleStore.self) private var store
    @Binding var trackDate: Date?
    @State private var showProfile = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.spacing) {
                    cycleLengthPill
                    CycleRingView(model: CycleRingModel.from(store))
                    feelCard
                    if let p = store.prediction { confidenceLine(p) }
                    Text(L.privacyFootnote)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .padding(.top, Theme.spacing)
                }
                .padding()
                .padding(.bottom, 90) // clear the floating tab bar
            }
            .background(Theme.screen)
            .navigationTitle("Chu kỳ của bạn")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showProfile = true
                        } label: {
                            Label("Hồ sơ & độ dài chu kỳ", systemImage: "person.crop.circle")
                        }
                        Button {
                            trackDate = Calendar.current.startOfDay(for: Date())
                        } label: {
                            Label("Ghi nhật ký hôm nay", systemImage: "plus.circle")
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal")
                    }
                    .tint(Theme.accent)
                }
            }
            .sheet(isPresented: $showProfile) { ProfileView(store: store) }
        }
    }

    // MARK: Cycle-length pill (visible + editable entry to inputs)

    private var cycleLengthPill: some View {
        Button { showProfile = true } label: {
            HStack(spacing: 6) {
                Text("Độ dài chu kỳ:")
                    .foregroundStyle(.secondary)
                Text("\(store.profile.typicalCycleLength ?? 28) ngày")
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.accent)
                Image(systemName: "chevron.down").font(.caption2).foregroundStyle(Theme.accent)
            }
            .font(.subheadline)
            .padding(.horizontal, 16).padding(.vertical, 9)
            .background(Color(.secondarySystemBackground), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: "How do you feel today?"

    private var feelCard: some View {
        Button { trackDate = Calendar.current.startOfDay(for: Date()) } label: {
            HStack(spacing: 12) {
                Image(systemName: "face.smiling")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .padding(8)
                    .background(.orange, in: Circle())
                Text("Hôm nay bạn cảm thấy thế nào?")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(.orange).opacity(0.18), in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius).stroke(.orange.opacity(0.4), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func confidenceLine(_ p: Prediction) -> some View {
        HStack(spacing: 8) {
            Circle().fill(Theme.color(forConfidence: p.confidence.rawValue)).frame(width: 8, height: 8)
            Text(L.confidence(p.confidence))
            Text("· ±\(max(Fmt.widthDays(p.nextPeriod) / 2, 1)) ngày")
            if store.loggedCycleCount < 2 {
                Text("· ghi thêm để chính xác hơn")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}
