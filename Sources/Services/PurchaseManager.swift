import Foundation
import StoreKit

/// StoreKit 2 entitlement manager for the Subscription Manager Pro tier.
///
/// Configure the matching auto-renewable subscription product IDs in App Store Connect:
/// - com.hieuthieudx79.subscriptionmanager.pro.monthly
/// - com.hieuthieudx79.subscriptionmanager.pro.yearly
///
/// The app intentionally stays in the Free tier if products are not available or
/// if StoreKit can't verify a transaction.
@MainActor
final class PurchaseManager: ObservableObject {
    static let shared = PurchaseManager()

    enum ProductID {
        static let monthly = "com.hieuthieudx79.subscriptionmanager.pro.monthly"
        static let yearly = "com.hieuthieudx79.subscriptionmanager.pro.yearly"
        static let all = [monthly, yearly]
    }

    @Published private(set) var products: [Product] = []
    @Published private(set) var isPro = false
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private var updatesTask: Task<Void, Never>?

    private init() {
        updatesTask = observeTransactionUpdates()
    }

    deinit {
        updatesTask?.cancel()
    }

    func loadProducts() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            products = try await Product.products(for: ProductID.all)
                .sorted { $0.price < $1.price }
        } catch {
            errorMessage = "We couldn't load Pro plans. Please try again later."
        }

        await refreshEntitlements()
    }

    func purchase(_ product: Product) async {
        errorMessage = nil

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard let transaction = verifiedTransaction(from: verification) else {
                    errorMessage = "The App Store couldn't verify this purchase."
                    return
                }
                await transaction.finish()
                await refreshEntitlements()
            case .userCancelled:
                break
            case .pending:
                errorMessage = "Your purchase is pending approval."
            @unknown default:
                errorMessage = "The purchase could not be completed."
            }
        } catch {
            errorMessage = "Purchase failed. Please try again."
        }
    }

    func restorePurchases() async {
        errorMessage = nil
        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            errorMessage = "Purchases couldn't be restored. Please try again."
        }
    }

    func refreshEntitlements() async {
        var hasPro = false

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard ProductID.all.contains(transaction.productID) else { continue }
            if transaction.revocationDate == nil {
                hasPro = true
            }
        }

        isPro = hasPro
    }

    private func observeTransactionUpdates() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard case .verified(let transaction) = result else { continue }
                await transaction.finish()
                await self?.refreshEntitlements()
            }
        }
    }

    private func verifiedTransaction(
        from result: VerificationResult<Transaction>
    ) -> Transaction? {
        guard case .verified(let transaction) = result else { return nil }
        return transaction
    }
}
