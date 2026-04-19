//
//  TransferListViewModel.swift
//  BuneIOS
//
//  Created by techvvs001 on 4/6/26.
//

import Foundation
import SwiftUI

// MARK: - Category Enum
//
// Raw values map to the backend's direction-group keys on
// GET /transport/api/transfers. Active Trips doesn't have its own
// backend group — it's every non-terminal transfer across groups
// filtered client-side by status.
enum TransferCategory: String, CaseIterable {
    case hub = "HUB"
    case outgoing = "OUTGOING"
    case incoming = "INCOMING"
    case activeTrips = "ACTIVE"

    var displayName: String {
        switch self {
        case .hub: return "Hub"
        case .outgoing: return "Outgoing"
        case .incoming: return "Incoming"
        case .activeTrips: return "Active"
        }
    }

    /// The backend group key for this category, or nil when the category
    /// spans multiple groups (Active Trips — every in-flight transfer
    /// regardless of direction).
    var backendGroup: String? {
        switch self {
        case .hub, .outgoing, .incoming: return rawValue
        case .activeTrips: return nil
        }
    }
}

// MARK: - Transfer List ViewModel
@MainActor
class TransferListViewModel: ObservableObject {

    // MARK: - Published Properties
    @Published var transfers: [Transfer] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    // Filter state — default to Hub Transfers since that's the primary
    // operational view for the current workflow.
    @Published var selectedCategory: TransferCategory = .hub
    @Published var selectedStatuses: Set<String> = []
    @Published var searchText: String = ""
    @Published var dateRange: (start: Date?, end: Date?) = (nil, nil)

    // Pagination
    @Published var currentPage: Int = 0
    @Published var totalPages: Int = 0
    @Published var hasMore: Bool = false

    // MARK: - Private Properties
    private let apiClient: TransportAPIClient
    private let pageSize = 20

    /// Notification service used to (re)schedule ETA + overdue alerts each
    /// time the list refreshes. Optional so previews / tests that don't
    /// need alerts can skip it.
    private let notificationService: NotificationService?

    /// Local cache used to warm-start and to serve stale results when the
    /// network fetch fails.
    private let cache: LocalCacheService?

    private let statusOptions = [
        "CREATED",
        "DISPATCH",
        "AT_HUB",
        "IN_TRANSIT",
        "DELIVERED",
        "ACCEPTED",
        "CANCELED"
    ]

    // MARK: - Init
    init(
        apiClient: TransportAPIClient,
        notificationService: NotificationService? = nil,
        cache: LocalCacheService? = nil
    ) {
        self.apiClient = apiClient
        self.notificationService = notificationService
        self.cache = cache
        // Warm-start from cache so the list has rows to render before the
        // first network call returns. Filtering/refresh will overwrite.
        if let cached = cache?.cachedTransfers, !cached.isEmpty {
            self.transfers = cached
        }
    }

    // MARK: - Public Methods

    /// Load transfers with current filters
    func loadTransfers() async {
        isLoading = true
        errorMessage = nil
        currentPage = 0
        transfers = []

        await performLoad()
    }

    /// Load more transfers (pagination)
    func loadMore() async {
        guard hasMore else { return }
        currentPage += 1
        await performLoad(append: true)
    }

    /// Refresh transfers (reset to first page)
    func refresh() async {
        currentPage = 0
        transfers = []
        errorMessage = nil
        await performLoad()
    }

    /// Toggle a status filter
    func applyFilter(status: String) {
        if selectedStatuses.contains(status) {
            selectedStatuses.remove(status)
        } else {
            selectedStatuses.insert(status)
        }

        Task {
            await refresh()
        }
    }

    /// Clear all status filters
    func clearFilters() {
        selectedStatuses.removeAll()
        Task {
            await refresh()
        }
    }

    /// Select a new category and reload
    func selectCategory(_ category: TransferCategory) {
        selectedCategory = category
        Task {
            await refresh()
        }
    }

    // MARK: - Private Methods

    private func performLoad(append: Bool = false) async {
        isLoading = true
        errorMessage = nil

        do {
            // Build status parameter. Active Trips is really a
            // "in-flight across all directions" view, so when no explicit
            // status filter is applied we narrow it to IN_TRANSIT.
            let statusParam: String?
            if !selectedStatuses.isEmpty {
                statusParam = selectedStatuses.joined(separator: ",")
            } else if selectedCategory == .activeTrips {
                statusParam = "IN_TRANSIT"
            } else {
                statusParam = nil
            }

            // Direction group narrows the backend response — nil for
            // Active Trips (which spans OUTGOING + INCOMING + HUB).
            let result: [Transfer] = try await apiClient.listTransfers(
                direction: selectedCategory.backendGroup,
                page: currentPage,
                size: pageSize,
                status: statusParam
            )

            if append {
                transfers.append(contentsOf: result)
            } else {
                transfers = result
            }

            // Update pagination state
            // Note: The API returns a flat array, so we estimate pagination
            hasMore = result.count == pageSize
            totalPages = (transfers.count + pageSize - 1) / pageSize

            // Re-schedule ETA + overdue notifications against fresh data.
            // Delivered / canceled transfers get their pending alerts canceled;
            // active ones with an ETA get an "arriving soon" + "overdue" pair.
            notificationService?.refreshScheduledAlerts(for: transfers)

            // Snapshot to cache on first-page loads only so offline launches
            // warm-start with the last-seen slice of transfers rather than
            // a partial append of an old filter.
            if !append && currentPage == 0 {
                cache?.cacheTransfers(transfers)
            }

        } catch {
            // Preserve any cached rows we warm-started with instead of clearing
            // them on a network blip.
            if transfers.isEmpty {
                errorMessage = "Failed to load transfers: \(error.localizedDescription)"
            }
        }

        isLoading = false
    }

    // MARK: - Helper Methods

    /// Get display name for a status
    func statusDisplayName(_ status: String) -> String {
        status.replacingOccurrences(of: "_", with: " ").capitalized
    }

    /// Get color for a status
    func statusColor(_ status: String) -> Color {
        BuneColors.statusColor(for: status)
    }

    /// Filter transfers based on search text
    var filteredTransfers: [Transfer] {
        guard !searchText.isEmpty else { return transfers }

        return transfers.filter { transfer in
            let manifest = transfer.manifestNumber ?? ""
            let shipper = transfer.shipperFacilityName ?? ""

            return manifest.localizedCaseInsensitiveContains(searchText) ||
                   shipper.localizedCaseInsensitiveContains(searchText)
        }
    }
}
