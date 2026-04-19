//
//  DemoToggleResult.swift
//  BuneIOS
//
//  Response from POST /api/v1/transport/demo/toggle. On enable, the backend
//  reports the created DEMO-0000001 manifest's transfer id and the package
//  labels that got seeded into the originator zone so the caller can link
//  straight to it for testing.
//
//  Backend quirk: some code paths return `message` as a Groovy-serialized
//  GString object rather than a plain String, e.g.
//      {"message":{"values":[0],"strings":["Demo transfer reset — ",
//                                           " package(s) restored ..."], ...}}
//  instead of
//      {"message":"Demo transfer reset — 0 package(s) restored ..."}.
//  The custom decoder below handles both shapes so the iOS app works
//  without waiting on a backend fix.
//

import Foundation

struct DemoToggleResult: Decodable {
    let success: Bool
    let demoMode: Bool
    let message: String?
    let error: String?

    // Populated on enable only.
    let transferId: Int?
    let manifestNumber: String?
    let packageLabels: [String]?
    let seeded: Bool?

    private enum CodingKeys: String, CodingKey {
        case success, demoMode, message, error
        case transferId, manifestNumber, packageLabels, seeded
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success        = (try? container.decode(Bool.self, forKey: .success)) ?? false
        demoMode       = (try? container.decode(Bool.self, forKey: .demoMode)) ?? false
        error          = try? container.decode(String.self, forKey: .error)
        transferId     = try? container.decode(Int.self, forKey: .transferId)
        manifestNumber = try? container.decode(String.self, forKey: .manifestNumber)
        packageLabels  = try? container.decode([String].self, forKey: .packageLabels)
        seeded         = try? container.decode(Bool.self, forKey: .seeded)

        // Message can be a plain String OR a Groovy GString object with a
        // `strings` array + `values` array. Try string first, then recover
        // by interleaving strings[] with values[] (values coerced to string).
        if let stringValue = try? container.decode(String.self, forKey: .message) {
            message = stringValue
        } else if let gstring = try? container.decode(GStringLike.self, forKey: .message) {
            message = gstring.assembled
        } else {
            message = nil
        }
    }
}

struct DemoStatusResult: Decodable {
    let success: Bool
    let demoMode: Bool
}

/// Mirror of a Groovy GString when serialized by Jackson without toString().
/// `strings` holds the literal chunks; `values` holds the interpolated values
/// that go between them. Joining them back together recreates the intended
/// human-readable message.
private struct GStringLike: Decodable {
    let strings: [String]?
    let values: [GStringValue]?

    var assembled: String {
        let parts = strings ?? []
        let interps = values ?? []
        var out = ""
        for i in 0..<parts.count {
            out += parts[i]
            if i < interps.count {
                out += interps[i].stringValue
            }
        }
        return out
    }
}

/// Flexible value container — GString values can be numbers, strings, or bools
/// depending on what was interpolated.
private struct GStringValue: Decodable {
    let stringValue: String

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let s = try? c.decode(String.self) {
            stringValue = s
        } else if let i = try? c.decode(Int.self) {
            stringValue = String(i)
        } else if let d = try? c.decode(Double.self) {
            stringValue = String(d)
        } else if let b = try? c.decode(Bool.self) {
            stringValue = String(b)
        } else {
            stringValue = ""
        }
    }
}
