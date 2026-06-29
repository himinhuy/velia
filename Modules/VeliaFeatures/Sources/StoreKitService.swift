import Observation
import StoreKit
import UIKit

/// Real StoreKit 2 layer for the $3/year auto-renewable subscription. Drives the entitlement on
/// `SubscriptionManager` (the trial stays local). Test now with the bundled `Velia.storekit`
/// config; in production it resolves the same Product ID from App Store Connect.
@MainActor
@Observable
final class StoreKitService {
    static let yearlyID = "app.velia.premium.yearly"

    private(set) var product: Product?
    private(set) var purchasing = false
    var errorMessage: String?

    private let subscription: SubscriptionManager
    @ObservationIgnored private var updatesTask: Task<Void, Never>?

    init(subscription: SubscriptionManager) {
        self.subscription = subscription
        updatesTask = listenForTransactions()
        Task {
            await loadProducts()
            await refreshEntitlement()
        }
    }

    deinit { updatesTask?.cancel() }

    /// Display price from StoreKit, falling back to the documented price.
    var priceText: String {
        product?.displayPrice ?? SubscriptionManager.priceString
    }

    // MARK: Loading & entitlement

    func loadProducts() async {
        do {
            let products = try await Product.products(for: [Self.yearlyID])
            product = products.first
        } catch {
            errorMessage = L2("Không tải được gói đăng ký.", "Couldn't load the subscription.")
        }
    }

    /// Reflect the App Store's source of truth into the app's entitlement.
    func refreshEntitlement() async {
        var active = false
        var renewal: Date?
        for await result in Transaction.currentEntitlements {
            guard case let .verified(transaction) = result,
                  transaction.productID == Self.yearlyID,
                  transaction.revocationDate == nil else { continue }
            // Not expired (or no expiry).
            if let exp = transaction.expirationDate, exp < Date() { continue }
            active = true
            renewal = transaction.expirationDate
        }
        subscription.updateEntitlement(active: active, renewal: renewal)
    }

    // MARK: Purchase / restore / manage

    func purchase() async {
        guard let product else {
            await loadProducts()
            if product == nil { errorMessage = L2("Gói chưa sẵn sàng.", "Subscription not available yet."); return }
            return await purchase()
        }
        purchasing = true
        defer { purchasing = false }
        do {
            let result = try await product.purchase()
            switch result {
            case let .success(verification):
                if case let .verified(transaction) = verification {
                    await transaction.finish()
                    await refreshEntitlement()
                } else {
                    errorMessage = L2("Không xác minh được giao dịch.", "Couldn't verify the purchase.")
                }
            case .userCancelled:
                break
            case .pending:
                errorMessage = L2("Giao dịch đang chờ duyệt.", "Purchase is pending approval.")
            @unknown default:
                break
            }
        } catch {
            errorMessage = L2("Mua không thành công. Vui lòng thử lại.", "Purchase failed. Please try again.")
        }
    }

    func restore() async {
        try? await AppStore.sync()
        await refreshEntitlement()
    }

    /// Apple requires cancellation to go through the system sheet (no in-app cancel for IAP).
    func manageSubscriptions() async {
        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else { return }
        try? await AppStore.showManageSubscriptions(in: scene)
        await refreshEntitlement()
    }

    // MARK: Transaction updates (renewals, refunds, purchases on other devices)

    private func listenForTransactions() -> Task<Void, Never> {
        Task { [weak self] in
            for await update in Transaction.updates {
                guard case let .verified(transaction) = update else { continue }
                await transaction.finish()
                await self?.refreshEntitlement()
            }
        }
    }
}
