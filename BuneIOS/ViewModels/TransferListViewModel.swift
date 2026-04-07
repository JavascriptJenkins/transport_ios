//
//  TransferListViewModel.swift
//  BuneIOS
//
//  Created by techvvs001 on 4/6/26.
//

import Foundation
import SwiftUI

// MARK: - Category Enum
enum TransferCategory: String, CaseIterable {
    case outgoing = "OUTGOING"
    case incoming = "INCOMING"
    case hub = "AT_HUB"
    case activeTrips = "IN_TRANSIT"

    var displayName: String {
        switch self {
        case .outgoing:
            return "Outgoing"
        case .incoming:
            return "Incoming"
        case .hub:
            return "Hub"
        case .activeTrips:
            return "Active"
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

    // Filter state
    @Published var selectedCategory: TransferCategory = .outgoing
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
    init(apiClient: TransportAPIClient) {
        self.apiClient = apiClient
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
            // Build status parameter from selected statuses
            let statusParam: String?
            if !selectedStatuses.isEmpty {
                statusParam = selectedStatuses.joined(separator: ",")
            } else {
                statusParam = nil
            }

            // Call API with current filters
            let result: [Transfer] = try await apiClient.listTransfers(
                direction: selectedCategory.rawValue,
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

        } catch {
            errorMessage = "Failed to load transfers: \(error.localizedDescription)"
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
