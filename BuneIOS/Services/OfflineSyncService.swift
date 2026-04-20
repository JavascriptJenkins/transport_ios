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

    /// On-disk queue file. Persisted in Documents/BuneCache/<tenant>/ so
    /// entries survive cold relaunches, are isolated per tenant, and aren't
    /// subject to the size-limited, system-pruned UserDefaults storage.
    private var queueFileURL: URL

    private(set) var tenantId: String?

    // Legacy UserDefaults key — only read from on first launch to migrate
    // any pending operations onto the new file-backed store.
    private let legacyQueueKey = "com.buneios.offlineQueue"

    // Operation types that can be queued
    enum QueuedOperation: Codable {
        case gpsPing(GPSPing)
        case packageScan(sessionId: Int, packageLabel: String, scanType: String)  // scanType: pickup/delivery
        case statusUpdate(transferId: Int, status: String)
        case zoneScan(zoneId: Int, packageLabel: String, action: String)
        case chatMessage(transferId: Int, text: String, sender: String)
        /// Pickup scan session complete — marks the session COMPLETE and
        /// (via zone assignments) lets the transfer's effective status
        /// advance to IN_TRANSIT.
        case completePickupSession(sessionId: Int)
        /// Delivery handoff complete with signature. Backend guards on
        /// all-packages-scanned, so this only succeeds if every scan in
        /// front of it in the queue drained cleanly.
        case completeDeliverySession(sessionId: Int, signatureData: String, signerName: String)
    }

    init() {
        self.queueFileURL = Self.queueFile(for: nil)
        Self.ensureDirectory(for: queueFileURL)

        startNetworkMonitoring()
        migrateLegacyQueueIfNeeded()
        loadQueue()
    }

    /// Point the queue at a tenant-scoped file. Call on login / tenant
    /// switch. In-flight drain is cancelled by virtue of isSyncing being
    /// read before work starts; the new queue is loaded from disk.
    func configure(tenantId newTenantId: String?) {
        let normalized = newTenantId?.lowercased()
        guard normalized != tenantId else { return }
        tenantId = normalized
        queueFileURL = Self.queueFile(for: normalized)
        Self.ensureDirectory(for: queueFileURL)
        loadQueue()
    }

    private static func queueFile(for tenantId: String?) -> URL {
        let documentDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        var dir = documentDir.appendingPathComponent("BuneCache", isDirectory: true)
        if let tenantId = tenantId, !tenantId.isEmpty {
            dir = dir.appendingPathComponent(tenantId, isDirectory: true)
        }
        return dir.appendingPathComponent("offline-queue.json")
    }

    private static func ensureDirectory(for fileURL: URL) {
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
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

    /// Convenience: if the given error is a network failure (offline,
    /// timeout, dropped connection), enqueue the operation and return true.
    /// Otherwise return false and let the caller surface the error.
    ///
    /// Lets ViewModels wire offline support with a single one-liner in
    /// the catch block rather than duplicating the error-classification
    /// logic across every scan / ping / status-update path.
    @discardableResult
    func enqueueIfNetworkFailure(_ error: Error, operation: QueuedOperation) -> Bool {
        guard Self.isNetworkFailure(error) else { return false }
        enqueue(operation)
        return true
    }

    static func isNetworkFailure(_ error: Error) -> Bool {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorNotConnectedToInternet,
                 NSURLErrorTimedOut,
                 NSURLErrorNetworkConnectionLost,
                 NSURLErrorCannotFindHost,
                 NSURLErrorCannotConnectToHost,
                 NSURLErrorDNSLookupFailed,
                 NSURLErrorDataNotAllowed,
                 NSURLErrorInternationalRoamingOff:
                return true
            default:
                return false
            }
        }
        return false
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
        case .completePickupSession(let sessionId):
            let _ = try await api.completePickup(sessionId: sessionId)
        case .completeDeliverySession(let sessionId, let signatureData, let signerName):
            let _ = try await api.completeDelivery(
                sessionId: sessionId,
                signatureData: signatureData,
                signerName: signerName
            )
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
