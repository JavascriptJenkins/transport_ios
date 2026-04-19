//
//  PickupScanView.swift
//  BuneIOS
//
//  Created by techvvs001 on 4/6/26.
//

import SwiftUI

// MARK: - Pickup Scan View

struct PickupScanView: View {
    @StateObject private var viewModel: PickupScanViewModel
    @State private var showResumeAlert = false
    @State private var scannedLabel = ""
    @State private var manualEntryMode = false
    @Environment(\.dismiss) var dismiss

    init(apiClient: TransportAPIClient) {
        _viewModel = StateObject(wrappedValue: PickupScanViewModel(apiClient: apiClient))
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
                // Header
                HStack {
                    Text("Pickup Scan")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(BuneColors.textPrimary)

                    Spacer()

                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(BuneColors.textSecondary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color.black.opacity(0.2))

                // Content based on phase
                switch viewModel.currentPhase {
                case .selectTransfer:
                    selectTransferPhase
                case .scanning:
                    scanningPhase
                case .complete:
                    completePhase
                }
            }
        }
        .task {
            await viewModel.loadTransfers()
            await viewModel.checkForActiveSession()
        }
        .alert("Resume Session?", isPresented: $showResumeAlert) {
            Button("Resume") {
                if let transferId = viewModel.selectedTransfer?.id {
                    Task { await viewModel.startSession(transferId: transferId) }
                }
            }
            Button("New Session", role: .destructive) {
                viewModel.selectedTransfer = nil
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let transfer = viewModel.selectedTransfer {
                Text("An active session exists for \(transfer.manifestNumber ?? "Transfer #\(transfer.id)")")
            }
        }
    }

    // MARK: - Phase 1: Select Transfer

    private var selectTransferPhase: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Available Transfers")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(BuneColors.textPrimary)

                Text("Select a transfer to begin pickup scanning")
                    .font(.caption)
                    .foregroundColor(BuneColors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 20)

            // Explain why pickup is gated on DISPATCH status so users with a
            // CREATED transfer on the dashboard aren't confused when it's
            // missing here or blocked on tap.
            eligibilityInfoBanner
                .padding(.horizontal, 20)

            // Inline error (ineligible tap, network failure, etc).
            if let error = viewModel.errorMessage {
                eligibilityErrorBanner(error)
                    .padding(.horizontal, 20)
            }

            if viewModel.isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .tint(BuneColors.accentPrimary)
                    Text("Loading transfers...")
                        .foregroundColor(BuneColors.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else if viewModel.availableTransfers.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "inbox")
                        .font(.system(size: 40))
                        .foregroundColor(BuneColors.textTertiary)
                    Text("No transfers ready for pickup")
                        .foregroundColor(BuneColors.textSecondary)
                        .font(.subheadline)
                    Text("Transfers show up here once they've been dispatched from the Transfers tab.")
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .foregroundColor(BuneColors.textTertiary)
                        .padding(.horizontal, 32)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(viewModel.availableTransfers) { transfer in
                            let blocked = PickupScanViewModel.pickupBlockedReason(for: transfer)
                            TransferSelectRow(
                                transfer: transfer,
                                blockedReason: blocked
                            ) {
                                Task { await viewModel.startSession(transferId: transfer.id) }
                            }
                        }
                    }
                    .padding(20)
                }
            }

            Spacer()
        }
    }

    // MARK: - Eligibility banners

    private var eligibilityInfoBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "info.circle.fill")
                .foregroundColor(BuneColors.accentPrimary)
            VStack(alignment: .leading, spacing: 2) {
                Text("Only dispatched transfers can be picked up")
                    .font(.caption.bold())
                    .foregroundColor(BuneColors.textPrimary)
                Text("Transfers must be in DISPATCH or AT_HUB status. Anything still in CREATED status needs to be dispatched first from the Transfers tab.")
                    .font(.caption2)
                    .foregroundColor(BuneColors.textSecondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(BuneColors.accentPrimary.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(BuneColors.accentPrimary.opacity(0.35), lineWidth: 1)
                )
        )
    }

    private func eligibilityErrorBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(Color(red: 1.0, green: 0.6, blue: 0.3))
            VStack(alignment: .leading, spacing: 2) {
                Text("Can't start pickup")
                    .font(.caption.bold())
                    .foregroundColor(BuneColors.textPrimary)
                Text(message)
                    .font(.caption2)
                    .foregroundColor(BuneColors.textSecondary)
            }
            Spacer()
            Button {
                viewModel.errorMessage = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(BuneColors.textTertiary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(red: 0.3, green: 0.15, blue: 0.05).opacity(0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(red: 0.95, green: 0.61, blue: 0.07).opacity(0.35), lineWidth: 1)
                )
        )
    }

    // MARK: - Phase 2: Scanning

    private var scanningPhase: some View {
        VStack(spacing: 16) {
            // Session Info Card
            if let session = viewModel.scanSession, let transfer = viewModel.selectedTransfer {
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Manifest")
                                .font(.caption)
                                .foregroundColor(BuneColors.textTertiary)
                            Text(transfer.manifestNumber ?? "#\(transfer.id)")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(BuneColors.textPrimary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Progress")
                                .font(.caption)
                                .foregroundColor(BuneColors.textTertiary)
                            Text("\(session.scannedCount)/\(session.totalCount)")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(BuneColors.successColor)
                        }
                    }

                    // Progress Bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.white.opacity(0.1))

                            RoundedRectangle(cornerRadius: 6)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            BuneColors.accentPrimary,
                                            BuneColors.accentSecondary
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * viewModel.scanProgress)
                        }
                    }
                    .frame(height: 8)
                }
                .padding(16)
                .glassCard(cornerRadius: 14)
                .padding(20)
            }

            // Scanner or Manual Entry
            VStack(spacing: 12) {
                HStack {
                    Text("Scan Package")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(BuneColors.textPrimary)

                    Spacer()

                    Button(action: { manualEntryMode.toggle() }) {
                        HStack(spacing: 6) {
                            Image(systemName: manualEntryMode ? "barcode" : "keyboard")
                            Text(manualEntryMode ? "Scanner" : "Manual")
                        }
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(BuneColors.accentPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(BuneColors.accentPrimary.opacity(0.15))
                        .cornerRadius(8)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)

                if manualEntryMode {
                    ScanInputField(
                        text: $scannedLabel,
                        placeholder: "Enter barcode",
                        onSubmit: {
                            Task {
                                await viewModel.scanPackage(scannedLabel)
                                scannedLabel = ""
                            }
                        }
                    )
                    .padding(.horizontal, 20)
                } else {
                    // Placeholder for BarcodeScannerView (referenced from another agent)
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(BuneColors.glassBorder, lineWidth: 1)
                            )

                        VStack(spacing: 12) {
                            Image(systemName: "barcode.viewfinder")
                                .font(.system(size: 40))
                                .foregroundColor(BuneColors.accentPrimary)
                            Text("Point camera at barcode")
                                .font(.caption)
                                .foregroundColor(BuneColors.textSecondary)
                        }
                    }
                    .frame(height: 200)
                    .padding(.horizontal, 20)
                }
            }

            // Package Checklist
            VStack(alignment: .leading, spacing: 12) {
                Text("Packages")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(BuneColors.textPrimary)
                    .padding(.horizontal, 20)

                if let session = viewModel.scanSession {
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(Array(session.packages.enumerated()), id: \.element.label) { _, pkg in
                                PickupPackageRow(
                                    package: pkg,
                                    onScan: {
                                        // Tap-to-scan shortcut: lets testers
                                        // (and simulator users without a
                                        // camera) mark packages scanned
                                        // by tapping the row directly.
                                        Task {
                                            await viewModel.scanPackage(pkg.label)
                                        }
                                    },
                                    onUnscan: {
                                        Task {
                                            await viewModel.unscanPackage(pkg.label)
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .frame(maxHeight: 250)
                }
            }

            Spacer()

            // Complete Button
            if let session = viewModel.scanSession, session.scannedCount == session.totalCount {
                Button(action: {
                    Task { await viewModel.completePickup() }
                }) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Complete Pickup")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .accentButton()
                }
                .padding(20)
            } else {
                HStack {
                    Image(systemName: "lock.fill")
                    Text("Scan all packages to complete")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(BuneColors.textTertiary)
                .background(Color.white.opacity(0.05))
                .cornerRadius(14)
                .padding(20)
            }
        }
    }

    // MARK: - Phase 3: Complete

    private var completePhase: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    BuneColors.successColor.opacity(0.2),
                                    BuneColors.accentPrimary.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)

                    Image(systemName: "checkmark")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(BuneColors.successColor)
                }

                VStack(spacing: 8) {
                    Text("Transfer In Transit")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(BuneColors.textPrimary)

                    Text("Pickup completed successfully")
                        .font(.caption)
                        .foregroundColor(BuneColors.textSecondary)
                }
            }

            if let transfer = viewModel.selectedTransfer {
                VStack(spacing: 12) {
                    HStack {
                        Label("Manifest", systemImage: "doc.text")
                            .font(.caption)
                            .foregroundColor(BuneColors.textSecondary)
                        Spacer()
                        Text(transfer.manifestNumber ?? "#\(transfer.id)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(BuneColors.textPrimary)
                    }

                    Divider()
                        .background(Color.white.opacity(0.1))

                    HStack {
                        Label("Packages", systemImage: "shippingbox.fill")
                            .font(.caption)
                            .foregroundColor(BuneColors.textSecondary)
                        Spacer()
                        Text("\(transfer.packageCount ?? 0)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(BuneColors.textPrimary)
                    }
                }
                .padding(16)
                .glassCard(cornerRadius: 14)
            }

            Spacer()

            Button(action: {
                viewModel.reset()
                dismiss()
            }) {
                Text("Done")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .accentButton()
            }
        }
        .padding(20)
    }
}

// MARK: - Supporting Views

private struct TransferSelectRow: View {
    let transfer: Transfer
    /// When non-nil, the row still renders but is visually dimmed + tappable.
    /// Tapping surfaces the reason via the view model's errorMessage so the
    /// user knows why pickup can't start yet (e.g. CREATED status).
    let blockedReason: String?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(transfer.manifestNumber ?? "#\(transfer.id)")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(BuneColors.textPrimary)

                        statusChip
                    }

                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Origin")
                                .font(.caption2)
                                .foregroundColor(BuneColors.textTertiary)
                            Text(transfer.shipperFacilityName ?? "Unknown")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(BuneColors.textSecondary)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Packages")
                                .font(.caption2)
                                .foregroundColor(BuneColors.textTertiary)
                            Text("\(transfer.packageCount ?? 0)")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(BuneColors.textSecondary)
                        }
                    }

                    if let reason = blockedReason {
                        Text(reason)
                            .font(.caption2)
                            .foregroundColor(Color(red: 1.0, green: 0.6, blue: 0.3))
                            .padding(.top, 2)
                    }
                }

                Spacer()

                Image(systemName: blockedReason == nil ? "chevron.right" : "lock.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(BuneColors.textTertiary)
            }
            .padding(14)
            .glassCard(cornerRadius: 14)
            .opacity(blockedReason == nil ? 1.0 : 0.75)
        }
    }

    /// Small pill showing the transfer's current status so the driver
    /// knows at a glance why a row might not be pickup-able.
    private var statusChip: some View {
        let label = transfer.status
        let (fg, bg): (Color, Color) = {
            switch transfer.status.uppercased() {
            case "DISPATCH", "STAGED FOR PICKUP", "EN ROUTE TO PICKUP":
                return (BuneColors.statusDispatch, BuneColors.statusDispatch.opacity(0.18))
            case "AT_HUB", "AT HUB":
                return (BuneColors.statusAtHub, BuneColors.statusAtHub.opacity(0.18))
            case "CREATED":
                return (BuneColors.warningColor, BuneColors.warningColor.opacity(0.18))
            default:
                return (BuneColors.textTertiary, Color.white.opacity(0.08))
            }
        }()
        return Text(label)
            .font(.caption2.bold())
            .foregroundColor(fg)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(bg)
            .cornerRadius(6)
    }
}

private struct PickupPackageRow: View {
    let package: ScanPackage
    let onScan: () -> Void
    let onUnscan: () -> Void

    @State private var showUnscanConfirm = false

    var body: some View {
        Button {
            // Tap-to-scan when the row is unscanned. Scanned rows keep their
            // tap inert so the explicit "×" button is the only way to undo
            // a scan (reduces accidental unscans during fast taps).
            if !package.scanned { onScan() }
        } label: {
            HStack(spacing: 12) {
                if package.scanned {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(BuneColors.successColor)
                } else {
                    Image(systemName: "circle")
                        .font(.system(size: 18))
                        .foregroundColor(BuneColors.textTertiary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(package.label)
                        .font(.system(.caption, design: .monospaced))
                        .fontWeight(.semibold)
                        .foregroundColor(BuneColors.textPrimary)

                    if let productName = package.productName {
                        Text(productName)
                            .font(.caption2)
                            .foregroundColor(BuneColors.textSecondary)
                    }
                }

                Spacer()

                if package.scanned {
                    Button(action: { showUnscanConfirm = true }) {
                        Image(systemName: "xmark.circle")
                            .font(.system(size: 16))
                            .foregroundColor(BuneColors.textTertiary)
                    }
                    .buttonStyle(.plain) // don't inherit the row's Button behavior
                    .alert("Unscan Package?", isPresented: $showUnscanConfirm) {
                        Button("Unscan", role: .destructive) { onUnscan() }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("Remove \(package.label) from scanned list?")
                    }
                } else {
                    // Hint affordance for the tap-to-scan gesture.
                    Text("Tap to scan")
                        .font(.caption2)
                        .foregroundColor(BuneColors.accentPrimary.opacity(0.8))
                }
            }
            .padding(12)
            .background(
                package.scanned
                    ? BuneColors.successColor.opacity(0.08)
                    : Color.white.opacity(0.05)
            )
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .disabled(package.scanned) // row-level button inert on scanned rows
    }
}

// MARK: - Preview

#Preview {
    PickupScanView(
        apiClient: TransportAPIClient(authService: AuthService())
    )
}
