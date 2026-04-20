//
//  RouteMapView.swift
//  BuneIOS
//
//  Created by techvvs001 on 4/6/26.
//

import SwiftUI
import MapKit
import CoreLocation

extension CLLocationCoordinate2D: @retroactive Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}

struct RouteMapView: View {
    let route: Route?
    let stops: [RouteStop]
    let vehicleLocation: CLLocationCoordinate2D?
    let locationHistory: [CLLocationCoordinate2D]

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var isAutoFollowing = false

    var body: some View {
        ZStack {
            Map(position: $cameraPosition) {
                // Route stops as numbered markers
                ForEach(stops) { stop in
                    if let lat = stop.lat, let lon = stop.lon {
                        Annotation("Stop \(stop.stopOrder)", coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon)) {
                            StopMarkerView(stopNumber: stop.stopOrder, name: stop.name ?? "")
                        }
                    }
                }

                // Planned route — prefer the backend's road-following polyline
                // (route.routePolylineJson, populated by the dashboard's
                // auto-corridor directions call) and fall back to straight
                // lines between stops if no polyline has been generated yet.
                if let roadPoints = routePolylineCoordinates, roadPoints.count >= 2 {
                    MapPolyline(coordinates: roadPoints)
                        .stroke(BuneColors.accentPrimary, lineWidth: 3)
                } else if stops.count >= 2 {
                    MapPolyline(coordinates: stopCoordinates)
                        .stroke(BuneColors.accentPrimary, lineWidth: 3)
                }

                // Vehicle location history trail — dashed polyline connecting
                // the ping points, plus a small marker at each ping.
                if locationHistory.count >= 2 {
                    MapPolyline(coordinates: locationHistory)
                        .stroke(
                            BuneColors.accentPrimary.opacity(0.6),
                            style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [4, 4])
                        )
                }
                ForEach(Array(locationHistory.enumerated()), id: \.offset) { _, coord in
                    Annotation("", coordinate: coord, anchor: .center) {
                        Circle()
                            .fill(BuneColors.accentPrimary.opacity(0.4))
                            .frame(width: 6, height: 6)
                    }
                }

                // Current vehicle position (prominent marker)
                if let vehicle = vehicleLocation {
                    Annotation("Vehicle", coordinate: vehicle) {
                        VehicleMarkerView()
                    }
                }
            }
            .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
            .mapControlVisibility(.hidden)

            // Overlay: custom map controls in bottom-right
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        // Zoom to fit button
                        Button {
                            withAnimation {
                                cameraPosition = .automatic
                                isAutoFollowing = false
                            }
                        } label: {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .mapControlStyle()
                        }

                        // Center on vehicle button (if vehicle exists)
                        if vehicleLocation != nil {
                            Button {
                                withAnimation {
                                    isAutoFollowing = true
                                    centerOnVehicle()
                                }
                            } label: {
                                Image(systemName: "location.fill")
                                    .mapControlStyle()
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .onChange(of: vehicleLocation) { _, newLocation in
            if isAutoFollowing, let newLocation = newLocation {
                withAnimation {
                    cameraPosition = .region(
                        MKCoordinateRegion(
                            center: newLocation,
                            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                        )
                    )
                }
            }
        }
    }

    private var stopCoordinates: [CLLocationCoordinate2D] {
        stops.compactMap { stop in
            guard let lat = stop.lat, let lon = stop.lon else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
    }

    /// Decoded form of `route.routePolylineJson`. Backend stores a JSON
    /// array of `{lat, lng}` objects (see GeofenceService.decodePolyline +
    /// TransportDashboardController:/api/routes/{id}/auto-corridor). Returns
    /// nil if the route hasn't had a polyline generated yet.
    private var routePolylineCoordinates: [CLLocationCoordinate2D]? {
        guard let json = route?.routePolylineJson,
              let data = json.data(using: .utf8),
              let raw = try? JSONSerialization.jsonObject(with: data) as? [[String: Double]] else {
            return nil
        }
        let coords = raw.compactMap { dict -> CLLocationCoordinate2D? in
            guard let lat = dict["lat"], let lon = dict["lng"] ?? dict["lon"] else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        return coords.count >= 2 ? coords : nil
    }

    private func centerOnVehicle() {
        guard let vehicle = vehicleLocation else { return }
        cameraPosition = .region(
            MKCoordinateRegion(
                center: vehicle,
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
        )
    }
}

// MARK: - MapControl Style Extension
extension View {
    func mapControlStyle() -> some View {
        self
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(.white)
            .frame(width: 40, height: 40)
            .background(BuneColors.glassFill)
            .clipShape(Circle())
            .overlay(Circle().stroke(BuneColors.glassBorder, lineWidth: 1))
    }
}

// MARK: - Preview
#Preview {
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
            name: "Delivery Point B",
            lat: 37.7849,
            lon: -122.4294,
            address: "456 Oak Ave, SF",
            stopType: "delivery",
            estimatedMinutes: 15,
            createdAt: nil
        ),
        RouteStop(
            id: 3,
            stopOrder: 3,
            name: "Final Destination",
            lat: 37.7949,
            lon: -122.4394,
            address: "789 Pine Rd, SF",
            stopType: "delivery",
            estimatedMinutes: 30,
            createdAt: nil
        )
    ]

    let mockRoute = Route(
        id: 1,
        name: "Route SF-001",
        description: "Downtown delivery route",
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

    let mockVehicleLocation = CLLocationCoordinate2D(latitude: 37.7849, longitude: -122.4294)
    let mockLocationHistory = [
        CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        CLLocationCoordinate2D(latitude: 37.7785, longitude: -122.4224),
        CLLocationCoordinate2D(latitude: 37.7820, longitude: -122.4260)
    ]

    return RouteMapView(
        route: mockRoute,
        stops: mockStops,
        vehicleLocation: mockVehicleLocation,
        locationHistory: mockLocationHistory
    )
}
