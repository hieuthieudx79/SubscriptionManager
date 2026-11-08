import SwiftUI
import SwiftData

struct ContentView: View {
    @Query(sort: \SubscriptionItem.renewalDate) private var subscriptions: [SubscriptionItem]
    @State private var selectedTab = 0
    @State private var showingAdd = false

    private var activeSubscriptions: [SubscriptionItem] {
        subscriptions.filter(\.isActive)
    }

    private var currencyCodes: [String] {
        Array(Set(activeSubscriptions.map(\.currencyCode))).sorted()
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                dashboard
                    .navigationTitle("Subscriptions")
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button { showingAdd = true } label: {
                                Image(systemName: "plus")
                            }
                            .accessibilityLabel("Add subscription")
                        }
                    }
                    .sheet(isPresented: $showingAdd) {
                        AddSubscriptionView()
                    }
            }
            .tabItem { Label("Home", systemImage: "house") }
            .tag(0)

            NavigationStack {
                SubscriptionListView()
                    .navigationTitle("My Subscriptions")
            }
            .tabItem { Label("Subscriptions", systemImage: "list.bullet") }
            .tag(1)

            NavigationStack {
                RenewalCalendarView()
                    .navigationTitle("Renewal Calendar")
            }
            .tabItem { Label("Calendar", systemImage: "calendar") }
            .tag(2)

            NavigationStack {
                SettingsView()
                    .navigationTitle("Settings")
            }
            .tabItem { Label("Settings", systemImage: "gearshape") }
            .tag(3)
        }
        .tint(.indigo)
    }

    private var dashboard: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Active subscriptions")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("\(activeSubscriptions.count)")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                    Text("Keep every renewal in one place.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(22)
                .background(.indigo.opacity(0.10), in: RoundedRectangle(cornerRadius: 22))

                if !activeSubscriptions.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Estimated monthly spending")
                            .font(.headline)
                        ForEach(currencyCodes, id: \.self) { currency in
                            let total = activeSubscriptions
                                .filter { $0.currencyCode == currency }
                                .reduce(Decimal.zero) { $0 + $1.monthlyEquivalent }
                            HStack {
                                Text(currency)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(total, format: .currency(code: currency))
                                    .font(.title3.weight(.semibold))
                            }
                        }
                        Text("Totals are shown separately by currency. Weekly, quarterly, and yearly plans are normalized to an estimated monthly amount.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(18)
                    .background(.background, in: RoundedRectangle(cornerRadius: 18))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(.quaternary, lineWidth: 1)
                    }
                }

                HStack {
                    Text("Upcoming renewals")
                        .font(.headline)
                    Spacer()
                    Button("See all") { selectedTab = 1 }
                        .font(.subheadline)
                }

                if activeSubscriptions.isEmpty {
                    ContentUnavailableView(
                        "No subscriptions yet",
                        systemImage: "calendar.badge.plus",
                        description: Text("Add a service manually or import an Apple or Google Play screenshot.")
                    )
                    .padding(.top, 8)
                } else {
                    ForEach(activeSubscriptions.sorted { $0.renewalDate < $1.renewalDate }.prefix(6)) { item in
                        SubscriptionRow(item: item)
                    }
                }

                Button { showingAdd = true } label: {
                    Label("Add subscription", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.indigo, in: RoundedRectangle(cornerRadius: 15))
                        .foregroundStyle(.white)
                }
            }
            .padding()
        }
    }
}
