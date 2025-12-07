import SwiftUI

struct RegisterView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.presentationMode) var presentationMode

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showPassword = false
    @State private var showConfirmPassword = false
    @State private var acceptTerms = false

    enum Field: Hashable {
        case firstName, lastName, email, password, confirmPassword
    }

    var body: some View {
        ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)

                        Text("Create Account")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("Join Mall Of Lebanon community")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 20)

                    // Form
                    VStack(spacing: 16) {
                        // Name Fields
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("First Name")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)

                                TextField("First name", text: $firstName)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .textInputAutocapitalization(.words)
                                    .submitLabel(.next)

                                if let firstNameError = authManager.validateName(firstName, field: "First name"), !firstName.isEmpty {
                                    Text(firstNameError)
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Last Name")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)

                                TextField("Last name", text: $lastName)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .textInputAutocapitalization(.words)
                                    .submitLabel(.next)

                                if let lastNameError = authManager.validateName(lastName, field: "Last name"), !lastName.isEmpty {
                                    Text(lastNameError)
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                            }
                        }

                        // Email Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)

                            TextField("Enter your email", text: $email)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .submitLabel(.next)

                            if let emailError = authManager.validateEmail(email), !email.isEmpty {
                                Text(emailError)
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }

                        // Password Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Password")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)

                            HStack {
                                if showPassword {
                                    TextField("Create a password", text: $password)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled()
                                } else {
                                    SecureField("Create a password", text: $password)
                                }

                                Button(action: {
                                    showPassword.toggle()
                                }) {
                                    Image(systemName: showPassword ? "eye.slash" : "eye")
                                        .foregroundColor(.secondary)
                                }
                            }
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .submitLabel(.next)

                            if let passwordError = authManager.validatePassword(password), !password.isEmpty {
                                Text(passwordError)
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }

                        // Confirm Password Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Confirm Password")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)

                            HStack {
                                if showConfirmPassword {
                                    TextField("Confirm your password", text: $confirmPassword)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled()
                                } else {
                                    SecureField("Confirm your password", text: $confirmPassword)
                                }

                                Button(action: {
                                    showConfirmPassword.toggle()
                                }) {
                                    Image(systemName: showConfirmPassword ? "eye.slash" : "eye")
                                        .foregroundColor(.secondary)
                                }
                            }
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .submitLabel(.go)
                            .onSubmit {
                                if isFormValid {
                                    register()
                                }
                            }

                            if let confirmPasswordError = validateConfirmPassword(), !confirmPassword.isEmpty {
                                Text(confirmPasswordError)
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }

                        // Terms and Conditions
                        HStack(alignment: .top, spacing: 12) {
                            Button(action: {
                                acceptTerms.toggle()
                            }) {
                                Image(systemName: acceptTerms ? "checkmark.square.fill" : "square")
                                    .foregroundColor(acceptTerms ? .blue : .secondary)
                                    .font(.title3)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("I agree to the Terms of Service and Privacy Policy")
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.leading)

                                HStack(spacing: 4) {
                                    Button("Terms of Service") {
                                        // TODO: Show terms
                                    }
                                    .font(.caption)
                                    .foregroundColor(.blue)

                                    Text("and")
                                        .font(.caption)
                                        .foregroundColor(.secondary)

                                    Button("Privacy Policy") {
                                        // TODO: Show privacy policy
                                    }
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                }
                            }

                            Spacer()
                        }
                        .padding(.top, 8)
                    }
                    .padding(.horizontal, 24)

                    // Error Message
                    if let errorMessage = authManager.errorMessage {
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

                    // Create Account Button
                    Button(action: register) {
                        HStack {
                            if authManager.isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .foregroundColor(.white)
                            }
                            Text("Create Account")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(isFormValid ? Color.blue : Color.gray)
                        .cornerRadius(12)
                    }
                    .disabled(!isFormValid || authManager.isLoading)
                    .padding(.horizontal, 24)

                    Spacer()
                }
            }
        .navigationTitle("Create Account")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
        .onChange(of: authManager.isAuthenticated) { isAuthenticated in
            if isAuthenticated {
                presentationMode.wrappedValue.dismiss()
            }
        }
        .onAppear {
            authManager.clearError()
        }
    }

    // MARK: - Computed Properties
    private var isFormValid: Bool {
        !firstName.isEmpty &&
        !lastName.isEmpty &&
        !email.isEmpty &&
        !password.isEmpty &&
        !confirmPassword.isEmpty &&
        acceptTerms &&
        authManager.validateName(firstName, field: "First name") == nil &&
        authManager.validateName(lastName, field: "Last name") == nil &&
        authManager.validateEmail(email) == nil &&
        authManager.validatePassword(password) == nil &&
        validateConfirmPassword() == nil
    }

    // MARK: - Validation
    private func validateConfirmPassword() -> String? {
        if confirmPassword.isEmpty {
            return "Please confirm your password"
        } else if confirmPassword != password {
            return "Passwords do not match"
        }
        return nil
    }

    // MARK: - Actions
    private func register() {
        hideKeyboard()
        authManager.register(
            email: email,
            password: password,
            firstName: firstName,
            lastName: lastName,
            role: .buyer
        )
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

struct RegisterView_Previews: PreviewProvider {
    static var previews: some View {
        RegisterView()
            .environmentObject(AuthenticationManager())
    }
}