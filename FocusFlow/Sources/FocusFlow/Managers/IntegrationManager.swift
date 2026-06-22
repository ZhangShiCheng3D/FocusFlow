import Foundation
import Combine
import Security

// MARK: - Integration Manager

@MainActor
final class IntegrationManager: ObservableObject {
    static let shared = IntegrationManager()

    @Published var integrationStatuses: [IntegrationType: IntegrationStatus] = [
        .slack: .notConfigured,
        .discord: .notConfigured,
        .teams: .notConfigured
    ]

    // Cloudflare Workers proxy URL
    private let proxyBaseURL = "https://focusflow-proxy.workers.dev"

    private init() {
        loadStoredAuthorizationStates()
    }

    // MARK: - Public API

    func setAllStatuses(_ status: UserFocusStatus) async {
        await withTaskGroup(of: Void.self) { group in
            for type in IntegrationType.allCases {
                guard case .authorized = integrationStatuses[type] else { continue }
                group.addTask { @MainActor in
                    await self.setStatus(for: type, status: status)
                }
            }
        }
    }

    func restoreAllStatuses() async {
        await setAllStatuses(.available)
    }

    func setStatus(for type: IntegrationType, status: UserFocusStatus) async {
        do {
            try await updateStatusViaProxy(type: type, status: status)
        } catch let error as IntegrationStatus.IntegrationError {
            if error.isSilent {
                // Silent failure - don't pop up errors during focus
                integrationStatuses[type] = .failed(reason: error)
                print("[Integration] Silent failure for \(type.rawValue): \(error.description)")
            } else {
                integrationStatuses[type] = .failed(reason: error)
            }
        } catch {
            integrationStatuses[type] = .failed(reason: .unknown)
        }
    }

    // MARK: - Authorization

    func authorize(_ type: IntegrationType) async {
        switch type {
        case .slack:
            await authorizeSlack()
        case .discord:
            await authorizeDiscord()
        case .teams:
            await authorizeTeams()
        }
    }

    func disconnect(_ type: IntegrationType) {
        integrationStatuses[type] = .notConfigured
        // Clear stored token from Keychain
        KeychainManager.shared.delete(key: tokenKey(for: type))
    }

    // MARK: - Individual Authorizations

    private func authorizeSlack() async {
        // Slack PKCE flow via CF Worker
        do {
            let token = try await performOAuthPKCE(
                provider: IntegrationType.slack.providerID,
                authURL: "https://slack.com/oauth/v2/authorize"
            )
            KeychainManager.shared.save(key: tokenKey(for: .slack), value: token)
            integrationStatuses[.slack] = .authorized
        } catch {
            handleAuthError(error, type: .slack)
        }
    }

    private func authorizeDiscord() async {
        do {
            let token = try await performOAuthPKCE(
                provider: IntegrationType.discord.providerID,
                authURL: "https://discord.com/api/oauth2/authorize"
            )
            KeychainManager.shared.save(key: tokenKey(for: .discord), value: token)
            integrationStatuses[.discord] = .authorized
        } catch {
            handleAuthError(error, type: .discord)
        }
    }

    private func authorizeTeams() async {
        do {
            let token = try await performOAuthPKCE(
                provider: IntegrationType.teams.providerID,
                authURL: "https://login.microsoftonline.com/common/oauth2/v2.0/authorize"
            )
            KeychainManager.shared.save(key: tokenKey(for: .teams), value: token)
            integrationStatuses[.teams] = .authorized
        } catch {
            handleAuthError(error, type: .teams)
        }
    }

    // MARK: - URL Helpers

    private func proxyURL(_ path: String) -> URL? {
        return URL(string: "\(proxyBaseURL)/\(path)")
    }

    private func requireProxyURL(_ path: String) throws -> URL {
        guard let url = proxyURL(path) else {
            throw IntegrationStatus.IntegrationError.networkError
        }
        return url
    }

    // MARK: - OAuth Helpers

    private func performOAuthPKCE(provider: String, authURL: String) async throws -> String {
        _ = authURL  // OAuth is intentionally brokered by the proxy; see design doc.
        let url = try requireProxyURL("\(provider)/pkce")
        let request = URLRequest(url: url)
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw IntegrationStatus.IntegrationError.networkError
        }

        if httpResponse.statusCode == 403 {
            throw IntegrationStatus.IntegrationError.adminConsentRequired
        }

        guard httpResponse.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let token = json["access_token"] as? String else {
            throw IntegrationStatus.IntegrationError.unknown
        }

        return token
    }

    private func updateStatusViaProxy(type: IntegrationType, status: UserFocusStatus) async throws {
        let token = KeychainManager.shared.get(key: tokenKey(for: type))
        guard let token = token else {
            throw IntegrationStatus.IntegrationError.tokenExpired
        }

        let url = try requireProxyURL("\(type.providerID)/status")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let statusText = brandedStatusText(for: type, status: status)
        let body: [String: Any] = [
            "status_text": statusText,
            "status_emoji": status.emoji,
            "expiration": status.expiration?.timeIntervalSince1970 ?? NSNull()
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw IntegrationStatus.IntegrationError.networkError
        }

        switch httpResponse.statusCode {
        case 200: return
        case 401, 403:
            throw IntegrationStatus.IntegrationError.tokenExpired
        case 503:
            throw IntegrationStatus.IntegrationError.networkError
        default:
            throw IntegrationStatus.IntegrationError.unknown
        }
    }

    private func handleAuthError(_ error: Error, type: IntegrationType) {
        if let integrationError = error as? IntegrationStatus.IntegrationError {
            integrationStatuses[type] = .failed(reason: integrationError)
        } else {
            integrationStatuses[type] = .failed(reason: .unknown)
        }
    }

    private func loadStoredAuthorizationStates() {
        for type in IntegrationType.allCases {
            if KeychainManager.shared.get(key: tokenKey(for: type)) != nil {
                integrationStatuses[type] = .authorized
            }
        }
    }

    private func tokenKey(for type: IntegrationType) -> String {
        "\(type.providerID)_token"
    }

    private func brandedStatusText(for type: IntegrationType, status: UserFocusStatus) -> String {
        let text = status.statusText
        guard type == .slack,
              PreferencesManager.shared.showSlackBranding,
              !text.isEmpty else {
            return text
        }
        return "\(text) · FocusFlow"
    }
}

// MARK: - User Focus Status

enum UserFocusStatus {
    case available
    case focusing(until: Date)

    var statusText: String {
        switch self {
        case .available:
            return ""
        case .focusing(let until):
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return "🔇 专注中，预计 \(formatter.string(from: until)) 回来"
        }
    }

    var emoji: String {
        switch self {
        case .available: return ""
        case .focusing: return "headphones"
        }
    }

    var expiration: Date? {
        switch self {
        case .available: return nil
        case .focusing(let until): return until
        }
    }
}

// MARK: - Keychain Manager

final class KeychainManager {
    static let shared = KeychainManager()
    private let serviceName = "com.zhulei.focusflow"

    /// Session-scoped fallback for environments where the Keychain is
    /// unavailable (simulator, sandbox edge cases). Deliberately in-memory:
    /// OAuth tokens are never written to disk in plaintext. If the Keychain
    /// is down, tokens simply don't survive an app restart and the user
    /// re-authorizes — a safer tradeoff than a readable plist.
    private var memoryFallback: [String: String] = [:]
    private let fallbackLock = NSLock()

    private func baseQuery(for key: String) -> [CFString: Any] {
        return [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: serviceName,
            kSecAttrAccount: key
        ]
    }

    private func setFallback(_ value: String?, for key: String) {
        fallbackLock.lock()
        defer { fallbackLock.unlock() }
        memoryFallback[key] = value
    }

    private func getFallback(for key: String) -> String? {
        fallbackLock.lock()
        defer { fallbackLock.unlock() }
        return memoryFallback[key]
    }

    func save(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }

        // Delete existing item first
        SecItemDelete(baseQuery(for: key) as CFDictionary)

        // Add new item
        var query = baseQuery(for: key)
        query[kSecValueData] = data
        query[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlock

        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            // Keychain unavailable — keep the token in memory only (not on disk).
            print("[Keychain] SecItemAdd failed (\(status)) — using in-memory fallback for key '\(key)'")
            setFallback(value, for: key)
        } else {
            // Keychain write succeeded — drop any stale in-memory copy.
            setFallback(nil, for: key)
        }
    }

    func get(key: String) -> String? {
        var query = baseQuery(for: key)
        query[kSecReturnData] = true
        query[kSecMatchLimit] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess,
              let data = item as? Data,
              let string = String(data: data, encoding: .utf8) else {
            // Keychain miss — fall back to the in-memory copy, if any.
            return getFallback(for: key)
        }

        // Keychain succeeded — drop any stale in-memory copy.
        setFallback(nil, for: key)
        return string
    }

    func delete(key: String) {
        SecItemDelete(baseQuery(for: key) as CFDictionary)
        setFallback(nil, for: key)
    }
}
