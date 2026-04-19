//
//  HubIntakeModels.swift
//  BuneIOS
//
//  DTOs for the hub intake workflow: accepting an IN_TRANSIT transfer at a
//  hub location, scanning its packages into STANDARD zones, and advancing
//  the transfer to AT_HUB once every package is placed.
//

import Foundation

// MARK: - Location
// Backend: GET /transport/api/locations
struct Location: Codable, Identifiable, Hashable {
    let id: Int
    let name: String?
    let licenseNumber: String?
    let facilityType: String?
    let address: String?
}

// MARK: - Hub Intake Session
// Backend: POST /transport/api/hub-intake/session
// Response shape: { success, session: {...}, resumed: Bool? }
struct HubIntakeSession: Codable, Identifiable {
    let id: Int
    let locationId: Int?
    let locationName: String?
    let transferId: Int?
    let transferManifestNumber: String?
    let shipperName: String?
    let receiverName: String?
    let totalPackages: Int
    /// Server-computed count of packages already in STANDARD hub zones.
    /// Populated by GET /hub-intake/session/{id}; zero on initial create.
    let assignedCount: Int?
    let status: String
    let createdBy: String?
    let startedAt: String?
    let completedAt: String?
    let updatedAt: String?
}
