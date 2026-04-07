//
//  ZoneManagerViewModel.swift
//  BuneIOS
//
//  Created by techvvs001 on 4/6/26.
//

import Foundation
import SwiftUI

@MainActor
class ZoneManagerViewModel: ObservableObject {
    @Published var zones: [Zone] = []
    @Published var selectedZone: Zone?
    @Published var zonePackages: [Package] = []
    @Published var recentScans: [ZoneScanAudit] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let apiClient: TransportAPIClient

    init(apiClient: TransportAPIClient) {
        self.apiClient = apiClient
    }

    // MARK: - Load Zones

    func loadZones() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            zones = try await apiClient.listZones()
        } catch {
            errorMessage = "Failed to load zones: \(error.localizedDescription)"
        }
    }

    // MARK: - Select Zone

    func selectZone(_ zone: Zone) async {
        selectedZone = zone
        await loadZonePackages(zoneId: zone.id)
        await loadZoneAudit(zoneId: zone.id)
    }

    // MARK: - Scan Package

    func scanPackage(label: String, action: String) async {
        guard let zone = selectedZone else {
            errorMessage = "No zone selected"
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            _ = try await apiClient.scanIntoZone(zoneId: zone.id, packageLabel: label, action: action)
            // Refresh packages and audit after successful scan
            await loadZonePackages(zoneId: zone.id)
            await loadZoneAudit(zoneId: zone.id)
        } catch {
            errorMessage = "Scan failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Load Zone Packages

    func loadZonePackages(zoneId: Int) async {
        do {
            zonePackages = try await apiClient.getZonePackages(zoneId: zoneId)
        } catch {
            errorMessage = "Failed to load zone packages: \(error.localizedDescription)"
        }
    }

    // MARK: - Load Zone Audit

    func loadZoneAudit(zoneId: Int) async {
        do {
            recentScans = try await apiClient.getZoneAudit(zoneId: zoneId)
        } catch {
            errorMessage = "Failed to load zone audit: \(error.localizedDescription)"
        }
    }
}
