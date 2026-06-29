import SwiftUI
import VeliaDesignSystem

/// Subscription paywall. Shown full-screen (forced) when the trial has expired, or as a dismissible
/// upsell from Settings. "Subscribe Now" runs the (simulated) purchase and returns full access.
struct PaywallView: View {
    @Environment(SubscriptionManager.self) private var subscription
    @Environment(StoreKitService.self) private var store
    /// Forced gate (no dismiss) vs. upsell sheet (dismissible).
    var onClose: (() -> Void)?

    private struct Benefit: Identifiable {
        let icon: String, vi: String, en: String
        var id: String {
            icon
        }
    }

    private let benefits: [Benefit] = [
        Benefit(icon: "infinity", vi: "Toàn quyền sử dụng", en: "Full access to the app"),
        Benefit(icon: "chart.line.uptrend.xyaxis", vi: "Dự đoán chu kỳ chính xác", en: "Accurate cycle predictions"),
        Benefit(
            icon: "lock.shield.fill",
            vi: "Riêng tư tuyệt đối — dữ liệu chỉ trên máy",
            en: "Fully private — data stays on device"
        ),
        Benefit(icon: "bell.badge.fill", vi: "Nhắc nhở kỳ kinh & ghi nhật ký", en: "Period & logging reminders")
    ]

    var body: some View {
        ZStack {
            Theme.screen.ignoresSafeArea()
            VStack(spacing: Theme.spacingLarge) {
                if let onClose {
                    HStack {
                        Spacer()
                        Button(action: onClose) {
                            Image(systemName: "xmark").font(.headline)
                                .foregroundStyle(.secondary).padding(10)
                                .background(Color(.secondarySystemBackground), in: Circle())
                        }
                    }
                }
                Spacer()

                Image(systemName: "drop.fill").font(.system(size: 48)).foregroundStyle(Theme.accent)
                Text(L2("Velia Premium", "Velia Premium")).font(.largeTitle.bold())
                Text(L2(
                    "Tiếp tục sử dụng Velia đầy đủ sau khi hết hạn dùng thử 7 ngày.",
                    "Keep full access to Velia after your 7-day free trial."
                ))
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

                VStack(alignment: .leading, spacing: Theme.spacing) {
                    ForEach(benefits) { benefit in
                        HStack(spacing: 12) {
                            Image(systemName: benefit.icon).foregroundStyle(Theme.accent).frame(width: 26)
                            Text(L2(benefit.vi, benefit.en)).font(.subheadline)
                            Spacer()
                        }
                    }
                }
                .padding(.horizontal)

                Spacer()

                VStack(spacing: 6) {
                    Text("\(store.priceText) / \(L2("năm", "year"))")
                        .font(.system(.title2, design: .rounded).weight(.bold))
                    Text(L2(
                        "Tự động gia hạn hằng năm · hủy bất cứ lúc nào",
                        "Renews yearly · cancel anytime"
                    ))
                    .font(.caption2).foregroundStyle(.secondary)
                }

                if let error = store.errorMessage {
                    Text(error).font(.footnote).foregroundStyle(.red).multilineTextAlignment(.center)
                }

                Button {
                    Task {
                        await store.purchase()
                        if subscription.isSubscribed { onClose?() }
                    }
                } label: {
                    if store.purchasing {
                        ProgressView().frame(maxWidth: .infinity).padding(.vertical, 6)
                    } else {
                        Text(L2("Đăng ký ngay", "Subscribe Now"))
                            .frame(maxWidth: .infinity).padding(.vertical, 6)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .disabled(store.purchasing)
                .padding(.horizontal)

                Button(L2("Khôi phục giao dịch", "Restore purchases")) {
                    Task {
                        await store.restore()
                        if subscription.isSubscribed { onClose?() }
                    }
                }
                .font(.footnote).tint(Theme.accent)

                Text(L2(
                    "Gia hạn tự động qua App Store. Hủy bất cứ lúc nào trong Cài đặt.",
                    "Auto-renews via the App Store. Cancel anytime in Settings."
                ))
                .font(.caption2).foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.bottom)
            }
            .padding()
        }
    }
}
