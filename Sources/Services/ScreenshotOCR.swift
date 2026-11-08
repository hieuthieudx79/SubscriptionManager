import Foundation
import Vision
import UIKit

struct ExtractedSubscription {
    var appName: String?
    var price: Decimal?
    var currencyCode: String?
    var renewalDate: Date?
    var billingCycle: BillingCycle?
    var recognizedText: String
}

enum ScreenshotOCR {
    static func recognize(image: UIImage) throws -> ExtractedSubscription {
        guard let cgImage = image.cgImage else {
            throw OCRError.invalidImage
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["en-US", "en-GB"]

        try VNImageRequestHandler(cgImage: cgImage).perform([request])

        let lines = (request.results ?? []).compactMap {
            $0.topCandidates(1).first?.string
        }
        let text = lines.joined(separator: "\n")

        return ExtractedSubscription(
            appName: guessAppName(in: lines),
            price: guessPrice(in: text),
            currencyCode: guessCurrency(in: text),
            renewalDate: guessRenewalDate(in: text),
            billingCycle: guessBillingCycle(in: text),
            recognizedText: text
        )
    }

    private static func guessAppName(in lines: [String]) -> String? {
        let knownServices = [
            "YouTube Premium", "Apple Music", "Apple TV+", "iCloud+",
            "Google One", "Google Play Pass", "Amazon Prime", "Prime Video",
            "Netflix", "Spotify", "Disney+", "Hulu", "Max", "ChatGPT",
            "Microsoft 365", "Adobe"
        ]

        let joined = lines.joined(separator: " ").lowercased()
        if let match = knownServices.first(where: { joined.contains($0.lowercased()) }) {
            return match
        }

        let ignored = [
            "subscriptions", "subscription", "renewal", "renews", "expires",
            "cancel", "manage", "google play", "apple account", "next billing",
            "billing date", "payment method", "active"
        ]

        return lines.first { line in
            let value = line.trimmingCharacters(in: .whitespacesAndNewlines)
            return value.count >= 2
                && value.count <= 36
                && !ignored.contains(where: { value.lowercased().contains($0) })
                && !value.contains(where: { $0.isNumber })
        }
    }

    private static func guessPrice(in text: String) -> Decimal? {
        let patterns = [
            #"(?i)(US\$|\$|USD)\s?(\d{1,4}(?:[.,]\d{1,2})?)"#,
            #"(?i)(£|GBP)\s?(\d{1,4}(?:[.,]\d{1,2})?)"#,
            #"(?i)(€|EUR)\s?(\d{1,4}(?:[.,]\d{1,2})?)"#
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(
                    in: text,
                    range: NSRange(text.startIndex..., in: text)
                  ),
                  let valueRange = Range(match.range(at: 2), in: text) else {
                continue
            }

            let rawValue = String(text[valueRange])
                .replacingOccurrences(of: ",", with: ".")
            if let value = Decimal(string: rawValue, locale: Locale(identifier: "en_US_POSIX")) {
                return value
            }
        }
        return nil
    }

    private static func guessCurrency(in text: String) -> String? {
        if text.contains("£") || text.localizedCaseInsensitiveContains("GBP") {
            return "GBP"
        }
        if text.contains("€") || text.localizedCaseInsensitiveContains("EUR") {
            return "EUR"
        }
        if text.localizedCaseInsensitiveContains("US$")
            || text.localizedCaseInsensitiveContains("USD") {
            return "USD"
        }
        if text.contains("$") {
            return "USD" // Dollar symbol is ambiguous; confirm this in the review form.
        }
        return nil
    }

    private static func guessRenewalDate(in text: String) -> Date? {
        let pattern = #"[A-Za-z]{3,9}\s+\d{1,2},?\s+\d{4}|\d{1,2}\s+[A-Za-z]{3,9}\s+\d{4}|\d{1,2}/\d{1,2}/\d{4}"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(
                in: text,
                range: NSRange(text.startIndex..., in: text)
              ),
              let range = Range(match.range, in: text) else {
            return nil
        }

        let dateText = String(text[range])
        let formats: [(String, String)] = [
            ("MMMM d, yyyy", "en_US"),
            ("MMM d, yyyy", "en_US"),
            ("d MMMM yyyy", "en_GB"),
            ("d MMM yyyy", "en_GB"),
            ("MM/dd/yyyy", "en_US"),
            ("dd/MM/yyyy", "en_GB")
        ]

        for (format, localeID) in formats {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: localeID)
            formatter.timeZone = .current
            formatter.dateFormat = format
            if let date = formatter.date(from: dateText) {
                return date
            }
        }
        return nil
    }

    private static func guessBillingCycle(in text: String) -> BillingCycle? {
        let value = text.lowercased()
        if value.contains("weekly") || value.contains("per week") {
            return .weekly
        }
        if value.contains("yearly") || value.contains("annual") || value.contains("per year") {
            return .yearly
        }
        if value.contains("quarterly") || value.contains("every 3 months") {
            return .quarterly
        }
        if value.contains("monthly") || value.contains("per month") {
            return .monthly
        }
        return nil
    }

    enum OCRError: Error {
        case invalidImage
    }
}
