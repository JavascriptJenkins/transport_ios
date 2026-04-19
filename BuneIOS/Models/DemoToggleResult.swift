//
//  DemoToggleResult.swift
//  BuneIOS
//
//  Response from POST /api/v1/transport/demo/toggle. On enable, the backend
//  reports the created DEMO-0000001 manifest's transfer id and the package
//  labels that got seeded into the originator zone so the caller can link
//  straight to it for testing.
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
}

struct DemoStatusResult: Decodable {
    let success: Bool
    let demoMode: Bool
}
