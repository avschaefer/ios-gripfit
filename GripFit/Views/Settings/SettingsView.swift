import SwiftUI

struct SettingsView: View {
    @Environment(AuthViewModel.self) private var authVM
    @State private var settingsVM = SettingsViewModel()

    var body: some View {
        NavigationStack {
            List {
                // Profile Section
                profileSection

                // Preferences Section
                preferencesSection

                // About Section
                aboutSection

                // Sign Out Section
                signOutSection
            }
            .navigationTitle(AppConstants.Tabs.settings)
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
                        Color.black.opacity(0.1)
                            .ignoresSafeArea()
                        ProgressView("Loading profile...")
                            .padding(24)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
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

    private var profileSection: some View {
        Section("Profile") {
            HStack {
                Image(systemName: AppConstants.Icons.person)
                    .foregroundStyle(.blue)
                    .frame(width: 30)
                VStack(alignment: .leading) {
                    Text(settingsVM.displayName.isEmpty ? "User" : settingsVM.displayName)
                        .fontWeight(.medium)
                    Text(settingsVM.email)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var preferencesSection: some View {
        Section("Preferences") {
            // Unit Picker
            HStack {
                Image(systemName: "scalemass.fill")
                    .foregroundStyle(.blue)
                    .frame(width: 30)
                Picker("Unit", selection: Binding(
                    get: { settingsVM.preferredUnit },
                    set: { settingsVM.updateUnit($0) }
                )) {
                    ForEach(ForceUnit.allCases, id: \.self) { unit in
                        Text(unit.displayName).tag(unit)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(settingsVM.isLoading)
            }

            // Dominant Hand Picker
            HStack {
                Image(systemName: "hand.raised.fill")
                    .foregroundStyle(.blue)
                    .frame(width: 30)
                Picker("Dominant Hand", selection: Binding(
                    get: { settingsVM.dominantHand },
                    set: { settingsVM.updateHand($0) }
                )) {
                    ForEach(Hand.allCases, id: \.self) { hand in
                        Text(hand.displayName).tag(hand)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(settingsVM.isLoading)
            }
        }
    }

    private var aboutSection: some View {
        Section("About") {
            HStack {
                Text("Version")
                Spacer()
                Text("\(settingsVM.appVersion) (\(settingsVM.buildNumber))")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var signOutSection: some View {
        Section {
            Button(role: .destructive) {
                settingsVM.showSignOutConfirmation = true
            } label: {
                HStack {
                    Image(systemName: AppConstants.Icons.signOut)
                    Text("Sign Out")
                }
            }
            .disabled(settingsVM.isLoading)
        }
    }
}

#Preview {
    SettingsView()
        .environment(AuthViewModel())
}

