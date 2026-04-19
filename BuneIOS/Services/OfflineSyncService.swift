//
//  OfflineSyncService.swift
//  BuneIOS
//
//  Manages offline queuing and sync for Transport operations.
//  Queues operations when offline and drains them when connection is restored.
//

import Foundation
import Network

@MainActor
class OfflineSyncService: ObservableObject {
    @Published var isOnline = true
    @Published var pendingOperationCount = 0
    @Published var isSyncing = false
    @Published var lastSyncAt: Date?

    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.buneios.networkMonitor")
    private var apiClient: TransportAPIClient?

    /// On-disk queue file. Persisted in Documents/BuneCache so entries survive
    /// cold relaunches and aren't subject to the size-limited, system-pruned
    /// UserDefaults storage.
    private let queueFileURL: URL

    // Legacy UserDefaults key — only read from on first launch to migrate
    // any pending operations onto the new file-backed store.
    private let legacyQueueKey = "com.buneios.offlineQueue"

    // Operation types that can be queued
    enum QueuedOperation: Codable {
        case gpsPing(GPSPing)
        case packageScan(sessionId: String, packageLabel: String, scanType: String)  // scanType: pickup/delivery
        case statusUpdate(transferId: Int, status: String)
        case zoneScan(zoneId: Int, packageLabel: String, action: String)
        case chatMessage(transferId: Int, text: String, sender: String)
    }

    init() {
        // Build a Documents/BuneCache/offline-queue.json path, creating the
        // directory if it doesn't exist yet.
        let documentDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let cacheDir = documentDir.appendingPathComponent("BuneCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        self.queueFileURL = cacheDir.appendingPathComponent("offline-queue.json")

        startNetworkMonitoring()
        migrateLegacyQueueIfNeeded()
        loadQueue()
    }

    /// One-shot migration: if a UserDefaults-backed queue exists from an
    /// older build, move its entries onto the file-backed store and clear
    /// the legacy key so we don't pick it up twice.
    private func migrateLegacyQueueIfNeeded() {
        guard let legacyData = UserDefaults.standard.data(forKey: legacyQueueKey) else { return }
        defer { UserDefaults.standard.removeObject(forKey: legacyQueueKey) }
        do {
            let legacyOps = try JSONDecoder().decode([QueuedOperation].self, from: legacyData)
            guard !legacyOps.isEmpty else { return }
            var existing = loadQueueFromStorage()
            existing.append(contentsOf: legacyOps)
            saveQueueToStorage(existing)
        } catch {
            // Legacy payload unreadable — drop it rather than block startup.
        }
    }

    func configure(apiClient: TransportAPIClient) {
        self.apiClient = apiClient
    }

    deinit {
        monitor.cancel()
    }

    // MARK: - Network Monitoring

    private func startNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                let wasOffline = !(self?.isOnline ?? true)
                self?.isOnline = path.status == .satisfied
                if wasOffline && path.status == .satisfied {
                    await self?.drainQueue()
                }
            }
        }
        monitor.start(queue: monitorQueue)
    }

    // MARK: - Queue Management

    func enqueue(_ operation: QueuedOperation) {
        var queue = loadQueueFromStorage()
        queue.append(operation)
        saveQueueToStorage(queue)
        pendingOperationCount = queue.count
    }

    func drainQueue() async {
        guard isOnline, !isSyncing else { return }
        isSyncing = true

        let queue = loadQueueFromStorage()
        var failedOps: [QueuedOperation] = []

        for op in queue {
            do {
                try await executeOperation(op)
            } catch {
                failedOps.append(op)  // Will retry next time
            }
        }

        saveQueueToStorage(failedOps)
        pendingOperationCount = failedOps.count
        lastSyncAt = Date()
        isSyncing = false
    }

    private func executeOperation(_ op: QueuedOperation) async throws {
        guard let api = apiClient else { return }
        switch op {
        case .gpsPing(let ping):
            let _ = try await api.submitGPSPing(ping)
        case .packageScan(let sessionId, let label, let scanType):
            if scanType == "pickup" {
                let _ = try await api.scanPickupPackage(sessionId: sessionId, packageLabel: label)
            } else {
                let _ = try await api.scanDeliveryPackage(sessionId: sessionId, packageLabel: label)
            }
        case .statusUpdate(let transferId, let status):
            let _ = try await api.updateTransferStatus(id: transferId, status: status)
        case .zoneScan(let zoneId, let label, let action):
            _ = try await api.scanIntoZone(zoneId: zoneId, packageLabel: label, action: action)
        case .chatMessage(let transferId, let text, let sender):
            let _ = try await api.postMessage(transferId: transferId, text: text, sender: sender)
        }
    }

    // MARK: - Storage Helpers

    private func loadQueueFromStorage() -> [QueuedOperation] {
        guard FileManager.default.fileExists(atPath: queueFileURL.path) else { return [] }
        do {
            let data = try Data(contentsOf: queueFileURL)
            guard !data.isEmpty else { return [] }
            return try JSONDecoder().decode([QueuedOperation].self, from: data)
        } catch {
            print("Failed to decode offline queue: \(error)")
            return []
        }
    }

    private func saveQueueToStorage(_ queue: [QueuedOperation]) {
        do {
            let data = try JSONEncoder().encode(queue)
            // Atomic write so a crash partway through doesn't corrupt the queue.
            try data.write(to: queueFileURL, options: .atomic)
        } catch {
            print("Failed to encode offline queue: \(error)")
        }
    }

    private func loadQueue() {
        pendingOperationCount = loadQueueFromStorage().count
    }

    func clearQueue() {
        saveQueueToStorage([])
        pendingOperationCount = 0
    }
}
