# GUIDE_SUBSCRIPTIONS.md — GripTrack Subscription System

> **Purpose:** Complete guide for implementing subscriptions in GripTrack using StoreKit 2 directly, syncing status to Firebase, managing a free-to-paid transition, and running a referral rewards program. Reference this alongside PROJECT_SPEC.md.

---

## 1. How iOS Subscriptions Work — The Full Picture

### 1.1 What Handles What

| Responsibility | Handled By |
|---|---|
| Payment processing, billing, receipts | **Apple App Store** (mandatory for iOS) |
| Subscription product definition & pricing | **App Store Connect** (Apple's web portal) |
| In-app purchase flow, entitlement checking | **StoreKit 2** (Apple's Swift framework in your app) |
| User identity (who is this person?) | **Firebase Auth** (your system) |
| Subscription status dashboard & analytics | **Cloud Firestore** (your system, synced from StoreKit) |
| Referral tracking & reward logic | **Cloud Firestore + Cloud Functions** (your system) |
| Local testing during development | **StoreKit Configuration File** (Xcode, no App Store Connect needed) |

### 1.2 The Money Flow

```
User taps Subscribe
    → Apple Payment Sheet (Face ID / Touch ID)
    → Apple processes payment
    → Apple takes 15% commission (Small Business Program) or 30%
    → Apple deposits remainder to your bank (45 days after fiscal month ends)
    → StoreKit 2 returns verified Transaction to your app
    → Your app writes subscription status to Firebase
    → Your app unlocks premium features
```

**Important:** Apple takes 30% of subscription revenue in Year 1, dropping to 15% from Year 2 onward for the same subscriber. If you qualify for the Apple Small Business Program (under $1M annual revenue), it's 15% from day one. You almost certainly qualify — enroll at developer.apple.com/programs/small-business.

### 1.3 Your Price Point

| Plan | Price | Apple's Cut (15%) | Your Revenue | Effective Monthly |
|---|---|---|---|---|
| Monthly | $3.99 | $0.60 | $3.39 | $3.99 |
| Yearly | $29.99 | $4.50 | $25.49 | $2.50 (37% savings) |

---

## 2. Product & Tier Strategy

### 2.1 Subscription Tiers

One subscription group with two tiers for MVP.

| Product ID | Type | Price | Description |
|---|---|---|---|
| `com.griptrack.pro.monthly` | Auto-renewable | $3.99/month | GripTrack Pro — monthly |
| `com.griptrack.pro.yearly` | Auto-renewable | $29.99/year | GripTrack Pro — annual (save 37%) |

Both products live in the same **Subscription Group** (`griptrack_pro`). Apple handles upgrade/downgrade logic automatically when products are in the same group.

### 2.2 Free vs. Pro Feature Gating

During initial product-market fit testing, **all features are free**. The subscription infrastructure exists in code but the paywall is not enforced. This is controlled by a single flag.

| Feature | Free Tier | Pro Tier |
|---|---|---|
| BLE device connection | ✅ | ✅ |
| Live force display | ✅ | ✅ |
| Record grip sessions | ✅ (limited to 5 stored) | ✅ Unlimited |
| View recording history | ✅ (last 5 only) | ✅ Full history |
| Dashboard stats | ✅ Basic (max, average) | ✅ Full (trends, charts, comparisons) |
| Cloud sync across devices | ❌ | ✅ |
| Export data | ❌ | ✅ |
| Settings & profile | ✅ | ✅ |

### 2.3 Pro Access Control — Three Tiers

There are three ways a user gets Pro access, checked in this order:

```
1. Global bypass flag (everyone free — early testing phase)
2. Manual Pro override (specific users you grant access — post-paywall)
3. Active StoreKit subscription (paid via App Store)
```

#### Tier 1: Global Bypass (Current Phase — Product-Market Fit)

```swift
// Constants.swift
enum AppConfig {
    /// Set to `true` during product-market fit testing.
    /// When true, ALL users get full Pro features regardless of subscription status.
    /// Set to `false` when ready to enforce paywall.
    static let bypassSubscription = true

    /// The number of free recordings allowed before paywall (when bypass is off)
    static let freeRecordingLimit = 5
}
```

This is the right approach while handing devices to test users. Zero friction, no codes, no per-user setup. Every user who downloads the app gets everything.

#### Tier 2: Manual Pro Override (After Paywall Goes Live)

Once you flip `bypassSubscription = false`, you'll still want to grant specific people free Pro access — beta testers, physical therapy partners, early supporters, demo accounts for trade shows. This is a Firestore field you set manually.

```swift
// In UserProfile model, add:
var manualProOverride: Bool = false    // Set via Firebase Console
var manualProNote: String? = nil       // Optional: "Beta tester", "PT partner", etc.
var manualProExpiresAt: Date? = nil    // Optional: auto-expire the override
```

**How to grant it:** Open Firebase Console → Firestore → `users/{userId}` → edit the document → set `manualProOverride: true`. That's it. No Apple involvement, no offer codes burned, instant, revocable.

#### Tier 3: Paid Subscription (StoreKit)

Standard App Store subscription via StoreKit 2. This is the long-term revenue path.

#### The Unified Access Check

```swift
// Used everywhere in the app that gates a Pro feature
var hasProAccess: Bool {
    AppConfig.bypassSubscription                           // Phase 1: everyone free
    || userProfile.manualProOverride                       // You granted it manually
    || subscriptionService.subscriptionState.isActive      // Paid via App Store
}
```

**This single computed property is the ONLY place access is determined.** Every view, every ViewModel references this. Never check subscription status independently elsewhere.

### 2.4 Phase Transitions

| Phase | bypassSubscription | manualProOverride | Paid Subscriptions | Who Gets Pro |
|---|---|---|---|---|
| **Phase 1: Testing** | `true` | irrelevant | Testable but not required | Everyone |
| **Phase 2: Soft Launch** | `false` | `true` for early testers | Active | Manual overrides + paying users |
| **Phase 3: Full Launch** | `false` | `true` only for partners/demos | Active | Manual overrides + paying users |

**Phase 1 → Phase 2 transition:**
1. Identify all current test users in Firestore
2. Set `manualProOverride = true` on each of their user documents (batch update)
3. Flip `bypassSubscription = false`
4. Push app update
5. Result: existing testers keep Pro, new users hit paywall

This means **no existing test user loses access** when you turn on the paywall.

---

## 3. StoreKit 2 Implementation

### 3.1 Files to Create

```
Services/
├── Subscription/
│   ├── SubscriptionService.swift      # StoreKit 2 product fetching, purchasing, entitlement checking
│   ├── SubscriptionStatus.swift       # Enum + model for subscription state
│   └── SubscriptionConstants.swift    # Product IDs
ViewModels/
│   └── SubscriptionViewModel.swift    # Paywall UI state, purchase actions
Views/
├── Subscription/
│   ├── PaywallView.swift              # Subscription offer screen
│   └── SubscriptionStatusView.swift   # Current plan display (for Settings)
```

### 3.2 SubscriptionConstants.swift

```swift
import Foundation

enum SubscriptionConstants {
    static let monthlyProductID = "com.griptrack.pro.monthly"
    static let yearlyProductID = "com.griptrack.pro.yearly"

    static let allProductIDs: Set<String> = [
        monthlyProductID,
        yearlyProductID,
    ]

    static let subscriptionGroupID = "griptrack_pro"  // Matches App Store Connect
}
```

### 3.3 SubscriptionStatus.swift

```swift
import Foundation

enum SubscriptionTier: String, Codable {
    case free
    case pro
}

struct SubscriptionState: Codable {
    var tier: SubscriptionTier
    var isActive: Bool
    var productId: String?
    var expirationDate: Date?
    var originalPurchaseDate: Date?
    var willAutoRenew: Bool
    var isInFreeTrialFromReferral: Bool  // Granted via offer code

    static let free = SubscriptionState(
        tier: .free,
        isActive: false,
        productId: nil,
        expirationDate: nil,
        originalPurchaseDate: nil,
        willAutoRenew: false,
        isInFreeTrialFromReferral: false
    )
}
```

### 3.4 SubscriptionService.swift — Core Implementation

```swift
import StoreKit
import Foundation

@MainActor
@Observable
class SubscriptionService {
    private(set) var products: [Product] = []
    private(set) var subscriptionState: SubscriptionState = .free
    private(set) var isLoading = false

    private var transactionListener: Task<Void, Error>?

    init() {
        // Start listening for transactions immediately
        transactionListener = listenForTransactions()
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - Fetch Products

    func fetchProducts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            products = try await Product.products(for: SubscriptionConstants.allProductIDs)
                .sorted { $0.price < $1.price }
        } catch {
            print("Failed to fetch products: \(error)")
        }
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async throws -> Bool {
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            await updateSubscriptionStatus()
            return true

        case .userCancelled:
            return false

        case .pending:
            // Transaction is pending (e.g., Ask to Buy)
            return false

        @unknown default:
            return false
        }
    }

    // MARK: - Restore Purchases

    func restorePurchases() async {
        try? await AppStore.sync()
        await updateSubscriptionStatus()
    }

    // MARK: - Check Subscription Status

    func updateSubscriptionStatus() async {
        var latestTransaction: StoreKit.Transaction?
        var latestExpiration: Date?

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }

            if SubscriptionConstants.allProductIDs.contains(transaction.productID) {
                if let expDate = transaction.expirationDate,
                   (latestExpiration == nil || expDate > latestExpiration!) {
                    latestTransaction = transaction
                    latestExpiration = expDate
                }
            }
        }

        if let transaction = latestTransaction, let expiration = latestExpiration {
            // Check renewal info for auto-renew status
            var willAutoRenew = true
            if let statuses = try? await Product.SubscriptionInfo.status(
                for: SubscriptionConstants.subscriptionGroupID
            ) {
                for status in statuses {
                    if case .verified(let renewalInfo) = status.renewalInfo {
                        willAutoRenew = renewalInfo.willAutoRenew
                    }
                }
            }

            subscriptionState = SubscriptionState(
                tier: .pro,
                isActive: expiration > Date(),
                productId: transaction.productID,
                expirationDate: expiration,
                originalPurchaseDate: transaction.originalPurchaseDate,
                willAutoRenew: willAutoRenew,
                isInFreeTrialFromReferral: transaction.offerType == .code
            )
        } else {
            subscriptionState = .free
        }
    }

    // MARK: - Offer Code Redemption (for referral rewards)

    func presentOfferCodeRedemption() async {
        // This presents Apple's built-in offer code redemption sheet
        // User enters the code, Apple handles the rest
        #if os(iOS)
        // Note: Use the SwiftUI .offerCodeRedemption modifier on a view instead.
        // This is here for reference — the view-level modifier is preferred.
        #endif
    }

    // MARK: - Private Helpers

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let item):
            return item
        }
    }

    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached {
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    await self.updateSubscriptionStatus()
                }
            }
        }
    }
}
```

### 3.5 PaywallView.swift — Subscription UI

Two approaches — pick one:

**Option A: Apple's built-in SubscriptionStoreView (simplest, recommended to start)**

```swift
import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        SubscriptionStoreView(groupID: SubscriptionConstants.subscriptionGroupID) {
            VStack(spacing: 16) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.blue)

                Text("GripTrack Pro")
                    .font(.title.bold())

                Text("Unlock unlimited recordings, full history, trends, and cloud sync.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(.top, 40)
        }
        .subscriptionStorePolicyDestination(
            url: URL(string: "https://griptrack.com/privacy")!,
            for: .privacyPolicy
        )
        .subscriptionStorePolicyDestination(
            url: URL(string: "https://griptrack.com/terms")!,
            for: .termsOfService
        )
        .storeButton(.visible, for: .restorePurchases)
        .onInAppPurchaseCompletion { _, result in
            if case .success(.success(_)) = result {
                dismiss()
            }
        }
    }
}
```

**Option B: Custom paywall (more control, implement later if needed)**

Build a custom view using `SubscriptionService.products` and calling `purchase()` manually. This gives full control over layout, messaging, A/B testing, etc.

### 3.6 Presenting the Paywall

In any view where a Pro feature is gated:

```swift
struct DashboardView: View {
    @Environment(SubscriptionService.self) var subscriptionService
    @State private var showPaywall = false

    var hasProAccess: Bool {
        AppConfig.bypassSubscription || subscriptionService.subscriptionState.isActive
    }

    var body: some View {
        // ... your dashboard content ...

        Button("View Full History") {
            if hasProAccess {
                // Navigate to full history
            } else {
                showPaywall = true
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }
}
```

### 3.7 Offer Code Redemption in SwiftUI

For the referral rewards system (Section 5), users redeem offer codes. Add this modifier to SettingsView or PaywallView:

```swift
@State private var showOfferCodeRedemption = false

Button("Redeem Code") {
    showOfferCodeRedemption = true
}
.offerCodeRedemption(isPresented: $showOfferCodeRedemption) { result in
    // Apple handles the UI. After redemption, Transaction.updates fires
    // and SubscriptionService picks it up automatically.
}
```

---

## 4. Firebase Subscription Sync — Dashboard Data

### 4.1 Why Sync to Firebase

StoreKit tells your app locally whether the user is subscribed. But you also want:
- A dashboard of all subscribers (who's paying, who churned, when do they expire)
- The ability to check subscription status from a web admin panel
- Data for business decisions (conversion rates, churn, revenue)
- Referral tracking that persists across devices

StoreKit is the **source of truth** for entitlement. Firebase is your **analytics mirror**.

### 4.2 Firestore Schema — Subscription Data

#### Collection: `users/{userId}` (add to existing user document)

```
{
  // ... existing fields (displayName, email, etc.) ...

  // Manual Pro access (set by you in Firebase Console)
  manualProOverride: Boolean,            // default: false
  manualProNote: String | null,          // e.g., "Beta tester", "PT clinic partner"
  manualProExpiresAt: Timestamp | null,  // optional auto-expiry

  // Subscription (synced from StoreKit)
  subscription: {
    tier: "free" | "pro",
    isActive: Boolean,
    productId: String | null,
    expirationDate: Timestamp | null,
    originalPurchaseDate: Timestamp | null,
    willAutoRenew: Boolean,
    lastSyncedAt: Timestamp,
    isFromOfferCode: Boolean
  }
}
```

#### Collection: `users/{userId}/subscriptionHistory/{eventId}`

```
{
  eventType: "purchase" | "renewal" | "cancellation" | "expiration" | "offer_redeemed",
  productId: String,
  timestamp: Timestamp,
  expirationDate: Timestamp | null,
  offerCodeUsed: String | null,
  transactionId: String
}
```

### 4.3 SubscriptionSyncService.swift

```swift
import Foundation
import FirebaseFirestore

class SubscriptionSyncService {
    private let db = Firestore.firestore()

    /// Call this every time SubscriptionService.updateSubscriptionStatus() completes
    func syncToFirebase(userId: String, state: SubscriptionState) async throws {
        let data: [String: Any] = [
            "subscription": [
                "tier": state.tier.rawValue,
                "isActive": state.isActive,
                "productId": state.productId as Any,
                "expirationDate": state.expirationDate.map { Timestamp(date: $0) } as Any,
                "originalPurchaseDate": state.originalPurchaseDate.map { Timestamp(date: $0) } as Any,
                "willAutoRenew": state.willAutoRenew,
                "lastSyncedAt": Timestamp(date: Date()),
                "isFromOfferCode": state.isInFreeTrialFromReferral
            ]
        ]

        try await db.collection("users").document(userId).setData(data, merge: true)
    }

    /// Log a subscription event for history
    func logSubscriptionEvent(
        userId: String,
        eventType: String,
        productId: String?,
        expirationDate: Date?,
        offerCode: String? = nil,
        transactionId: String
    ) async throws {
        let data: [String: Any] = [
            "eventType": eventType,
            "productId": productId as Any,
            "timestamp": Timestamp(date: Date()),
            "expirationDate": expirationDate.map { Timestamp(date: $0) } as Any,
            "offerCodeUsed": offerCode as Any,
            "transactionId": transactionId
        ]

        try await db.collection("users").document(userId)
            .collection("subscriptionHistory")
            .addDocument(data: data)
    }
}
```

### 4.4 Wiring It Together

In `SubscriptionService`, after every status update, sync to Firebase:

```swift
// Inside SubscriptionService.updateSubscriptionStatus(), at the end:
if let userId = AuthService.shared.currentUserId {
    try? await SubscriptionSyncService().syncToFirebase(
        userId: userId,
        state: subscriptionState
    )
}
```

### 4.5 Subscription Status in Settings

```swift
// SettingsView — Subscription section
struct SubscriptionStatusView: View {
    @Environment(SubscriptionService.self) var subscriptionService
    @State private var showPaywall = false

    let userProfile: UserProfile

    var state: SubscriptionState { subscriptionService.subscriptionState }

    var hasProAccess: Bool {
        AppConfig.bypassSubscription
        || userProfile.manualProOverride
        || state.isActive
    }

    var body: some View {
        Section("Subscription") {
            if AppConfig.bypassSubscription {
                Label("All features unlocked (beta)", systemImage: "gift.fill")
                    .foregroundStyle(.green)
                Text("Free during early access period")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if userProfile.manualProOverride {
                Label("GripTrack Pro (Complimentary)", systemImage: "star.fill")
                    .foregroundStyle(.green)
                if let note = userProfile.manualProNote {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let expires = userProfile.manualProExpiresAt {
                    Text("Access until \(expires, style: .date)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if state.isActive {
                Label("GripTrack Pro", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green)
                if let productId = state.productId {
                    Text(productId == SubscriptionConstants.yearlyProductID ? "Annual Plan" : "Monthly Plan")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let exp = state.expirationDate {
                    Text("Renews \(exp, style: .date)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if !state.willAutoRenew {
                    Text("Auto-renew is off — expires \(state.expirationDate ?? Date(), style: .date)")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                Button("Manage Subscription") {
                    if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                        UIApplication.shared.open(url)
                    }
                }
            } else {
                Label("Free Plan", systemImage: "person.fill")
                Button("Upgrade to Pro") {
                    showPaywall = true
                }
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }
}
```

---

## 5. Referral & Rewards System

### 5.1 How It Works — Overview

```
User A (referrer) shares a referral link/code
    → User B (referee) signs up and redeems an Offer Code
    → User B gets 1 month free (Apple Offer Code handles this)
    → Your app detects the redemption via Transaction with offerType == .code
    → Firebase records the referral
    → User A gets credited with a reward (1 free month via a separate Offer Code)
    → User A redeems their reward code
```

### 5.2 Apple Offer Codes — Your Mechanism for Free Months

Apple's Offer Code system is the compliant way to give free subscription months. You do NOT bypass Apple's billing — instead you create offer codes in App Store Connect that grant free periods, and Apple handles the redemption.

**Two types of offer codes:**

| Type | How It Works | Best For |
|---|---|---|
| **One-time-use codes** | Unique alphanumeric codes, each used once. You generate batches (500-25,000 at a time) in App Store Connect and download as CSV. | Referral rewards — give one unique code per earned reward |
| **Custom codes** | A named code like `GRIPFREE` with a redemption limit you set. Reusable by multiple people. | Launch promotions, influencer campaigns, broad marketing |

**For the referral program, use one-time-use codes.** Each reward earns one unique code.

### 5.3 Setting Up Offer Codes in App Store Connect

This happens in App Store Connect (web), not in code:

1. Go to **Apps → GripTrack → Subscriptions → your subscription group → your subscription**
2. Scroll to **Subscription Prices** → click **+** → **Create Offer Code**
3. Configure the offer:
   - **Reference Name:** `referral-reward-1month` (internal, for your tracking)
   - **Customer Eligibility:** New subscribers + Expired subscribers (both, so referrers and referees can redeem)
   - **Payment Type:** Free
   - **Duration:** 1 month
4. After creating the offer, go to **Offer Codes** tab:
   - Click **Create One-Time Use Codes**
   - Generate a batch (e.g., 500 codes)
   - Download the CSV
5. Store these codes in Firestore (see 5.5 below) so your app/backend can distribute them

**Limits to know:**
- 1 million code redemptions per app per quarter
- One-time-use code batches: 500-25,000 per creation
- Codes expire maximum 6 months from creation
- Users can only redeem one code per offer

### 5.4 Referral Flow — Step by Step

```
1. GENERATE REFERRAL CODE
   - When a user creates an account, generate a unique referral code (e.g., "GRIP-A7X2")
   - Store in Firestore: users/{userId}.referralCode = "GRIP-A7X2"
   - This is YOUR code, not Apple's — it identifies who referred whom

2. SHARE
   - User A taps "Share" in Settings → shares a link like:
     https://griptrack.com/invite/GRIP-A7X2
   - Or simply tells friend the code verbally

3. REFEREE SIGNS UP
   - User B downloads app, creates account
   - During registration (or in Settings), enters referrer's code: "GRIP-A7X2"
   - App writes to Firestore:
     referrals/{referralId}: { referrerUserId, refereeUserId, referrerCode, status: "pending", createdAt }

4. REFEREE GETS REWARD
   - App presents User B with an Apple Offer Code for 1 free month
   - User B redeems it via .offerCodeRedemption modifier
   - StoreKit processes it, user gets 1 month free, then auto-renews at $3.99

5. REFERRER GETS REWARD
   - When referral is confirmed (User B redeems and subscribes):
   - Update Firestore: referrals/{id}.status = "completed"
   - Assign an Apple Offer Code to User A from your stored pool
   - Notify User A (in-app badge/message): "You earned a free month! Redeem it in Settings."
   - User A redeems their offer code

6. TRACK EVERYTHING
   - Firestore records: who referred whom, when, redemption status, codes used
```

### 5.5 Firestore Schema — Referrals

#### In `users/{userId}` document (add fields):

```
{
  // ... existing fields ...
  referralCode: "GRIP-A7X2",           // Unique per user, generated at registration
  referredBy: String | null,            // userId of who referred them
  referralRewardsPending: Number,       // Unredeemed reward count
  referralRewardsRedeemed: Number,      // Total redeemed
  pendingOfferCode: String | null       // Apple offer code waiting to be redeemed
}
```

#### Collection: `referrals/{referralId}`

```
{
  referrerUserId: String,
  referrerCode: String,                 // e.g., "GRIP-A7X2"
  refereeUserId: String,
  refereeEmail: String,
  status: "pending" | "completed" | "expired",
  refereeSubscribed: Boolean,
  refereeOfferCode: String | null,      // Apple offer code given to referee
  referrerOfferCode: String | null,     // Apple offer code earned by referrer
  createdAt: Timestamp,
  completedAt: Timestamp | null
}
```

#### Collection: `offerCodePool/{codeId}`

```
{
  code: "ABCD-EFGH-IJKL",             // The actual Apple offer code
  type: "referral-reward-1month",
  status: "available" | "assigned" | "redeemed",
  assignedToUserId: String | null,
  assignedAt: Timestamp | null,
  batchId: String,                      // Which CSV batch this came from
  expiresAt: Timestamp
}
```

### 5.6 ReferralService.swift

```swift
import Foundation
import FirebaseFirestore

class ReferralService {
    private let db = Firestore.firestore()

    /// Generate a unique referral code for a new user
    func generateReferralCode() -> String {
        let chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"  // No ambiguous chars (0/O, 1/I)
        let code = "GRIP-" + String((0..<4).map { _ in chars.randomElement()! })
        return code
    }

    /// Record that User B was referred by a code
    func recordReferral(refereeUserId: String, referrerCode: String) async throws {
        // Look up who owns this referral code
        let snapshot = try await db.collection("users")
            .whereField("referralCode", isEqualTo: referrerCode)
            .limit(to: 1)
            .getDocuments()

        guard let referrerDoc = snapshot.documents.first else {
            throw ReferralError.invalidCode
        }

        let referrerUserId = referrerDoc.documentID

        // Prevent self-referral
        guard referrerUserId != refereeUserId else {
            throw ReferralError.selfReferral
        }

        // Create referral record
        try await db.collection("referrals").addDocument(data: [
            "referrerUserId": referrerUserId,
            "referrerCode": referrerCode,
            "refereeUserId": refereeUserId,
            "status": "pending",
            "refereeSubscribed": false,
            "createdAt": Timestamp(date: Date())
        ])

        // Mark referee as referred
        try await db.collection("users").document(refereeUserId).setData([
            "referredBy": referrerUserId
        ], merge: true)
    }

    /// When referee subscribes, complete the referral and assign reward
    func completeReferral(refereeUserId: String) async throws {
        let snapshot = try await db.collection("referrals")
            .whereField("refereeUserId", isEqualTo: refereeUserId)
            .whereField("status", isEqualTo: "pending")
            .limit(to: 1)
            .getDocuments()

        guard let referralDoc = snapshot.documents.first else { return }

        let referrerUserId = referralDoc.data()["referrerUserId"] as? String ?? ""

        // Assign an offer code to the referrer from the pool
        let codeSnapshot = try await db.collection("offerCodePool")
            .whereField("status", isEqualTo: "available")
            .limit(to: 1)
            .getDocuments()

        var assignedCode: String? = nil
        if let codeDoc = codeSnapshot.documents.first {
            assignedCode = codeDoc.data()["code"] as? String
            try await codeDoc.reference.updateData([
                "status": "assigned",
                "assignedToUserId": referrerUserId,
                "assignedAt": Timestamp(date: Date())
            ])
        }

        // Update referral status
        try await referralDoc.reference.updateData([
            "status": "completed",
            "refereeSubscribed": true,
            "referrerOfferCode": assignedCode as Any,
            "completedAt": Timestamp(date: Date())
        ])

        // Notify referrer (increment pending rewards)
        try await db.collection("users").document(referrerUserId).updateData([
            "referralRewardsPending": FieldValue.increment(Int64(1)),
            "pendingOfferCode": assignedCode as Any
        ])
    }
}

enum ReferralError: LocalizedError {
    case invalidCode
    case selfReferral

    var errorDescription: String? {
        switch self {
        case .invalidCode: return "That referral code doesn't exist."
        case .selfReferral: return "You can't refer yourself."
        }
    }
}
```

### 5.7 Referral UI in Settings

```swift
Section("Referrals") {
    // Share your code
    HStack {
        Text("Your Code")
        Spacer()
        Text(userProfile.referralCode)
            .font(.system(.body, design: .monospaced))
            .bold()
    }

    ShareLink(
        item: URL(string: "https://griptrack.com/invite/\(userProfile.referralCode)")!,
        subject: Text("Try GripTrack"),
        message: Text("Track your grip strength! Use my code \(userProfile.referralCode) for a free month.")
    ) {
        Label("Share Referral Link", systemImage: "square.and.arrow.up")
    }

    // Enter someone else's code (for referees)
    if userProfile.referredBy == nil {
        Button("Enter Referral Code") {
            showReferralCodeEntry = true
        }
    }

    // Pending rewards
    if userProfile.referralRewardsPending > 0 {
        Button("Redeem Reward (\(userProfile.referralRewardsPending) free month(s))") {
            showOfferCodeRedemption = true
        }
        .offerCodeRedemption(isPresented: $showOfferCodeRedemption)
    }

    // Stats
    Text("Friends referred: \(userProfile.referralRewardsRedeemed + userProfile.referralRewardsPending)")
        .font(.caption)
        .foregroundStyle(.secondary)
}
```

---

## 6. Loading Offer Codes into Firebase

You'll periodically generate offer code batches in App Store Connect and upload them to Firestore. Here's a simple process:

### 6.1 Manual Process (MVP)

1. Generate codes in App Store Connect (batch of 500)
2. Download the CSV
3. Run a simple script or do it manually in Firebase Console to upload codes to the `offerCodePool` collection
4. Each code gets `status: "available"`

### 6.2 Upload Script (run locally, one-time)

```javascript
// upload-offer-codes.js — Run with Node.js
// npm install firebase-admin
const admin = require("firebase-admin");
const fs = require("fs");

admin.initializeApp({
    credential: admin.credential.cert("./serviceAccountKey.json"),
});

const db = admin.firestore();

async function uploadCodes(csvPath, batchId, expiresAt) {
    const csv = fs.readFileSync(csvPath, "utf-8");
    const codes = csv.split("\n").map(line => line.trim()).filter(Boolean);

    // Skip header row if present
    const startIndex = codes[0].toLowerCase().includes("code") ? 1 : 0;

    const batch = db.batch();
    for (let i = startIndex; i < codes.length; i++) {
        const ref = db.collection("offerCodePool").doc();
        batch.set(ref, {
            code: codes[i],
            type: "referral-reward-1month",
            status: "available",
            assignedToUserId: null,
            assignedAt: null,
            batchId: batchId,
            expiresAt: admin.firestore.Timestamp.fromDate(new Date(expiresAt)),
        });

        // Firestore batch limit is 500
        if ((i - startIndex + 1) % 500 === 0) {
            await batch.commit();
        }
    }
    await batch.commit();
    console.log(`Uploaded ${codes.length - startIndex} codes.`);
}

uploadCodes("./offer_codes_batch1.csv", "batch-2026-02", "2026-08-01");
```

---

## 7. StoreKit Testing in Xcode (Local Development)

You can test the entire subscription flow without App Store Connect or a real Apple ID.

### 7.1 Create StoreKit Configuration File

1. In Xcode: **File → New → File → StoreKit Configuration File**
2. Name it `GripTrack.storekit`
3. Add a subscription group: `griptrack_pro`
4. Add subscription **#1**:
   - **Reference Name:** GripTrack Pro Monthly
   - **Product ID:** `com.griptrack.pro.monthly`
   - **Price:** $3.99
   - **Duration:** 1 month
   - **Introductory Offer:** (optional) 7-day free trial
5. Add subscription **#2**:
   - **Reference Name:** GripTrack Pro Yearly
   - **Product ID:** `com.griptrack.pro.yearly`
   - **Price:** $29.99
   - **Duration:** 1 year
   - **Introductory Offer:** (optional) 7-day free trial
6. Set the subscription ranking in the group: **Yearly above Monthly** (Apple considers higher-priced plans as upgrades)
7. Add an offer code:
   - **Reference Name:** `referral-reward-1month`
   - **Payment Type:** Free
   - **Duration:** 1 month

### 7.2 Enable in Scheme

1. **Product → Scheme → Edit Scheme → Run → Options**
2. Set **StoreKit Configuration** to `GripTrack.storekit`

### 7.3 What You Can Test Locally

- Product fetching and display
- Purchase flow (Apple shows a simulated payment sheet)
- Subscription activation and feature unlocking
- Renewal (use Xcode's **Debug → StoreKit → Manage Transactions** to simulate)
- Cancellation and expiration
- Offer code redemption
- Firebase sync of subscription status

### 7.4 Transaction Manager

While running in the simulator or on a device with the StoreKit config:
- **Debug → StoreKit → Manage Transactions** — view, delete, refund, or expire transactions
- This lets you test every subscription lifecycle event without waiting for real time to pass

---

## 8. Implementation Order

Add this to the existing PROJECT_SPEC.md implementation sequence, after Step 10 (Recording Detail) or as a parallel track:

### Step S1: StoreKit Configuration

1. Create `GripTrack.storekit` configuration file
2. Add subscription group and monthly product
3. Enable in scheme
4. **Verify:** StoreKit config loads in Xcode without errors

### Step S2: Subscription Service

1. Create `SubscriptionConstants.swift`, `SubscriptionStatus.swift`, `SubscriptionService.swift`
2. Inject `SubscriptionService` via environment in App entry point
3. Fetch products on app launch
4. **Verify:** Products load and print to console in simulator

### Step S3: Paywall & Purchase Flow

1. Create `PaywallView.swift` using `SubscriptionStoreView`
2. Wire subscription button in SettingsView to present PaywallView
3. Implement `SubscriptionStatusView` in Settings
4. **Verify:** Can open paywall, see product with price, complete simulated purchase, see status change in Settings

### Step S4: Feature Gating & Manual Override

1. Add `AppConfig.bypassSubscription` flag to Constants.swift
2. Add `manualProOverride`, `manualProNote`, `manualProExpiresAt` fields to UserProfile model
3. Fetch `manualProOverride` from Firestore when loading user profile
4. Add the unified `hasProAccess` computed property pattern to relevant ViewModels:
   ```swift
   var hasProAccess: Bool {
       AppConfig.bypassSubscription
       || userProfile.manualProOverride
       || subscriptionService.subscriptionState.isActive
   }
   ```
5. Gate features per the free/pro table in Section 2.2
6. If `manualProExpiresAt` is set and in the past, treat as `manualProOverride = false`
7. **Verify:** With bypass ON, all features available. With bypass OFF + manual override ON, all features available. With both OFF, hitting recording limit shows paywall.

### Step S5: Firebase Sync

1. Create `SubscriptionSyncService.swift`
2. Wire sync into `SubscriptionService.updateSubscriptionStatus()`
3. Add `subscriptionHistory` subcollection logging
4. **Verify:** After simulated purchase, check Firestore Console — subscription data appears on user document

### Step S6: Referral System

1. Create `ReferralService.swift`
2. Generate referral code at user registration
3. Add referral UI to Settings (share code, enter code, redeem reward)
4. Add offer code redemption button with `.offerCodeRedemption` modifier
5. Manually add test offer codes to Firestore `offerCodePool` collection
6. **Verify:** Full referral flow works: share code → friend enters code → friend subscribes → referrer gets reward notification

---

## 9. Cursor Rules Addition

Add this file to `.cursor/rules/subscriptions.mdc`:

```
---
description: StoreKit 2 subscription implementation rules
globs: ["**/Services/Subscription/**/*.swift", "**/ViewModels/SubscriptionViewModel.swift", "**/Views/Subscription/**/*.swift"]
alwaysApply: false
---

# Subscription Rules

## StoreKit 2 Only
- Use StoreKit 2 APIs exclusively (Product, Transaction, etc.)
- Do NOT use StoreKit 1 APIs (SKProduct, SKPaymentQueue, etc.)
- Do NOT use any third-party subscription SDK (RevenueCat, Adapty, etc.)

## Source of Truth
- StoreKit (Transaction.currentEntitlements) is the SOURCE OF TRUTH for subscription status
- Firebase is the ANALYTICS MIRROR — always sync after checking StoreKit, never the reverse
- Never grant Pro access based solely on Firebase data — always verify with StoreKit first

## Bypass Flag
- All feature gating must respect AppConfig.bypassSubscription
- Pattern: `AppConfig.bypassSubscription || subscriptionService.subscriptionState.isActive`
- This flag ships as `true` during product-market fit testing

## Offer Codes
- Use Apple's offer code system for referral rewards — do NOT build custom billing
- Use .offerCodeRedemption SwiftUI modifier for in-app redemption
- Detect offer code usage via transaction.offerType == .code

## Subscription UI
- Always show "Restore Purchases" option on paywall (Apple requires this)
- Use SubscriptionStoreView for MVP paywall (Apple's built-in SwiftUI view)
- Always include links to Privacy Policy and Terms of Service on paywall
- "Manage Subscription" should open Apple's subscription management URL
- Never show subscription price without using product.displayPrice (handles localization)

## Testing
- Use StoreKit Configuration File for all local development
- Use Debug → StoreKit → Manage Transactions to simulate lifecycle events
- Test: purchase, renewal, cancellation, expiration, offer code redemption, restore
```

---

## 10. Pre-Launch Checklist

Before flipping `bypassSubscription` to `false`:

- [ ] Apple Developer Program enrolled
- [ ] Small Business Program enrolled (15% commission)
- [ ] Subscription group created in App Store Connect with both monthly and yearly products
- [ ] Offer codes created for referral program (first batch)
- [ ] Offer codes uploaded to Firestore `offerCodePool`
- [ ] Privacy Policy URL live
- [ ] Terms of Service URL live
- [ ] Paywall tested end-to-end in sandbox (both monthly and yearly purchase)
- [ ] Referral flow tested end-to-end
- [ ] Firebase subscription data verified in Firestore Console
- [ ] **All existing test users have `manualProOverride: true` set in Firestore**
- [ ] `bypassSubscription` flipped to `false`
- [ ] App submitted for review with demo account credentials
- [ ] App Review notes explain subscription features and how to test

---

*Last updated: February 2026*