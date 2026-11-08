import SwiftUI
import SwiftData

@main
struct SubscriptionManagerApp: App {
    @StateObject private var purchases = PurchaseManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(purchases)
                .task {
                    await purchases.loadProducts()
                    await purchases.refreshEntitlements()
                }
        }
        .modelContainer(for: SubscriptionItem.self)
    }
}
