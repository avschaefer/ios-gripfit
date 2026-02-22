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
    var readinessTimeframe: ReadinessTimeframe = .oneWeek
    var showSignOutConfirmation: Bool = false
    var isLoading: Bool = false
    var errorMessage: String?
    var showError: Bool = false

    private let databaseService = DatabaseService.shared
    private var userId: String = ""

    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.1"
    }

    var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var fullVersion: String {
        appVersion
    }

    // MARK: - Load Profile

    private var hasLoadedOnce = false

    func loadProfile(userId: String, displayName: String?, email: String?) async {
        self.userId = userId
        errorMessage = nil

        // Populate immediately from auth state and UserDefaults (no loading overlay)
        if !hasLoadedOnce {
            self.displayName = displayName ?? ""
            self.email = email ?? ""

            if let unitRaw = UserDefaults.standard.string(forKey: AppConstants.UserDefaultsKeys.preferredUnit),
               let unit = ForceUnit(rawValue: unitRaw) {
                preferredUnit = unit
            }

            if let handRaw = UserDefaults.standard.string(forKey: AppConstants.UserDefaultsKeys.dominantHand),
               let hand = Hand(rawValue: handRaw) {
                dominantHand = hand
            }

            if let tfRaw = UserDefaults.standard.string(forKey: AppConstants.UserDefaultsKeys.readinessTimeframe),
               let tf = ReadinessTimeframe(rawValue: tfRaw) {
                readinessTimeframe = tf
            }

            hasLoadedOnce = true
        }

        // Silently sync with Firestore in background (no loading overlay)
        do {
            if let profile = try await databaseService.fetchUserProfile(userId: userId) {
                self.displayName = profile.displayName
                self.email = profile.email
                self.preferredUnit = profile.preferredUnit
                self.dominantHand = profile.dominantHand
                saveToUserDefaults()
            }
        } catch {
            errorMessage = "Failed to load profile. Using local settings."
            showError = true
            print("Failed to fetch profile: \(error)")
        }
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

    func updateReadinessTimeframe(_ timeframe: ReadinessTimeframe) {
        readinessTimeframe = timeframe
        saveToUserDefaults()
    }

    private func saveToUserDefaults() {
        UserDefaults.standard.set(preferredUnit.rawValue, forKey: AppConstants.UserDefaultsKeys.preferredUnit)
        UserDefaults.standard.set(dominantHand.rawValue, forKey: AppConstants.UserDefaultsKeys.dominantHand)
        UserDefaults.standard.set(readinessTimeframe.rawValue, forKey: AppConstants.UserDefaultsKeys.readinessTimeframe)
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

