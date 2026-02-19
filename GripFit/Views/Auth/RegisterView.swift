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
        ZStack {
            ModernScreenBackground()

            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    formSection
                    validationSection
                    createAccountButton
                    backToLoginLink
                    Spacer().frame(height: 20)
                }
                .padding(.horizontal, AppConstants.UI.screenHorizontalPadding)
                .padding(.top, 20)
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
        .navigationTitle("Create Account")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
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
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(.blue.opacity(0.14))
                    .frame(width: 72, height: 72)
                Circle()
                    .stroke(.blue.opacity(0.4), lineWidth: 1.5)
                    .frame(width: 72, height: 72)
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 28))
                    .foregroundStyle(.white)
            }

            Text("Join \(AppConstants.appName)")
                .font(.title2.weight(.bold))

            Text("Create your account to start tracking")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var formSection: some View {
        VStack(spacing: 14) {
            darkField {
                TextField("Display Name", text: $displayName)
                    .textFieldStyle(.plain)
                    .textContentType(.name)
                    .autocapitalization(.words)
                    .submitLabel(.next)
            }

            darkField {
                TextField("Email", text: $email)
                    .textFieldStyle(.plain)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .submitLabel(.next)
            }

            darkField {
                SecureField("Password (min. \(AppConstants.minimumPasswordLength) chars)", text: $password)
                    .textFieldStyle(.plain)
                    .textContentType(.newPassword)
                    .submitLabel(.next)
            }

            darkField {
                SecureField("Confirm Password", text: $confirmPassword)
                    .textFieldStyle(.plain)
                    .textContentType(.newPassword)
                    .submitLabel(.done)
                    .onSubmit { createAccount() }
            }
        }
    }

    private func darkField<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
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

    private var validationSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !password.isEmpty && password.count < AppConstants.minimumPasswordLength {
                Label("Password must be at least \(AppConstants.minimumPasswordLength) characters", systemImage: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.red.opacity(0.85))
            }

            if !confirmPassword.isEmpty && password != confirmPassword {
                Label("Passwords do not match", systemImage: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.red.opacity(0.85))
            }

            if !password.isEmpty && password.count >= AppConstants.minimumPasswordLength && !confirmPassword.isEmpty && password == confirmPassword {
                Label("Passwords match", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green.opacity(0.85))
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
                }
            }
        }
        .buttonStyle(ModernPrimaryButtonStyle())
        .disabled(!isFormValid || authVM.isLoading)
    }

    private var backToLoginLink: some View {
        HStack(spacing: 4) {
            Text("Already have an account?")
                .foregroundStyle(.secondary)
            Button("Sign In") {
                dismiss()
            }
            .fontWeight(.semibold)
            .foregroundStyle(.blue.opacity(0.85))
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
            .preferredColorScheme(.dark)
    }
}
