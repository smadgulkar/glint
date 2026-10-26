import Foundation
import Combine
import StoreKit

/// One non-consumable in-app purchase: Glint Pro, $4.99, forever.
@MainActor
final class Purchases: ObservableObject {
    /// Must match the product ID you create in App Store Connect.
    static let proProductID = "com.example.glint.pro.lifetime"

    @Published private(set) var isPro = false
    @Published private(set) var product: Product?
    @Published private(set) var isBusy = false
    @Published var errorMessage: String?

    private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    await self?.refreshEntitlement()
                }
            }
        }
        Task {
            await loadProduct()
            await refreshEntitlement()
        }
    }

    var priceText: String {
        product?.displayPrice ?? "$4.99"
    }

    func loadProduct() async {
        do {
            product = try await Product.products(for: [Self.proProductID]).first
        } catch {
            print("Product load failed: \(error)")
        }
    }

    func refreshEntitlement() async {
        var owned = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.proProductID,
               transaction.revocationDate == nil {
                owned = true
            }
        }
        isPro = owned
    }

    func buy() async {
        if product == nil { await loadProduct() }
        guard let product else {
            errorMessage = "The App Store isn't reachable right now. Try again in a moment."
            return
        }
        isBusy = true
        defer { isBusy = false }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    isPro = true
                }
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func restore() async {
        isBusy = true
        defer { isBusy = false }
        do {
            try await AppStore.sync()
        } catch {
            errorMessage = error.localizedDescription
        }
        await refreshEntitlement()
    }
}
