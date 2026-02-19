import SwiftUI

struct SettingsView: View {
    @Environment(AuthViewModel.self) private var authVM
    @State private var settingsVM = SettingsViewModel()

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
                Text("Grip strength insights")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("Profile")
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.white.opacity(0.1), in: Capsule())
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

                Text("Edit")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.white.opacity(0.1), in: Capsule())
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

                aboutRow(icon: "shield", title: "Privacy")
                aboutRow(icon: "doc.text", title: "Terms")
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
}

#Preview {
    SettingsView()
        .environment(AuthViewModel())
        .preferredColorScheme(.dark)
}
