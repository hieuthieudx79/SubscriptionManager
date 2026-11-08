# Subscription Manager

A lightweight iOS app for tracking recurring payments in one place.

## MVP features

- Add subscriptions manually.
- Import a screenshot from Apple App Store Subscriptions or Google Play Subscriptions.
- Recognize text locally on the iPhone using Apple Vision.
- Review and correct detected service name, price, currency, billing cycle, and next renewal date.
- Store records locally using SwiftData.
- Schedule local renewal reminders for 7, 3, and 1 days before renewal.
- Dashboard, subscriptions list, and renewal calendar.
- USD, GBP, and EUR currency support.

## Important limitations

- This app does not access a user's Apple Account or Google Play account. Screenshot import is an OCR-assisted convenience, not an official account integration.
- OCR results are estimates and must be checked. Some screenshots omit the next renewal date or billing interval.
- A dollar symbol can represent USD, CAD, AUD, and other currencies. Confirm the currency before saving.
- Screenshots taken on Android must be transferred to the iPhone before importing.
- This MVP stores data locally. It does not include cloud sync, bank connections, login, or automatic cancellation.

## Requirements

- macOS with Xcode 15 or later.
- iOS 17 or later deployment target.
- XcodeGen.

Install XcodeGen with Homebrew:

    brew install xcodegen

Generate and open the Xcode project:

    xcodegen generate
    open SubscriptionManager.xcodeproj

Select an iPhone simulator or connected iPhone and run the SubscriptionManager scheme.

## Project structure

    Sources/
      SubscriptionManagerApp.swift
      Models/
        SubscriptionItem.swift
      Services/
        ReminderScheduler.swift
        ScreenshotOCR.swift
      Views/
        ContentView.swift
        AddSubscriptionView.swift
        SubscriptionComponents.swift
    project.yml

## Before App Store release

- Test screenshots from real US and UK Apple and Google Play account pages.
- Improve date parsing for locale-specific formats and dates without a year.
- Add unit tests for OCR parsing and recurring-cost calculations.
- Test local notifications on physical devices.
- Add app icon, onboarding, privacy policy, and App Store screenshots.
- Verify App Store Review Guidelines and privacy disclosures.


## Pro subscriptions (StoreKit 2)

The app includes a native StoreKit 2 subscription flow and a Free plan limit.

### Product IDs to create in App Store Connect

Create a subscription group named **Subscription Manager Pro**, then add two auto-renewable products:

- `com.hieuthieudx79.subscriptionmanager.pro.monthly`
- `com.hieuthieudx79.subscriptionmanager.pro.yearly`

Choose the final storefront prices in App Store Connect. The app displays localized product names and prices returned by StoreKit; it does not hardcode prices.

### Current tier rules

- Free: up to 5 active subscriptions, manual entry, dashboard, list, calendar, and local reminders.
- Pro: unlimited active subscriptions and screenshot import.
- The Pro paywall also lists advanced reminders, insights, and export as intended premium benefits. Those features must be implemented before they are advertised as available in a public release.

### StoreKit testing

In Xcode, create a StoreKit Configuration file and add products using the product IDs above. Select the configuration in the Run scheme to test purchase and restore flows in Simulator. For sandbox testing, configure the products and subscription group in App Store Connect and use a Sandbox Apple Account.

Purchases are verified with StoreKit 2 transaction verification and current entitlements. Restore Purchases calls `AppStore.sync()`. If the products are not configured or unavailable, the app remains usable on the Free tier.

Before release, complete subscription metadata, localized descriptions, review screenshots, privacy details, and test purchase/renewal/cancellation/restore on real devices.
