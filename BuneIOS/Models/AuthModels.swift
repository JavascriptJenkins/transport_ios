//
//  AuthModels.swift
//  BuneIOS
//
//  Created by techvvs001 on 4/2/26.
//

import Foundation

// MARK: - OAuth2 Token Response
struct TokenResponse: Codable {
    let accessToken: String
    let tokenType: String
    let expiresIn: Int?
    let refreshToken: String?
    let scope: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
        case scope
    }
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
