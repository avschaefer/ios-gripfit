import SwiftUI
import UIKit

struct RegisterView: View {
    @Environment(AuthViewModel.self) private var authVM
    @Environment(\.dismiss) private var dismiss
    @State private var displayName: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header
                headerSection

                // Form Fields
                formSection

                // Validation Messages
                validationSection

                // Create Account Button
                createAccountButton

                // Link back to login
                backToLoginLink
            }
            .padding(.horizontal, 24)
            .padding(.top, 32)
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
        .navigationTitle("Create Account")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Error", isPresented: Bindable(authVM).showError) {
            Button("OK", role: .cancel) {
                authVM.clearError()
            }
        } message: {
            Text(authVM.errorMessage ?? AppConstants.ErrorMessages.genericError)
        }
    }

    // MARK: - Subviews

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "person.badge.plus")
                .font(.system(size: 50))
                .foregroundStyle(.blue)

            Text("Join \(AppConstants.appName)")
                .font(.title2)
                .fontWeight(.bold)

            Text("Create your account to start tracking")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var formSection: some View {
        VStack(spacing: 16) {
            TextField("Display Name", text: $displayName)
                .textFieldStyle(.roundedBorder)
                .textContentType(.name)
                .autocapitalization(.words)
                .submitLabel(.next)

            TextField("Email", text: $email)
                .textFieldStyle(.roundedBorder)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .autocorrectionDisabled()
                .submitLabel(.next)

            SecureField("Password (min. \(AppConstants.minimumPasswordLength) characters)", text: $password)
                .textFieldStyle(.roundedBorder)
                .textContentType(.newPassword)
                .submitLabel(.next)

            SecureField("Confirm Password", text: $confirmPassword)
                .textFieldStyle(.roundedBorder)
                .textContentType(.newPassword)
                .submitLabel(.done)
                .onSubmit {
                    createAccount()
                }
        }
    }

    private var validationSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !password.isEmpty && password.count < AppConstants.minimumPasswordLength {
                Label("Password must be at least \(AppConstants.minimumPasswordLength) characters", systemImage: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if !confirmPassword.isEmpty && password != confirmPassword {
                Label("Passwords do not match", systemImage: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if !password.isEmpty && password.count >= AppConstants.minimumPasswordLength && !confirmPassword.isEmpty && password == confirmPassword {
                Label("Passwords match", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var createAccountButton: some View {
        Button(action: createAccount) {
            Group {
                if authVM.isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Create Account")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
        }
        .buttonStyle(.borderedProminent)
        .disabled(!isFormValid || authVM.isLoading)
    }

    private var backToLoginLink: some View {
        HStack {
            Text("Already have an account?")
                .foregroundStyle(.secondary)
            Button("Sign In") {
                dismiss()
            }
            .fontWeight(.semibold)
        }
        .font(.subheadline)
    }

    // MARK: - Validation

    private var isFormValid: Bool {
        !displayName.isEmpty &&
        !email.isEmpty &&
        password.count >= AppConstants.minimumPasswordLength &&
        password == confirmPassword
    }

    // MARK: - Actions

    private func createAccount() {
        Task {
            await authVM.register(
                email: email,
                password: password,
                confirmPassword: confirmPassword,
                displayName: displayName
            )
        }
    }
}

#Preview {
    NavigationStack {
        RegisterView()
            .environment(AuthViewModel())
    }
}

