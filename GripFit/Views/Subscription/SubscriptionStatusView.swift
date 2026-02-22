import SwiftUI

struct SubscriptionStatusView: View {
    @Environment(SubscriptionService.self) private var subscriptionService
    @Binding var showPaywall: Bool

    private var state: SubscriptionState {
        subscriptionService.subscriptionState
    }

    var body: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Subscription")
                    .font(.headline)

                if AppConfig.bypassSubscription {
                    betaUnlockedRow
                } else if state.isActive {
                    activeProSection
                } else {
                    freePlanSection
                }
            }
        }
    }

    // MARK: - Beta Unlocked

    private var betaUnlockedRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "gift.fill")
                .font(.title3)
                .foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 2) {
                Text("All features unlocked")
                    .font(.subheadline.weight(.semibold))
                Text("Beta period — enjoy full access")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppConstants.UI.compactCardCornerRadius, style: .continuous)
                .fill(.green.opacity(0.08))
        )
    }

    // MARK: - Active Pro

    private var activeProSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.title3)
                    .foregroundStyle(.green)
                Text("GripFit Pro")
                    .font(.subheadline.weight(.semibold))
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: AppConstants.UI.compactCardCornerRadius, style: .continuous)
                    .fill(.green.opacity(0.08))
            )

            if let exp = state.expirationDate {
                if state.willAutoRenew {
                    Text("Renews \(exp, style: .date)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                } else {
                    Text("Auto-renew is off — expires \(exp, style: .date)")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 12)
                }
            }

            Button {
                if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                    UIApplication.shared.open(url)
                }
            } label: {
                manageRow
            }
            .buttonStyle(.plain)
        }
    }

    private var manageRow: some View {
        HStack {
            Label("Manage Subscription", systemImage: "arrow.up.right.square")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary.opacity(0.9))
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(
            .white.opacity(0.06),
            in: RoundedRectangle(cornerRadius: AppConstants.UI.compactCardCornerRadius, style: .continuous)
        )
    }

    // MARK: - Free Plan

    private var freePlanSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "person.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Text("Free Plan")
                    .font(.subheadline.weight(.semibold))
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: AppConstants.UI.compactCardCornerRadius, style: .continuous)
                    .fill(.white.opacity(0.06))
            )

            Button {
                showPaywall = true
            } label: {
                HStack {
                    Label("Upgrade to Pro", systemImage: "crown.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.yellow)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(
                    .white.opacity(0.06),
                    in: RoundedRectangle(cornerRadius: AppConstants.UI.compactCardCornerRadius, style: .continuous)
                )
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    ZStack {
        ModernScreenBackground()
        SubscriptionStatusView(showPaywall: .constant(false))
            .environment(SubscriptionService())
            .padding()
    }
    .preferredColorScheme(.dark)
}
