//
//  KeychainStore.swift
//  BuneIOS
//
//  Minimal wrapper around the iOS Keychain for storing OAuth tokens.
//  Uses kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly so items stay
//  available after first unlock but never leave this device via backup.
//

import Foundation
import Security

enum KeychainStore {

    /// Service identifier used to scope Keychain items to this app.
    private static let service = "io.techvvs.bune"

    /// Store (or replace) a value for the given account key. Pass `nil` to delete.
    /// Returns `true` on success.
    @discardableResult
    static func set(_ value: String?, for account: String) -> Bool {
        if let value = value {
            return setValue(value, for: account)
        } else {
            return delete(account: account)
        }
    }

    /// Read the string value for a given account key, or nil if not found.
    static func get(_ account: String) -> String? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8)
        else { return nil }
        return string
    }

    /// Delete a value.
    @discardableResult
    static func delete(account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    // MARK: - Internals

    private static func setValue(_ value: String, for account: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let attrs: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attrs as CFDictionary)
        if updateStatus == errSecSuccess { return true }
        if updateStatus != errSecItemNotFound { return false }

        var addQuery = query
        for (k, v) in attrs { addQuery[k] = v }
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        return addStatus == errSecSuccess
    }
}
