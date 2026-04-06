import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.presentationMode) var presentationMode

    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var showingForgotPassword = false

    @FocusState private var focusedField: Field?

    enum Field: Hashable {
        case email, password
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)

                        Text("Welcome Back")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("Sign in to your account")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 20)

                    // Form
                    VStack(spacing: 16) {
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
                                .focused($focusedField, equals: .email)
                                .onSubmit {
                                    // Move focus to password field on submit
                                    focusedField = .password
                                }

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
                                    TextField("Enter your password", text: $password)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled()
                                        .focused($focusedField, equals: .password)
                                } else {
                                    SecureField("Enter your password", text: $password)
                                        .focused($focusedField, equals: .password)
                                }

                                Button(action: {
                                    showPassword.toggle()
                                }) {
                                    Image(systemName: showPassword ? "eye.slash" : "eye")
                                        .foregroundColor(.secondary)
                                }
                            }
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .submitLabel(.go)
                            .onSubmit {
                                if isFormValid {
                                    focusedField = nil
                                    login()
                                }
                            }

                            if let passwordError = authManager.validatePassword(password), !password.isEmpty {
                                Text(passwordError)
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }

                        // Forgot Password
                        HStack {
                            Spacer()
                            Button("Forgot Password?") {
                                showingForgotPassword = true
                            }
                            .font(.subheadline)
                            .foregroundColor(.blue)
                        }
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

                    // Sign In Button
                    Button(action: login) {
                        HStack {
                            if authManager.isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .foregroundColor(.white)
                            }
                            Text("Sign In")
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
                .frame(minHeight: geometry.size.height)
            }
            .onTapGesture {
                focusedField = nil
            }
        }
        .navigationTitle("Sign In")
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
            // Automatically focus email field when view appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                focusedField = .email
            }

            // Force software keyboard in simulator
            #if targetEnvironment(simulator)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                focusedField = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    focusedField = .email
                }
            }
            #endif
        }
        .alert("Reset Password", isPresented: $showingForgotPassword) {
            Button("OK") { }
        } message: {
            Text("Password reset feature coming soon. Please contact support if you need help accessing your account.")
        }
    }

    // MARK: - Computed Properties
    private var isFormValid: Bool {
        !email.isEmpty &&
        !password.isEmpty &&
        authManager.validateEmail(email) == nil &&
        authManager.validatePassword(password) == nil
    }

    // MARK: - Actions
    private func login() {
        focusedField = nil
        authManager.login(email: email, password: password)
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
            .environmentObject(AuthenticationManager())
    }
}