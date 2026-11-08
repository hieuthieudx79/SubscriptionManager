import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct AddSubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var appName = ""
    @State private var priceText = ""
    @State private var currencyCode = "USD"
    @State private var billingCycle: BillingCycle = .monthly
    @State private var renewalDate = Calendar.current.date(
        byAdding: .month,
        value: 1,
        to: .now
    ) ?? .now
    @State private var source: SubscriptionSource = .manual
    @State private var reminderDays: Set<Int> = [7, 3, 1]
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isProcessing = false
    @State private var recognitionNote: String?
    @State private var recognizedText = ""

    private let currencies = ["USD", "GBP", "EUR"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Add method") {
                    Picker("Source", selection: $source) {
                        ForEach(SubscriptionSource.allCases) { item in
                            Text(item.rawValue).tag(item)
                        }
                    }

                    if source != .manual {
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            Label("Choose screenshot", systemImage: "photo")
                        }
                        .onChange(of: selectedPhoto) { _, item in
                            Task { await importScreenshot(item) }
                        }

                        if isProcessing {
                            ProgressView("Reading screenshot…")
                        }

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
                        TextField("Price", text: $priceText)
                            .keyboardType(.decimalPad)
                        Picker("Currency", selection: $currencyCode) {
                            ForEach(currencies, id: \.self) { currency in
                                Text(currency).tag(currency)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    Picker("Billing cycle", selection: $billingCycle) {
                        ForEach(BillingCycle.allCases) { cycle in
                            Text(cycle.rawValue).tag(cycle)
                        }
                    }

                    DatePicker(
                        "Next renewal",
                        selection: $renewalDate,
                        displayedComponents: .date
                    )
                }

                Section("Reminders") {
                    ForEach([7, 3, 1], id: \.self) { days in
                        Toggle(
                            "\(days) day\(days == 1 ? "" : "s") before",
                            isOn: Binding(
                                get: { reminderDays.contains(days) },
                                set: { enabled in
                                    if enabled {
                                        reminderDays.insert(days)
                                    } else {
                                        reminderDays.remove(days)
                                    }
                                }
                            )
                        )
                    }
                }

                if let recognitionNote {
                    Section("Screenshot import") {
                        Text(recognitionNote)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("New Subscription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(
                            appName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            || parsedPrice == nil
                        )
                }
            }
        }
    }

    private var parsedPrice: Decimal? {
        let normalized = priceText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        return Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX"))
    }

    @MainActor
    private func importScreenshot(_ item: PhotosPickerItem?) async {
        guard let item else { return }

        isProcessing = true
        recognitionNote = nil
        defer { isProcessing = false }

        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                recognitionNote = "The selected image could not be opened. Try another screenshot."
                return
            }

            let result = try ScreenshotOCR.recognize(image: image)
            if let value = result.appName { appName = value }
            if let value = result.price {
                priceText = NSDecimalNumber(decimal: value).stringValue
            }
            if let value = result.currencyCode { currencyCode = value }
            if let value = result.renewalDate { renewalDate = value }
            if let value = result.billingCycle { billingCycle = value }

            recognizedText = result.recognizedText
            recognitionNote = "Check every field before saving. Text recognition can miss or misread the service name, amount, currency, renewal date, or billing cycle. A dollar sign alone cannot distinguish USD, CAD, AUD, or other dollar currencies."
        } catch {
            recognitionNote = "We couldn't read this screenshot. You can still enter the details manually."
        }
    }

    private func save() {
        guard let amount = parsedPrice else { return }

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
