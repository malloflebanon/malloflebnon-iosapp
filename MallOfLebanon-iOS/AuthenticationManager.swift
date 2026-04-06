import Foundation
import Combine

class AuthenticationManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var welcomeEmailSent = false
    @Published var showEmailConfirmation = false

    private var cancellables = Set<AnyCancellable>()
    private let apiService = APIService.shared

    init() {
        checkAuthenticationStatus()
    }

    private func checkAuthenticationStatus() {
        // Check if user has valid token and user data
        if let _ = KeychainManager.shared.getToken(),
           let userData = UserDefaults.standard.data(forKey: "currentUser"),
           let user = try? JSONDecoder().decode(User.self, from: userData) {
            self.currentUser = user
            self.isAuthenticated = true
        }
    }

    // MARK: - Login
    func login(email: String, password: String) {
        isLoading = true
        errorMessage = nil

        apiService.login(email: email, password: password)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] response in
                    if response.success {
                        // Check if user is a seller - sellers cannot access customer mobile app
                        if response.user.role == .seller {
                            self?.errorMessage = "Sellers cannot access the customer mobile app. Please use the web admin panel to manage your store."
                            return
                        }

                        // Use token if provided, otherwise use a placeholder or handle session-based auth
                        let authToken = response.token ?? "session_auth"
                        self?.handleSuccessfulAuth(user: response.user, token: authToken)
                    } else {
                        self?.errorMessage = response.message
                    }
                }
            )
            .store(in: &cancellables)
    }

    // MARK: - Register
    func register(
        email: String,
        password: String,
        firstName: String,
        lastName: String,
        role: UserRole = .buyer
    ) {
        isLoading = true
        errorMessage = nil

        apiService.register(
            email: email,
            password: password,
            firstName: firstName,
            lastName: lastName,
            role: role
        )
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                }
            },
            receiveValue: { [weak self] response in
                if response.success {
                    // Check if user is a seller - sellers cannot access customer mobile app
                    if response.user.role == .seller {
                        self?.errorMessage = "Sellers cannot access the customer mobile app. Please use the web admin panel to manage your store."
                        return
                    }

                    // Set welcome email sent flag
                    self?.welcomeEmailSent = true
                    self?.showEmailConfirmation = true

                    // Use token if provided, otherwise use a placeholder or handle session-based auth
                    let authToken = response.token ?? "session_auth"
                    self?.handleSuccessfulAuth(user: response.user, token: authToken)
                } else {
                    self?.errorMessage = response.message
                }
            }
        )
        .store(in: &cancellables)
    }

    // MARK: - Logout
    func logout() {
        isLoading = true

        apiService.logout()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    // Always clear local auth state regardless of API response
                    self?.clearAuthState()
                },
                receiveValue: { [weak self] _ in
                    self?.clearAuthState()
                }
            )
            .store(in: &cancellables)
    }

    // MARK: - Refresh Profile
    func refreshProfile() {
        guard isAuthenticated else { return }

        apiService.getProfile()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(_) = completion {
                        // Token might be expired, logout user
                        self?.clearAuthState()
                    }
                },
                receiveValue: { [weak self] response in
                    if response.success, let user = response.data {
                        self?.currentUser = user
                        self?.saveUserData(user)
                    }
                }
            )
            .store(in: &cancellables)
    }

    // MARK: - Helper Methods
    private func handleSuccessfulAuth(user: User, token: String) {
        print("🎯 [AuthManager] handleSuccessfulAuth called with token: \(token)")
        self.currentUser = user
        self.isAuthenticated = true
        self.errorMessage = nil

        // Save token securely
        print("💾 [AuthManager] About to save token to keychain")
        KeychainManager.shared.saveToken(token)
        print("✅ [AuthManager] Token saved to keychain")

        // Save user data
        saveUserData(user)
        print("🔑 [AuthManager] Authentication state updated - isAuthenticated: \(self.isAuthenticated)")
    }

    private func saveUserData(_ user: User) {
        if let userData = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(userData, forKey: "currentUser")
        }
    }

    private func clearAuthState() {
        self.isAuthenticated = false
        self.currentUser = nil
        self.errorMessage = nil

        // Clear stored data
        KeychainManager.shared.deleteToken()
        UserDefaults.standard.removeObject(forKey: "currentUser")
    }


    // MARK: - Validation
    func validateEmail(_ email: String) -> String? {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format:"SELF MATCHES %@", emailRegex)

        if email.isEmpty {
            return "Email is required"
        } else if !emailPredicate.evaluate(with: email) {
            return "Please enter a valid email address"
        }
        return nil
    }

    func validatePassword(_ password: String) -> String? {
        if password.isEmpty {
            return "Password is required"
        } else if password.count < 6 {
            return "Password must be at least 6 characters"
        }
        return nil
    }

    func validateName(_ name: String, field: String) -> String? {
        if name.isEmpty {
            return "\(field) is required"
        } else if name.count < 2 {
            return "\(field) must be at least 2 characters"
        }
        return nil
    }

    // MARK: - Clear Error
    func clearError() {
        errorMessage = nil
        showEmailConfirmation = false
        welcomeEmailSent = false
    }
}