import SwiftUI
import UIKit

struct LoginView: View {
    @Environment(AuthViewModel.self) private var authVM
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var showRegister: Bool = false
    @State private var showForgotPassword: Bool = false
    @State private var forgotPasswordEmail: String = ""

    var body: some View {
        NavigationStack {
            ZStack {
                ModernScreenBackground()

                ScrollView {
                    VStack(spacing: 28) {
                        Spacer().frame(height: 20)
                        headerSection
                        formSection
                        signInButton
                        dividerSection
                        googleSignInButton
                        linksSection
                        Spacer().frame(height: 20)
                    }
                    .padding(.horizontal, AppConstants.UI.screenHorizontalPadding)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
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
            Image("AppLogo")
                .resizable()
                .scaledToFill()
                .frame(width: 120, height: 120)
                .clipShape(Circle())

            Text(AppConstants.appName)
                .font(.largeTitle.weight(.bold))

            Text("Track your grip strength")
                .font(.subheadline)
                .foregroundStyle(.secondary)
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

    private var googleSignInButton: some View {
        Button(action: signInWithGoogle) {
            HStack(spacing: 10) {
                Image(systemName: "globe")
                Text("Continue with Google")
            }
        }
        .buttonStyle(ModernSecondaryButtonStyle())
        .disabled(authVM.isLoading)
    }

    private var linksSection: some View {
        VStack(spacing: 16) {
            Button("Forgot Password?") {
                forgotPasswordEmail = email
                showForgotPassword = true
            }
            .font(.subheadline)
            .foregroundStyle(.blue.opacity(0.85))

            HStack(spacing: 4) {
                Text("Don't have an account?")
                    .foregroundStyle(.secondary)
                Button("Create Account") {
                    showRegister = true
                }
                .fontWeight(.semibold)
                .foregroundStyle(.blue.opacity(0.85))
            }
            .font(.subheadline)
        }
    }

    // MARK: - Actions

    private func signIn() {
        Task {
            await authVM.signIn(email: email, password: password)
        }
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

#Preview {
    LoginView()
        .environment(AuthViewModel())
        .preferredColorScheme(.dark)
}
