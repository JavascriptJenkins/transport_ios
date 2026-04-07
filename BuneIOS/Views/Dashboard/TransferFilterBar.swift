//
//  TransferFilterBar.swift
//  BuneIOS
//
//  Created by techvvs001 on 4/6/26.
//

import SwiftUI

// MARK: - Transfer Filter Bar
struct TransferFilterBar: View {
    @Binding var selectedStatuses: Set<String>

    private let statusOptions = [
        "CREATED",
        "DISPATCH",
        "AT_HUB",
        "IN_TRANSIT",
        "DELIVERED",
        "ACCEPTED",
        "CANCELED"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with clear button
            HStack {
                Text("Filters")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(BuneColors.textSecondary)

                Spacer()

                if !selectedStatuses.isEmpty {
                    Button(action: {
                        selectedStatuses.removeAll()
                    }) {
                        Text("Clear")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(BuneColors.accentPrimary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            // Filter pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(statusOptions, id: \.self) { status in
                        FilterPill(
                            status: status,
                            isSelected: selectedStatuses.contains(status),
                            action: {
                                toggleStatus(status)
                            }
                        )
                    }
                }
                .padding(.horizontal, 16)
            }
            .frame(height: 40)

            // Active filter count
            if !selectedStatuses.isEmpty {
                Text("Active filters: \(selectedStatuses.count)")
                    .font(.caption2)
                    .foregroundColor(BuneColors.textTertiary)
                    .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 8)
    }

    private func toggleStatus(_ status: String) {
        if selectedStatuses.contains(status) {
            selectedStatuses.remove(status)
        } else {
            selectedStatuses.insert(status)
        }
    }
}

// MARK: - Filter Pill Component
private struct FilterPill: View {
    let status: String
    let isSelected: Bool
    let action: () -> Void

    private var statusColor: Color {
        BuneColors.statusColor(for: status)
    }

    private var displayText: String {
        status.replacingOccurrences(of: "_", with: " ").capitalized
    }

    var body: some View {
        Button(action: action) {
            Text(displayText)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(
                            isSelected
                                ? statusColor
                                : statusColor.opacity(0.2)
                        )
                )
                .overlay(
                    Capsule()
                        .stroke(
                            isSelected
                                ? statusColor.opacity(0.6)
                                : Color.white.opacity(0.1),
                            lineWidth: 1
                        )
                )
        }
    }
}

// MARK: - Preview

private struct TransferFilterBarPreview: View {
    @State var selectedStatuses: Set<String> = ["IN_TRANSIT", "DELIVERED"]

    var body: some View {
        ZStack {
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

            VStack(spacing: 16) {
                Text("Transfer Filter Bar")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(BuneColors.textPrimary)
                    .padding(.top, 20)

                GlassCard {
                    TransferFilterBar(selectedStatuses: $selectedStatuses)
                }

                Spacer()
            }
            .padding(.horizontal, 20)
        }
    }
}

#Preview {
    TransferFilterBarPreview()
}
