//
//  LiveTrackingView.swift
//  BuneIOS
//
//  Created by techvvs001 on 4/6/26.
//

import SwiftUI
import CoreLocation

struct LiveTrackingView: View {
    @StateObject private var viewModel: LiveTrackingViewModel
    @StateObject private var gpsService = GPSTrackingService()
    @State private var showDeliveryScan = false
    @State private var showPickupScan = false
    let transferId: Int
    let apiClient: TransportAPIClient

    init(transferId: Int, apiClient: TransportAPIClient) {
        self.transferId = transferId
        self.apiClient = apiClient
        _viewModel = StateObject(wrappedValue: LiveTrackingViewModel(transferId: transferId, apiClient: apiClient))
    }

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [
                    BuneColors.backgroundPrimary,
                    BuneColors.backgroundSecondary,
                    BuneColors.backgroundTertiary
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    // MARK: - Section 1: Progress Bar
                    if let status = viewModel.trackingStatus?.status {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Transfer Progress")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(BuneColors.textSecondary)
                                .padding(.horizontal, 16)
                                .padding(.top, 16)

                            TransferProgressBar(currentStatus: status, compact: false)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 16)
                        }
                        .glassCard()
                    }

                    // MARK: - Section 2: Status Banner
                    if let status = viewModel.trackingStatus?.status {
                        VStack(spacing: 16) {
                            // Status icon and text
                            VStack(spacing: 8) {
                                Image(systemName: statusIcon(status))
                                    .font(.system(size: 44, weight: .semibold))
                                    .foregroundColor(BuneColors.statusColor(for: status))

                                Text(viewModel.statusText)
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(BuneColors.textPrimary)
                            }

                            Divider()
                                .background(Color.white.opacity(0.1))

                            // ETA and overdue badge
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("ETA")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(BuneColors.textSecondary)

                                    Text(viewModel.etaText)
                                        .font(.system(.body, design: .monospaced))
                                        .fontWeight(.semibold)
                                        .foregroundColor(BuneColors.textPrimary)
                                }

                                Spacer()

                                if viewModel.trackingStatus?.statusProgress ?? 0 > 80 {
                                    VStack(spacing: 4) {
                                        Text("OVERDUE")
                                            .font(.caption2)
                                            .fontWeight(.bold)
                                            .foregroundColor(BuneColors.errorColor)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(
                                                Capsule()
                                                    .fill(BuneColors.errorColor.opacity(0.2))
                                                    .overlay(
                                                        Capsule()
                                                            .stroke(BuneColors.errorColor.opacity(0.5), lineWidth: 1)
                                                    )
                                            )
                                    }
                                }
                            }
                        }
                        .padding(16)
                        .glassCard()
                    }

                    // MARK: - Section 3: Transfer Info
                    if let transfer = viewModel.trackingStatus {
                        VStack(spacing: 16) {
                            // Manifest
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Manifest")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(BuneColors.textSecondary)

                                Text(viewModel.manifestNumber)
                                    .font(.system(.body, design: .monospaced))
                                    .fontWeight(.semibold)
                                    .foregroundColor(BuneColors.textPrimary)
                                    .textSelection(.enabled)
                            }

                            Divider()
                                .background(Color.white.opacity(0.1))

                            // Route
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("From")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundColor(BuneColors.textSecondary)

                                        Text(viewModel.originLocation)
                                            .font(.callout)
                                            .fontWeight(.semibold)
                                            .foregroundColor(BuneColors.textPrimary)
                                            .lineLimit(2)
                                    }

                                    Image(systemName: "arrow.right")
                                        .foregroundColor(BuneColors.textSecondary)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("To")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundColor(BuneColors.textSecondary)

                                        Text(viewModel.destinationLocation)
                                            .font(.callout)
                                            .fontWeight(.semibold)
                                            .foregroundColor(BuneColors.textPrimary)
                                            .lineLimit(2)
                                    }
                                }
                            }

                            Divider()
                                .background(Color.white.opacity(0.1))

                            // Driver & Vehicle
                            VStack(spacing: 12) {
                                HStack(spacing: 12) {
                                    Image(systemName: "person.fill")
                                        .foregroundColor(BuneColors.accentPrimary)
                                        .frame(width: 24)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Driver")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundColor(BuneColors.textSecondary)

                                        Text(viewModel.driverName)
                                            .font(.callout)
                                            .fontWeight(.semibold)
                                            .foregroundColor(BuneColors.textPrimary)
                                    }

                                    Spacer()
                                }

                                HStack(spacing: 12) {
                                    Image(systemName: "car.fill")
                                        .foregroundColor(BuneColors.accentPrimary)
                                        .frame(width: 24)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Vehicle")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundColor(BuneColors.textSecondary)

                                        Text(viewModel.vehiclePlate)
                                            .font(.system(.callout, design: .monospaced))
                                            .fontWeight(.semibold)
                                            .foregroundColor(BuneColors.textPrimary)
                                    }

                                    Spacer()
                                }
                            }
                        }
                        .padding(16)
                        .glassCard()
                    }

                    // MARK: - Section 4: Driver Actions
                    VStack(spacing: 12) {
                        // Depart button
                        if viewModel.canDepart {
                            Button(action: {
                                Task {
                                    await viewModel.depart()
                                }
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "play.circle.fill")
                                    Text("Depart")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .accentButton()
                            .disabled(viewModel.isLoading)
                        }

                        // Pickup scan navigation
                        if viewModel.canPickup && !viewModel.hasPickupSession {
                            NavigationLink(destination: PickupScanView(apiClient: apiClient)) {
                                HStack(spacing: 8) {
                                    Image(systemName: "qrcode.viewfinder")
                                    Text("Pickup Scan")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .accentButton()
                        }

                        // Resume pickup
                        if viewModel.hasPickupSession {
                            NavigationLink(destination: PickupScanView(apiClient: apiClient)) {
                                HStack(spacing: 8) {
                                    Image(systemName: "arrow.uturn.right")
                                    Text("Resume Pickup")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .accentButton()
                        }

                        // Mark delivered button
                        if viewModel.canDeliver {
                            Button(action: {
                                Task {
                                    await viewModel.markDelivered()
                                }
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("Mark Delivered")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .accentButton()
                            .disabled(viewModel.isLoading)
                        }

                        // Delivery scan navigation
                        if viewModel.trackingStatus?.status.uppercased() == "DELIVERED" && !viewModel.hasDeliverySession {
                            NavigationLink(destination: DeliveryScanView(apiClient: apiClient)) {
                                HStack(spacing: 8) {
                                    Image(systemName: "signature")
                                    Text("Delivery Scan")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .accentButton()
                        }

                        // Resume delivery
                        if viewModel.hasDeliverySession {
                            NavigationLink(destination: DeliveryScanView(apiClient: apiClient)) {
                                HStack(spacing: 8) {
                                    Image(systemName: "arrow.uturn.right")
                                    Text("Resume Delivery")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .accentButton()
                        }

                        // Ping location button
                        Button(action: {
                            if let location = gpsService.currentLocation {
                                Task {
                                    await viewModel.pingLocation(
                                        latitude: location.coordinate.latitude,
                                        longitude: location.coordinate.longitude
                                    )
                                }
                            }
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "location.fill")
                                Text("Ping Location")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .foregroundColor(BuneColors.textPrimary)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.white.opacity(0.08))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                    )
                            )
                        }
                        .disabled(gpsService.currentLocation == nil)
                    }
                    .padding(16)
                    .glassCard()

                    // MARK: - Section 5: GPS Status
                    VStack(spacing: 12) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(gpsService.isTracking ? BuneColors.successColor : BuneColors.textMuted)
                                .frame(width: 8, height: 8)

                            Text(gpsService.isTracking ? "GPS Active" : "GPS Inactive")
                                .font(.callout)
                                .fontWeight(.semibold)
                                .foregroundColor(BuneColors.textPrimary)

                            Spacer()
                        }

                        if let lastPing = gpsService.lastPingTime {
                            HStack(spacing: 8) {
                                Image(systemName: "clock.fill")
                                    .font(.caption)
                                    .foregroundColor(BuneColors.textSecondary)

                                let formatter = RelativeDateTimeFormatter()
                                Text("Last ping: \(formatter.localizedString(for: lastPing, relativeTo: Date()))")
                                    .font(.caption)
                                    .foregroundColor(BuneColors.textSecondary)

                                Spacer()
                            }
                        }

                        if gpsService.pendingPingCount > 0 {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.caption)
                                    .foregroundColor(BuneColors.warningColor)

                                Text("\(gpsService.pendingPingCount) pending ping\(gpsService.pendingPingCount == 1 ? "" : "s")")
                                    .font(.caption)
                                    .foregroundColor(BuneColors.warningColor)

                                Spacer()
                            }
                        }
                    }
                    .padding(16)
                    .glassCard()

                    // Error message
                    if let error = viewModel.errorMessage {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .font(.body)
                                    .foregroundColor(BuneColors.errorColor)

                                Text("Error")
                                    .font(.callout)
                                    .fontWeight(.semibold)
                                    .foregroundColor(BuneColors.errorColor)

                                Spacer()
                            }

                            Text(error)
                                .font(.caption)
                                .foregroundColor(BuneColors.textSecondary)
                                .lineLimit(3)
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(BuneColors.errorColor.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(BuneColors.errorColor.opacity(0.3), lineWidth: 1)
                                )
                        )
                        .padding(.horizontal, 16)
                    }

                    // Loading indicator
                    if viewModel.isLoading {
                        HStack(spacing: 8) {
                            ProgressView()
                                .tint(BuneColors.accentPrimary)

                            Text("Updating...")
                                .font(.caption)
                                .foregroundColor(BuneColors.textSecondary)

                            Spacer()
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.white.opacity(0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )
                        )
                        .padding(.horizontal, 16)
                    }

                    Spacer(minLength: 20)
                }
                .padding(.vertical, 20)
            }
        }
        .navigationTitle("Live Tracking")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadStatus()
            viewModel.startPolling()
            gpsService.requestPermission()
            if let status = viewModel.trackingStatus?.status,
               status.uppercased() == "IN_TRANSIT" {
                gpsService.startTracking(transferId: transferId, vehicleId: 0, apiClient: apiClient)
            }
        }
        .onDisappear {
            viewModel.stopPolling()
            gpsService.stopTracking()
        }
    }

    private func statusIcon(_ status: String) -> String {
        switch status.uppercased() {
        case "CREATED":
            return "circle.dashed"
        case "DISPATCH":
            return "truck.box.fill"
        case "AT_HUB":
            return "building.2.fill"
        case "IN_TRANSIT":
            return "location.fill"
        case "DELIVERED":
            return "checkmark.circle.fill"
        case "ACCEPTED":
            return "hand.thumbsup.fill"
        case "CANCELED":
            return "xmark.circle.fill"
        default:
            return "questionmark.circle.fill"
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        LiveTrackingView(
            transferId: 1,
            apiClient: TransportAPIClient(authService: AuthService())
        )
    }
}
