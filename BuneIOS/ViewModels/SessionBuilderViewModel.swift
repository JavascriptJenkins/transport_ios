//
//  SessionBuilderViewModel.swift
//  BuneIOS
//
//  Created by techvvs001 on 4/6/26.
//

import Foundation
import SwiftUI

// MARK: - Session Builder View Model

@MainActor
class SessionBuilderViewModel: ObservableObject {

    // MARK: - Phase Management
    enum Phase {
        case scan
        case configure
        case review
    }

    // MARK: - Published Properties

    // Session state
    @Published var session: TransportSession?
    @Published var scannedPackages: [SessionPackage] = []

    // Phase management
    @Published var currentPhase: Phase = .scan

    // Loading states
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isSubmitting = false
    @Published var submissionResult: SubmissionResult?

    // Reference data
    @Published var drivers: [Driver] = []
    @Published var vehicles: [Vehicle] = []
    @Published var destinations: [Destination] = []
    @Published var routes: [Route] = []
    @Published var transporters: [Transporter] = []
    @Published var transferTypes: [TransferType] = []

    // Configuration state
    @Published var selectedDriverId: Int?
    @Published var selectedVehicleId: Int?
    @Published var selectedDestinationId: Int?
    @Published var selectedRouteId: Int?
    @Published var selectedTransporterId: Int?
    @Published var selectedTransferType: String?
    @Published var estimatedDeparture: Date = Date()
    @Published var estimatedArrival: Date = Date().addingTimeInterval(3600)
    @Published var notes: String = ""

    // Private
    private let apiClient: TransportAPIClient
    private let cache: LocalCacheService?

    // MARK: - Initialization

    init(apiClient: TransportAPIClient, cache: LocalCacheService? = nil) {
        self.apiClient = apiClient
        self.cache = cache
        // Warm the reference-data fields from disk immediately so the
        // Configure phase renders instantly with stale values while a
        // network refresh happens in the background. Empty arrays stay
        // empty — no spinners needed when a fresh cache exists.
        if let cache = cache {
            self.drivers = cache.cachedDrivers
            self.vehicles = cache.cachedVehicles
            self.destinations = cache.cachedDestinations
            self.routes = cache.cachedRoutes
        }
    }

    // MARK: - Session Management

    func createSession() async {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await apiClient.createSession(type: "OUTGOING_TRANSFER")
            self.session = response
            currentPhase = .scan
        } catch {
            errorMessage = "Failed to create session: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func addPackage(tag: String) async {
        guard let session = session else {
            errorMessage = "No active session"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let response: TransportSession = try await apiClient.addPackageToSession(
                uuid: session.sessionUuid,
                packageTag: tag
            )
            self.session = response
            self.scannedPackages = extractPackages(from: response)
        } catch {
            errorMessage = "Failed to add package: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func removePackage(label: String) async {
        guard let session = session else {
            errorMessage = "No active session"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let response: TransportSession = try await apiClient.removePackageFromSession(
                uuid: session.sessionUuid,
                packageLabel: label
            )
            self.session = response
            self.scannedPackages = extractPackages(from: response)
        } catch {
            errorMessage = "Failed to remove package: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func loadReferenceData() async {
        isLoading = true
        errorMessage = nil

        // Load all reference data in parallel
        async let driversTask = apiClient.listDrivers()
        async let vehiclesTask = apiClient.listVehicles()
        async let destinationsTask = apiClient.listDestinations()
        async let routesTask = apiClient.listRoutes()
        async let transportersTask = apiClient.listTransporters()
        async let transferTypesTask = apiClient.listTransferTypes()

        do {
            drivers = try await driversTask
            vehicles = try await vehiclesTask
            destinations = try await destinationsTask
            routes = try await routesTask
            transporters = try await transportersTask
            transferTypes = try await transferTypesTask

            // Push successful fetches into the local cache so subsequent
            // launches (especially offline ones) can warm-start instantly.
            cache?.cacheDrivers(drivers)
            cache?.cacheVehicles(vehicles)
            cache?.cacheDestinations(destinations)
            cache?.cacheRoutes(routes)
        } catch {
            // If we already warm-started from cache, keep the stale values
            // rather than wiping the UI to empty on a network blip.
            let haveCachedData = !drivers.isEmpty || !vehicles.isEmpty
                || !destinations.isEmpty || !routes.isEmpty
            if !haveCachedData {
                errorMessage = "Failed to load reference data: \(error.localizedDescription)"
            }
        }

        isLoading = false
    }

    func updateSessionConfig() async {
        guard let session = session else {
            errorMessage = "No active session"
            return
        }

        isLoading = true
        errorMessage = nil

        let dateFormatter = ISO8601DateFormatter()

        let config = SessionUpdateRequest(
            driverId: selectedDriverId,
            vehicleId: selectedVehicleId,
            destinationId: selectedDestinationId,
            routeId: selectedRouteId,
            estimatedDeparture: dateFormatter.string(from: estimatedDeparture),
            estimatedArrival: dateFormatter.string(from: estimatedArrival),
            notes: notes.isEmpty ? nil : notes
        )

        do {
            let response: TransportSession = try await apiClient.updateSession(
                uuid: session.sessionUuid,
                config: config
            )
            self.session = response
        } catch {
            errorMessage = "Failed to update session: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func submitSession() async {
        guard let session = session else {
            errorMessage = "No active session"
            return
        }

        isSubmitting = true
        errorMessage = nil

        do {
            let response: TransportSession = try await apiClient.submitSession(
                uuid: session.sessionUuid
            )
            self.session = response

            submissionResult = SubmissionResult(
                transferId: response.id,
                manifestNumber: response.sessionUuid,
                success: true
            )
        } catch {
            errorMessage = "Failed to submit session: \(error.localizedDescription)"
            submissionResult = SubmissionResult(
                transferId: nil,
                manifestNumber: nil,
                success: false
            )
        }

        isSubmitting = false
    }

    func abandonSession() async {
        guard let session = session else {
            errorMessage = "No active session"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            try await apiClient.deleteSession(uuid: session.sessionUuid)
            self.session = nil
            self.scannedPackages = []
            self.currentPhase = .scan
            resetConfiguration()
        } catch {
            errorMessage = "Failed to abandon session: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Phase Navigation

    func advancePhase() {
        switch currentPhase {
        case .scan:
            if scannedPackages.count >= 1 {
                currentPhase = .configure
                errorMessage = nil
            } else {
                errorMessage = "Please scan at least one package before proceeding"
            }
        case .configure:
            if isConfigurePhaseValid() {
                currentPhase = .review
                errorMessage = nil
            } else {
                errorMessage = "Please fill in all required fields"
            }
        case .review:
            break
        }
    }

    func goBackPhase() {
        switch currentPhase {
        case .scan:
            break
        case .configure:
            currentPhase = .scan
            errorMessage = nil
        case .review:
            currentPhase = .configure
            errorMessage = nil
        }
    }

    // MARK: - Validation

    private func isConfigurePhaseValid() -> Bool {
        return selectedDriverId != nil &&
               selectedVehicleId != nil &&
               selectedDestinationId != nil &&
               selectedTransporterId != nil &&
               selectedTransferType != nil
    }

    func isReviewPhaseValid() -> Bool {
        return !scannedPackages.isEmpty &&
               selectedDriverId != nil &&
               selectedVehicleId != nil &&
               selectedDestinationId != nil &&
               selectedTransporterId != nil &&
               selectedTransferType != nil
    }

    // MARK: - Helper Methods

    private func extractPackages(from session: TransportSession) -> [SessionPackage] {
        // This is a simplified extraction. In a real scenario, you might fetch
        // the packages from an API endpoint or store them separately
        return []
    }

    private func resetConfiguration() {
        selectedDriverId = nil
        selectedVehicleId = nil
        selectedDestinationId = nil
        selectedRouteId = nil
        selectedTransporterId = nil
        selectedTransferType = nil
        estimatedDeparture = Date()
        estimatedArrival = Date().addingTimeInterval(3600)
        notes = ""
    }
}

// MARK: - Helper Structs

struct CreateSessionRequest: Encodable {
    let type: String
}

struct SubmissionResult {
    let transferId: Int?
    let manifestNumber: String?
    let success: Bool
}
