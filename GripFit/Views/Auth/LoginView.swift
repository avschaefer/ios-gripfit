import SwiftUI
import UIKit
import AuthenticationServices

struct LoginView: View {
    @Environment(AuthViewModel.self) private var authVM
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var showRegister: Bool = false
    @State private var showForgotPassword: Bool = false
    @State private var forgotPasswordEmail: String = ""
    @State private var appleSignInNonce: String = ""
    @State private var appleSignInDelegate: AppleSignInDelegate?

    var body: some View {
        NavigationStack {
            ZStack {
                ModernScreenBackground()

                VStack(spacing: 22) {
                    Spacer()
                    headerSection
                    formSection
                    signInButton
                    dividerSection
                    appleSignInButton
                    googleSignInButton
                    forgotPasswordLink
                    Spacer()
                    createAccountLink
                }
                .padding(.horizontal, AppConstants.UI.screenHorizontalPadding)
                .padding(.bottom, 16)
            }
            .onTapGesture {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
            .navigationDestination(isPresented: $showRegister) {
                RegisterView()
            }
            .alert("Reset Password", isPresented: $showForgotPassword) {
                TextField("Email", text: $forgotPasswordEmail)
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)
                Button("Send Reset Link") {
                    Task {
                        await authVM.resetPassword(email: forgotPasswordEmail)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Enter your email address and we'll send you a link to reset your password.")
            }
            .alert("Password Reset Sent", isPresented: Bindable(authVM).passwordResetSent) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Check your email for a password reset link.")
            }
            .alert("Error", isPresented: Bindable(authVM).showError) {
                Button("OK", role: .cancel) {
                    authVM.clearError()
                }
            } message: {
                Text(authVM.errorMessage ?? AppConstants.ErrorMessages.genericError)
            }
        }
    }

    // MARK: - Subviews

    private var headerSection: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(.blue.opacity(0.14))
                    .frame(width: 100, height: 100)
                Circle()
                    .stroke(.blue.opacity(0.55), lineWidth: 1.5)
                    .frame(width: 100, height: 100)
                Image("AppLogo")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 90, height: 90)
                    .clipShape(Circle())
                    .blendMode(.lighten)
            }

            Text(AppConstants.appName)
                .font(.largeTitle.weight(.bold))
        }
    }

    private var formSection: some View {
        VStack(spacing: 14) {
            TextField("Email", text: $email)
                .textFieldStyle(.plain)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .autocorrectionDisabled()
                .submitLabel(.next)
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

            SecureField("Password", text: $password)
                .textFieldStyle(.plain)
                .textContentType(.password)
                .submitLabel(.done)
                .onSubmit { signIn() }
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
    }

    private var signInButton: some View {
        Button(action: signIn) {
            Group {
                if authVM.isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Sign In")
                }
            }
        }
        .buttonStyle(ModernPrimaryButtonStyle())
        .disabled(email.isEmpty || password.isEmpty || authVM.isLoading)
    }

    private var dividerSection: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(.white.opacity(0.12))
                .frame(height: 1)
            Text("or")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            Rectangle()
                .fill(.white.opacity(0.12))
                .frame(height: 1)
        }
    }

    private var appleSignInButton: some View {
        Button {
            signInWithApple()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "apple.logo")
                Text("Continue with Apple")
            }
        }
        .buttonStyle(ModernSecondaryButtonStyle())
        .disabled(authVM.isLoading)
    }

    private var googleSignInButton: some View {
        Button(action: signInWithGoogle) {
            HStack(spacing: 10) {
                Image("GoogleLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                Text("Continue with Google")
            }
        }
        .buttonStyle(ModernSecondaryButtonStyle())
        .disabled(authVM.isLoading)
    }

    private var createAccountLink: some View {
        HStack(spacing: 4) {
            Text("Don't have an account?")
                .foregroundStyle(.secondary)
            Button("Sign up") {
                showRegister = true
            }
            .fontWeight(.semibold)
            .foregroundStyle(.blue.opacity(0.85))
        }
        .font(.subheadline)
    }

    private var forgotPasswordLink: some View {
        Button("Forgot Password?") {
            forgotPasswordEmail = email
            showForgotPassword = true
        }
        .font(.subheadline)
        .foregroundStyle(.blue.opacity(0.85))
    }

    // MARK: - Actions

    private func signIn() {
        Task {
            await authVM.signIn(email: email, password: password)
        }
    }

    private func signInWithApple() {
        let nonceResult = authVM.prepareAppleSignIn()
        appleSignInNonce = nonceResult.nonce

        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = nonceResult.hashedNonce

        let delegate = AppleSignInDelegate { authorization in
            Task {
                await authVM.signInWithApple(authorization: authorization, rawNonce: appleSignInNonce)
            }
        }
        appleSignInDelegate = delegate

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = delegate
        controller.performRequests()
    }

    private func signInWithGoogle() {
        guard let rootViewController = currentRootViewController() else {
            authVM.errorMessage = "Unable to present Google Sign-In."
            authVM.showError = true
            return
        }

        Task {
            await authVM.signInWithGoogle(presenting: rootViewController)
        }
    }

    private func currentRootViewController() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?
            .windows
            .first { $0.isKeyWindow }?
            .rootViewController
    }
}

// MARK: - Apple Sign-In Delegate

final class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate {
    private let onSuccess: (ASAuthorization) -> Void

    init(onSuccess: @escaping (ASAuthorization) -> Void) {
        self.onSuccess = onSuccess
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        onSuccess(authorization)
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {}
}

#Preview {
    LoginView()
        .environment(AuthViewModel())
        .preferredColorScheme(.dark)
}
