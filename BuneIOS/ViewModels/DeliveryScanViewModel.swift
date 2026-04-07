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

    var scanProgress: Double {
        guard let session = scanSession, session.totalCount > 0 else { return 0 }
        return Double(session.scannedCount) / Double(session.totalCount)
    }

    init(apiClient: TransportAPIClient) {
        self.apiClient = apiClient
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

    // MARK: - Session Management

    func startSession(transferId: Int) async {
        isLoading = true
        errorMessage = nil

        do {
            let session = try await apiClient.startDeliverySession(transferId: transferId)

            // Map Session to ScanSession
            let packages = try await apiClient.getTransferPackages(transferId: transferId)
            let scanPackages = packages.map { package in
                ScanPackage(
                    label: package.packageLabel,
                    productName: package.productName,
                    scanned: false
                )
            }

            scanSession = ScanSession(
                sessionId: session.id,
                transferId: transferId,
                packages: scanPackages,
                scannedCount: 0,
                totalCount: packages.count
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
                sessionId: String(session.sessionId),
                packageLabel: label
            )

            // Update local session
            if var packages = scanSession?.packages {
                if let index = packages.firstIndex(where: { $0.label == label }) {
                    packages[index].scanned = true
                    scanSession?.packages = packages
                }
            }

            isLoading = false
        } catch {
            errorMessage = "Failed to scan package: \(error.localizedDescription)"
            isLoading = false
        }
    }

    func unscanPackage(_ label: String) async {
        guard let session = scanSession else { return }

        isLoading = true
        errorMessage = nil

        do {
            _ = try await apiClient.unscanDeliveryPackage(
                sessionId: String(session.sessionId),
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

        isLoading = true
        errorMessage = nil

        do {
            let result = try await apiClient.completeDelivery(
                sessionId: String(session.sessionId),
                signatureData: signatureData,
                signerName: signerName
            )

            // Update transfer status to DELIVERED
            if let transferId = selectedTransfer?.id {
                _ = try await apiClient.updateTransferStatus(id: transferId, status: "DELIVERED")
            }

            // Store receipt (in a real app, this would come from the API response)
            deliveryReceipt = DeliveryReceipt(
                receiptUrl: "https://haven.bunepos.com/receipts/\(session.sessionId)",
                qrCodeUrl: "https://haven.bunepos.com/qr/\(session.sessionId)"
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
