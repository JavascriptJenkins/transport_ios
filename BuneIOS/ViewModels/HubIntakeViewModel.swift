//
//  HubIntakeViewModel.swift
//  BuneIOS
//
//  Orchestrates the hub intake workflow: driver arrives at a hub with an
//  IN_TRANSIT transfer, creates a session, picks a STANDARD zone, scans each
//  package into that zone, then completes the session to auto-advance the
//  transfer to AT_HUB.
//
//  Zone scan submissions go through the existing scanIntoZone API, so this
//  VM is really a state machine around the server-side session + zone-scan
//  count rather than a separate scanning backend.
//

import Foundation

@MainActor
class HubIntakeViewModel: ObservableObject {
    enum Phase {
        case selectTransfer  // pick an IN_TRANSIT transfer to intake
        case selectZone      // choose a location + hub zone to place packages in
        case scanning        // scan packages; assignedCount polls from server
        case complete        // intake finished, transfer advanced to AT_HUB
    }

    // MARK: - Published State
    @Published var phase: Phase = .selectTransfer

    // Transfer selection
    @Published var availableTransfers: [Transfer] = []
    @Published var selectedTransfer: Transfer?

    // Location + zone selection
    @Published var locations: [Location] = []
    @Published var selectedLocation: Location?
    @Published var zones: [Zone] = []
    @Published var selectedZone: Zone?

    // Active session + progress
    @Published var session: HubIntakeSession?
    @Published var wasResumed: Bool = false
    /// Labels of packages the user has successfully scanned in this session.
    /// Used to disambiguate "already in zone before I started" from "I scanned
    /// it just now" on the UI — the server-side assignedCount counts both.
    @Published var scannedLabels: [String] = []

    /// Full package list for the active transfer, so the scanning phase can
    /// render a tappable checklist. Populated when the session starts.
    @Published var transferPackages: [Package] = []

    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var statusAdvanced: Bool = false

    private let apiClient: TransportAPIClient
    private var pollingTask: Task<Void, Never>?

    /// Progress 0..1 based on assignedCount vs totalPackages.
    var progress: Double {
        guard let session = session, session.totalPackages > 0 else { return 0 }
        let assigned = session.assignedCount ?? 0
        return min(1.0, Double(assigned) / Double(session.totalPackages))
    }

    var progressLabel: String {
        guard let session = session else { return "0 / 0" }
        return "\(session.assignedCount ?? 0) / \(session.totalPackages)"
    }

    var canComplete: Bool {
        guard let session = session else { return false }
        return (session.assignedCount ?? 0) >= session.totalPackages && session.totalPackages > 0
    }

    init(apiClient: TransportAPIClient) {
        self.apiClient = apiClient
    }

    // MARK: - Phase 1 — transfer selection

    func loadTransfers() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            // Hub intake only makes sense on IN_TRANSIT transfers. The
            // backend /api/v1/transport listing supports status filters;
            // keep the listing broad here and filter client-side so we
            // don't need a dedicated endpoint.
            let transfers = try await apiClient.listTransfers(
                direction: "INCOMING",
                page: 0,
                size: 50,
                status: "IN_TRANSIT"
            )
            availableTransfers = transfers
        } catch {
            errorMessage = "Failed to load transfers: \(error.localizedDescription)"
        }
    }

    /// Proceed to zone selection for the chosen transfer. Runs the backend
    /// hub-accept pre-flight check, which validates IN_TRANSIT status and
    /// that the transfer has packages.
    func selectTransfer(_ transfer: Transfer) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            _ = try await apiClient.hubAcceptTransfer(transferId: transfer.id)
            selectedTransfer = transfer
            await loadLocations()
            phase = .selectZone
        } catch {
            errorMessage = "Cannot accept transfer at hub: \(error.localizedDescription)"
        }
    }

    // MARK: - Phase 2 — zone selection

    func loadLocations() async {
        do {
            locations = try await apiClient.listLocations()
            // If there's only one location, pre-select it and load zones.
            if locations.count == 1 {
                await selectLocation(locations[0])
            }
        } catch {
            errorMessage = "Failed to load locations: \(error.localizedDescription)"
        }
    }

    func selectLocation(_ location: Location) async {
        selectedLocation = location
        selectedZone = nil
        zones = []
        do {
            zones = try await apiClient.listZones(locationId: location.id)
        } catch {
            errorMessage = "Failed to load zones: \(error.localizedDescription)"
        }
    }

    /// Create (or resume) the hub intake session against the selected zone
    /// and transfer, then transition to scanning.
    func startSession(zone: Zone) async {
        guard let transfer = selectedTransfer else { return }
        selectedZone = zone
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let result = try await apiClient.createHubIntakeSession(
                transferId: transfer.id,
                transferManifestNumber: transfer.manifestNumber,
                shipperName: transfer.shipperFacilityName,
                receiverName: transfer.destinations?.first?.recipientFacilityName,
                totalPackages: transfer.packageCount ?? 0,
                locationId: selectedLocation?.id,
                locationName: selectedLocation?.name
            )
            session = result.session
            wasResumed = result.resumed
            scannedLabels = []
            phase = .scanning

            // Fetch the transfer's package list so the UI can render a
            // tappable checklist in the scanning phase. Silent on failure —
            // the manual barcode input still works without it.
            do {
                transferPackages = try await apiClient.getTransferPackages(transferId: transfer.id)
            } catch {
                transferPackages = []
            }

            startProgressPolling()
        } catch {
            errorMessage = "Failed to start hub intake: \(error.localizedDescription)"
        }
    }

    // MARK: - Phase 3 — scanning

    func scanPackage(_ label: String) async {
        let cleaned = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty, let zone = selectedZone else { return }
        errorMessage = nil
        do {
            _ = try await apiClient.scanIntoZone(
                zoneId: zone.id,
                packageLabel: cleaned,
                action: "PICK"
            )
            if !scannedLabels.contains(cleaned) {
                scannedLabels.append(cleaned)
            }
            // Refresh session assignedCount immediately so the progress bar
            // reflects the scan without waiting for the next poll tick.
            await refreshSession()
        } catch {
            errorMessage = "Scan failed for \(cleaned): \(error.localizedDescription)"
        }
    }

    private func refreshSession() async {
        guard let id = session?.id else { return }
        do {
            session = try await apiClient.getHubIntakeSession(id: id)
        } catch {
            // Silent on poll failure — keep the last-known session.
        }
    }

    private func startProgressPolling() {
        stopProgressPolling()
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                if Task.isCancelled { break }
                await self?.refreshSession()
            }
        }
    }

    private func stopProgressPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    // MARK: - Phase 4 — complete / abandon

    func completeSession() async {
        guard let id = session?.id else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            statusAdvanced = try await apiClient.completeHubIntakeSession(id: id)
            stopProgressPolling()
            phase = .complete
        } catch {
            errorMessage = "Failed to complete intake: \(error.localizedDescription)"
        }
    }

    func abandonSession() async {
        guard let id = session?.id else {
            // No session — just reset the VM to the start.
            reset()
            return
        }
        do {
            _ = try await apiClient.abandonHubIntakeSession(id: id)
        } catch {
            // Still reset locally even if the server call fails; nothing
            // valuable is lost because the session was just a wrapper.
        }
        reset()
    }

    func reset() {
        stopProgressPolling()
        phase = .selectTransfer
        selectedTransfer = nil
        selectedLocation = nil
        selectedZone = nil
        zones = []
        session = nil
        wasResumed = false
        scannedLabels = []
        transferPackages = []
        statusAdvanced = false
        errorMessage = nil
    }

    deinit {
        pollingTask?.cancel()
    }
}
