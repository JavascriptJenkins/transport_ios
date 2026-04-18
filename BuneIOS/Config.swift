//
//  Config.swift
//  BuneIOS
//
//  Reads build-time config injected via Config.xcconfig → Info.plist.
//  Never hardcode secrets in source — set them in Config.xcconfig (gitignored).
//

import Foundation

enum Config {
    static let apiKey: String = {
        guard
            let value = Bundle.main.object(forInfoDictionaryKey: "TRANSPORT_API_KEY") as? String,
            !value.isEmpty,
            value != "your_api_key_here"
        else {
            assertionFailure("TRANSPORT_API_KEY is missing. Copy Config.xcconfig.example → Config.xcconfig and set the key.")
            return ""
        }
        return value
    }()

    static let transportBaseURL: String = {
        guard
            let value = Bundle.main.object(forInfoDictionaryKey: "TRANSPORT_BASE_URL") as? String,
            !value.isEmpty
        else {
            assertionFailure("TRANSPORT_BASE_URL is missing. Set it in Config.xcconfig.")
            return "https://haven.bunepos.com"
        }
        return value.hasSuffix("/") ? String(value.dropLast()) : value
    }()

    static var tokenURL: String { "\(transportBaseURL)/oauth2/token" }
}
