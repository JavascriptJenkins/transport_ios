//
//  Config.swift
//  BuneIOS
//
//  Reads build-time secrets injected via Config.xcconfig → Info.plist.
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

    static let transportBaseURL = "https://haven.bunepos.com"
    static let tokenURL = "https://haven.bunepos.com/oauth2/token"
}
