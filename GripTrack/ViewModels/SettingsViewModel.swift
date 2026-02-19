import Foundation
import Observation
import SwiftUI

@Observable
@MainActor
final class SettingsViewModel {
    var displayName: String = ""
    var email: String = ""
    var preferredUnit: ForceUnit = .kilograms
    var dominantHand: Hand = .right
    var showSignOutConfirmation: Bool = false
    var isLoading: Bool = false
    var errorMessage: String?
    var showError: Bool = false

    private let databaseService = DatabaseService.shared
    private var userId: String = ""

    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    // MARK: - Load Profile

    func loadProfile(userId: String, displayName: String?, email: String?) async {
        self.userId = userId
        self.displayName = displayName ?? ""
        self.email = email ?? ""
        isLoading = true
        errorMessage = nil

        // Load saved preferences from UserDefaults
        if let unitRaw = UserDefaults.standard.string(forKey: AppConstants.UserDefaultsKeys.preferredUnit),
           let unit = ForceUnit(rawValue: unitRaw) {
            preferredUnit = unit
        }

        if let handRaw = UserDefaults.standard.string(forKey: AppConstants.UserDefaultsKeys.dominantHand),
           let hand = Hand(rawValue: handRaw) {
            dominantHand = hand
        }

        // Try to fetch from Firestore
        do {
            if let profile = try await databaseService.fetchUserProfile(userId: userId) {
                self.displayName = profile.displayName
                self.email = profile.email
                self.preferredUnit = profile.preferredUnit
                self.dominantHand = profile.dominantHand

                // Sync to UserDefaults
                saveToUserDefaults()
            }
        } catch {
            errorMessage = "Failed to load profile. Using local settings."
            showError = true
            print("Failed to fetch profile: \(error)")
        }

        isLoading = false
    }

    // MARK: - Update Preferences

    func updateUnit(_ unit: ForceUnit) {
        preferredUnit = unit
        saveToUserDefaults()
        Task {
            await syncPreferencesToFirestore()
        }
    }

    func updateHand(_ hand: Hand) {
        dominantHand = hand
        saveToUserDefaults()
        Task {
            await syncPreferencesToFirestore()
        }
    }

    private func saveToUserDefaults() {
        UserDefaults.standard.set(preferredUnit.rawValue, forKey: AppConstants.UserDefaultsKeys.preferredUnit)
        UserDefaults.standard.set(dominantHand.rawValue, forKey: AppConstants.UserDefaultsKeys.dominantHand)
    }

    private func syncPreferencesToFirestore() async {
        guard !userId.isEmpty else { return }
        do {
            try await databaseService.updateUserPreferences(
                userId: userId,
                unit: preferredUnit,
                hand: dominantHand
            )
        } catch {
            errorMessage = "Preferences saved locally but failed to sync to cloud."
            showError = true
            print("Failed to sync preferences: \(error)")
        }
    }

    // MARK: - Current Unit Helper

    static func currentUnit() -> ForceUnit {
        if let unitRaw = UserDefaults.standard.string(forKey: AppConstants.UserDefaultsKeys.preferredUnit),
           let unit = ForceUnit(rawValue: unitRaw) {
            return unit
        }
        return .kilograms
    }
}

