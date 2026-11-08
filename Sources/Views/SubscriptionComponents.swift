import SwiftUI
import SwiftData

struct SubscriptionRow: View {
    let item: SubscriptionItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: sourceIcon)
                .font(.title2)
                .frame(width: 46, height: 46)
                .background(.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.appName)
                    .font(.headline)
                Text("\(item.billingCycle.rawValue) · \(item.renewalDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(item.price, format: .currency(code: item.currencyCode))
                .font(.headline)
        }
        .padding(.vertical, 5)
    }

    private var sourceIcon: String {
        switch item.source {
        case .apple: return "apple.logo"
        case .googlePlay: return "play.rectangle"
        case .manual: return "creditcard"
        }
    }
}

struct SubscriptionListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SubscriptionItem.renewalDate) private var subscriptions: [SubscriptionItem]
    @State private var showingAdd = false

    var body: some View {
        List {
            ForEach(subscriptions) { item in
                SubscriptionRow(item: item)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            ReminderScheduler.remove(for: item)
                            modelContext.delete(item)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }

                        Button {
                            item.isActive.toggle()
                            Task {
                                if item.isActive {
                                    await ReminderScheduler.schedule(for: item)
                                } else {
                                    ReminderScheduler.remove(for: item)
                                }
                            }
                        } label: {
                            Label(
                                item.isActive ? "Pause" : "Resume",
                                systemImage: item.isActive ? "pause" : "play"
                            )
                        }
                        .tint(.orange)
                    }
            }
        }
        .overlay {
            if subscriptions.isEmpty {
                ContentUnavailableView("No subscriptions", systemImage: "list.bullet")
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingAdd = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAdd) {
            AddSubscriptionView()
        }
    }
}

struct RenewalCalendarView: View {
    @Query(sort: \SubscriptionItem.renewalDate) private var subscriptions: [SubscriptionItem]

    private var activeSubscriptions: [SubscriptionItem] {
        subscriptions.filter(\.isActive)
    }

    var body: some View {
        List(activeSubscriptions) { item in
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.appName)
                        .font(.headline)
                    Text(item.renewalDate.formatted(date: .complete, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(item.price, format: .currency(code: item.currencyCode))
                    .font(.headline)
            }
            .padding(.vertical, 4)
        }
        .overlay {
            if activeSubscriptions.isEmpty {
                ContentUnavailableView("No upcoming renewals", systemImage: "calendar")
            }
        }
    }
}

struct SettingsView: View {
    var body: some View {
        Form {
            Section("About") {
                LabeledContent("Version", value: "0.1.0")
                LabeledContent("Storage", value: "On this device")
                Text("Subscription Manager does not connect to Apple or Google billing accounts. Screenshot import uses on-device text recognition, and detected information should be reviewed before saving.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Privacy") {
                Label("No account required", systemImage: "person.crop.circle.badge.checkmark")
                Label("No bank connection", systemImage: "building.columns")
                Label("On-device screenshot recognition", systemImage: "iphone.gen3")
            }
        }
    }
}
