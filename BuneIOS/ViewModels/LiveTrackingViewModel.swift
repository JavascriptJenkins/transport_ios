//
//  LiveTrackingViewModel.swift
//  BuneIOS
//
//  Created by techvvs001 on 4/6/26.
//

import Foundation

@MainActor
class LiveTrackingViewModel: ObservableObject {
    @Published var trackingStatus: Transfer?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let transferId: Int
    private let apiClient: TransportAPIClient
    private var pollingTimer: Timer?

    // Computed properties for UI state
    var canDepart: Bool {
        guard let status = trackingStatus?.status else { return false }
        let statusUpper = status.uppercased()
        return (statusUpper == "CREATED" || statusUpper == "DISPATCH" || statusUpper == "AT_HUB")
    }

    var canPickup: Bool {
        guard let status = trackingStatus?.status else { return false }
        return status.uppercased() == "DISPATCH"
    }

    var canDeliver: Bool {
        guard let status = trackingStatus?.status else { return false }
        return status.uppercased() == "IN_TRANSIT"
    }

    var hasPickupSession: Bool {
        // Would be set based on transfer state tracking
        false
    }

    var hasDeliverySession: Bool {
        // Would be set based on transfer state tracking
        false
    }

    var statusText: String {
        guard let status = trackingStatus?.status else { return "Unknown" }
        return status
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }

    var manifestNumber: String {
        trackingStatus?.manifestNumber ?? "N/A"
    }

    var driverName: String {
        trackingStatus?.driverName ?? "Unassigned"
    }

    var vehiclePlate: String {
        trackingStatus?.vehiclePlate ?? "N/A"
    }

    var originLocation: String {
        trackingStatus?.shipperFacilityName ?? "Unknown"
    }

    var destinationLocation: String {
        guard let destinations = trackingStatus?.destinations,
              let first = destinations.first else {
            return "Unknown"
        }
        return first.recipientFacilityName ?? "Unknown"
    }

    var etaText: String {
        guard let eta = trackingStatus?.estimatedArrivalDateTime else {
            return "No ETA"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yyyy HH:mm"
        if let date = formatter.date(from: eta) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "HH:mm"
            return displayFormatter.string(from: date)
        }
        return eta
    }

    init(transferId: Int, apiClient: TransportAPIClient) {
        self.transferId = transferId
        self.apiClient = apiClient
    }

    func loadStatus() async {
        isLoading = true
        errorMessage = nil

        do {
            let transfer = try await apiClient.getTrackingStatus(transferId: transferId)
            self.trackingStatus = transfer
        } catch {
            self.errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func startPolling() {
        // Initial load
        Task {
            await loadStatus()
        }

        // Poll every 10 seconds
        pollingTimer?.invalidate()
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            Task {
                await self?.loadStatus()
            }
        }
    }

    func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }

    func depart() async {
        isLoading = true
        errorMessage = nil

        do {
            let updated = try await apiClient.departTransfer(transferId: transferId)
            self.trackingStatus = updated
        } catch {
            self.errorMessage = "Failed to depart transfer: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func markDelivered() async {
        isLoading = true
        errorMessage = nil

        do {
            let updated = try await apiClient.markDelivered(transferId: transferId)
            self.trackingStatus = updated
        } catch {
            self.errorMessage = "Failed to mark delivered: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func pingLocation(latitude: Double, longitude: Double) async {
        do {
            _ = try await apiClient.pingLocation(transferId: transferId, lat: latitude, lng: longitude)
        } catch {
            self.errorMessage = "Failed to ping location: \(error.localizedDescription)"
        }
    }

}
