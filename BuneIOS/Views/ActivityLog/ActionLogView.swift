//
//  ActionLogView.swift
//  BuneIOS
//
//  Created by techvvs001 on 4/6/26.
//

import SwiftUI

struct ActionLogView: View {
    @StateObject private var viewModel: ActionLogViewModel
    @State private var expandedIds: Set<Int> = []

    init(apiClient: TransportAPIClient) {
        _viewModel = StateObject(wrappedValue: ActionLogViewModel(apiClient: apiClient))
    }

    var activeFilterCount: Int {
        viewModel.selectedActionTypes.count
    }

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [
                    BuneColors.backgroundPrimary,
                    BuneColors.backgroundSecondary,
                    BuneColors.backgroundTertiary
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                // Header
                Text("Activity Log")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(BuneColors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Filter Chips
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Filters")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(BuneColors.textSecondary)

                        if activeFilterCount > 0 {
                            Badge(count: activeFilterCount)
                                .padding(.leading, 4)
                        }

                        Spacer()

                        if activeFilterCount > 0 {
                            Button("Clear") {
                                viewModel.clearFilters()
                            }
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(BuneColors.accentPrimary)
                        }
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(viewModel.actionTypeOptions, id: \.self) { actionType in
                                FilterChip(
                                    label: actionType.replacingOccurrences(of: "_", with: " "),
                                    isSelected: viewModel.selectedActionTypes.contains(actionType),
                                    color: viewModel.colorForActionType(actionType),
                                    action: {
                                        viewModel.toggleFilter(actionType)
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .scrollClipDisabled()
                }

                // Log List
                if viewModel.logs.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 40))
                            .foregroundColor(BuneColors.textTertiary)

                        Text("No activity yet")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(BuneColors.textSecondary)

                        Text("Actions will appear here")
                            .font(.caption)
                            .foregroundColor(BuneColors.textTertiary)
                    }
                    .frame(maxHeight: .infinity)
                    .padding(40)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(Array(viewModel.logs.enumerated()), id: \.element.id) { index, log in
                                ActionLogRow(
                                    log: log,
                                    color: viewModel.colorForActionType(log.actionType),
                                    isExpanded: expandedIds.contains(log.id),
                                    onTap: {
                                        if expandedIds.contains(log.id) {
                                            expandedIds.remove(log.id)
                                        } else {
                                            expandedIds.insert(log.id)
                                        }
                                    }
                                )

                                // Load more trigger
                                if index == viewModel.logs.count - 3 {
                                    Color.clear
                                        .onAppear {
                                            Task {
                                                await viewModel.loadMore()
                                            }
                                        }
                                }
                            }

                            if viewModel.isLoading && !viewModel.logs.isEmpty {
                                VStack(spacing: 12) {
                                    ProgressView()
                                        .tint(BuneColors.accentPrimary)

                                    Text("Loading more...")
                                        .font(.caption)
                                        .foregroundColor(BuneColors.textSecondary)
                                }
                                .padding(20)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .refreshable {
                        await viewModel.refresh()
                    }
                }

                Spacer()
            }
            .padding(.vertical, 20)
        }
        .task {
            await viewModel.loadLogs()
        }
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(isSelected ? .white : BuneColors.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(
                            isSelected
                                ? color.opacity(0.7)
                                : Color.white.opacity(0.07)
                        )
                        .overlay(
                            Capsule()
                                .stroke(
                                    isSelected
                                        ? color.opacity(0.9)
                                        : Color.white.opacity(0.1),
                                    lineWidth: 1
                                )
                        )
                )
        }
    }
}

// MARK: - Badge

struct Badge: View {
    let count: Int

    var body: some View {
        Text("\(count)")
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .frame(width: 20, height: 20)
            .background(
                Circle()
                    .fill(BuneColors.accentPrimary)
            )
    }
}

// MARK: - Action Log Row

struct ActionLogRow: View {
    let log: ActionLog
    let color: Color
    let isExpanded: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Main Row
            HStack(spacing: 12) {
                // Left: Colored dot
                Circle()
                    .fill(color)
                    .frame(width: 10, height: 10)

                VStack(alignment: .leading, spacing: 8) {
                    // Top: Action type + timestamp
                    HStack(spacing: 8) {
                        Text(log.actionType.replacingOccurrences(of: "_", with: " "))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(BuneColors.textPrimary)

                        Spacer()

                        if let createdAt = log.createdAt {
                            Text(formattedTime(createdAt))
                                .font(.caption2)
                                .foregroundColor(BuneColors.textMuted)
                        }
                    }

                    // Middle: Action Label
                    if let label = log.actionLabel {
                        Text(label)
                            .font(.caption)
                            .foregroundColor(BuneColors.textSecondary)
                            .lineLimit(2)
                    }

                    // Bottom: Manifest + User
                    HStack(spacing: 12) {
                        if let manifestNumber = log.manifestNumber {
                            Text(manifestNumber)
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(BuneColors.textTertiary)
                                .lineLimit(1)
                        }

                        Spacer()

                        if let userEmail = log.userEmail {
                            Text(userEmail)
                                .font(.caption2)
                                .foregroundColor(BuneColors.textMuted)
                                .lineLimit(1)
                        }
                    }
                }

                Spacer()

                // Expand indicator
                if log.detailSummary != nil || log.metrcResponse != nil {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(BuneColors.textTertiary)
                }
            }
            .padding(16)
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)

            // Expanded Details
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    Divider()
                        .background(Color.white.opacity(0.1))

                    if let summary = log.detailSummary {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Details")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(BuneColors.textSecondary)

                            Text(summary)
                                .font(.caption)
                                .foregroundColor(BuneColors.textPrimary)
                                .lineLimit(10)
                        }
                    }

                    if let metrcResponse = log.metrcResponse {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("METRC Response")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(BuneColors.textSecondary)

                            Text(metrcResponse)
                                .font(.caption2)
                                .foregroundColor(BuneColors.textTertiary)
                                .lineLimit(10)
                        }
                    }

                    if let status = log.status {
                        HStack(spacing: 8) {
                            Text("Status")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(BuneColors.textSecondary)

                            Spacer()

                            StatusBadge(status: status)
                        }
                    }
                }
                .padding(16)
                .background(Color.white.opacity(0.02))
            }
        }
        .glassCard(cornerRadius: 14)
    }

    private func formattedTime(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            let timeFormatter = DateFormatter()
            timeFormatter.timeStyle = .short
            timeFormatter.dateStyle = .short
            return timeFormatter.string(from: date)
        }
        return dateString
    }
}

// MARK: - Preview

#Preview {
    ActionLogView(apiClient: TransportAPIClient(authService: AuthService()))
}
