//
//  TransferDetailViewModel.swift
//  BuneIOS
//
//  Created by techvvs001 on 4/6/26.
//

import Foundation
import SwiftUI

// MARK: - Transfer Detail View Model
@MainActor
class TransferDetailViewModel: ObservableObject {
    // MARK: - Published State
    @Published var transfer: Transfer?
    @Published var packages: [Package] = []
    @Published var trackingEvents: [TrackingEvent] = []
    @Published var messages: [ChatMessage] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    // MARK: - Dependencies
    private let transferId: Int
    private let apiClient: TransportAPIClient
    private var messagePollingTimer: Timer?
    private var lastMessageTimestamp: String?

    // MARK: - Init
    init(transferId: Int, apiClient: TransportAPIClient) {
        self.transferId = transferId
        self.apiClient = apiClient
    }

    // MARK: - Load All Data in Parallel
    func loadAll() async {
        isLoading = true
        errorMessage = nil

        // Load transfer detail first — it includes inline packages
        await loadTransfer()

        // Use inline packages from transfer detail if available;
        // only call the separate packages endpoint as a fallback
        if let inlinePackages = transfer?.packages, !inlinePackages.isEmpty {
            packages = inlinePackages
            print("✅ [Detail] Using \(inlinePackages.count) inline packages from transfer detail")
        } else {
            await loadPackages()
        }

        await loadMessages()

        isLoading = false
    }

    // MARK: - Load Transfer
    private func loadTransfer() async {
        do {
            transfer = try await apiClient.getTransfer(id: transferId)
            print("✅ [Detail] Transfer loaded: id=\(transferId), status=\(transfer?.status ?? "nil")")
        } catch {
            print("❌ [Detail] Failed to load transfer \(transferId): \(error)")
            errorMessage = "Failed to load transfer: \(error.localizedDescription)"
        }
    }

    // MARK: - Load Packages (fallback if not inline)
    private func loadPackages() async {
        do {
            packages = try await apiClient.getTransferPackages(transferId: transferId)
        } catch {
            // Don't overwrite a transfer error; packages are secondary
            if errorMessage == nil {
                errorMessage = "Failed to load packages: \(error.localizedDescription)"
            }
            print("⚠️ [Detail] Packages endpoint failed (non-fatal if transfer has inline packages): \(error)")
        }
    }

    // MARK: - Load Messages
    func loadMessages() async {
        do {
            let loadedMessages: [ChatMessage] = try await apiClient.loadMessages(transferId: transferId)
            messages = loadedMessages
            if let lastMessage = loadedMessages.last {
                lastMessageTimestamp = lastMessage.timestamp
            }
        } catch {
            errorMessage = "Failed to load messages: \(error.localizedDescription)"
        }
    }

    // MARK: - Refresh Messages (Incremental)
    func refreshMessages() async {
        do {
            let newMessages: [ChatMessage] = try await apiClient.loadMessages(
                transferId: transferId,
                since: lastMessageTimestamp
            )
            messages.append(contentsOf: newMessages)
            if let lastMessage = newMessages.last {
                lastMessageTimestamp = lastMessage.timestamp
            }
        } catch {
            // Silent fail on refresh; don't update errorMessage for polling
        }
    }

    // MARK: - Update Transfer Status
    func updateStatus(_ newStatus: String) async {
        do {
            transfer = try await apiClient.updateTransferStatus(id: transferId, status: newStatus)
            errorMessage = nil
        } catch {
            errorMessage = "Failed to update status: \(error.localizedDescription)"
        }
    }

    // MARK: - Send Message
    /// Post a message. Sender label is derived from the active user's role so
    /// drivers, managers, and admins all show up on the correct side of the
    /// thread on both web and mobile.
    func sendMessage(_ text: String, sender: String = "driver") async {
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        do {
            let message: ChatMessage = try await apiClient.postMessage(
                transferId: transferId,
                text: text,
                sender: sender
            )
            messages.append(message)
            lastMessageTimestamp = message.timestamp
        } catch {
            errorMessage = "Failed to send message: \(error.localizedDescription)"
        }
    }

    // MARK: - Message Polling
    func startMessagePolling() {
        stopMessagePolling()
        messagePollingTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            Task {
                await self?.refreshMessages()
            }
        }
    }

    func stopMessagePolling() {
        messagePollingTimer?.invalidate()
        messagePollingTimer = nil
    }

}
