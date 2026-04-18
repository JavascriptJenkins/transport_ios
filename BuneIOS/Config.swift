//
//  Config.swift
//  BuneIOS
//
//  Reads build-time config injected via Config.xcconfig → Info.plist.
//  Never hardcode secrets in source — set them in Config.xcconfig (gitignored).
//

import Foundation

// MARK: - Tenant

/// A single backend environment identified by a name that becomes the
/// subdomain of the backend URL (e.g. `haven` → `https://haven.bunepos.com`).
struct Tenant: Identifiable, Equatable, Hashable {
    /// Lowercased, whitespace-trimmed identifier used in URLs.
    let id: String
    /// API key scoped to this tenant.
    let apiKey: String

    var displayName: String { id }

    var baseURL: String { "https://\(id).\(Config.tenantHostSuffix)" }
    var tokenURL: String { "\(baseURL)/oauth2/token" }
}

// MARK: - Config

enum Config {

    // MARK: - Tenants

    /// Host suffix used to build tenant URLs (e.g. "bunepos.com" → "haven.bunepos.com").
    static let tenantHostSuffix: String = {
        guard
            let value = Bundle.main.object(forInfoDictionaryKey: "TRANSPORT_HOST_SUFFIX") as? String,
            !value.isEmpty
        else {
            return "bunepos.com"
        }
        return value
    }()

    /// Parsed from TRANSPORT_TENANTS in Info.plist. Format:
    ///   `tenant1:key1,tenant2:key2,tenant3:key3`
    /// Returns [] when the key is missing or the string is empty.
    static let tenants: [Tenant] = {
        guard
            let raw = Bundle.main.object(forInfoDictionaryKey: "TRANSPORT_TENANTS") as? String,
            !raw.isEmpty
        else {
            return []
        }
        return raw
            .split(separator: ",")
            .compactMap { entry -> Tenant? in
                let parts = entry.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
                guard parts.count == 2 else { return nil }
                let id = parts[0].trimmingCharacters(in: .whitespaces).lowercased()
                let key = parts[1].trimmingCharacters(in: .whitespaces)
                guard !id.isEmpty, !key.isEmpty else { return nil }
                return Tenant(id: id, apiKey: key)
            }
    }()

    /// Case-insensitive tenant lookup. Returns nil when the name is
    /// unknown or the tenant list is empty.
    static func tenant(matching name: String) -> Tenant? {
        let needle = name.trimmingCharacters(in: .whitespaces).lowercased()
        guard !needle.isEmpty else { return nil }
        return tenants.first(where: { $0.id == needle })
    }

    // MARK: - Legacy Single-Tenant Fallback
    // Kept so dev setups without TRANSPORT_TENANTS keep working.
    // AuthService + TransportAPIClient prefer selectedTenant when available.

    static let apiKey: String = {
        guard
            let value = Bundle.main.object(forInfoDictionaryKey: "TRANSPORT_API_KEY") as? String,
            !value.isEmpty,
            value != "your_api_key_here"
        else {
            if tenants.isEmpty {
                assertionFailure("Neither TRANSPORT_TENANTS nor TRANSPORT_API_KEY is configured.")
            }
            return ""
        }
        return value
    }()

    static let transportBaseURL: String = {
        guard
            let value = Bundle.main.object(forInfoDictionaryKey: "TRANSPORT_BASE_URL") as? String,
            !value.isEmpty
        else {
            return "https://haven.\(tenantHostSuffix)"
        }
        return value.hasSuffix("/") ? String(value.dropLast()) : value
    }()

    static var tokenURL: String { "\(transportBaseURL)/oauth2/token" }
}
