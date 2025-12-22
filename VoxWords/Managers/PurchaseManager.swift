import Foundation
import StoreKit
import OSLog

/// StoreKit 2 purchase / entitlement manager.
///
/// Supports:
/// - Auto-renewing subscription (monthly / yearly; trial configured in App Store Connect)
@MainActor
final class PurchaseManager: ObservableObject {
    enum Tier: String, CaseIterable {
        case monthly
        case yearly
    }

    struct ProductIDs {
        static let monthly = "com.angyee.voxwords.plus.monthly"
        static let yearly = "com.angyee.voxwords.plus.yearly"
    }

    @Published private(set) var productsByTier: [Tier: Product] = [:]
    @Published private(set) var isPremium: Bool = false
    @Published private(set) var isLoadingProducts: Bool = false
    @Published private(set) var lastPurchaseErrorMessage: String?

    private let logger = Logger(subsystem: "com.angyee.voxwords", category: "purchase")
    private var updatesTask: Task<Void, Never>?

    func start() {
        if updatesTask == nil {
            updatesTask = Task { [weak self] in
                guard let self else { return }
                await self.refreshEntitlements()
                for await _ in Transaction.updates {
                    await self.refreshEntitlements()
                }
            }
        }
        Task { [weak self] in
            await self?.loadProductsIfNeeded()
        }
    }

    func stop() {
        updatesTask?.cancel()
        updatesTask = nil
    }

    func loadProductsIfNeeded() async {
        guard isLoadingProducts == false, productsByTier.isEmpty else { return }
        isLoadingProducts = true
        defer { isLoadingProducts = false }

        do {
            let ids: Set<String> = [
                ProductIDs.monthly,
                ProductIDs.yearly
            ]
            let products = try await Product.products(for: ids)
            var map: [Tier: Product] = [:]
            for p in products {
                switch p.id {
                case ProductIDs.monthly: map[.monthly] = p
                case ProductIDs.yearly: map[.yearly] = p
                default: break
                }
            }
            self.productsByTier = map
        } catch {
            logger.error("Failed to load products: \(error.localizedDescription, privacy: .public)")
            lastPurchaseErrorMessage = error.localizedDescription
        }
    }

    func purchase(_ tier: Tier) async {
        lastPurchaseErrorMessage = nil
        guard let product = productsByTier[tier] else {
            await loadProductsIfNeeded()
            guard let product = productsByTier[tier] else { return }
            await purchaseProduct(product)
            return
        }
        await purchaseProduct(product)
    }

    func restorePurchases() async {
        lastPurchaseErrorMessage = nil
        do {
            try await StoreKit.AppStore.sync()
            await refreshEntitlements()
        } catch {
            logger.error("Restore failed: \(error.localizedDescription, privacy: .public)")
            lastPurchaseErrorMessage = error.localizedDescription
        }
    }

    // MARK: - Internals

    private func purchaseProduct(_ product: Product) async {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                logger.info("Purchase success: \(transaction.productID, privacy: .public)")
                await transaction.finish()
                await refreshEntitlements()
            case .userCancelled:
                break
            case .pending:
                // Payment needs approval (e.g. Ask to Buy)
                break
            @unknown default:
                break
            }
        } catch {
            logger.error("Purchase failed: \(error.localizedDescription, privacy: .public)")
            lastPurchaseErrorMessage = error.localizedDescription
        }
    }

    private func refreshEntitlements() async {
        var premium = false
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result) else { continue }
            // revoked subscriptions / purchases should not count
            if transaction.revocationDate != nil { continue }

            switch transaction.productID {
            case ProductIDs.monthly, ProductIDs.yearly:
                // Subscription: if not expired, user is premium
                if let exp = transaction.expirationDate {
                    if exp > Date() { premium = true }
                } else {
                    // Some subscription transactions can be non-expiring in sandbox edge cases.
                    premium = true
                }
            default:
                break
            }
        }
        isPremium = premium
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let signed):
            return signed
        }
    }
}

