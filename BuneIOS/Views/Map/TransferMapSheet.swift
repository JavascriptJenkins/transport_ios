//
//  TransferMapSheet.swift
//  BuneIOS
//
//  Created by techvvs001 on 4/6/26.
//

import SwiftUI
import MapKit

struct TransferMapSheet: View {
    let transfer: Transfer
    let route: Route?

    @StateObject private var locationTracker = LocationTrackingService()
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Map takes most of the space
                RouteMapView(
                    route: route,
                    stops: route?.stops ?? [],
                    vehicleLocation: currentVehicleCoord,
                    locationHistory: locationTracker.locationHistory
                )
                .frame(maxHeight: .infinity)

                // Bottom panel: glass card with route info
                bottomInfoPanel
                    .background(BuneColors.backgroundSecondary)
            }
            .navigationTitle("Route Map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(BuneColors.accentPrimary)
                }
            }
        }
        .onAppear {
            locationTracker.startTracking(transferId: transfer.id)
        }
        .onDisappear {
            locationTracker.stopTracking()
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
                        }
                    }
                    Spacer()

                    // Distance/Time badge (if available)
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

            // Stop list (compact)
            if let stops = route?.stops, !stops.isEmpty {
                VStack(spacing: 8) {
                    ForEach(stops) { stop in
                        HStack(spacing: 12) {
                            // Stop number circle
                            ZStack {
                                Circle()
                                    .fill(BuneColors.accentPrimary.opacity(0.2))
                                    .frame(width: 28, height: 28)

                                Text("\(stop.stopOrder)")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(BuneColors.accentPrimary)
                            }

                            // Stop info
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

                            // ETA offset
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

    private var currentVehicleCoord: CLLocationCoordinate2D? {
        locationTracker.currentLocation.map { location in
            CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
        }
    }

    private func formatETA(_ dateString: String) -> String? {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else { return nil }

        let now = Date()
        let interval = date.timeIntervalSince(now)

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

// MARK: - LocationTrackingService (Mock)
class LocationTrackingService: NSObject, ObservableObject {
    @Published var currentLocation: (latitude: Double, longitude: Double)?
    @Published var locationHistory: [CLLocationCoordinate2D] = []

    private var isTracking = false

    func startTracking(transferId: Int) {
        isTracking = true
        // In production, this would integrate with GPSTrackingService
        // For now, it's a placeholder that can be connected to the real service
    }

    func stopTracking() {
        isTracking = false
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
        RouteStop(
            id: 1,
            stopOrder: 1,
            name: "Pickup Point A",
            lat: 37.7749,
            lon: -122.4194,
            address: "123 Main St, SF",
            stopType: "pickup",
            estimatedMinutes: 5,
            createdAt: nil
        ),
        RouteStop(
            id: 2,
            stopOrder: 2,
            name: "Distribution Hub",
            lat: 37.7849,
            lon: -122.4294,
            address: "456 Oak Ave, SF",
            stopType: "hub",
            estimatedMinutes: 20,
            createdAt: nil
        ),
        RouteStop(
            id: 3,
            stopOrder: 3,
            name: "Final Delivery",
            lat: 37.7949,
            lon: -122.4394,
            address: "789 Pine Rd, SF",
            stopType: "delivery",
            estimatedMinutes: 35,
            createdAt: nil
        )
    ]

    let mockRoute = Route(
        id: 1,
        name: "Route SF-001",
        description: "Downtown SF delivery route",
        originAddress: "123 Main St, SF",
        originLat: 37.7749,
        originLon: -122.4194,
        destinationAddress: "789 Pine Rd, SF",
        destinationLat: 37.7949,
        destinationLon: -122.4394,
        geofencePolygonJson: nil,
        routePolylineJson: nil,
        bufferMeters: 100,
        status: "IN_TRANSIT",
        stops: mockStops,
        createdAt: nil,
        updatedAt: nil
    )

    TransferMapSheet(transfer: mockTransfer, route: mockRoute)
}
