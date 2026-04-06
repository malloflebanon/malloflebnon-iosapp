import Foundation
import Security

class KeychainManager {
    static let shared = KeychainManager()

    private let service = "com.malloflebanon.ios"
    private let tokenKey = "authToken"
    private let userDefaultsTokenKey = "simulator_auth_token"

    private init() {}

    // Check if running on simulator
    private var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    // MARK: - Save Token
    func saveToken(_ token: String) {
        print("💾 [KeychainManager] Saving token: \(token.prefix(20))...")

        if isSimulator {
            print("📱 [KeychainManager] Running on simulator - using UserDefaults fallback")
            UserDefaults.standard.set(token, forKey: userDefaultsTokenKey)
            print("✅ [KeychainManager] Token saved to UserDefaults successfully!")
            return
        }

        let data = Data(token.utf8)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: tokenKey,
            kSecValueData as String: data
        ]

        // Delete any existing item
        let deleteStatus = SecItemDelete(query as CFDictionary)
        print("🗑️ [KeychainManager] Delete existing token status: \(deleteStatus)")

        // Add new item
        let addStatus = SecItemAdd(query as CFDictionary, nil)
        print("💾 [KeychainManager] Save token status: \(addStatus)")

        if addStatus == errSecSuccess {
            print("✅ [KeychainManager] Token saved successfully!")
        } else {
            print("❌ [KeychainManager] Failed to save token - status: \(addStatus)")
        }
    }

    // MARK: - Get Token
    func getToken() -> String? {
        print("🔍 [KeychainManager] Attempting to retrieve token...")

        if isSimulator {
            print("📱 [KeychainManager] Running on simulator - using UserDefaults fallback")
            let token = UserDefaults.standard.string(forKey: userDefaultsTokenKey)
            if let token = token {
                print("✅ [KeychainManager] Token retrieved from UserDefaults: \(token.prefix(20))...")
                return token
            } else {
                print("❌ [KeychainManager] No token found in UserDefaults")
                return nil
            }
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: tokenKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        print("🔍 [KeychainManager] Keychain query status: \(status)")

        guard status == errSecSuccess,
              let data = item as? Data,
              let token = String(data: data, encoding: .utf8) else {
            print("❌ [KeychainManager] Failed to retrieve token - status: \(status)")
            return nil
        }

        print("✅ [KeychainManager] Token retrieved successfully: \(token.prefix(20))...")
        return token
    }

    // MARK: - Delete Token
    func deleteToken() {
        if isSimulator {
            print("📱 [KeychainManager] Running on simulator - clearing UserDefaults token")
            UserDefaults.standard.removeObject(forKey: userDefaultsTokenKey)
            return
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: tokenKey
        ]

        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Check if Token Exists
    func hasToken() -> Bool {
        return getToken() != nil
    }
}