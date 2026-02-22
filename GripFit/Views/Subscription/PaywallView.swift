import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        SubscriptionStoreView(groupID: SubscriptionConstants.subscriptionGroupID) {
            VStack(spacing: 16) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.yellow)

                Text("GripFit Pro")
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
            url: URL(string: "https://gripfit.app/privacy")!,
            for: .privacyPolicy
        )
        .subscriptionStorePolicyDestination(
            url: URL(string: "https://gripfit.app/terms")!,
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

#Preview {
    PaywallView()
}
