//
//  TransferMapSheet.swift
//  BuneIOS
//

import SwiftUI
import MapKit

struct TransferMapSheet: View {
    let transfer: Transfer
    let route: Route?
    let apiClient: TransportAPIClient?
    /// Vehicle id for GPS-history polling. Not currently a field on Transfer
    /// from the backend, so callers must resolve it (e.g. by matching
    /// vehiclePlate against the vehicles list) and pass it in.
    let vehicleId: Int?

    @StateObject private var tracker = VehicleBreadcrumbTracker()
    @Environment(\.dismiss) var dismiss

    /// Convenience init for previews / call sites without live GPS polling.
    init(transfer: Transfer, route: Route?, apiClient: TransportAPIClient? = nil, vehicleId: Int? = nil) {
        self.transfer = transfer
        self.route = route
        self.apiClient = apiClient
        self.vehicleId = vehicleId
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                RouteMapView(
                    route: route,
                    stops: route?.stops ?? [],
                    vehicleLocation: tracker.currentLocation,
                    locationHistory: tracker.locationHistory
                )
                .frame(maxHeight: .infinity)

                bottomInfoPanel
                    .background(BuneColors.backgroundSecondary)
            }
            .navigationTitle("Route Map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundColor(BuneColors.accentPrimary)
                }
            }
        }
        .task {
            if let client = apiClient, let vid = vehicleId {
                await tracker.start(apiClient: client, vehicleId: vid)
            }
        }
        .onDisappear {
            tracker.stop()
        }
    }

    @ViewBuilder
    private var bottomInfoPanel: some View {
        VStack(spacing: 12) {
            if let route = route {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(route.name)
                            .font(.headline)
                            .foregroundColor(BuneColors.textPrimary)

                        HStack(spacing: 12) {
                            Label(
                                "\(route.stops?.count ?? 0) stops",
                                systemImage: "mappin.circle.fill"
                            )
                            .font(.caption)
                            .foregroundColor(BuneColors.textTertiary)

                            if let status = route.status {
                                Label(status, systemImage: "road.lanes")
                                    .font(.caption)
                                    .foregroundColor(BuneColors.statusInTransit)
                            }

                            Label("\(tracker.locationHistory.count) pings",
                                  systemImage: "location.circle.fill")
                                .font(.caption)
                                .foregroundColor(BuneColors.textTertiary)
                        }
                    }
                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("In Transit")
                            .font(.caption2)
                            .foregroundColor(BuneColors.textTertiary)
                        Text(transfer.estimatedArrivalDateTime.flatMap(formatETA) ?? "—")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(BuneColors.accentPrimary)
                    }
                }
                .padding()
                .background(BuneColors.backgroundTertiary)
                .cornerRadius(12)
            }

            if let stops = route?.stops, !stops.isEmpty {
                VStack(spacing: 8) {
                    ForEach(stops) { stop in
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(BuneColors.accentPrimary.opacity(0.2))
                                    .frame(width: 28, height: 28)
                                Text("\(stop.stopOrder)")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(BuneColors.accentPrimary)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(stop.name ?? "Stop \(stop.stopOrder)")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(BuneColors.textPrimary)
                                    .lineLimit(1)

                                if let address = stop.address {
                                    Text(address)
                                        .font(.system(size: 11))
                                        .foregroundColor(BuneColors.textTertiary)
                                        .lineLimit(1)
                                }
                            }

                            Spacer()

                            if let estimatedMinutes = stop.estimatedMinutes {
                                VStack(alignment: .trailing, spacing: 1) {
                                    Text("\(estimatedMinutes)m")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(BuneColors.textPrimary)
                                    Text("ETA")
                                        .font(.system(size: 10))
                                        .foregroundColor(BuneColors.textTertiary)
                                }
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(BuneColors.backgroundTertiary.opacity(0.5))
                        .cornerRadius(8)
                    }
                }
            }
        }
        .padding()
    }

    private func formatETA(_ dateString: String) -> String? {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else { return nil }

        let interval = date.timeIntervalSince(Date())

        if interval < 60 {
            return "Now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m"
        } else {
            let hours = Int(interval / 3600)
            let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)
            return "\(hours)h \(minutes)m"
        }
    }
}

// MARK: - Vehicle Breadcrumb Tracker
//
// Polls `GET /transport/api/vehicles/{id}/pings` every 15 seconds while the
// map sheet is visible, exposing the history as CLLocationCoordinate2D
// points for RouteMapView to render as a trail.

@MainActor
class VehicleBreadcrumbTracker: ObservableObject {
    @Published var locationHistory: [CLLocationCoordinate2D] = []
    @Published var currentLocation: CLLocationCoordinate2D?

    private var pollingTask: Task<Void, Never>?
    private var apiClient: TransportAPIClient?
    private var vehicleId: Int?

    func start(apiClient: TransportAPIClient, vehicleId: Int) async {
        self.apiClient = apiClient
        self.vehicleId = vehicleId
        await refresh()
        pollingTask?.cancel()
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 15_000_000_000)
                if Task.isCancelled { break }
                await self?.refresh()
            }
        }
    }

    func stop() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    private func refresh() async {
        guard let apiClient = apiClient, let vehicleId = vehicleId else { return }
        do {
            let pings = try await apiClient.getVehicleHistory(vehicleId: vehicleId)
            let coords = pings.map {
                CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
            }
            locationHistory = coords
            currentLocation = coords.last
        } catch {
            // Silent failure — leave existing trail visible rather than clearing on a network blip.
        }
    }
}

// MARK: - Preview
#Preview {
    let mockTransfer = Transfer(
        id: 1,
        manifestNumber: "DEMO-0000001",
        shipperFacilityName: "San Francisco Hub",
        shipperFacilityLicenseNumber: "LIC-SF-001",
        status: "IN_TRANSIT",
        direction: "OUTGOING",
        packageCount: 5,
        estimatedDepartureDateTime: "2026-04-06T10:00:00Z",
        estimatedArrivalDateTime: "2026-04-06T14:30:00Z",
        vehiclePlate: "ABC-1234",
        driverName: "John Doe",
        routeId: 1,
        routeName: "Route SF-001",
        statusProgress: 50,
        statusColor: "#7030A0",
        destinations: nil
    )

    let mockStops = [
        RouteStop(id: 1, stopOrder: 1, name: "Pickup Point A", lat: 37.7749, lon: -122.4194,
                  address: "123 Main St, SF", stopType: "pickup", estimatedMinutes: 5, createdAt: nil),
        RouteStop(id: 2, stopOrder: 2, name: "Distribution Hub", lat: 37.7849, lon: -122.4294,
                  address: "456 Oak Ave, SF", stopType: "hub", estimatedMinutes: 20, createdAt: nil),
        RouteStop(id: 3, stopOrder: 3, name: "Final Delivery", lat: 37.7949, lon: -122.4394,
                  address: "789 Pine Rd, SF", stopType: "delivery", estimatedMinutes: 35, createdAt: nil)
    ]

    let mockRoute = Route(
        id: 1, name: "Route SF-001", description: "Downtown SF delivery route",
        originAddress: "123 Main St, SF", originLat: 37.7749, originLon: -122.4194,
        destinationAddress: "789 Pine Rd, SF", destinationLat: 37.7949, destinationLon: -122.4394,
        geofencePolygonJson: nil, routePolylineJson: nil, bufferMeters: 100,
        status: "IN_TRANSIT", stops: mockStops, createdAt: nil, updatedAt: nil
    )

    TransferMapSheet(transfer: mockTransfer, route: mockRoute, apiClient: nil)
}
