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
    static let apiKey = Config.apiKey

    // MARK: - Configuration
    /// Token endpoint from the OAuth2 password grant guide
    private let tokenURL = "https://haven.bunepos.com/oauth2/token"

    // Keychain keys
    private let accessTokenKey = "com.buneios.accessToken"
    private let refreshTokenKey = "com.buneios.refreshToken"

    // MARK: - Init
    init() {
        loadStoredTokens()
    }

    // MARK: - Login
    func login(username: String, password: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let tokenResponse = try await requestToken(username: username, password: password)
            accessToken = tokenResponse.accessToken
            refreshToken = tokenResponse.refreshToken
            saveTokens(access: tokenResponse.accessToken, refresh: tokenResponse.refreshToken)
            isAuthenticated = true

            // Parse roles from scope
            let roles = tokenResponse.scope?.components(separatedBy: " ") ?? []
            self.userRoles = roles
            let expiresAt = tokenResponse.expiresIn.map { Date().addingTimeInterval(TimeInterval($0)) }
            self.currentSession = UserSession(accessToken: tokenResponse.accessToken, refreshToken: tokenResponse.refreshToken, roles: roles, expiresAt: expiresAt)
        } catch let error as AuthError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "An unexpected error occurred."
        }

        isLoading = false
    }

    // MARK: - Logout
    func logout() {
        accessToken = nil
        refreshToken = nil
        isAuthenticated = false
        userRoles = []
        currentSession = nil
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
        accessToken = tokenResponse.accessToken
        // Server issues a new refresh token each time; old one is revoked
        refreshToken = tokenResponse.refreshToken ?? currentRefresh
        saveTokens(access: tokenResponse.accessToken, refresh: refreshToken)
    }

    // MARK: - Simple Token Persistence (UserDefaults for now, migrate to Keychain later)
    private let rolesKey = "com.buneios.userRoles"

    private func saveTokens(access: String, refresh: String?) {
        UserDefaults.standard.set(access, forKey: accessTokenKey)
        if let refresh = refresh {
            UserDefaults.standard.set(refresh, forKey: refreshTokenKey)
        }
        // Save roles
        UserDefaults.standard.set(userRoles, forKey: rolesKey)
    }

    private func loadStoredTokens() {
        if let access = UserDefaults.standard.string(forKey: accessTokenKey) {
            accessToken = access
            refreshToken = UserDefaults.standard.string(forKey: refreshTokenKey)
            isAuthenticated = true

            // Load roles
            let storedRoles = UserDefaults.standard.array(forKey: rolesKey) as? [String] ?? []
            userRoles = storedRoles

            // Recreate currentSession from stored data
            let expiresAt: Date? = nil // Expiration is not persisted; would need separate storage
            currentSession = UserSession(accessToken: access, refreshToken: refreshToken, roles: storedRoles, expiresAt: expiresAt)
        }
    }

    private func clearStoredTokens() {
        UserDefaults.standard.removeObject(forKey: accessTokenKey)
        UserDefaults.standard.removeObject(forKey: refreshTokenKey)
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
        request.setValue(Self.apiKey, forHTTPHeaderField: "X-API-Key")
        return request
    }
}
