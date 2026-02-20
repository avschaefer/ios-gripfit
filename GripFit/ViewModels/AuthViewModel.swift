import Foundation
import UIKit
import Observation
import FirebaseAuth

@Observable
@MainActor
final class AuthViewModel {
    var isAuthenticated: Bool = false
    var currentUserId: String?
    var currentUserEmail: String?
    var currentUserDisplayName: String?
    var isLoading: Bool = false
    var errorMessage: String?
    var showError: Bool = false
    var passwordResetSent: Bool = false

    private let authService = AuthService.shared
    private let databaseService = DatabaseService.shared
    private var authStateHandle: AuthStateDidChangeListenerHandle?

    init() {
        listenToAuthState()
    }

    // MARK: - Auth State

    private func listenToAuthState() {
        authStateHandle = authService.addAuthStateListener { [weak self] user in
            Task { @MainActor in
                self?.isAuthenticated = user != nil
                self?.currentUserId = user?.uid
                self?.currentUserEmail = user?.email
                self?.currentUserDisplayName = user?.displayName
            }
        }
    }

    // MARK: - Sign In

    func signIn(email: String, password: String) async {
        guard !email.isEmpty, !password.isEmpty else {
            showErrorMessage(AppConstants.ErrorMessages.emptyFields)
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            try await authService.signIn(email: email, password: password)
        } catch {
            showErrorMessage(error.localizedDescription)
        }

        isLoading = false
    }

    func signInWithGoogle(presenting viewController: UIViewController) async {
        isLoading = true
        errorMessage = nil

        do {
            let userId = try await authService.signInWithGoogle(presenting: viewController)
            try await ensureUserProfileExists(userId: userId)
        } catch {
            showErrorMessage(error.localizedDescription)
        }

        isLoading = false
    }

    // MARK: - Register

    func register(email: String, password: String, confirmPassword: String, displayName: String) async {
        // Validation
        guard !email.isEmpty, !password.isEmpty, !displayName.isEmpty else {
            showErrorMessage(AppConstants.ErrorMessages.emptyFields)
            return
        }

        guard password == confirmPassword else {
            showErrorMessage(AppConstants.ErrorMessages.passwordMismatch)
            return
        }

        guard password.count >= AppConstants.minimumPasswordLength else {
            showErrorMessage(AppConstants.ErrorMessages.passwordTooShort)
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let userId = try await authService.register(
                email: email,
                password: password,
                displayName: displayName
            )

            // Create user profile in Firestore
            let profile = UserProfile(
                userId: userId,
                displayName: displayName,
                email: email
            )
            try await databaseService.createUserProfile(profile)
        } catch {
            showErrorMessage(error.localizedDescription)
        }

        isLoading = false
    }

    // MARK: - Update Profile

    func updateDisplayName(_ name: String) async {
        isLoading = true
        do {
            try await authService.updateDisplayName(name)
            currentUserDisplayName = name
            try await databaseService.updateDisplayName(userId: currentUserId ?? "", name: name)
        } catch {
            showErrorMessage(error.localizedDescription)
        }
        isLoading = false
    }

    // MARK: - Sign Out

    func signOut() {
        do {
            try authService.signOut()
        } catch {
            showErrorMessage(error.localizedDescription)
        }
    }

    // MARK: - Password Reset

    func resetPassword(email: String) async {
        guard !email.isEmpty else {
            showErrorMessage(AppConstants.ErrorMessages.invalidEmail)
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            try await authService.resetPassword(email: email)
            passwordResetSent = true
        } catch {
            showErrorMessage(error.localizedDescription)
        }

        isLoading = false
    }

    // MARK: - Helpers

    private func showErrorMessage(_ message: String) {
        errorMessage = message
        showError = true
    }

    private func ensureUserProfileExists(userId: String) async throws {
        if try await databaseService.fetchUserProfile(userId: userId) != nil {
            return
        }

        let profile = UserProfile(
            userId: userId,
            displayName: currentUserDisplayName ?? "User",
            email: currentUserEmail ?? ""
        )
        try await databaseService.createUserProfile(profile)
    }

    func clearError() {
        errorMessage = nil
        showError = false
    }
}

