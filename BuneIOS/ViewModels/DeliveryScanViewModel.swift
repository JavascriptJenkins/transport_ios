//
//  DeliveryScanViewModel.swift
//  BuneIOS
//
//  Created by techvvs001 on 4/6/26.
//

import Foundation
import SwiftUI

@MainActor
class DeliveryScanViewModel: ObservableObject {
    enum Phase {
        case selectTransfer
        case scanning
        case signature
        case complete
    }

    @Published var availableTransfers: [Transfer] = []
    @Published var selectedTransfer: Transfer?
    @Published var scanSession: ScanSession?
    @Published var deliveryReceipt: DeliveryReceipt?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var currentPhase: Phase = .selectTransfer

    private let apiClient: TransportAPIClient
    private let offlineSyncService: OfflineSyncService?

    var scanProgress: Double {
        guard let session = scanSession, session.totalCount > 0 else { return 0 }
        return Double(session.scannedCount) / Double(session.totalCount)
    }

    init(apiClient: TransportAPIClient, offlineSyncService: OfflineSyncService? = nil) {
        self.apiClient = apiClient
        self.offlineSyncService = offlineSyncService
    }

    // MARK: - Load Transfers

    func loadTransfers() async {
        isLoading = true
        errorMessage = nil

        do {
            availableTransfers = try await apiClient.listDeliveryTransfers()
            isLoading = false
        } catch {
            errorMessage = "Failed to load transfers: \(error.localizedDescription)"
            isLoading = false
        }
    }

    // MARK: - Eligibility

    /// Raw / label statuses that indicate the transfer is at its destination
    /// and awaiting handoff. Matches the backend
    /// DeliveryHandoffController filter:
    ///     transferRepo.findByTulipStatusIn(['DELIVERED'])
    private static let deliveryEligibleTokens: Set<String> = [
        "DELIVERED"
    ]

    static func deliveryBlockedReason(for transfer: Transfer) -> String? {
        let normalized = transfer.status.uppercased()
        if deliveryEligibleTokens.contains(normalized) { return nil }

        switch normalized {
        case "CREATED":
            return "This transfer hasn't been dispatched yet — nothing to hand off."
        case "DISPATCH", "STAGED FOR PICKUP", "EN ROUTE TO PICKUP":
            return "This transfer hasn't been picked up yet. Complete pickup before starting the delivery handoff."
        case "IN_TRANSIT", "EN_ROUTE":
            return "This transfer is still in transit. Mark it delivered at the destination before starting the handoff."
        case "AT_HUB", "AT HUB":
            return "This transfer is at a hub — complete hub intake and continue the trip before handoff."
        case "ACCEPTED":
            return "This transfer has already been accepted by the recipient."
        case "CANCELED", "CANCELLED":
            return "This transfer was canceled."
        default:
            return "Transfer can't be delivered while it's in “\(transfer.status)” status."
        }
    }

    // MARK: - Session Management

    func startSession(transferId: Int) async {
        errorMessage = nil

        // Belt-and-braces guard: the backend already narrows its delivery
        // list to DELIVERED-status transfers, but a stale / cached row
        // could slip through. Block the request client-side so the user
        // gets a clear status-specific message instead of a generic error.
        if let transfer = availableTransfers.first(where: { $0.id == transferId }),
           let reason = Self.deliveryBlockedReason(for: transfer) {
            errorMessage = reason
            return
        }

        isLoading = true

        do {
            let (session, _) = try await apiClient.startDeliverySession(transferId: transferId)

            // Pull the authoritative session detail — packages + per-
            // package scanned flags + scannedCount — so a resumed session
            // reflects whatever the driver already scanned on the web or
            // before backing out of this screen. No more local-only state.
            let detail = try await apiClient.getDeliverySession(sessionId: session.id)
            let scanPackages: [ScanPackage] = (detail.packages ?? []).map {
                ScanPackage(label: $0.packageLabel, productName: $0.productName, scanned: $0.scanned)
            }

            scanSession = ScanSession(
                sessionId: session.id,
                transferId: transferId,
                packages: scanPackages,
                scannedCount: detail.scannedCount ?? scanPackages.filter(\.scanned).count,
                totalCount: detail.totalPackages ?? scanPackages.count
            )

            selectedTransfer = availableTransfers.first { $0.id == transferId }
            currentPhase = .scanning
            isLoading = false
        } catch {
            errorMessage = "Failed to start session: \(error.localizedDescription)"
            isLoading = false
        }
    }

    // MARK: - Package Scanning

    func scanPackage(_ label: String) async {
        guard let session = scanSession else { return }

        isLoading = true
        errorMessage = nil

        do {
            _ = try await apiClient.scanDeliveryPackage(
                sessionId: session.sessionId,
                packageLabel: label
            )
            markLocallyScanned(label: label)
            isLoading = false
        } catch {
            let queued = offlineSyncService?.enqueueIfNetworkFailure(
                error,
                operation: .packageScan(
                    sessionId: session.sessionId,
                    packageLabel: label,
                    scanType: "delivery"
                )
            ) ?? false

            if queued {
                markLocallyScanned(label: label)
                errorMessage = nil
            } else {
                errorMessage = "Failed to scan package: \(error.localizedDescription)"
            }
            isLoading = false
        }
    }

    private func markLocallyScanned(label: String) {
        guard var packages = scanSession?.packages,
              let index = packages.firstIndex(where: { $0.label == label }),
              let session = scanSession else { return }
        packages[index].scanned = true
        scanSession = ScanSession(
            sessionId: session.sessionId,
            transferId: session.transferId,
            packages: packages,
            scannedCount: packages.filter { $0.scanned }.count,
            totalCount: session.totalCount
        )
    }

    func unscanPackage(_ label: String) async {
        guard let session = scanSession else { return }

        isLoading = true
        errorMessage = nil

        do {
            _ = try await apiClient.unscanDeliveryPackage(
                sessionId: session.sessionId,
                packageLabel: label
            )

            // Update local session
            if var packages = scanSession?.packages {
                if let index = packages.firstIndex(where: { $0.label == label }) {
                    packages[index].scanned = false
                    scanSession?.packages = packages
                }
            }

            isLoading = false
        } catch {
            errorMessage = "Failed to unscan package: \(error.localizedDescription)"
            isLoading = false
        }
    }

    // MARK: - Complete Delivery with Signature

    func completeDelivery(signatureData: String, signerName: String) async {
        guard let session = scanSession else { return }

        // Client-side mirror of the backend accept-gate: completing is only
        // legal once every package has been scanned out of the vehicle.
        // Prevents a double-tap race where the user reaches the signature
        // phase before a scan round-trip completes.
        guard session.scannedCount >= session.totalCount, session.totalCount > 0 else {
            errorMessage = "Scan all \(session.totalCount) packages out of the vehicle before capturing the signature."
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            // completeDelivery flips the session to COMPLETE and the transfer
            // to ACCEPTED server-side. The backend guards on scannedCount >=
            // totalPackages, so a half-scanned session will come back with
            // success=false and a specific error; surface that instead of a
            // generic failure message.
            _ = try await apiClient.completeDelivery(
                sessionId: session.sessionId,
                signatureData: signatureData,
                signerName: signerName
            )

            // Receipt URL matches the public endpoint that the web's
            // delivery-scan.html uses after submit:
            //   /public/transfer/receipt/{transferId}
            // (see PublicTransferTrackingController:/receipt/{transferId}).
            // The QR on the completion screen links the customer directly
            // to the PDF-downloadable receipt page.
            let receiptUrl = "\(apiClient.baseURL)/public/transfer/receipt/\(session.transferId)"
            deliveryReceipt = DeliveryReceipt(
                receiptUrl: receiptUrl,
                qrCodeUrl: receiptUrl
            )

            currentPhase = .complete
            isLoading = false
        } catch {
            errorMessage = "Failed to complete delivery: \(error.localizedDescription)"
            isLoading = false
        }
    }

    func transitionToSignature() {
        currentPhase = .signature
    }

    // MARK: - Session Recovery

    func checkForActiveSession() async {
        for transfer in availableTransfers {
            if transfer.status == "IN_TRANSIT" {
                // Check if this transfer has an active session
                do {
                    let detail = try await apiClient.getTransfer(id: transfer.id)
                    if detail.statusProgress != nil && detail.statusProgress ?? 0 > 0 {
                        // Offer to resume this session
                        selectedTransfer = detail
                        break
                    }
                } catch {
                    // Continue to next transfer
                    continue
                }
            }
        }
    }

    // MARK: - Reset

    func reset() {
        selectedTransfer = nil
        scanSession = nil
        deliveryReceipt = nil
        currentPhase = .selectTransfer
        errorMessage = nil
    }
}
