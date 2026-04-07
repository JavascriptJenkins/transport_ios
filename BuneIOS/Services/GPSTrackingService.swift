//
//  GPSTrackingService.swift
//  BuneIOS
//
//  Created by techvvs001 on 4/6/26.
//

import CoreLocation
import Foundation

@MainActor
class GPSTrackingService: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var currentLocation: CLLocation?
    @Published var isTracking = false
    @Published var hasPermission = false
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var pendingPingCount = 0
    @Published var lastPingTime: Date?

    private let locationManager = CLLocationManager()
    private var apiClient: TransportAPIClient?
    private var activeTransferId: Int?
    private var activeVehicleId: Int?
    private var pingTimer: Timer?
    private var pendingPings: [GPSPing] = []

    // Configuration
    var pingIntervalSeconds: TimeInterval = 30
    var distanceFilter: CLLocationDistance = 50 // meters

    override init() {
        super.init()
        configureLocationManager()
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

        // Enable background location updates
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.showsBackgroundLocationIndicator = true

        // Start location updates
        if hasPermission {
            locationManager.startUpdatingLocation()
        }

        // Start ping timer
        startPingTimer()
    }

    func stopTracking() {
        self.isTracking = false
        locationManager.stopUpdatingLocation()
        locationManager.allowsBackgroundLocationUpdates = false
        pingTimer?.invalidate()
        pingTimer = nil

        // Flush any pending pings before stopping
        Task {
            await flushPendingPings()
        }
    }

    private func startPingTimer() {
        pingTimer?.invalidate()
        pingTimer = Timer.scheduledTimer(withTimeInterval: pingIntervalSeconds, repeats: true) { [weak self] _ in
            Task {
                await self?.submitPing()
            }
        }
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        self.currentLocation = latest
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
            // Queue for later submission
            pendingPings.append(ping)
            self.pendingPingCount = pendingPings.count
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
        startPingTimer()
    }

    func normalPingFrequency() {
        pingIntervalSeconds = 30
        startPingTimer()
    }
}
