//
//  ActionLogViewModel.swift
//  BuneIOS
//
//  Created by techvvs001 on 4/6/26.
//

import Foundation
import SwiftUI

@MainActor
class ActionLogViewModel: ObservableObject {
    @Published var logs: [ActionLog] = []
    @Published var isLoading = false
    @Published var selectedActionTypes: Set<String> = []
    @Published var currentPage = 0
    @Published var hasMore = true

    private let apiClient: TransportAPIClient
    private let pageSize = 20

    let actionTypeOptions = [
        "CREATED",
        "DISPATCHED",
        "DEPARTED",
        "SCAN",
        "UNSCAN",
        "STAGED",
        "STATUS_CHANGE",
        "COMPLETED",
        "ACCEPTED",
        "CANCELED",
        "GPS_PING",
        "GEOFENCE_ALERT",
        "MESSAGE",
        "SIGNATURE",
        "RECEIPT"
    ]

    init(apiClient: TransportAPIClient) {
        self.apiClient = apiClient
    }

    // MARK: - Load Logs

    func loadLogs() async {
        isLoading = true
        currentPage = 0
        logs = []
        defer { isLoading = false }

        await fetchLogs()
    }

    // MARK: - Load More (Pagination)

    func loadMore() async {
        guard hasMore && !isLoading else { return }

        isLoading = true
        currentPage += 1
        defer { isLoading = false }

        await fetchLogs()
    }

    // MARK: - Refresh

    func refresh() async {
        currentPage = 0
        logs = []
        await fetchLogs()
    }

    // MARK: - Toggle Filter

    func toggleFilter(_ type: String) {
        if selectedActionTypes.contains(type) {
            selectedActionTypes.remove(type)
        } else {
            selectedActionTypes.insert(type)
        }
        Task {
            await loadLogs()
        }
    }

    // MARK: - Clear Filters

    func clearFilters() {
        selectedActionTypes.removeAll()
        Task {
            await loadLogs()
        }
    }

    // MARK: - Private Helper

    private func fetchLogs() async {
        do {
            // For now, fetch without filter since API may not support multiple filters
            // In production, construct query based on selectedActionTypes
            let actionType = selectedActionTypes.first
            let newLogs = try await apiClient.listActionLog(
                actionType: actionType,
                page: currentPage,
                size: pageSize
            )

            if currentPage == 0 {
                logs = newLogs
            } else {
                logs.append(contentsOf: newLogs)
            }

            hasMore = newLogs.count == pageSize
        } catch {
            hasMore = false
        }
    }

    // MARK: - Color for Action Type

    func colorForActionType(_ type: String) -> Color {
        switch type {
        case "SCAN", "UNSCAN":
            return BuneColors.infoColor
        case "STATUS_CHANGE":
            return BuneColors.warningColor
        case "GEOFENCE_ALERT":
            return BuneColors.errorColor
        case "GPS_PING":
            return Color(red: 0.8, green: 0.4, blue: 1.0) // Purple
        case "MESSAGE":
            return BuneColors.successColor
        case "COMPLETED", "ACCEPTED":
            return BuneColors.statusDelivered
        case "CANCELED", "SIGNATURE":
            return BuneColors.errorColor
        default:
            return BuneColors.accentPrimary
        }
    }
}
