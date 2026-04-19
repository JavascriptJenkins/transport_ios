//
//  AuthService.swift
//  BuneIOS
//
//  Created by techvvs001 on 4/2/26.
//

import Foundation
import SwiftUI

// MARK: - Auth Service
@MainActor
class AuthService: ObservableObject {

    // MARK: - Published State
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?

    // MARK: - Token Storage
    @Published private(set) var accessToken: String?
    private var refreshToken: String?

    // MARK: - Session & Role Management
    @Published var currentSession: UserSession?
    @Published private(set) var userRoles: [String] = []

    // MARK: - Tenant Selection
    /// Active tenant for this session. When nil in multi-tenant mode, LoginView
    /// shows the tenant picker before the credentials form.
    @Published var selectedTenant: Tenant?

    /// Full list of configured tenants from Config.xcconfig.
    var availableTenants: [Tenant] { Config.tenants }

    /// True when Config.xcconfig declares one or more tenants.
    var isMultiTenant: Bool { !Config.tenants.isEmpty }

    /// API key to send with transport requests — tenant-specific when selected,
    /// otherwise falls back to the legacy single-tenant key.
    var apiKey: String { selectedTenant?.apiKey ?? Config.apiKey }

    /// Token endpoint for the active tenant, or the legacy fallback.
    private var tokenURL: String { selectedTenant?.tokenURL ?? Config.tokenURL }

    // MARK: - 2FA
    /// Set when the server responds to a password grant with `mfa_required`.
    /// LoginView watches this to show the TOTP code-entry sheet; value is the
    /// short-lived mfa_token we must echo back with the code.
    @Published var pendingMFAToken: String?

    // Storage keys
    private let accessTokenKey = "com.buneios.accessToken"
    private let refreshTokenKey = "com.buneios.refreshToken"
    private let selectedTenantKey = "com.buneios.selectedTenant"

    // MARK: - Init
    init() {
        loadStoredTenant()
        // In multi-tenant mode, don't resurrect tokens when no tenant is selected —
        // they'd be orphans pointing at a tenant the user can no longer reach
        // (e.g. the tenant was removed from TRANSPORT_TENANTS in a newer build).
        // Clearing them forces the user through the tenant picker + login again.
        if isMultiTenant && selectedTenant == nil {
            clearStoredTokens()
        } else {
            loadStoredTokens()
        }
    }

    // MARK: - Tenant Management
    func selectTenant(_ tenant: Tenant) {
        selectedTenant = tenant
        UserDefaults.standard.set(tenant.id, forKey: selectedTenantKey)
    }

    /// Clear tenant selection (used when user wants to switch tenants).
    /// Also clears credentials since they were scoped to the old tenant.
    func clearTenantAndLogout() {
        UserDefaults.standard.removeObject(forKey: selectedTenantKey)
        selectedTenant = nil
        logout()
    }

    private func loadStoredTenant() {
        if let id = UserDefaults.standard.string(forKey: selectedTenantKey) {
            selectedTenant = Config.tenant(matching: id)
        }
    }

    // MARK: - Login
    func login(username: String, password: String) async {
        // In multi-tenant mode, login requires a tenant. The UI gates this,
        // but guard here too so we never accidentally hit the legacy fallback.
        if isMultiTenant && selectedTenant == nil {
            errorMessage = "Select a tenant before signing in."
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let tokenResponse = try await requestToken(username: username, password: password)

            // If the server issued an MFA challenge, stash the mfa_token and
            // let the UI collect the TOTP code. No session is authenticated
            // yet — isAuthenticated stays false. This is also a definitive
            // signal that the user has 2FA on, so record it locally.
            if tokenResponse.isMFAChallenge, let mfaToken = tokenResponse.mfaToken {
                pendingMFAToken = mfaToken
                setTOTPEnabled(true)
                isLoading = false
                return
            }

            try applyGrantedTokens(tokenResponse)
        } catch let error as AuthError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "An unexpected error occurred."
        }

        isLoading = false
    }

    /// Submit the 6-digit TOTP code the user received via email to complete a
    /// login that was gated by 2FA. Consumes the pendingMFAToken.
    func submitTOTPCode(_ code: String) async {
        guard let mfaToken = pendingMFAToken else {
            errorMessage = "No 2FA challenge pending."
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            let response = try await requestTOTPToken(mfaToken: mfaToken, code: code)
            try applyGrantedTokens(response)
            pendingMFAToken = nil
        } catch let error as AuthError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "Could not verify code. Try again."
        }
        isLoading = false
    }

    /// Cancel a pending MFA challenge (user tapped "back"). Wipes the
    /// short-lived mfa_token so it isn't reused.
    func cancelMFAChallenge() {
        pendingMFAToken = nil
        errorMessage = nil
    }

    /// Apply a token response that carries access + refresh tokens.
    /// Throws if the response unexpectedly lacks an access token.
    private func applyGrantedTokens(_ response: TokenResponse) throws {
        guard let access = response.accessToken else {
            throw AuthError.decodingError
        }
        accessToken = access
        refreshToken = response.refreshToken
        saveTokens(access: access, refresh: response.refreshToken)
        isAuthenticated = true

        let roles = response.scope?.components(separatedBy: " ") ?? []
        self.userRoles = roles
        let expiresAt = response.expiresIn.map { Date().addingTimeInterval(TimeInterval($0)) }
        self.currentSession = UserSession(
            accessToken: access,
            refreshToken: response.refreshToken,
            roles: roles,
            expiresAt: expiresAt
        )
    }

    // MARK: - Logout
    func logout() {
        accessToken = nil
        refreshToken = nil
        isAuthenticated = false
        userRoles = []
        currentSession = nil
        pendingMFAToken = nil
        clearStoredTokens()
    }

    // MARK: - Token Request
    private func requestToken(username: String, password: String) async throws -> TokenResponse {
        guard let url = URL(string: tokenURL) else {
            throw AuthError.networkError("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        // Form-encode the body per the OAuth2 password grant spec
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "grant_type", value: "password"),
            URLQueryItem(name: "username", value: username),
            URLQueryItem(name: "password", value: password)
        ]
        request.httpBody = components.query?.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.unknown
        }

        switch httpResponse.statusCode {
        case 200...299:
            let decoder = JSONDecoder()
            guard let tokenResponse = try? decoder.decode(TokenResponse.self, from: data) else {
                throw AuthError.decodingError
            }
            return tokenResponse
        case 400:
            // The server returns 400 for invalid_grant (wrong credentials)
            throw AuthError.invalidCredentials
        case 401:
            throw AuthError.invalidCredentials
        default:
            throw AuthError.serverError(httpResponse.statusCode)
        }
    }

    // MARK: - TOTP Token Request
    /// Exchange an mfa_token + TOTP code for a full access/refresh token pair.
    private func requestTOTPToken(mfaToken: String, code: String) async throws -> TokenResponse {
        guard let url = URL(string: tokenURL) else {
            throw AuthError.networkError("Invalid URL")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "grant_type", value: "mfa_totp"),
            URLQueryItem(name: "mfa_token", value: mfaToken),
            URLQueryItem(name: "totp_code", value: code.trimmingCharacters(in: .whitespaces))
        ]
        request.httpBody = components.query?.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AuthError.unknown }

        switch http.statusCode {
        case 200...299:
            guard let token = try? JSONDecoder().decode(TokenResponse.self, from: data) else {
                throw AuthError.decodingError
            }
            return token
        case 400, 401:
            throw AuthError.invalidCredentials
        default:
            throw AuthError.serverError(http.statusCode)
        }
    }

    // MARK: - TOTP Enrollment / Management
    //
    // Backend:
    //   POST /oauth2/totp/setup            — authenticated; emails first code
    //   POST /oauth2/totp/verify-setup     — authenticated; activates 2FA with code
    //   POST /oauth2/totp/disable          — authenticated; turns off with current code
    //
    // We also maintain a local `isTOTPEnabled` flag so the Settings screen
    // can render the right action without an extra "get status" endpoint.
    // This flag is best-effort: it flips to true after a successful
    // verify-setup, false after disable, and is also set true opportunistically
    // whenever the server challenges the current user with MFA at login.

    private let totpEnabledKey = "com.buneios.totpEnabled"

    /// Best-effort local record of whether the user has 2FA enabled.
    /// Prefer reading via `isTOTPEnabled` on the main actor.
    @Published var isTOTPEnabled: Bool = UserDefaults.standard.bool(forKey: "com.buneios.totpEnabled")

    /// Trigger enrollment. Backend emails a verification code to the user's
    /// address. Call `completeTOTPSetup(code:)` next with the value.
    func beginTOTPSetup() async throws {
        struct SetupResponse: Decodable {
            let enrolled: Bool?
            let message: String?
            let error: String?
        }
        let response: SetupResponse = try await authedPost(
            path: "/oauth2/totp/setup",
            formBody: [:]
        )
        if response.enrolled != true, let err = response.error {
            throw APIError.serverError(err)
        }
    }

    /// Confirm enrollment with the emailed code. On success 2FA is active.
    func completeTOTPSetup(code: String) async throws {
        struct VerifyResponse: Decodable {
            let enabled: Bool?
            let message: String?
            let error: String?
        }
        let response: VerifyResponse = try await authedPost(
            path: "/oauth2/totp/verify-setup",
            formBody: ["totp_code": code.trimmingCharacters(in: .whitespaces)]
        )
        if response.enabled == true {
            setTOTPEnabled(true)
        } else {
            throw APIError.serverError(response.error ?? "Verification failed")
        }
    }

    /// Turn 2FA off. Requires a currently valid TOTP code.
    func disableTOTP(code: String) async throws {
        struct DisableResponse: Decodable {
            let disabled: Bool?
            let message: String?
            let error: String?
        }
        let response: DisableResponse = try await authedPost(
            path: "/oauth2/totp/disable",
            formBody: ["totp_code": code.trimmingCharacters(in: .whitespaces)]
        )
        if response.disabled == true {
            setTOTPEnabled(false)
        } else {
            throw APIError.serverError(response.error ?? "Failed to disable 2FA")
        }
    }

    /// Mark the local 2FA flag (persists through relaunches).
    func setTOTPEnabled(_ enabled: Bool) {
        isTOTPEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: totpEnabledKey)
    }

    /// Shared helper for form-encoded POSTs to the auth endpoints. The OAuth2
    /// controller consumes application/x-www-form-urlencoded for everything
    /// except /totp/setup (no body); it tolerates an empty form body too.
    private func authedPost<T: Decodable>(path: String, formBody: [String: String]) async throws -> T {
        // Auth endpoints live on the same host as the tenant base URL; tokenURL
        // already accounts for multi-tenant selection.
        let baseURL = selectedTenant?.baseURL ?? Config.transportBaseURL
        guard let url = URL(string: baseURL + path) else {
            throw AuthError.networkError("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        var components = URLComponents()
        components.queryItems = formBody.map { URLQueryItem(name: $0.key, value: $0.value) }
        request.httpBody = components.query?.data(using: .utf8) ?? Data()

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AuthError.unknown }
        guard (200...299).contains(http.statusCode) else {
            // The backend returns 400 with { error, error_description } for
            // validation failures — try to surface that message.
            if let env = try? JSONDecoder().decode(AuthErrorEnvelope.self, from: data) {
                throw APIError.serverError(env.error_description ?? env.error ?? "HTTP \(http.statusCode)")
            }
            throw APIError.serverError("HTTP \(http.statusCode)")
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    /// File-scope helper — Swift can't nest Decodable structs inside generic
    /// functions, so we lift it out but keep it private to the service.
    private struct AuthErrorEnvelope: Decodable {
        let error: String?
        let error_description: String?
    }

    // MARK: - Token Refresh
    func refreshAccessToken() async throws {
        guard let currentRefresh = refreshToken else {
            logout()
            return
        }

        guard let url = URL(string: tokenURL) else {
            throw AuthError.networkError("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "grant_type", value: "refresh_token"),
            URLQueryItem(name: "refresh_token", value: currentRefresh)
        ]
        request.httpBody = components.query?.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            logout()
            return
        }

        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        guard let newAccess = tokenResponse.accessToken else {
            // Refresh endpoint should never return an MFA challenge, but
            // defend against a malformed response.
            logout()
            return
        }
        accessToken = newAccess
        // Server issues a new refresh token each time; old one is revoked
        refreshToken = tokenResponse.refreshToken ?? currentRefresh
        saveTokens(access: newAccess, refresh: refreshToken)
    }

    // MARK: - Token Persistence
    // Access + refresh tokens live in the Keychain (sensitive credentials).
    // Roles are non-sensitive descriptive data and stay in UserDefaults.
    private let rolesKey = "com.buneios.userRoles"

    private func saveTokens(access: String, refresh: String?) {
        KeychainStore.set(access, for: accessTokenKey)
        KeychainStore.set(refresh, for: refreshTokenKey)
        UserDefaults.standard.set(userRoles, forKey: rolesKey)
    }

    private func loadStoredTokens() {
        // One-time migration: if legacy UserDefaults tokens exist, move them
        // to the Keychain then clear the plaintext copy.
        if let legacyAccess = UserDefaults.standard.string(forKey: accessTokenKey) {
            let legacyRefresh = UserDefaults.standard.string(forKey: refreshTokenKey)
            KeychainStore.set(legacyAccess, for: accessTokenKey)
            KeychainStore.set(legacyRefresh, for: refreshTokenKey)
            UserDefaults.standard.removeObject(forKey: accessTokenKey)
            UserDefaults.standard.removeObject(forKey: refreshTokenKey)
        }

        guard let access = KeychainStore.get(accessTokenKey) else { return }
        accessToken = access
        refreshToken = KeychainStore.get(refreshTokenKey)
        isAuthenticated = true

        let storedRoles = UserDefaults.standard.array(forKey: rolesKey) as? [String] ?? []
        userRoles = storedRoles

        // Expiration is not persisted; refreshAccessToken() handles 401s.
        currentSession = UserSession(
            accessToken: access,
            refreshToken: refreshToken,
            roles: storedRoles,
            expiresAt: nil
        )
    }

    private func clearStoredTokens() {
        KeychainStore.delete(account: accessTokenKey)
        KeychainStore.delete(account: refreshTokenKey)
        UserDefaults.standard.removeObject(forKey: rolesKey)
    }

    // MARK: - Convenience Role Properties
    var isDriver: Bool { currentSession?.isDriver ?? false }
    var isClient: Bool { currentSession?.isClient ?? false }
    var isManager: Bool { currentSession?.isManager ?? false }
    var isAdmin: Bool { currentSession?.isAdmin ?? false }
    var canScan: Bool { currentSession?.canScan ?? false }
    var canCreateTransfers: Bool { currentSession?.canCreateTransfers ?? false }
    var canManage: Bool { currentSession?.canManage ?? false }

    // MARK: - Authorized Request Helpers
    func authorizedRequest(for url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    func authorizedTransportRequest(for url: URL) -> URLRequest {
        var request = authorizedRequest(for: url)
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        return request
    }
}
