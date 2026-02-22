import StoreKit
import Foundation

@MainActor
@Observable
class SubscriptionService {
    private(set) var products: [Product] = []
    private(set) var subscriptionState: SubscriptionState = .free
    private(set) var isLoading = false

    private var transactionListener: Task<Void, Error>?
    private let syncService = SubscriptionSyncService()

    var hasProAccess: Bool {
        AppConfig.bypassSubscription || subscriptionState.isActive
    }

    init() {
        transactionListener = listenForTransactions()
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - Fetch Products

    func fetchProducts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            products = try await Product.products(for: SubscriptionConstants.allProductIDs)
                .sorted { $0.price < $1.price }
        } catch {
            print("Failed to fetch products: \(error)")
        }
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async throws -> Bool {
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            await updateSubscriptionStatus()
            return true

        case .userCancelled:
            return false

        case .pending:
            return false

        @unknown default:
            return false
        }
    }

    // MARK: - Restore Purchases

    func restorePurchases() async {
        try? await AppStore.sync()
        await updateSubscriptionStatus()
    }

    // MARK: - Check Subscription Status

    func updateSubscriptionStatus() async {
        var latestTransaction: StoreKit.Transaction?
        var latestExpiration: Date?

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }

            if SubscriptionConstants.allProductIDs.contains(transaction.productID) {
                if let expDate = transaction.expirationDate,
                   (latestExpiration == nil || expDate > latestExpiration!) {
                    latestTransaction = transaction
                    latestExpiration = expDate
                }
            }
        }

        if let transaction = latestTransaction, let expiration = latestExpiration {
            var willAutoRenew = true
            if let statuses = try? await Product.SubscriptionInfo.status(
                for: SubscriptionConstants.subscriptionGroupID
            ) {
                for status in statuses {
                    if case .verified(let renewalInfo) = status.renewalInfo {
                        willAutoRenew = renewalInfo.willAutoRenew
                    }
                }
            }

            subscriptionState = SubscriptionState(
                tier: .pro,
                isActive: expiration > Date(),
                productId: transaction.productID,
                expirationDate: expiration,
                originalPurchaseDate: transaction.originalPurchaseDate,
                willAutoRenew: willAutoRenew,
                isInFreeTrialFromReferral: transaction.offerType == .code
            )
        } else {
            subscriptionState = .free
        }

        await syncToFirebase()
    }

    // MARK: - Firebase Sync

    private func syncToFirebase() async {
        guard let userId = AuthService.shared.currentUserId else { return }
        try? await syncService.syncToFirebase(userId: userId, state: subscriptionState)
    }

    // MARK: - Private Helpers

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let item):
            return item
        }
    }

    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached {
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    await self.updateSubscriptionStatus()
                }
            }
        }
    }
}
