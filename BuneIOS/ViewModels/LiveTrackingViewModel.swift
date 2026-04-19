//
//  LiveTrackingViewModel.swift
//  BuneIOS
//
//  Created by techvvs001 on 4/6/26.
//

import Foundation

@MainActor
class LiveTrackingViewModel: ObservableObject {
    // The two /public/transfer/track/* shapes live side-by-side here.
    // Status is polled; details are fetched once (and refreshed alongside
    // status so the vehicle/driver cards track reassignments).
    @Published var trackingStatus: PublicTrackingStatus?
    @Published var trackingDetails: PublicTrackingDetails?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let transferId: Int
    private let apiClient: TransportAPIClient
    private var pollingTimer: Timer?

    // MARK: - Derived UI State

    /// Tight to DISPATCH / AT_HUB. CREATED is intentionally NOT depart-able
    /// on this surface: the backend only flips a CREATED transfer to
    /// DISPATCHING via the dashboard dispatch action, not via /track/depart.
    var canDepart: Bool {
        guard let status = trackingStatus?.status.uppercased() else { return false }
        return status == "DISPATCH" || status == "AT_HUB"
    }

    var canPickup: Bool {
        trackingStatus?.status.uppercased() == "DISPATCH"
    }

    var canDeliver: Bool {
        trackingStatus?.status.uppercased() == "IN_TRANSIT"
    }

    // Session-resume flags are driven off whichever signal the backend
    // surfaces; once wired to the scan-session endpoints these flip to true
    // after the first scan. For now they stay false — no fake state.
    var hasPickupSession: Bool { false }
    var hasDeliverySession: Bool { false }

    /// Authoritative overdue flag comes from the backend; the old
    /// statusProgress>80 heuristic was inverted (an almost-done transfer
    /// isn't overdue) and is gone.
    var isOverdue: Bool {
        trackingStatus?.overdue == true
    }

    var statusText: String {
        if let label = trackingStatus?.statusLabel, !label.isEmpty {
            return label
        }
        guard let status = trackingStatus?.status else { return "Unknown" }
        return status.replacingOccurrences(of: "_", with: " ").capitalized
    }

    var manifestNumber: String {
        trackingDetails?.manifestNumber ?? "N/A"
    }

    var driverName: String {
        trackingDetails?.driverName ?? "Unassigned"
    }

    var vehiclePlate: String {
        trackingDetails?.vehiclePlate ?? "N/A"
    }

    var originLocation: String {
        trackingDetails?.shipperName ?? "Unknown"
    }

    var destinationLocation: String {
        trackingDetails?.receiverName ?? "Unknown"
    }

    /// Backend pre-formats etaDisplay; fall back to estimatedArrival and
    /// try a couple of common timestamp shapes (ISO-8601 with or without
    /// fractional seconds, plus the legacy MM/dd/yyyy).
    var etaText: String {
        if let display = trackingStatus?.etaDisplay, !display.isEmpty {
            return display
        }
        guard let raw = trackingDetails?.estimatedArrival, !raw.isEmpty else {
            return "No ETA"
        }
        if let date = Self.parseFlexibleDate(raw) {
            let out = DateFormatter()
            out.dateStyle = .short
            out.timeStyle = .short
            return out.string(from: date)
        }
        return raw
    }

    /// Used by the view's GPS start call so we don't rely on a hard-coded
    /// vehicleId=0. Backend /ping resolves the vehicle from the transfer
    /// anyway, but keeping this honest avoids surprises elsewhere.
    var vehicleId: Int { 0 }

    private static func parseFlexibleDate(_ raw: String) -> Date? {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: raw) { return d }
        iso.formatOptions = [.withInternetDateTime]
        if let d = iso.date(from: raw) { return d }
        let legacy = DateFormatter()
        legacy.dateFormat = "MM/dd/yyyy HH:mm"
        return legacy.date(from: raw)
    }

    // MARK: - Lifecycle

    init(transferId: Int, apiClient: TransportAPIClient) {
        self.transferId = transferId
        self.apiClient = apiClient
    }

    func loadStatus() async {
        isLoading = true
        errorMessage = nil

        async let statusTask = apiClient.getTrackingStatus(transferId: transferId)
        async let detailsTask = apiClient.getTrackingDetails(transferId: transferId)

        do {
            self.trackingStatus = try await statusTask
        } catch {
            self.errorMessage = error.localizedDescription
        }

        // Details failure is non-fatal — status is the load-bearing call.
        if let details = try? await detailsTask {
            self.trackingDetails = details
        }

        isLoading = false
    }

    /// Silent refresh used by the polling timer so the UI doesn't flicker a
    /// spinner or clobber an in-flight error banner on each tick.
    private func refreshStatusSilently() async {
        if let updated = try? await apiClient.getTrackingStatus(transferId: transferId) {
            self.trackingStatus = updated
        }
    }

    func startPolling() {
        Task { await loadStatus() }

        pollingTimer?.invalidate()
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            Task { await self?.refreshStatusSilently() }
        }
    }

    func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }

    // MARK: - Actions

    func depart() async {
        isLoading = true
        errorMessage = nil

        do {
            let result = try await apiClient.departTransfer(transferId: transferId)
            if !result.success {
                errorMessage = result.error ?? "Failed to depart transfer"
            }
            // Refresh status from the authoritative endpoint after the
            // action lands so overdue / etaDisplay / progress recompute.
            await refreshStatusSilently()
        } catch {
            errorMessage = "Failed to depart transfer: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func markDelivered() async {
        isLoading = true
        errorMessage = nil

        do {
            let result = try await apiClient.markDelivered(transferId: transferId)
            if !result.success && result.alreadyDelivered != true {
                errorMessage = result.error ?? "Failed to mark delivered"
            }
            await refreshStatusSilently()
        } catch {
            errorMessage = "Failed to mark delivered: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func pingLocation(latitude: Double, longitude: Double) async {
        do {
            _ = try await apiClient.pingLocation(
                transferId: transferId,
                lat: latitude,
                lon: longitude
            )
        } catch {
            errorMessage = "Failed to ping location: \(error.localizedDescription)"
        }
    }
}
