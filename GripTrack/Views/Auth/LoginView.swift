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
            ScrollView {
                VStack(spacing: 32) {
                    // Logo / Header
                    headerSection

                    // Form Fields
                    formSection

                    // Sign In Button
                    signInButton

                    // Links
                    linksSection
                }
                .padding(.horizontal, 24)
                .padding(.top, 60)
            }
            .scrollDismissesKeyboard(.interactively)
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
        VStack(spacing: 12) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 60))
                .foregroundStyle(.blue)

            Text(AppConstants.appName)
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Track your grip strength")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var formSection: some View {
        VStack(spacing: 16) {
            TextField("Email", text: $email)
                .textFieldStyle(.roundedBorder)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .autocorrectionDisabled()
                .submitLabel(.next)

            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)
                .textContentType(.password)
                .submitLabel(.done)
                .onSubmit {
                    signIn()
                }
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
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
        }
        .buttonStyle(.borderedProminent)
        .disabled(email.isEmpty || password.isEmpty || authVM.isLoading)
    }

    private var linksSection: some View {
        VStack(spacing: 16) {
            Button("Forgot Password?") {
                forgotPasswordEmail = email
                showForgotPassword = true
            }
            .font(.subheadline)

            HStack {
                Text("Don't have an account?")
                    .foregroundStyle(.secondary)
                Button("Create Account") {
                    showRegister = true
                }
                .fontWeight(.semibold)
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
}

#Preview {
    LoginView()
        .environment(AuthViewModel())
}

