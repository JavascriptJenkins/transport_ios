//
//  DeliveryScanView.swift
//  BuneIOS
//
//  Created by techvvs001 on 4/6/26.
//

import SwiftUI
import CoreImage.CIFilterBuiltins

// MARK: - Delivery Scan View

struct DeliveryScanView: View {
    @StateObject private var viewModel: DeliveryScanViewModel
    @State private var showResumeAlert = false
    @State private var scannedLabel = ""
    @State private var manualEntryMode = false
    @State private var signerName = ""
    @State private var signatureImage: UIImage?
    @Environment(\.dismiss) var dismiss

    init(apiClient: TransportAPIClient) {
        _viewModel = StateObject(wrappedValue: DeliveryScanViewModel(apiClient: apiClient))
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
                    Text("Delivery Scan")
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
                case .signature:
                    signaturePhase
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

                Text("Select a transfer to begin delivery scanning")
                    .font(.caption)
                    .foregroundColor(BuneColors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)

            if viewModel.isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .tint(BuneColors.accentPrimary)
                    Text("Loading transfers...")
                        .foregroundColor(BuneColors.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else if let error = viewModel.errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.circle")
                        .font(.system(size: 40))
                        .foregroundColor(BuneColors.errorColor)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(BuneColors.errorColor)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .padding(20)
            } else if viewModel.availableTransfers.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "inbox")
                        .font(.system(size: 40))
                        .foregroundColor(BuneColors.textTertiary)
                    Text("No transfers available")
                        .foregroundColor(BuneColors.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(viewModel.availableTransfers) { transfer in
                            DeliveryTransferSelectRow(transfer: transfer) {
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
                    // Placeholder for BarcodeScannerView
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
                                DeliveryPackageRow(
                                    package: pkg,
                                    onScan: {
                                        Task { await viewModel.scanPackage(pkg.label) }
                                    },
                                    onUnscan: {
                                        Task { await viewModel.unscanPackage(pkg.label) }
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .frame(maxHeight: 200)
                }
            }

            Spacer()

            // Complete Button
            if let session = viewModel.scanSession, session.scannedCount == session.totalCount {
                Button(action: {
                    viewModel.transitionToSignature()
                }) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Proceed to Signature")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .accentButton()
                }
                .padding(20)
            } else {
                HStack {
                    Image(systemName: "lock.fill")
                    Text("Scan all packages to continue")
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

    // MARK: - Phase 3: Signature Capture

    private var signaturePhase: some View {
        VStack(spacing: 16) {
            // Signer Name Input
            VStack(alignment: .leading, spacing: 8) {
                Text("Recipient Name")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(BuneColors.textSecondary)

                HStack(spacing: 12) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 16))
                        .foregroundColor(BuneColors.accentPrimary)

                    TextField(
                        "",
                        text: $signerName,
                        prompt: Text("Full name")
                            .foregroundColor(BuneColors.textMuted)
                    )
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(BuneColors.textPrimary)
                    .autocapitalization(.words)
                    .disableAutocorrection(true)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.07))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(BuneColors.glassBorder, lineWidth: 1)
                        )
                )
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            // Signature Capture
            VStack(spacing: 12) {
                SignatureCaptureView(signatureImage: $signatureImage)
                    .glassCard(cornerRadius: 16)
            }
            .padding(.horizontal, 20)

            Spacer()

            // Submit Button
            if !signerName.trimmingCharacters(in: .whitespaces).isEmpty && signatureImage != nil {
                Button(action: {
                    if let imageData = signatureImage?.base64PNGString {
                        Task {
                            await viewModel.completeDelivery(
                                signatureData: imageData,
                                signerName: signerName
                            )
                        }
                    }
                }) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Submit Delivery")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .accentButton()
                }
                .padding(20)
            } else {
                HStack {
                    Image(systemName: "lock.fill")
                    Text("Enter name and sign to submit")
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

    // MARK: - Phase 4: Complete

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
                    Text("Delivery Completed")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(BuneColors.textPrimary)

                    Text("Signature received successfully")
                        .font(.caption)
                        .foregroundColor(BuneColors.textSecondary)
                }
            }

            // Receipt QR Code
            if let receipt = viewModel.deliveryReceipt {
                VStack(spacing: 16) {
                    VStack(spacing: 12) {
                        if let qrImage = generateQRCode(from: receipt.receiptUrl) {
                            Image(uiImage: qrImage)
                                .interpolation(.none)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 150, height: 150)
                                .padding(16)
                                .background(Color.white.opacity(0.07))
                                .cornerRadius(12)
                        }

                        Text("Download Receipt")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(BuneColors.textSecondary)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Receipt URL")
                            .font(.caption2)
                            .foregroundColor(BuneColors.textTertiary)

                        Text(receipt.receiptUrl)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(BuneColors.accentPrimary)
                            .lineLimit(3)
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(10)
                }
                .padding(20)
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
            .padding(20)
        }
    }

    // MARK: - Helper Functions

    private func generateQRCode(from string: String) -> UIImage? {
        let data = string.data(using: String.Encoding.utf8)
        if let filter = CIFilter(name: "CIQRCodeGenerator") {
            filter.setValue(data, forKey: "inputMessage")
            if let output = filter.outputImage {
                let transform = CGAffineTransform(scaleX: 3, y: 3)
                let scaledImage = output.transformed(by: transform)
                return UIImage(ciImage: scaledImage)
            }
        }
        return nil
    }
}

// MARK: - Supporting Views

private struct DeliveryTransferSelectRow: View {
    let transfer: Transfer
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

                        if transfer.status == "IN_TRANSIT" {
                            Label("In Transit", systemImage: "truck.box.fill")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(BuneColors.infoColor)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(BuneColors.infoColor.opacity(0.15))
                                .cornerRadius(6)
                        }
                    }

                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Destination")
                                .font(.caption2)
                                .foregroundColor(BuneColors.textTertiary)
                            Text(transfer.destinations?.first?.recipientFacilityName ?? "Unknown")
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
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(BuneColors.textTertiary)
            }
            .padding(14)
            .glassCard(cornerRadius: 14)
        }
    }
}

private struct DeliveryPackageRow: View {
    let package: ScanPackage
    let onScan: () -> Void
    let onUnscan: () -> Void

    @State private var showUnscanConfirm = false

    var body: some View {
        Button {
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
                    .buttonStyle(.plain)
                    .alert("Unscan Package?", isPresented: $showUnscanConfirm) {
                        Button("Unscan", role: .destructive) { onUnscan() }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("Remove \(package.label) from scanned list?")
                    }
                } else {
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
        .disabled(package.scanned)
    }
}

// MARK: - Preview

#Preview {
    DeliveryScanView(
        apiClient: TransportAPIClient(authService: AuthService())
    )
}
