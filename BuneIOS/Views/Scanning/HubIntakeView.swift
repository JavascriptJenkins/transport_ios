//
//  HubIntakeView.swift
//  BuneIOS
//
//  4-phase UI for the hub intake workflow:
//    1. selectTransfer — pick an IN_TRANSIT transfer arriving at this hub
//    2. selectZone     — pick the location + STANDARD zone to stage into
//    3. scanning       — scan each package, server counts STANDARD-zone hits
//    4. complete       — session finalized; backend advances status to AT_HUB
//
//  Scan UI patterned after PickupScanView so drivers see consistent controls
//  across pickup / delivery / hub intake.
//

import SwiftUI

struct HubIntakeView: View {
    @StateObject private var viewModel: HubIntakeViewModel
    @State private var scanInput: String = ""
    @State private var showAbandonConfirm = false
    @FocusState private var scanFieldFocused: Bool

    init(apiClient: TransportAPIClient) {
        _viewModel = StateObject(wrappedValue: HubIntakeViewModel(apiClient: apiClient))
    }

    var body: some View {
        ZStack {
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

            VStack(spacing: 0) {
                header
                Group {
                    switch viewModel.phase {
                    case .selectTransfer: selectTransferPhase
                    case .selectZone:     selectZonePhase
                    case .scanning:       scanningPhase
                    case .complete:       completePhase
                    }
                }
            }
        }
        .task {
            if viewModel.phase == .selectTransfer && viewModel.availableTransfers.isEmpty {
                await viewModel.loadTransfers()
            }
        }
        .alert("Abandon Hub Intake?", isPresented: $showAbandonConfirm) {
            Button("Abandon", role: .destructive) {
                Task { await viewModel.abandonSession() }
            }
            Button("Keep Scanning", role: .cancel) {}
        } message: {
            Text("The session will be marked abandoned on the server. Any packages already scanned into the zone stay where they are.")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Hub Intake")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(BuneColors.textPrimary)
                if let transfer = viewModel.selectedTransfer {
                    Text(transfer.manifestNumber ?? "—")
                        .font(.caption2)
                        .foregroundColor(BuneColors.textSecondary)
                }
            }

            Spacer()

            if viewModel.phase == .scanning {
                Button(action: { showAbandonConfirm = true }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(BuneColors.textSecondary)
                }
            } else if viewModel.phase == .complete {
                Button("Done") { viewModel.reset() }
                    .foregroundColor(BuneColors.accentPrimary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.black.opacity(0.2))
    }

    // MARK: - Phase 1: Select Transfer

    private var selectTransferPhase: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                phaseTitle(
                    "Incoming Transfers",
                    subtitle: "Pick the manifest arriving at this hub."
                )

                if let error = viewModel.errorMessage {
                    errorBanner(error)
                }

                if viewModel.isLoading && viewModel.availableTransfers.isEmpty {
                    ProgressView().tint(BuneColors.accentPrimary)
                        .frame(maxWidth: .infinity, minHeight: 140)
                } else if viewModel.availableTransfers.isEmpty {
                    emptyState(
                        icon: "tray",
                        title: "No transfers in transit",
                        message: "Nothing is currently inbound. Pull to refresh when a driver marks a trip in transit."
                    )
                } else {
                    ForEach(viewModel.availableTransfers) { transfer in
                        Button {
                            Task { await viewModel.selectTransfer(transfer) }
                        } label: {
                            transferRow(transfer)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(20)
        }
        .refreshable { await viewModel.loadTransfers() }
    }

    private func transferRow(_ transfer: Transfer) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(transfer.manifestNumber ?? "Unknown manifest")
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.semibold)
                    .foregroundColor(BuneColors.accentPrimary)
                if let shipper = transfer.shipperFacilityName {
                    Text("From: \(shipper)")
                        .font(.caption)
                        .foregroundColor(BuneColors.textSecondary)
                }
                Text("\(transfer.packageCount ?? 0) packages")
                    .font(.caption2)
                    .foregroundColor(BuneColors.textTertiary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(BuneColors.textTertiary)
        }
        .padding(14)
        .background(BuneColors.backgroundTertiary.opacity(0.5))
        .cornerRadius(12)
    }

    // MARK: - Phase 2: Select Zone

    private var selectZonePhase: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                phaseTitle(
                    "Where are you staging?",
                    subtitle: "Pick the hub zone you'll be scanning packages into."
                )

                if let error = viewModel.errorMessage {
                    errorBanner(error)
                }

                // Location picker — skip when exactly one location exists
                // (VM auto-selects it).
                if viewModel.locations.count > 1 {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Location")
                            .font(.caption)
                            .foregroundColor(BuneColors.textTertiary)
                        ForEach(viewModel.locations) { location in
                            Button {
                                Task { await viewModel.selectLocation(location) }
                            } label: {
                                HStack {
                                    Text(location.name ?? "Location \(location.id)")
                                        .foregroundColor(BuneColors.textPrimary)
                                    Spacer()
                                    if viewModel.selectedLocation?.id == location.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(BuneColors.accentPrimary)
                                    }
                                }
                                .padding(12)
                                .background(BuneColors.backgroundTertiary.opacity(0.5))
                                .cornerRadius(10)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Zone picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Hub Zone")
                        .font(.caption)
                        .foregroundColor(BuneColors.textTertiary)

                    if viewModel.selectedLocation == nil && viewModel.locations.count > 1 {
                        Text("Select a location first.")
                            .font(.footnote)
                            .foregroundColor(BuneColors.textSecondary)
                    } else if viewModel.zones.isEmpty {
                        emptyState(
                            icon: "square.dashed",
                            title: "No zones yet",
                            message: "Add a zone to this location on the web dashboard first."
                        )
                    } else {
                        ForEach(viewModel.zones) { zone in
                            Button {
                                Task { await viewModel.startSession(zone: zone) }
                            } label: {
                                HStack {
                                    Text(zone.name ?? "Zone \(zone.id)")
                                        .foregroundColor(BuneColors.textPrimary)
                                    Spacer()
                                    if !zone.zoneType.isEmpty {
                                        Text(zone.zoneType)
                                            .font(.caption2)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(BuneColors.glassFill)
                                            .cornerRadius(6)
                                            .foregroundColor(BuneColors.textSecondary)
                                    }
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(BuneColors.textTertiary)
                                }
                                .padding(12)
                                .background(BuneColors.backgroundTertiary.opacity(0.5))
                                .cornerRadius(10)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Button {
                    viewModel.reset()
                } label: {
                    Text("Back to transfer list")
                        .font(.footnote)
                        .foregroundColor(BuneColors.textSecondary)
                }
                .padding(.top, 8)
            }
            .padding(20)
        }
    }

    // MARK: - Phase 3: Scanning

    private var scanningPhase: some View {
        VStack(spacing: 16) {
            // Progress card
            VStack(spacing: 10) {
                HStack {
                    Text(viewModel.progressLabel)
                        .font(.system(.title2, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(BuneColors.textPrimary)
                    Spacer()
                    if let zone = viewModel.selectedZone {
                        Label(zone.name ?? "Zone", systemImage: "square.grid.2x2.fill")
                            .font(.caption)
                            .foregroundColor(BuneColors.accentPrimary)
                    }
                }
                ProgressView(value: viewModel.progress)
                    .tint(BuneColors.accentPrimary)
                if viewModel.wasResumed {
                    Text("Resuming an existing session")
                        .font(.caption2)
                        .foregroundColor(BuneColors.textTertiary)
                }
            }
            .padding(16)
            .background(BuneColors.backgroundTertiary.opacity(0.5))
            .cornerRadius(12)
            .padding(.horizontal, 20)
            .padding(.top, 16)

            // Scan input
            HStack(spacing: 12) {
                Image(systemName: "barcode.viewfinder")
                    .foregroundColor(BuneColors.accentPrimary)
                TextField("", text: $scanInput,
                          prompt: Text("Scan or enter METRC label")
                            .foregroundColor(BuneColors.textTertiary))
                    .focused($scanFieldFocused)
                    .autocapitalization(.allCharacters)
                    .disableAutocorrection(true)
                    .foregroundColor(BuneColors.textPrimary)
                    .onSubmit { submitScan() }
                if !scanInput.isEmpty {
                    Button { scanInput = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(BuneColors.textTertiary)
                    }
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(BuneColors.glassFill)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(BuneColors.glassBorder, lineWidth: 1))
            )
            .padding(.horizontal, 20)

            Button(action: submitScan) {
                Text("Scan Into Zone")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [
                                Color(red: 0.35, green: 0.25, blue: 0.65),
                                Color(red: 0.25, green: 0.18, blue: 0.50)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .disabled(scanInput.trimmingCharacters(in: .whitespaces).isEmpty)
            .opacity(scanInput.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1.0)
            .padding(.horizontal, 20)

            if let error = viewModel.errorMessage {
                errorBanner(error)
                    .padding(.horizontal, 20)
            }

            // Package checklist — tap to scan each package into the chosen
            // zone. The transfer's full package list is fetched when the
            // session starts; rows the user has already scanned in this
            // session render as checked off.
            ScrollView {
                LazyVStack(spacing: 8) {
                    if viewModel.transferPackages.isEmpty {
                        // Backend package list hasn't loaded (or is empty for
                        // this transfer). Fall back to the "recently scanned"
                        // log so the user still sees progress.
                        ForEach(viewModel.scannedLabels.reversed(), id: \.self) { label in
                            scannedChip(label)
                        }
                    } else {
                        ForEach(viewModel.transferPackages, id: \.id) { pkg in
                            HubIntakePackageRow(
                                packageLabel: pkg.packageLabel,
                                productName: pkg.productName,
                                scanned: viewModel.scannedLabels.contains(pkg.packageLabel)
                            ) {
                                Task { await viewModel.scanPackage(pkg.packageLabel) }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }

            Button {
                Task { await viewModel.completeSession() }
            } label: {
                HStack {
                    Spacer()
                    if viewModel.isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text(viewModel.canComplete ? "Complete Intake" : "Complete Anyway")
                            .font(.headline)
                    }
                    Spacer()
                }
                .padding(.vertical, 14)
                .background(
                    viewModel.canComplete
                        ? BuneColors.statusDelivered
                        : BuneColors.backgroundTertiary
                )
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(viewModel.isLoading)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }

    private func submitScan() {
        let label = scanInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !label.isEmpty else { return }
        scanInput = ""
        scanFieldFocused = true
        Task { await viewModel.scanPackage(label) }
    }

    // MARK: - Phase 4: Complete

    private var completePhase: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: viewModel.statusAdvanced ? "checkmark.seal.fill" : "checkmark.circle")
                .font(.system(size: 72))
                .foregroundColor(BuneColors.statusDelivered)
            Text(viewModel.statusAdvanced ? "Transfer at hub" : "Intake complete")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(BuneColors.textPrimary)
            Text(viewModel.statusAdvanced
                 ? "All packages are staged and the manifest has advanced to AT_HUB."
                 : "Session marked complete. Scan the remaining packages into a hub zone to auto-advance the transfer to AT_HUB.")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundColor(BuneColors.textSecondary)
                .padding(.horizontal, 32)

            Button("Start another intake") {
                viewModel.reset()
                Task { await viewModel.loadTransfers() }
            }
            .foregroundColor(BuneColors.accentPrimary)
            .padding(.top, 8)

            Spacer()
        }
    }

    // MARK: - Shared helpers

    private func phaseTitle(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
                .foregroundColor(BuneColors.textPrimary)
            Text(subtitle)
                .font(.footnote)
                .foregroundColor(BuneColors.textSecondary)
        }
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(Color(red: 1.0, green: 0.7, blue: 0.3))
            Text(message)
                .font(.caption)
                .foregroundColor(BuneColors.textPrimary)
        }
        .padding(10)
        .background(Color(red: 0.3, green: 0.15, blue: 0.05).opacity(0.4))
        .cornerRadius(8)
    }

    private func emptyState(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundColor(BuneColors.textTertiary)
            Text(title)
                .font(.headline)
                .foregroundColor(BuneColors.textPrimary)
            Text(message)
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundColor(BuneColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(BuneColors.backgroundTertiary.opacity(0.3))
        .cornerRadius(12)
    }

    /// Small row used when the transfer package list couldn't load —
    /// mirrors the original "recently scanned" chip style.
    private func scannedChip(_ label: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(BuneColors.statusDelivered)
            Text(label)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(BuneColors.textPrimary)
            Spacer()
        }
        .padding(10)
        .background(BuneColors.backgroundTertiary.opacity(0.4))
        .cornerRadius(8)
    }
}

// MARK: - Hub Intake Package Row

/// Tappable package checklist row matching the pickup/delivery row styling.
/// Tap an unscanned row to invoke the caller's onScan closure which runs
/// scanIntoZone under the hood. Scanned rows are visually checked off and
/// inert so rapid list-tapping doesn't accidentally re-trigger a scan.
private struct HubIntakePackageRow: View {
    let packageLabel: String
    let productName: String?
    let scanned: Bool
    let onScan: () -> Void

    var body: some View {
        Button {
            if !scanned { onScan() }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: scanned ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundColor(scanned ? BuneColors.statusDelivered : BuneColors.textTertiary)

                VStack(alignment: .leading, spacing: 4) {
                    Text(packageLabel)
                        .font(.system(.caption, design: .monospaced))
                        .fontWeight(.semibold)
                        .foregroundColor(BuneColors.textPrimary)
                    if let productName = productName, !productName.isEmpty {
                        Text(productName)
                            .font(.caption2)
                            .foregroundColor(BuneColors.textSecondary)
                    }
                }

                Spacer()

                if !scanned {
                    Text("Tap to scan")
                        .font(.caption2)
                        .foregroundColor(BuneColors.accentPrimary.opacity(0.8))
                }
            }
            .padding(12)
            .background(
                scanned
                    ? BuneColors.statusDelivered.opacity(0.10)
                    : Color.white.opacity(0.05)
            )
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .disabled(scanned)
    }
}
