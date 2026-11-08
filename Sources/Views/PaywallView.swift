import SwiftUI
import StoreKit

struct PaywallView: View {
    @ObservedObject private var purchases = PurchaseManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedProductID = PurchaseManager.ProductID.yearly

    private var selectedProduct: Product? {
        purchases.products.first { $0.id == selectedProductID }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    VStack(spacing: 10) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 42))
                            .foregroundStyle(.yellow)
                            .padding(.top, 18)
                        Text("Get more from Subscription Manager")
                            .font(.largeTitle.bold())
                            .multilineTextAlignment(.center)
                        Text("Protect every trial, track all your services, and understand your recurring spending.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        feature("Unlimited active subscriptions", icon: "infinity")
                        feature("Apple and Google Play screenshot import", icon: "text.viewfinder")
                        feature("Advanced renewal reminders", icon: "bell.badge")
                        feature("Spending insights and export", icon: "chart.bar.xaxis")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))

                    if purchases.isLoading && purchases.products.isEmpty {
                        ProgressView("Loading plans…")
                            .padding()
                    } else if purchases.products.isEmpty {
                        ContentUnavailableView(
                            "Plans unavailable",
                            systemImage: "wifi.exclamationmark",
                            description: Text("Connect to the App Store and try again. You can continue using the Free plan.")
                        )
                    } else {
                        VStack(spacing: 12) {
                            ForEach(purchases.products, id: \.id) { product in
                                planRow(product)
                            }
                        }

                        Button {
                            guard let selectedProduct else { return }
                            Task { await purchases.purchase(selectedProduct) }
                        } label: {
                            HStack {
                                if purchases.isLoading {
                                    ProgressView().tint(.white)
                                }
                                Text("Continue")
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.indigo, in: RoundedRectangle(cornerRadius: 14))
                            .foregroundStyle(.white)
                        }
                        .disabled(selectedProduct == nil || purchases.isLoading)
                    }

                    if let message = purchases.errorMessage {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }

                    Button("Restore Purchases") {
                        Task { await purchases.restorePurchases() }
                    }
                    .font(.footnote.weight(.medium))

                    Text("Payment will be charged to your Apple Account at confirmation. Subscriptions renew automatically unless cancelled at least 24 hours before the end of the current period. You can manage or cancel your subscription in your Apple Account settings.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
            .navigationTitle("Subscription Manager Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
            .task {
                await purchases.loadProducts()
                if purchases.products.contains(where: { $0.id == selectedProductID }) == false {
                    selectedProductID = purchases.products.first?.id ?? PurchaseManager.ProductID.yearly
                }
            }
            .onChange(of: purchases.isPro) { _, isPro in
                if isPro { dismiss() }
            }
        }
    }

    private func feature(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.subheadline.weight(.medium))
    }

    private func planRow(_ product: Product) -> some View {
        let isSelected = selectedProductID == product.id
        return Button {
            selectedProductID = product.id
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(isSelected ? .indigo : .secondary)
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.displayName)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(product.id == PurchaseManager.ProductID.yearly ? "Best value · billed yearly" : "Billed monthly")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(product.displayPrice)
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(isSelected ? Color.indigo : Color.secondary.opacity(0.25), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}
