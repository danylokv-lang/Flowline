import Foundation
import Security
import Combine

// ── User model returned by the API ────────────────────────────────────────

struct AuthUser: Codable {
    let userId: String
    let name: String
    let email: String
    let isPro: Bool
}

// ── Auth errors ────────────────────────────────────────────────────────────

enum AuthError: LocalizedError {
    case invalidCredentials
    case emailTaken
    case networkError
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .invalidCredentials: return "Invalid email or password."
        case .emailTaken:         return "An account with this email already exists."
        case .networkError:       return "No internet connection."
        case .serverError(let m): return m
        }
    }
}

// ── AuthService ────────────────────────────────────────────────────────────

@MainActor
final class AuthService: ObservableObject {

    @Published private(set) var isLoggedIn = false
    @Published private(set) var currentUser: AuthUser?

    private(set) var token: String?

    private let baseURL = "https://claude-proxy.danylokv.workers.dev"
    private let keychainKey = "flowline.jwt"
    private let userKey     = "flowline.user"

    // MARK: - Init

    init() {
        token = loadFromKeychain(keychainKey)
        if let data = UserDefaults.standard.data(forKey: userKey),
           let user = try? JSONDecoder().decode(AuthUser.self, from: data) {
            currentUser = user
            isLoggedIn  = token != nil
        }
    }

    // MARK: - Register

    func register(name: String, email: String, password: String) async throws {
        let body: [String: String] = ["name": name, "email": email, "password": password]
        let (user, jwt) = try await post("/auth/register", body: body)
        persist(user: user, token: jwt)
    }

    // MARK: - Login

    func login(email: String, password: String) async throws {
        let body: [String: String] = ["email": email, "password": password]
        let (user, jwt) = try await post("/auth/login", body: body)
        persist(user: user, token: jwt)
    }

    // MARK: - Delete Account

    /// Best-effort server-side deletion. Does NOT call logout().
    /// Capture token before calling logout(), then pass it here.
    func deleteAccountOnServer(token: String) async {
        guard !token.isEmpty,
              let url = URL(string: baseURL + "/auth/account") else { return }

        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        req.setValue("Bearer \(token)",   forHTTPHeaderField: "Authorization")
        req.setValue(Config.appSecret,    forHTTPHeaderField: "x-app-secret")

        _ = try? await URLSession.shared.data(for: req)
        // Failure is intentionally silent — local session is already cleared by the time
        // this runs. The account row will remain on the server but is unreachable without
        // credentials. Redeploy the worker if the route returns 404.
    }

    // MARK: - Logout

    func logout() {
        token       = nil
        currentUser = nil
        isLoggedIn  = false
        deleteFromKeychain(keychainKey)
        UserDefaults.standard.removeObject(forKey: userKey)
    }

    // MARK: - Helpers

    private func persist(user: AuthUser, token: String) {
        self.token       = token
        self.currentUser = user
        self.isLoggedIn  = true
        saveToKeychain(token, key: keychainKey)
        if let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: userKey)
        }
    }

    private func post(_ path: String, body: [String: String]) async throws -> (AuthUser, String) {
        guard let url = URL(string: baseURL + path) else { throw AuthError.networkError }
        var req = URLRequest(url: url)
        req.httpMethod  = "POST"
        req.httpBody    = try? JSONEncoder().encode(body)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: req)
        } catch {
            throw AuthError.networkError
        }

        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0

        if statusCode == 409 { throw AuthError.emailTaken }
        if statusCode == 401 { throw AuthError.invalidCredentials }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let token = json["token"] as? String else {
            let msg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
            throw AuthError.serverError(msg ?? "Something went wrong")
        }

        let user = AuthUser(
            userId: json["userId"] as? String ?? "",
            name:   json["name"]   as? String ?? "",
            email:  json["email"]  as? String ?? "",
            isPro:  json["isPro"]  as? Bool   ?? false
        )
        return (user, token)
    }

    // MARK: - Keychain

    private func saveToKeychain(_ value: String, key: String) {
        guard let data = value.data(using: .utf8) else { return }
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                 kSecAttrAccount as String: key,
                                 kSecValueData as String: data]
        SecItemDelete(q as CFDictionary)
        SecItemAdd(q as CFDictionary, nil)
    }

    private func loadFromKeychain(_ key: String) -> String? {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                 kSecAttrAccount as String: key,
                                 kSecReturnData as String: true,
                                 kSecMatchLimit as String: kSecMatchLimitOne]
        var result: AnyObject?
        SecItemCopyMatching(q as CFDictionary, &result)
        guard let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func deleteFromKeychain(_ key: String) {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                 kSecAttrAccount as String: key]
        SecItemDelete(q as CFDictionary)
    }
}
