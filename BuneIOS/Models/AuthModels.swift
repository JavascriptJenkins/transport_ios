//
//  AuthModels.swift
//  BuneIOS
//
//  Created by techvvs001 on 4/2/26.
//

import Foundation

// MARK: - OAuth2 Token Response
// A normal password-grant response carries access + refresh tokens. When the
// user has 2FA enabled the server instead returns `mfa_required: true` with
// an `mfa_token` and no access token — the client must re-submit using the
// mfa_totp grant. Both response shapes decode through this one struct.
struct TokenResponse: Codable {
    let accessToken: String?
    let tokenType: String?
    let expiresIn: Int?
    let refreshToken: String?
    let scope: String?
    let mfaRequired: Bool?
    let mfaToken: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
        case scope
        case mfaRequired = "mfa_required"
        case mfaToken = "mfa_token"
    }

    /// True when the backend returned an MFA challenge instead of real tokens.
    var isMFAChallenge: Bool { (mfaRequired ?? false) && mfaToken != nil }
}

// MARK: - Login Credentials
struct LoginCredentials {
    let username: String
    let password: String
}

// MARK: - Auth Error
enum AuthError: LocalizedError {
    case invalidCredentials
    case networkError(String)
    case serverError(Int)
    case decodingError
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid username or password."
        case .networkError(let message):
            return "Network error: \(message)"
        case .serverError(let code):
            return "Server error (code \(code)). Please try again."
        case .decodingError:
            return "Unexpected response from server."
        case .unknown:
            return "An unknown error occurred."
        }
    }
}

// MARK: - User Session
struct UserSession {
    let accessToken: String
    let refreshToken: String?
    let roles: [String]
    let expiresAt: Date?

    var isDriver: Bool { roles.contains("ROLE_TRANSPORT_DRIVER") || roles.contains("ROLE_DELIVERY_DRIVER") }
    var isClient: Bool { roles.contains("ROLE_TRANSPORT_CLIENT") }
    /// Transportation manager OR any of the adjacent manager roles the backend
    /// grants the same transport-admin capabilities to.
    var isManager: Bool {
        roles.contains("ROLE_TRANSPORTATION_MANAGER") ||
        roles.contains("ROLE_STORE_MANAGER") ||
        roles.contains("ROLE_INVENTORY_MANAGER")
    }
    /// Both regular admin and super admin. The backend's demo-toggle guard
    /// checks `ROLE_ADMIN`, `ROLE_SUPER_ADMIN`, `ROLE_TRANSPORTATION_MANAGER` —
    /// mirrored here so users with ROLE_SUPER_ADMIN don't silently see a
    /// strictly smaller feature set than ROLE_ADMIN users.
    var isAdmin: Bool {
        roles.contains("ROLE_ADMIN") || roles.contains("ROLE_SUPER_ADMIN")
    }
    var isDispatcher: Bool { roles.contains("ROLE_DISPATCH_COORDINATOR") }
    var isFleetManager: Bool { roles.contains("ROLE_VEHICLE_FLEET_MANAGER") }
    var isComplianceOfficer: Bool { roles.contains("ROLE_TRANSPORT_COMPLIANCE_OFFICER") }
    var canScan: Bool { isDriver || isManager || isAdmin }
    var canCreateTransfers: Bool { isManager || isAdmin }
    var canManage: Bool { isManager || isAdmin }
    var canViewAllTransfers: Bool { isManager || isAdmin || isDispatcher || isComplianceOfficer }
}
