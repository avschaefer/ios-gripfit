import Foundation
import UIKit
import FirebaseCore
import FirebaseAuth
import GoogleSignIn
import AuthenticationServices
import CryptoKit

enum AuthError: LocalizedError {
    case invalidEmail
    case wrongPassword
    case emailAlreadyInUse
    case weakPassword
    case userNotFound
    case networkError
    case missingGoogleClientID
    case missingIDToken
    case appleSignInFailed
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .invalidEmail:
            return "Please enter a valid email address."
        case .wrongPassword:
            return "Incorrect password. Please try again."
        case .emailAlreadyInUse:
            return "An account with this email already exists."
        case .weakPassword:
            return "Password is too weak. Please use at least 8 characters."
        case .userNotFound:
            return "No account found with this email."
        case .networkError:
            return "Network error. Please check your connection."
        case .missingGoogleClientID:
            return "Google Sign-In is not configured correctly for this app."
        case .missingIDToken:
            return "Google Sign-In could not retrieve an identity token."
        case .appleSignInFailed:
            return "Apple Sign-In was cancelled or failed."
        case .unknown(let message):
            return message
        }
    }

    static func from(_ error: Error) -> AuthError {
        let nsError = error as NSError
        guard nsError.domain == AuthErrorDomain else {
            return .unknown(error.localizedDescription)
        }

        switch AuthErrorCode(rawValue: nsError.code) {
        case .invalidEmail:
            return .invalidEmail
        case .wrongPassword:
            return .wrongPassword
        case .emailAlreadyInUse:
            return .emailAlreadyInUse
        case .weakPassword:
            return .weakPassword
        case .userNotFound:
            return .userNotFound
        case .networkError:
            return .networkError
        default:
            return .unknown(error.localizedDescription)
        }
    }
}

@MainActor
final class AuthService {
    static let shared = AuthService()

    private init() {}

    var currentUser: User? {
        Auth.auth().currentUser
    }

    var currentUserId: String? {
        Auth.auth().currentUser?.uid
    }

    var isAuthenticated: Bool {
        currentUser != nil
    }

    func signIn(email: String, password: String) async throws {
        do {
            try await Auth.auth().signIn(withEmail: email, password: password)
        } catch {
            throw AuthError.from(error)
        }
    }

    func register(email: String, password: String, displayName: String) async throws -> String {
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)

            // Update display name
            let changeRequest = result.user.createProfileChangeRequest()
            changeRequest.displayName = displayName
            try await changeRequest.commitChanges()

            return result.user.uid
        } catch {
            throw AuthError.from(error)
        }
    }

    func signInWithGoogle(presenting viewController: UIViewController) async throws -> String {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw AuthError.missingGoogleClientID
        }

        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        let result: GIDSignInResult
        do {
            result = try await GIDSignIn.sharedInstance.signIn(withPresenting: viewController)
        } catch {
            throw AuthError.unknown("Google Sign-In was cancelled or failed.")
        }

        guard let idToken = result.user.idToken?.tokenString else {
            throw AuthError.missingIDToken
        }

        let accessToken = result.user.accessToken.tokenString
        let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)

        do {
            let authResult = try await Auth.auth().signIn(with: credential)
            return authResult.user.uid
        } catch {
            throw AuthError.from(error)
        }
    }

    // MARK: - Apple Sign-In

    private var currentNonce: String?

    func startAppleSignIn() -> (nonce: String, hashedNonce: String) {
        let nonce = randomNonceString()
        currentNonce = nonce
        return (nonce, sha256(nonce))
    }

    func signInWithApple(idToken: String, rawNonce: String, fullName: PersonNameComponents?) async throws -> String {
        let credential = OAuthProvider.appleCredential(
            withIDToken: idToken,
            rawNonce: rawNonce,
            fullName: fullName
        )

        do {
            let authResult = try await Auth.auth().signIn(with: credential)

            if let name = fullName, authResult.additionalUserInfo?.isNewUser == true {
                let displayName = [name.givenName, name.familyName].compactMap { $0 }.joined(separator: " ")
                if !displayName.isEmpty {
                    let changeRequest = authResult.user.createProfileChangeRequest()
                    changeRequest.displayName = displayName
                    try? await changeRequest.commitChanges()
                }
            }

            return authResult.user.uid
        } catch {
            throw AuthError.from(error)
        }
    }

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        guard errorCode == errSecSuccess else {
            fatalError("Unable to generate nonce: \(errorCode)")
        }
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }

    func signOut() throws {
        do {
            GIDSignIn.sharedInstance.signOut()
            try Auth.auth().signOut()
        } catch {
            throw AuthError.unknown("Failed to sign out: \(error.localizedDescription)")
        }
    }

    func updateDisplayName(_ name: String) async throws {
        guard let user = Auth.auth().currentUser else { return }
        let changeRequest = user.createProfileChangeRequest()
        changeRequest.displayName = name
        do {
            try await changeRequest.commitChanges()
        } catch {
            throw AuthError.from(error)
        }
    }

    func updateEmail(_ newEmail: String) async throws {
        guard let user = Auth.auth().currentUser else { return }
        do {
            try await user.sendEmailVerification(beforeUpdatingEmail: newEmail)
        } catch {
            throw AuthError.from(error)
        }
    }

    func resetPassword(email: String) async throws {
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
        } catch {
            throw AuthError.from(error)
        }
    }

    func addAuthStateListener(_ handler: @escaping (User?) -> Void) -> AuthStateDidChangeListenerHandle {
        return Auth.auth().addStateDidChangeListener { _, user in
            handler(user)
        }
    }

    func removeAuthStateListener(_ handle: AuthStateDidChangeListenerHandle) {
        Auth.auth().removeStateDidChangeListener(handle)
    }
}

