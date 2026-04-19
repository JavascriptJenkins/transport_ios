//
//  GPSTrackingService.swift
//  BuneIOS
//
//  Created by techvvs001 on 4/6/26.
//

import CoreLocation
import Foundation

@MainActor
class GPSTrackingService: NSObject, ObservableObject, @preconcurrency CLLocationManagerDelegate {
    @Published var currentLocation: CLLocation?
    @Published var isTracking = false
    @Published var hasPermission = false
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var pendingPingCount = 0
    @Published var lastPingTime: Date?

    private let locationManager = CLLocationManager()
    private var apiClient: TransportAPIClient?
    /// Persistent offline queue. When set, ping failures that look like
    /// network issues get persisted through it so they survive cold launches.
    /// The in-memory pendingPings array is kept alongside for quick-reconnect
    /// retry without going back to disk.
    private var offlineSyncService: OfflineSyncService?
    private var activeTransferId: Int?
    private var activeVehicleId: Int?
    private var pendingPings: [GPSPing] = []

    /// Timestamp of the last ping sent (or queued) — used to gate callback-driven
    /// submissions so we don't spam when CLLocationManager delivers frequently.
    private var lastPingSubmittedAt: Date = .distantPast

    // Configuration
    var pingIntervalSeconds: TimeInterval = 30
    var distanceFilter: CLLocationDistance = 50 // meters

    override init() {
        super.init()
        configureLocationManager()
    }

    /// Attach the persistent offline queue. Safe to call multiple times
    /// (most-recent wins). Called from LiveTrackingView.onAppear.
    func configure(offlineSyncService: OfflineSyncService) {
        self.offlineSyncService = offlineSyncService
    }

    private func configureLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = distanceFilter
        locationManager.pausesLocationUpdatesAutomatically = false
        authorizationStatus = locationManager.authorizationStatus
        updatePermissionStatus()
    }

    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }

    func requestAlwaysPermission() {
        locationManager.requestAlwaysAuthorization()
    }

    func startTracking(transferId: Int, vehicleId: Int, apiClient: TransportAPIClient) {
        self.activeTransferId = transferId
        self.activeVehicleId = vehicleId
        self.apiClient = apiClient
        self.isTracking = true
        self.lastPingSubmittedAt = .distantPast

        // Upgrade to "Always" authorization so tracking keeps working when the
        // driver puts the phone away during a trip. If the user has only
        // granted WhenInUse, this is a no-op — iOS will continue delivering
        // updates only while the app is in the foreground.
        if authorizationStatus != .authorizedAlways {
            locationManager.requestAlwaysAuthorization()
        }

        // Background modes capability is declared in Info.plist. These two
        // properties are required for CLLocationManager to keep delivering
        // updates when the app is backgrounded.
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.showsBackgroundLocationIndicator = true

        // Start continuous updates. Pings are driven off the resulting
        // didUpdateLocations callbacks (throttled by pingIntervalSeconds),
        // NOT a foreground Timer — timers stop firing once the app suspends.
        if hasPermission {
            locationManager.startUpdatingLocation()
            // Significant-change service as a safety net: wakes us up if the
            // OS suspends continuous delivery during long idle stretches.
            locationManager.startMonitoringSignificantLocationChanges()
        }
    }

    func stopTracking() {
        self.isTracking = false
        locationManager.stopUpdatingLocation()
        locationManager.stopMonitoringSignificantLocationChanges()
        locationManager.allowsBackgroundLocationUpdates = false

        Task { await flushPendingPings() }
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        self.currentLocation = latest

        // Drive pings from the delegate callback rather than a foreground
        // Timer so the behavior survives app suspension. A 30s throttle
        // (pingIntervalSeconds) prevents spamming when the driver is moving
        // and CLLocationManager fires frequently.
        guard isTracking else { return }
        let now = Date()
        if now.timeIntervalSince(lastPingSubmittedAt) >= pingIntervalSeconds {
            lastPingSubmittedAt = now
            Task { await submitPing() }
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        updatePermissionStatus()

        // Start tracking if permission was granted
        if isTracking && hasPermission {
            locationManager.startUpdatingLocation()
        } else if !hasPermission && isTracking {
            stopTracking()
        }
    }

    private func updatePermissionStatus() {
        let status = locationManager.authorizationStatus
        authorizationStatus = status
        hasPermission = status == .authorizedAlways || status == .authorizedWhenInUse
    }

    // MARK: - GPS Ping Submission

    private func submitPing() async {
        guard let location = currentLocation,
              let transferId = activeTransferId,
              let vehicleId = activeVehicleId,
              let apiClient = apiClient else {
            return
        }

        let now = ISO8601DateFormatter().string(from: Date())
        let ping = GPSPing(
            vehicleId: vehicleId,
            transferId: transferId,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            speed: location.speed >= 0 ? location.speed : nil,
            heading: location.course >= 0 ? location.course : nil,
            accuracy: location.horizontalAccuracy >= 0 ? location.horizontalAccuracy : nil,
            timestamp: now,
            driverName: nil
        )

        do {
            let response = try await apiClient.submitGPSPing(ping)
            self.lastPingTime = Date()

            // Remove from pending queue if it was there
            pendingPings.removeAll { $0.timestamp == ping.timestamp }
            self.pendingPingCount = pendingPings.count

            // Check for geofence alerts
            if let alert = response.geofenceAlert {
                handleGeofenceAlert(alert)
            }
        } catch {
            // Two-level fallback:
            //  1. Persist through OfflineSyncService when it's clearly a
            //     network failure — survives cold launches, drains on
            //     reconnect, survives tenant scoping like every other queued
            //     op.
            //  2. Fall back to the in-memory pendingPings array for
            //     transient / unknown errors (server 5xx, short blips) so
            //     we retry on the next ping tick without going to disk.
            let persisted = offlineSyncService?.enqueueIfNetworkFailure(
                error,
                operation: .gpsPing(ping)
            ) ?? false

            if !persisted {
                pendingPings.append(ping)
                self.pendingPingCount = pendingPings.count
            }
        }
    }

    func flushPendingPings() async {
        guard !pendingPings.isEmpty,
              let apiClient = apiClient else {
            return
        }

        var successful: [String] = []

        for ping in pendingPings {
            do {
                _ = try await apiClient.submitGPSPing(ping)
                successful.append(ping.timestamp)
            } catch {
                // Keep in queue
            }
        }

        // Remove successful pings
        pendingPings.removeAll { ping in
            successful.contains(ping.timestamp)
        }

        self.pendingPingCount = pendingPings.count
    }

    private func handleGeofenceAlert(_ alert: GeofenceAlert) {
        // Log or display geofence alert
        // This could trigger a notification or update UI
        print("Geofence Alert: \(alert.type) at \(alert.zoneName ?? "Unknown Zone")")
    }

    // MARK: - Battery Optimization

    func reducePingFrequency() {
        pingIntervalSeconds = 60
        // Throttle gate in didUpdateLocations picks this up immediately;
        // no timer to restart.
    }

    func normalPingFrequency() {
        pingIntervalSeconds = 30
    }
}
