import Foundation
import SwiftData

enum BillingCycle: String, CaseIterable, Identifiable, Codable {
    case weekly = "Weekly"
    case monthly = "Monthly"
    case quarterly = "Quarterly"
    case yearly = "Yearly"

    var id: String { rawValue }

    var monthlyMultiplier: Decimal {
        switch self {
        case .weekly: return Decimal(string: "4.333333")!
        case .monthly: return 1
        case .quarterly: return Decimal(string: "0.333333")!
        case .yearly: return Decimal(string: "0.083333")!
        }
    }
}

enum SubscriptionSource: String, CaseIterable, Identifiable, Codable {
    case manual = "Manual"
    case apple = "Apple App Store"
    case googlePlay = "Google Play"

    var id: String { rawValue }
}

@Model
final class SubscriptionItem {
    var id: UUID
    var appName: String
    var price: Decimal
    var currencyCode: String
    var billingCycleRawValue: String
    var renewalDate: Date
    var reminderDaysCSV: String
    var sourceRawValue: String
    var isActive: Bool
    var createdAt: Date

    init(
        appName: String,
        price: Decimal,
        currencyCode: String = "USD",
        billingCycle: BillingCycle = .monthly,
        renewalDate: Date,
        reminderDays: [Int] = [7, 3, 1],
        source: SubscriptionSource = .manual
    ) {
        self.id = UUID()
        self.appName = appName
        self.price = price
        self.currencyCode = currencyCode
        self.billingCycleRawValue = billingCycle.rawValue
        self.renewalDate = renewalDate
        self.reminderDaysCSV = reminderDays.sorted(by: >).map(String.init).joined(separator: ",")
        self.sourceRawValue = source.rawValue
        self.isActive = true
        self.createdAt = .now
    }

    var billingCycle: BillingCycle {
        get { BillingCycle(rawValue: billingCycleRawValue) ?? .monthly }
        set { billingCycleRawValue = newValue.rawValue }
    }

    var source: SubscriptionSource {
        get { SubscriptionSource(rawValue: sourceRawValue) ?? .manual }
        set { sourceRawValue = newValue.rawValue }
    }

    var reminderDays: [Int] {
        get {
            reminderDaysCSV
                .split(separator: ",")
                .compactMap { Int($0) }
                .sorted(by: >)
        }
        set {
            reminderDaysCSV = newValue.sorted(by: >).map(String.init).joined(separator: ",")
        }
    }

    var monthlyEquivalent: Decimal {
        price * billingCycle.monthlyMultiplier
    }
}
