//
//  PickupScanViewModel.swift
//  BuneIOS
//
//  Created by techvvs001 on 4/6/26.
//

import Foundation
import SwiftUI

@MainActor
class PickupScanViewModel: ObservableObject {
    enum Phase {
        case selectTransfer
        case scanning
        case complete
    }

    @Published var availableTransfers: [Transfer] = []
    @Published var selectedTransfer: Transfer?
    @Published var scanSession: ScanSession?
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
            availableTransfers = try await apiClient.listPickupTransfers()
            isLoading = false
        } catch {
            errorMessage = "Failed to load transfers: \(error.localizedDescription)"
            isLoading = false
        }
    }

    // MARK: - Eligibility

    /// Statuses (raw code OR display label) that are ready for pickup scanning.
    /// Matches the backend's PickupScanController filter which only returns
    /// transfers whose computeEffectiveStatus is DISPATCH or AT_HUB.
    private static let pickupEligibleTokens: Set<String> = [
        "DISPATCH", "AT_HUB",
        // Common label equivalents surfaced via statusLabel on the API row:
        "STAGED FOR PICKUP", "EN ROUTE TO PICKUP", "AT HUB"
    ]

    /// Returns nil when the transfer is eligible for pickup; otherwise a
    /// driver-facing explanation of why it isn't.
    static func pickupBlockedReason(for transfer: Transfer) -> String? {
        let normalized = transfer.status.uppercased()
        if pickupEligibleTokens.contains(normalized) { return nil }

        switch normalized {
        case "CREATED":
            return "This transfer hasn't been dispatched yet. Dispatch it from the Transfers tab before picking up packages."
        case "IN_TRANSIT", "EN_ROUTE":
            return "This transfer is already in transit — packages are loaded on the vehicle."
        case "DELIVERED":
            return "This transfer has already been delivered."
        case "ACCEPTED":
            return "This transfer has been accepted at its destination."
        case "CANCELED", "CANCELLED":
            return "This transfer was canceled."
        default:
            return "Transfer can't be picked up while it's in “\(transfer.status)” status."
        }
    }

    // MARK: - Session Management

    func startSession(transferId: Int) async {
        errorMessage = nil

        // Belt-and-braces guard: the backend already filters its pickup list
        // to DISPATCH/AT_HUB, but users may reach this path from cached lists
        // or from a transfer that flipped status between fetch and tap.
        if let transfer = availableTransfers.first(where: { $0.id == transferId }),
           let reason = Self.pickupBlockedReason(for: transfer) {
            errorMessage = reason
            return
        }

        isLoading = true

        do {
            let session = try await apiClient.startPickupSession(transferId: transferId)

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
            _ = try await apiClient.scanPickupPackage(
                sessionId: session.sessionId,
                packageLabel: label
            )
            markLocallyScanned(label: label)
            isLoading = false
        } catch {
            // If we're offline/timed out, queue the scan and optimistically
            // flip the row scanned. The OfflineSyncService drains on reconnect;
            // any server-side rejection surfaces later on drain.
            let queued = offlineSyncService?.enqueueIfNetworkFailure(
                error,
                operation: .packageScan(
                    sessionId: session.sessionId,
                    packageLabel: label,
                    scanType: "pickup"
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

    /// Flip a package row's scanned flag in the local scanSession. Used by
    /// both the online happy-path and the offline-queued path so the UI is
    /// immediately responsive either way.
    private func markLocallyScanned(label: String) {
        if var packages = scanSession?.packages,
           let index = packages.firstIndex(where: { $0.label == label }) {
            packages[index].scanned = true
            scanSession?.packages = packages
            if let session = scanSession {
                scanSession = ScanSession(
                    sessionId: session.sessionId,
                    transferId: session.transferId,
                    packages: packages,
                    scannedCount: packages.filter { $0.scanned }.count,
                    totalCount: session.totalCount
                )
            }
        }
    }

    func unscanPackage(_ label: String) async {
        guard let session = scanSession else { return }

        isLoading = true
        errorMessage = nil

        do {
            _ = try await apiClient.unscanPickupPackage(
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

    // MARK: - Complete Pickup

    func completePickup() async {
        guard let session = scanSession else { return }

        isLoading = true
        errorMessage = nil

        do {
            _ = try await apiClient.completePickup(sessionId: session.sessionId)

            // Don't force tulipStatus = IN_TRANSIT here. Effective status is
            // zone-derived — the backend's TransportStatusService returns
            // IN_TRANSIT only when every package is physically in a VEHICLE
            // zone (or vehicle-package assignment). Writing IN_TRANSIT into
            // tulipStatus would pollute the stored value and let the V1 list
            // endpoint show IN_TRANSIT for a transfer whose packages are
            // still in the originator.

            currentPhase = .complete
            isLoading = false
        } catch {
            errorMessage = "Failed to complete pickup: \(error.localizedDescription)"
            isLoading = false
        }
    }

    // MARK: - Session Recovery

    func checkForActiveSession() async {
        for transfer in availableTransfers {
            // Only consider pickup-eligible rows. Uses the shared
            // eligibility check so we stay consistent with startSession and
            // catch all the label forms the backend might return
            // ("Staged for Pickup", "At Hub", etc.) — the old literal
            // comparison against "DISPATCH" / "AT_HUB" missed those.
            guard Self.pickupBlockedReason(for: transfer) == nil else { continue }

            do {
                let detail = try await apiClient.getTransfer(id: transfer.id)
                if (detail.statusProgress ?? 0) > 0 {
                    selectedTransfer = detail
                    // App should show resume alert here
                    break
                }
            } catch {
                continue
            }
        }
    }

    // MARK: - Reset

    func reset() {
        selectedTransfer = nil
        scanSession = nil
        currentPhase = .selectTransfer
        errorMessage = nil
    }
}
