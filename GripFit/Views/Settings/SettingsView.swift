import SwiftUI

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
    @State private var settingsVM = SettingsViewModel()
    @State private var showEditProfile = false
    @State private var editName = ""

    var body: some View {
        NavigationStack {
            ZStack {
                ModernScreenBackground()

                ScrollView {
                    VStack(spacing: AppConstants.UI.sectionSpacing) {
                        header
                        profileSection
                        preferencesSection
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
            }
            .overlay {
                if settingsVM.isLoading {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        ProgressView("Loading profile...")
                            .padding(24)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
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
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Units")
                            .font(.subheadline.weight(.semibold))
                        Text("Choose your measurement system")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
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
            Text("\(settingsVM.appVersion) (\(settingsVM.buildNumber))")
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

                        VStack(alignment: .leading, spacing: 14) {
                            Text("Email")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(settingsVM.email)
                                .font(.subheadline)
                                .foregroundStyle(.primary.opacity(0.7))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: AppConstants.UI.compactCardCornerRadius, style: .continuous)
                                        .fill(.white.opacity(0.04))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppConstants.UI.compactCardCornerRadius, style: .continuous)
                                        .stroke(.white.opacity(0.08), lineWidth: 1)
                                )
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

                            Text("A reset link will be sent to your email address.")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }

                        Button {
                            Task {
                                await authVM.updateDisplayName(editName)
                                settingsVM.displayName = editName
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
    }
}

#Preview {
    SettingsView()
        .environment(AuthViewModel())
        .preferredColorScheme(.dark)
}
