import SwiftUI
import MessageUI
import StoreKit

// MARK: - Legal Placeholder Views

struct PrivacyPolicyView: View {
    var body: some View {
        ZStack {
            ModernScreenBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Privacy Policy")
                        .font(.title.weight(.bold))

                    Group {
                        section("Information We Collect",
                            "GripFit collects grip strength measurement data, device connection information, and basic account details (email, display name) to provide and improve our services. We collect data you provide directly when creating an account and data generated automatically through your use of the app, including grip force readings, session timestamps, and device identifiers.")

                        section("How We Use Your Data",
                            "Your data is used to display your grip strength history, track progress over time, and sync your recordings across devices. We do not sell your personal data to third parties. Aggregated, anonymized data may be used to improve the app experience and develop new features.")

                        section("Data Storage & Security",
                            "Your data is stored securely using Google Firebase infrastructure with encryption in transit and at rest. Authentication is handled through Firebase Authentication. We implement industry-standard security measures to protect your information.")

                        section("Data Retention & Deletion",
                            "You may delete your account and associated data at any time through the app settings. Upon account deletion, your personal data and recordings will be permanently removed from our servers within 30 days.")

                        section("Third-Party Services",
                            "GripFit uses Google Firebase for authentication and data storage, and Google Sign-In as an optional authentication method. These services have their own privacy policies that govern their handling of your data.")

                        section("Contact",
                            "If you have questions about this privacy policy, please contact us at support@gripfit.app.")
                    }

                    Text("Last updated: February 2026")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, AppConstants.UI.screenHorizontalPadding)
                .padding(.top, 10)
                .padding(.bottom, 24)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("")
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private func section(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            Text(body)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

struct TermsOfServiceView: View {
    var body: some View {
        ZStack {
            ModernScreenBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Terms of Service")
                        .font(.title.weight(.bold))

                    Group {
                        section("Acceptance of Terms",
                            "By downloading, installing, or using GripFit, you agree to be bound by these Terms of Service. If you do not agree to these terms, do not use the application.")

                        section("Description of Service",
                            "GripFit is a grip strength tracking application that connects to Bluetooth-enabled grip measurement devices. The app records, stores, and displays grip strength data to help users monitor their progress. GripFit is intended for personal fitness tracking and is not a medical device.")

                        section("User Accounts",
                            "You are responsible for maintaining the confidentiality of your account credentials. You agree to provide accurate information when creating your account and to update your information as necessary. You are responsible for all activity that occurs under your account.")

                        section("Acceptable Use",
                            "You agree to use GripFit only for its intended purpose of personal grip strength tracking. You may not attempt to reverse engineer, modify, or interfere with the app's functionality, servers, or connected devices.")

                        section("Medical Disclaimer",
                            "GripFit is not a medical device and should not be used for medical diagnosis or treatment. The data provided is for personal fitness tracking purposes only. Consult a healthcare professional for medical advice regarding grip strength or hand health.")

                        section("Limitation of Liability",
                            "GripFit is provided \"as is\" without warranties of any kind. We are not liable for any damages arising from your use of the application, including but not limited to data loss, device damage, or physical injury.")

                        section("Changes to Terms",
                            "We reserve the right to modify these terms at any time. Continued use of GripFit after changes constitutes acceptance of the updated terms.")
                    }

                    Text("Last updated: February 2026")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, AppConstants.UI.screenHorizontalPadding)
                .padding(.top, 10)
                .padding(.bottom, 24)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("")
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private func section(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            Text(body)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @Environment(AuthViewModel.self) private var authVM
    @Environment(SubscriptionService.self) private var subscriptionService
    @State private var settingsVM = SettingsViewModel()
    @State private var showEditProfile = false
    @State private var editName = ""
    @State private var editEmail = ""
    @State private var showEmailVerificationSent = false
    @State private var showFeedbackSheet = false
    @State private var feedbackMessage = ""
    @State private var showFeedbackSentAlert = false
    @State private var showMailUnavailableAlert = false
    @State private var showPaywall = false
    @State private var showReferralCodeEntry = false
    @State private var referralCodeInput = ""
    @State private var showOfferCodeRedemption = false
    @State private var referralCode: String = ""
    @State private var referralPending: Int = 0
    @State private var referralRedeemed: Int = 0
    @State private var referredBy: String?
    @State private var referralError: String?
    @State private var showReferralError = false
    @State private var showReferralSuccess = false

    var body: some View {
        NavigationStack {
            ZStack {
                ModernScreenBackground()

                ScrollView {
                    VStack(spacing: AppConstants.UI.sectionSpacing) {
                        header
                        profileSection
                        SubscriptionStatusView(showPaywall: $showPaywall)
                        referralSection
                        instructionsSection
                        readinessInfoSection
                        preferencesSection
                        actionsSection
                        aboutSection
                        signOutSection
                    }
                    .padding(.horizontal, AppConstants.UI.screenHorizontalPadding)
                    .padding(.top, 10)
                    .padding(.bottom, 24)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("")
            .toolbarBackground(.hidden, for: .navigationBar)
            .task {
                await settingsVM.loadProfile(
                    userId: authVM.currentUserId ?? "",
                    displayName: authVM.currentUserDisplayName,
                    email: authVM.currentUserEmail
                )
                await loadReferralData()
            }
            .sheet(isPresented: $showEditProfile) {
                editProfileSheet
            }
            .alert("Sign Out", isPresented: $settingsVM.showSignOutConfirmation) {
                Button("Sign Out", role: .destructive) {
                    authVM.signOut()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to sign out?")
            }
            .alert("Error", isPresented: $settingsVM.showError) {
                Button("Retry") {
                    Task {
                        await settingsVM.loadProfile(
                            userId: authVM.currentUserId ?? "",
                            displayName: authVM.currentUserDisplayName,
                            email: authVM.currentUserEmail
                        )
                    }
                }
                Button("OK", role: .cancel) {}
            } message: {
                Text(settingsVM.errorMessage ?? AppConstants.ErrorMessages.genericError)
            }
            .sheet(isPresented: $showFeedbackSheet) {
                feedbackSheet
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .sheet(isPresented: $showReferralCodeEntry) {
                referralCodeEntrySheet
            }
            .offerCodeRedemption(isPresented: $showOfferCodeRedemption)
            .alert("Feedback Sent", isPresented: $showFeedbackSentAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Thank you for your feedback!")
            }
            .alert("Email Unavailable", isPresented: $showMailUnavailableAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Please email us directly at support@gripfit.app")
            }
            .alert("Referral Error", isPresented: $showReferralError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(referralError ?? "Something went wrong.")
            }
            .alert("Referral Applied", isPresented: $showReferralSuccess) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Referral code applied successfully!")
            }
        }
    }

    // MARK: - Sections

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Settings")
                    .font(.title.weight(.bold))
                Text("Manage your profile & preferences")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var profileSection: some View {
        ModernCard {
            HStack(spacing: 12) {
                ProfileInitialsView(
                    name: settingsVM.displayName.isEmpty ? "User" : settingsVM.displayName
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(settingsVM.displayName.isEmpty ? "User" : settingsVM.displayName)
                        .font(.subheadline.weight(.semibold))
                    Text(settingsVM.email)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    editName = settingsVM.displayName
                    editEmail = settingsVM.email
                    showEditProfile = true
                } label: {
                    Text("Edit")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.white.opacity(0.1), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var preferencesSection: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Preferences")
                    .font(.headline)

                HStack(alignment: .top, spacing: 10) {
                    Text("Units")
                        .font(.subheadline.weight(.semibold))
                    Spacer(minLength: 10)
                    Picker("Unit", selection: Binding(
                        get: { settingsVM.preferredUnit },
                        set: { settingsVM.updateUnit($0) }
                    )) {
                        ForEach(ForceUnit.allCases, id: \.self) { unit in
                            Text(unit.displayName).tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 170)
                    .disabled(settingsVM.isLoading)
                }

                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Default Hand")
                            .font(.subheadline.weight(.semibold))
                        Text("Used when starting a new test")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 10)
                    Picker("Dominant Hand", selection: Binding(
                        get: { settingsVM.dominantHand },
                        set: { settingsVM.updateHand($0) }
                    )) {
                        ForEach(Hand.allCases, id: \.self) { hand in
                            Text(hand.displayName).tag(hand)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 130)
                    .disabled(settingsVM.isLoading)
                }

                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Readiness Window")
                            .font(.subheadline.weight(.semibold))
                        Text("Time frame for readiness score")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 10)
                    Picker("Readiness", selection: Binding(
                        get: { settingsVM.readinessTimeframe },
                        set: { settingsVM.updateReadinessTimeframe($0) }
                    )) {
                        ForEach(ReadinessTimeframe.allCases, id: \.self) { tf in
                            Text(tf.displayName).tag(tf)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.white)
                }
            }
        }
    }

    // MARK: - Instructions Card

    private var instructionsSection: some View {
        NavigationLink(destination: InstructionsView()) {
            ModernCard {
                HStack(spacing: 12) {
                    Image(systemName: "book.closed")
                        .font(.title2)
                        .foregroundStyle(.blue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Getting Started")
                            .font(.subheadline.weight(.semibold))
                        Text("Pairing, usage & data tips")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var readinessInfoSection: some View {
        NavigationLink(destination: ReadinessAboutView()) {
            ModernCard {
                HStack(spacing: 12) {
                    Image(systemName: "heart.text.square")
                        .font(.title2)
                        .foregroundStyle(.blue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Grip & Readiness")
                            .font(.subheadline.weight(.semibold))
                        Text("How grip strength impacts readiness")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private var actionsSection: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Actions")
                    .font(.headline)

                Button {
                    showFeedbackSheet = true
                } label: {
                    aboutRow(icon: "envelope", title: "Send Feedback")
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var aboutSection: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("About")
                    .font(.headline)

                NavigationLink(destination: PrivacyPolicyView()) {
                    aboutRow(icon: "shield", title: "Privacy")
                }
                .buttonStyle(.plain)

                NavigationLink(destination: TermsOfServiceView()) {
                    aboutRow(icon: "doc.text", title: "Terms")
                }
                .buttonStyle(.plain)

                versionRow
            }
        }
    }

    private var signOutSection: some View {
        Button(role: .destructive) {
            settingsVM.showSignOutConfirmation = true
        } label: {
            Label("Sign Out", systemImage: AppConstants.Icons.signOut)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.red.opacity(0.9))
        .disabled(settingsVM.isLoading)
    }

    private func aboutRow(icon: String, title: String) -> some View {
        HStack {
            Label(title, systemImage: icon)
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

    private var versionRow: some View {
        HStack {
            Text("Version")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
            Text(settingsVM.fullVersion)
                .font(.subheadline.weight(.semibold))
        }
        .padding(12)
        .background(
            .white.opacity(0.06),
            in: RoundedRectangle(cornerRadius: AppConstants.UI.compactCardCornerRadius, style: .continuous)
        )
    }

    // MARK: - Edit Profile Sheet

    private var editProfileSheet: some View {
        NavigationStack {
            ZStack {
                ModernScreenBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Display Name")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                            TextField("Your name", text: $editName)
                                .textFieldStyle(.plain)
                                .textContentType(.name)
                                .autocapitalization(.words)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: AppConstants.UI.compactCardCornerRadius, style: .continuous)
                                        .fill(.white.opacity(0.07))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppConstants.UI.compactCardCornerRadius, style: .continuous)
                                        .stroke(.white.opacity(0.14), lineWidth: 1)
                                )
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                            TextField("Email address", text: $editEmail)
                                .textFieldStyle(.plain)
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: AppConstants.UI.compactCardCornerRadius, style: .continuous)
                                        .fill(.white.opacity(0.07))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppConstants.UI.compactCardCornerRadius, style: .continuous)
                                        .stroke(.white.opacity(0.14), lineWidth: 1)
                                )
                            if editEmail != settingsVM.email && !editEmail.isEmpty {
                                Text("A verification email will be sent to the new address. Your email will update after you confirm.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Password")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)

                            Button {
                                Task {
                                    await authVM.resetPassword(email: settingsVM.email)
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "envelope")
                                    Text("Send Password Reset Email")
                                }
                            }
                            .buttonStyle(ModernSecondaryButtonStyle())

                            Text("A reset link will be sent to your current email.")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }

                        Button {
                            Task {
                                let nameChanged = editName != settingsVM.displayName
                                let emailChanged = editEmail != settingsVM.email && !editEmail.isEmpty

                                if nameChanged {
                                    await authVM.updateDisplayName(editName)
                                    settingsVM.displayName = editName
                                }

                                if emailChanged {
                                    let sent = await authVM.updateEmail(editEmail)
                                    if sent {
                                        showEmailVerificationSent = true
                                        return
                                    }
                                }

                                showEditProfile = false
                            }
                        } label: {
                            Text("Save Changes")
                        }
                        .buttonStyle(ModernPrimaryButtonStyle())
                        .disabled(editName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    .padding(.horizontal, AppConstants.UI.screenHorizontalPadding)
                    .padding(.top, 20)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showEditProfile = false
                    }
                    .foregroundStyle(.secondary)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .alert("Verification Email Sent", isPresented: $showEmailVerificationSent) {
            Button("OK") {
                showEditProfile = false
            }
        } message: {
            Text("Check \(editEmail) for a verification link. Your email will update once confirmed.")
        }
    }

    // MARK: - Feedback Sheet

    private var feedbackSheet: some View {
        NavigationStack {
            ZStack {
                ModernScreenBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("We'd love to hear from you. Share your thoughts, report a bug, or suggest a feature.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        ZStack(alignment: .topLeading) {
                            if feedbackMessage.isEmpty {
                                Text("Your message...")
                                    .font(.subheadline)
                                    .foregroundStyle(.tertiary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                            }
                            TextEditor(text: $feedbackMessage)
                                .scrollContentBackground(.hidden)
                                .font(.subheadline)
                                .frame(minHeight: 150)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                        }
                        .background(
                            RoundedRectangle(cornerRadius: AppConstants.UI.compactCardCornerRadius, style: .continuous)
                                .fill(.white.opacity(0.07))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: AppConstants.UI.compactCardCornerRadius, style: .continuous)
                                .stroke(.white.opacity(0.14), lineWidth: 1)
                        )

                        Button {
                            sendFeedback()
                        } label: {
                            Text("Send Feedback")
                        }
                        .buttonStyle(ModernPrimaryButtonStyle())
                        .disabled(feedbackMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(.horizontal, AppConstants.UI.screenHorizontalPadding)
                    .padding(.top, 20)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Send Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showFeedbackSheet = false
                    }
                    .foregroundStyle(.secondary)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func sendFeedback() {
        let subject = "GripFit Feedback"
        let body = feedbackMessage
        let email = "support@gripfit.app"
        let encoded = "mailto:\(email)?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&body=\(body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"

        if let url = URL(string: encoded), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
            feedbackMessage = ""
            showFeedbackSheet = false
            showFeedbackSentAlert = true
        } else {
            showFeedbackSheet = false
            showMailUnavailableAlert = true
        }
    }

    // MARK: - Referral Section

    private var referralSection: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Referrals")
                    .font(.headline)

                if !referralCode.isEmpty {
                    HStack {
                        Text("Your Code")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(referralCode)
                            .font(.system(.body, design: .monospaced))
                            .bold()
                    }
                    .padding(12)
                    .background(
                        .white.opacity(0.06),
                        in: RoundedRectangle(cornerRadius: AppConstants.UI.compactCardCornerRadius, style: .continuous)
                    )

                    ShareLink(
                        item: URL(string: "https://gripfit.app/invite/\(referralCode)")!,
                        subject: Text("Try GripFit"),
                        message: Text("Track your grip strength! Use my code \(referralCode) for a free month.")
                    ) {
                        HStack {
                            Label("Share Referral Link", systemImage: "square.and.arrow.up")
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
                    .buttonStyle(.plain)
                }

                if referredBy == nil {
                    Button {
                        referralCodeInput = ""
                        showReferralCodeEntry = true
                    } label: {
                        aboutRow(icon: "person.badge.plus", title: "Enter Referral Code")
                    }
                    .buttonStyle(.plain)
                }

                if referralPending > 0 {
                    Button {
                        showOfferCodeRedemption = true
                    } label: {
                        HStack {
                            Label("Redeem Reward (\(referralPending) free month\(referralPending == 1 ? "" : "s"))", systemImage: "gift.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.green)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(12)
                        .background(
                            .green.opacity(0.08),
                            in: RoundedRectangle(cornerRadius: AppConstants.UI.compactCardCornerRadius, style: .continuous)
                        )
                    }
                    .buttonStyle(.plain)
                }

                let totalReferred = referralPending + referralRedeemed
                if totalReferred > 0 {
                    Text("Friends referred: \(totalReferred)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                }
            }
        }
    }

    // MARK: - Referral Code Entry Sheet

    private var referralCodeEntrySheet: some View {
        NavigationStack {
            ZStack {
                ModernScreenBackground()

                VStack(alignment: .leading, spacing: 16) {
                    Text("Enter the referral code shared by a friend.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    TextField("e.g. GRIP-A7X2", text: $referralCodeInput)
                        .textFieldStyle(.plain)
                        .autocapitalization(.allCharacters)
                        .autocorrectionDisabled()
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: AppConstants.UI.compactCardCornerRadius, style: .continuous)
                                .fill(.white.opacity(0.07))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: AppConstants.UI.compactCardCornerRadius, style: .continuous)
                                .stroke(.white.opacity(0.14), lineWidth: 1)
                        )

                    Button {
                        Task {
                            await submitReferralCode()
                        }
                    } label: {
                        Text("Apply Code")
                    }
                    .buttonStyle(ModernPrimaryButtonStyle())
                    .disabled(referralCodeInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Spacer()
                }
                .padding(.horizontal, AppConstants.UI.screenHorizontalPadding)
                .padding(.top, 20)
            }
            .navigationTitle("Referral Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showReferralCodeEntry = false
                    }
                    .foregroundStyle(.secondary)
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Referral Data

    private func loadReferralData() async {
        guard let userId = authVM.currentUserId else { return }
        let service = ReferralService.shared

        if let code = try? await service.fetchReferralCode(userId: userId) {
            referralCode = code
        } else {
            let newCode = service.generateReferralCode()
            try? await service.saveReferralCode(userId: userId, code: newCode)
            referralCode = newCode
        }

        if let stats = try? await service.fetchReferralStats(userId: userId) {
            referralPending = stats.pending
            referralRedeemed = stats.redeemed
            referredBy = stats.referredBy
        }
    }

    private func submitReferralCode() async {
        guard let userId = authVM.currentUserId else { return }
        let trimmed = referralCodeInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        do {
            try await ReferralService.shared.recordReferral(refereeUserId: userId, referrerCode: trimmed)
            showReferralCodeEntry = false
            showReferralSuccess = true
            await loadReferralData()
        } catch {
            referralError = error.localizedDescription
            showReferralError = true
        }
    }
}

// MARK: - Readiness About View

struct ReadinessAboutView: View {
    var body: some View {
        ZStack {
            ModernScreenBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Grip & Readiness")
                        .font(.title.weight(.bold))

                    topicCard(
                        icon: "hand.raised.fill",
                        title: "Why Grip Strength Matters",
                        body: "Grip strength is one of the most reliable biomarkers of overall health. Research links it to cardiovascular fitness, muscular endurance, and longevity. A stronger grip correlates with lower all-cause mortality risk and better functional independence as you age."
                    )

                    topicCard(
                        icon: "brain.head.profile",
                        title: "Grip & Nervous System Readiness",
                        body: "Your grip force output is governed by the central nervous system. When you're fatigued, under-recovered, or stressed, your peak grip strength drops measurably — often before you feel it. Tracking daily grip force gives you an objective window into neuromuscular readiness."
                    )

                    topicCard(
                        icon: "gauge.with.dots.needle.33percent",
                        title: "How Readiness Is Calculated",
                        body: "Your Readiness score (0–100) combines three factors:\n\n• Performance (50%) — How your recent average compares to your all-time peak.\n• Consistency (40%) — How many days in the selected window you tested.\n• Trend (10%) — Whether today's best exceeds your recent average.\n\nA score above 80 suggests you're well-recovered. Below 40 may indicate accumulated fatigue."
                    )

                    topicCard(
                        icon: "arrow.triangle.2.circlepath",
                        title: "Using Readiness Day-to-Day",
                        body: "Test first thing in the morning before training. Compare your score to your personal baseline over the past week. If readiness is trending down, consider lighter training, more sleep, or a recovery day. A rising trend means your body is adapting well."
                    )

                    topicCard(
                        icon: "scalemass",
                        title: "Strength Balance",
                        body: "A large imbalance between left and right grip strength can indicate asymmetric fatigue, injury risk, or compensation patterns. Aim for less than 10% difference between hands. The Strength Balance card on your dashboard tracks this automatically."
                    )

                    topicCard(
                        icon: "chart.line.uptrend.xyaxis",
                        title: "Long-Term Tracking",
                        body: "Grip strength improves with consistent training. Use the timeline controls on your dashboard chart to observe weekly, monthly, and yearly trends. Small, steady gains in peak force are a strong signal of improving overall fitness."
                    )
                }
                .padding(.horizontal, AppConstants.UI.screenHorizontalPadding)
                .padding(.top, 10)
                .padding(.bottom, 24)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("")
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private func topicCard(icon: String, title: String, body: String) -> some View {
        ModernCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(.blue.opacity(0.14))
                            .frame(width: 36, height: 36)
                        Image(systemName: icon)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.blue)
                    }
                    Text(title)
                        .font(.body.weight(.semibold))
                }
                Text(body)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Instructions View

struct InstructionsView: View {
    var body: some View {
        ZStack {
            ModernScreenBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Getting Started")
                        .font(.title.weight(.bold))

                    instructionCard(
                        step: "1",
                        icon: "antenna.radiowaves.left.and.right",
                        title: "Pair Your Device",
                        body: "Go to the Device tab, tap Scan, and select your GripFit sensor from the list. Make sure Bluetooth is enabled."
                    )

                    instructionCard(
                        step: "2",
                        icon: "hand.raised",
                        title: "Run a Test",
                        body: "Select your hand, tap Start Test, and squeeze as hard as you can. Hold for a few seconds, then release."
                    )

                    instructionCard(
                        step: "3",
                        icon: "chart.line.uptrend.xyaxis",
                        title: "Read Your Data",
                        body: "Your dashboard shows daily bests, averages, and trends over time. The Readiness score reflects your recent performance consistency relative to your peak."
                    )
                }
                .padding(.horizontal, AppConstants.UI.screenHorizontalPadding)
                .padding(.top, 10)
                .padding(.bottom, 24)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("")
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private func instructionCard(step: String, icon: String, title: String, body: String) -> some View {
        ModernCard {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(.blue.opacity(0.14))
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.blue)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Step \(step): \(title)")
                        .font(.subheadline.weight(.semibold))
                    Text(body)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    SettingsView()
        .environment(AuthViewModel())
        .environment(SubscriptionService())
        .preferredColorScheme(.dark)
}
