//
//  ZoneManagerView.swift
//  BuneIOS
//
//  Created by techvvs001 on 4/6/26.
//

import SwiftUI

struct ZoneManagerView: View {
    @StateObject private var viewModel: ZoneManagerViewModel
    @State private var scanInput = ""
    @State private var selectedAction = "ADD"

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    /// The location we're managing zones for. Required — zones are
    /// location-scoped on the backend. Callers typically pick from
    /// apiClient.listLocations() first.
    let location: Location

    init(apiClient: TransportAPIClient, location: Location) {
        self.location = location
        let vm = ZoneManagerViewModel(apiClient: apiClient)
        vm.locationId = location.id
        _viewModel = StateObject(wrappedValue: vm)
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

            VStack(spacing: 24) {
                // Header
                Text("Zone Manager")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(BuneColors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ScrollView {
                    VStack(spacing: 24) {
                        zoneGrid

                        if let selectedZone = viewModel.selectedZone {
                            selectedZoneDetail(selectedZone)
                        }

                        errorMessageView
                    }
                }
            }
            .padding(20)

            loadingOverlay
        }
        .task {
            await viewModel.loadZones()
        }
    }

    // MARK: - Zone Grid

    private var zoneGrid: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(viewModel.zones) { zone in
                ZoneCard(
                    zone: zone,
                    isSelected: viewModel.selectedZone?.id == zone.id
                )
                .onTapGesture {
                    Task {
                        await viewModel.selectZone(zone)
                    }
                }
            }
        }
    }

    // MARK: - Selected Zone Detail

    private func selectedZoneDetail(_ selectedZone: Zone) -> some View {
        VStack(spacing: 16) {
            zoneHeader(selectedZone)

            Divider()
                .background(Color.white.opacity(0.1))

            scanInputSection

            actionPickerSection

            Divider()
                .background(Color.white.opacity(0.1))

            zonePackagesList

            Divider()
                .background(Color.white.opacity(0.1))

            recentScansSection
        }
        .padding(16)
        .glassCard()
    }

    // MARK: - Zone Header

    private func zoneHeader(_ zone: Zone) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(zone.name)
                    .font(.headline)
                    .foregroundColor(BuneColors.textPrimary)

                Spacer()

                ZoneTypeBadge(zoneType: zone.zoneType)
            }

            if let count = zone.packageCount {
                Text("\(count) package(s)")
                    .font(.caption)
                    .foregroundColor(BuneColors.textSecondary)
            }
        }
    }

    // MARK: - Scan Input

    private var scanInputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Scan Package")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(BuneColors.textSecondary)

            ScanInputField(
                text: $scanInput,
                placeholder: "Scan METRC barcode",
                onSubmit: {
                    Task {
                        await viewModel.scanPackage(label: scanInput, action: selectedAction)
                        scanInput = ""
                    }
                }
            )
        }
    }

    // MARK: - Action Picker

    private var actionPickerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Action")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(BuneColors.textSecondary)

            Picker("Action", selection: $selectedAction) {
                Text("Add").tag("ADD")
                Text("Remove").tag("REMOVE")
            }
            .pickerStyle(.segmented)
            .tint(BuneColors.accentPrimary)
        }
    }

    // MARK: - Zone Packages List

    private var zonePackagesList: some View {
        Group {
            if !viewModel.zonePackages.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Zone Contents")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(BuneColors.textSecondary)

                    VStack(spacing: 8) {
                        ForEach(viewModel.zonePackages) { package in
                            ZonePackageRow(package: package) {
                                Task {
                                    await viewModel.scanPackage(
                                        label: package.packageLabel,
                                        action: "REMOVE"
                                    )
                                }
                            }
                        }
                    }
                }
            } else {
                Text("No packages in zone")
                    .font(.caption)
                    .foregroundColor(BuneColors.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(16)
            }
        }
    }

    // MARK: - Recent Scans

    private var recentScansSection: some View {
        Group {
            if !viewModel.recentScans.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Recent Scans")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(BuneColors.textSecondary)

                    VStack(spacing: 8) {
                        ForEach(viewModel.recentScans.prefix(5)) { audit in
                            ScanAuditRow(audit: audit)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Error Message

    @ViewBuilder
    private var errorMessageView: some View {
        if let error = viewModel.errorMessage {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(BuneColors.errorColor)

                Text(error)
                    .font(.caption)
                    .foregroundColor(BuneColors.errorColor)

                Spacer()
            }
            .padding(12)
            .background(BuneColors.errorColor.opacity(0.1))
            .cornerRadius(8)
        }
    }

    // MARK: - Loading Overlay

    @ViewBuilder
    private var loadingOverlay: some View {
        if viewModel.isLoading {
            ZStack {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()

                VStack(spacing: 12) {
                    ProgressView()
                        .tint(BuneColors.accentPrimary)

                    Text("Loading...")
                        .font(.caption)
                        .foregroundColor(BuneColors.textSecondary)
                }
            }
        }
    }
}

// MARK: - Zone Package Row

struct ZonePackageRow: View {
    let package: Package
    let onRemove: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(package.packageLabel)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(BuneColors.textPrimary)

                if let productName = package.productName {
                    Text(productName)
                        .font(.caption2)
                        .foregroundColor(BuneColors.textSecondary)
                }
            }

            Spacer()

            Button(action: onRemove) {
                Image(systemName: "trash.fill")
                    .font(.caption)
                    .foregroundColor(BuneColors.errorColor)
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
    }
}

// MARK: - Zone Card

struct ZoneCard: View {
    let zone: Zone
    let isSelected: Bool

    var zoneColor: Color {
        switch zone.zoneType {
        case "ORIGINATOR":
            return BuneColors.infoColor
        case "VEHICLE":
            return BuneColors.statusDispatch
        default:
            return BuneColors.accentPrimary
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(zone.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(BuneColors.textPrimary)

                Spacer()

                ZoneTypeBadge(zoneType: zone.zoneType)
            }

            HStack(spacing: 8) {
                Image(systemName: "shippingbox.fill")
                    .font(.caption)
                    .foregroundColor(zoneColor)

                Text("\(zone.packageCount ?? 0)")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(BuneColors.textSecondary)

                Spacer()
            }
        }
        .padding(14)
        .glassCard(cornerRadius: 16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    isSelected ? zoneColor : Color.clear,
                    lineWidth: 2
                )
        )
    }
}

// MARK: - Zone Type Badge

struct ZoneTypeBadge: View {
    let zoneType: String

    var badgeColor: Color {
        switch zoneType {
        case "ORIGINATOR":
            return BuneColors.infoColor
        case "VEHICLE":
            return BuneColors.statusDispatch
        default:
            return BuneColors.accentPrimary
        }
    }

    var body: some View {
        Text(zoneType.replacingOccurrences(of: "_", with: " "))
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(badgeColor.opacity(0.7))
            )
    }
}

// MARK: - Scan Audit Row

struct ScanAuditRow: View {
    let audit: ZoneScanAudit

    var actionColor: Color {
        switch audit.action {
        case "ADD":
            return BuneColors.successColor
        case "REMOVE":
            return BuneColors.errorColor
        default:
            return BuneColors.accentPrimary
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(audit.success ? actionColor : BuneColors.errorColor)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(audit.packageLabel)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(BuneColors.textPrimary)

                    Spacer()

                    Text(audit.action)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(actionColor)
                }

                HStack {
                    if let scannedBy = audit.scannedBy {
                        Text(scannedBy)
                            .font(.caption2)
                            .foregroundColor(BuneColors.textTertiary)
                    }

                    Spacer()

                    if let scannedAt = audit.scannedAt {
                        Text(formattedTime(scannedAt))
                            .font(.caption2)
                            .foregroundColor(BuneColors.textMuted)
                    }
                }
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.03))
        .cornerRadius(6)
    }

    private func formattedTime(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            let timeFormatter = DateFormatter()
            timeFormatter.timeStyle = .short
            return timeFormatter.string(from: date)
        }
        return dateString
    }
}

// MARK: - Preview

#Preview {
    ZoneManagerView(
        apiClient: TransportAPIClient(authService: AuthService()),
        location: Location(
            id: 1,
            name: "Demo Hub",
            licenseNumber: nil,
            facilityType: nil,
            address: nil
        )
    )
}
