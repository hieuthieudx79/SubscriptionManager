import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct AddSubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var purchases: PurchaseManager
    @Query private var subscriptions: [SubscriptionItem]

    @State private var appName = ""
    @State private var priceText = ""
    @State private var currencyCode = "USD"
    @State private var billingCycle: BillingCycle = .monthly
    @State private var renewalDate = Calendar.current.date(byAdding: .month, value: 1, to: .now) ?? .now
    @State private var source: SubscriptionSource = .manual
    @State private var reminderDays: Set<Int> = [7, 3, 1]
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isProcessing = false
    @State private var recognitionNote: String?
    @State private var recognizedText = ""

    private let currencies = ["USD", "GBP", "EUR"]

    private var activeCount: Int { subscriptions.filter(\.isActive).count }
    private var canUseScreenshotImport: Bool { purchases.isPro }

    var body: some View {
        NavigationStack {
            Form {
                Section("Add method") {
                    Picker("Source", selection: $source) {
                        Text(SubscriptionSource.manual.rawValue).tag(SubscriptionSource.manual)
                        Text(SubscriptionSource.apple.rawValue).tag(SubscriptionSource.apple)
                        Text(SubscriptionSource.googlePlay.rawValue).tag(SubscriptionSource.googlePlay)
                    }
                    .onChange(of: source) { _, newSource in
                        if newSource != .manual && !canUseScreenshotImport {
                            source = .manual
                            recognitionNote = "Screenshot import is a Pro feature. Upgrade to unlock it."
                        }
                    }

                    if source != .manual {
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            Label("Choose screenshot", systemImage: "photo")
                        }
                        .onChange(of: selectedPhoto) { _, item in
                            Task { await importScreenshot(item) }
                        }

                        if isProcessing { ProgressView("Reading screenshot…") }

                        if !recognizedText.isEmpty {
                            DisclosureGroup("View recognized text") {
                                Text(recognizedText)
                                    .font(.caption)
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                }

                Section("Subscription details") {
                    TextField("App or service name", text: $appName)
                    HStack {
                        TextField("Price", text: $priceText).keyboardType(.decimalPad)
                        Picker("Currency", selection: $currencyCode) {
                            ForEach(currencies, id: \.self) { currency in Text(currency).tag(currency) }
                        }
                        .pickerStyle(.menu)
                    }
                    Picker("Billing cycle", selection: $billingCycle) {
                        ForEach(BillingCycle.allCases) { cycle in Text(cycle.rawValue).tag(cycle) }
                    }
                    DatePicker("Next renewal", selection: $renewalDate, displayedComponents: .date)
                }

                Section("Reminders") {
                    ForEach([7, 3, 1], id: \.self) { days in
                        Toggle("\(days) day\(days == 1 ? "" : "s") before", isOn: Binding(
                            get: { reminderDays.contains(days) },
                            set: { enabled in
                                if enabled { reminderDays.insert(days) } else { reminderDays.remove(days) }
                            }
                        ))
                    }
                }

                if let recognitionNote {
                    Section("Notice") {
                        Text(recognitionNote).font(.footnote).foregroundStyle(.secondary)
                        if recognitionNote.contains("Pro feature") {
                            Button("Upgrade to Pro") { dismiss(); NotificationCenter.default.post(name: .showProPaywall, object: nil) }
                        }
                    }
                }
            }
            .navigationTitle("New Subscription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(appName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || parsedPrice == nil)
                }
            }
        }
    }

    private var parsedPrice: Decimal? {
        let normalized = priceText.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
        return Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX"))
    }

    @MainActor
    private func importScreenshot(_ item: PhotosPickerItem?) async {
        guard purchases.isPro else { recognitionNote = "Screenshot import is a Pro feature."; return }
        guard let item else { return }
        isProcessing = true
        recognitionNote = nil
        defer { isProcessing = false }
        do {
            guard let data = try await item.loadTransferable(type: Data.self), let image = UIImage(data: data) else {
                recognitionNote = "The selected image could not be opened. Try another screenshot."
                return
            }
            let result = try ScreenshotOCR.recognize(image: image)
            if let value = result.appName { appName = value }
            if let value = result.price { priceText = NSDecimalNumber(decimal: value).stringValue }
            if let value = result.currencyCode { currencyCode = value }
            if let value = result.renewalDate { renewalDate = value }
            if let value = result.billingCycle { billingCycle = value }
            recognizedText = result.recognizedText
            recognitionNote = "Check every field before saving. Text recognition can miss or misread the details. A dollar sign alone cannot distinguish USD, CAD, AUD, or other dollar currencies."
        } catch {
            recognitionNote = "We couldn't read this screenshot. You can still enter the details manually."
        }
    }

    private func save() {
        guard let amount = parsedPrice else { return }
        guard PremiumFeatures.canAddSubscription(currentActiveCount: activeCount, isPro: purchases.isPro) else {
            recognitionNote = "The Free plan allows up to \(PremiumFeatures.freeActiveSubscriptionLimit) active subscriptions. Upgrade to Pro to add more."
            return
        }

        let item = SubscriptionItem(
            appName: appName.trimmingCharacters(in: .whitespacesAndNewlines),
            price: amount,
            currencyCode: currencyCode,
            billingCycle: billingCycle,
            renewalDate: renewalDate,
            reminderDays: reminderDays.sorted(by: >),
            source: source
        )
        modelContext.insert(item)
        Task {
            _ = await ReminderScheduler.requestPermission()
            await ReminderScheduler.schedule(for: item)
            dismiss()
        }
    }
}
