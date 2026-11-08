import SwiftUI
import SwiftData

@main
struct SubscriptionManagerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: SubscriptionItem.self)
    }
}
