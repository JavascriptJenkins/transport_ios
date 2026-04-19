//
//  TransferListView.swift
//  BuneIOS
//
//  Created by techvvs001 on 4/6/26.
//

import SwiftUI

// MARK: - Transfer List View
struct TransferListView: View {
    @StateObject private var viewModel: TransferListViewModel
    @EnvironmentObject private var demoModeService: DemoModeService
    @Environment(\.colorScheme) var colorScheme

    private let apiClient: TransportAPIClient

    init(
        apiClient: TransportAPIClient,
        notificationService: NotificationService? = nil,
        cache: LocalCacheService? = nil,
        demoModeService: DemoModeService? = nil
    ) {
        self.apiClient = apiClient
        _viewModel = StateObject(
            wrappedValue: TransferListViewModel(
                apiClient: apiClient,
                notificationService: notificationService,
                cache: cache,
                demoModeService: demoModeService
            )
        )
    }

    var body: some View {
        NavigationStack {
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

                VStack(spacing: 0) {
                    // Header
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Transfers")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(BuneColors.textPrimary)

                        // Category Tabs
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(TransferCategory.allCases, id: \.self) { category in
                                    CategoryTab(
                                        title: category.displayName,
                                        isSelected: viewModel.selectedCategory == category,
                                        action: {
                                            viewModel.selectCategory(category)
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        .frame(height: 44)

                        // Search Bar
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(BuneColors.textTertiary)

                            TextField("Search manifest or shipper", text: $viewModel.searchText)
                                .textFieldStyle(.plain)
                                .foregroundColor(BuneColors.textPrimary)

                            if !viewModel.searchText.isEmpty {
                                Button(action: { viewModel.searchText = "" }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(BuneColors.textTertiary)
                                }
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(BuneColors.glassFill)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(BuneColors.glassBorder, lineWidth: 1)
                                )
                        )
                        .padding(.horizontal, 20)
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 12)

                    // Filter Bar
                    GlassCard {
                        TransferFilterBar(selectedStatuses: $viewModel.selectedStatuses)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)

                    // Transfer List
                    if viewModel.isLoading && viewModel.transfers.isEmpty {
                        VStack(spacing: 16) {
                            ProgressView()
                                .tint(BuneColors.accentPrimary)

                            Text("Loading transfers...")
                                .font(.caption)
                                .foregroundColor(BuneColors.textSecondary)
                        }
                        .frame(maxHeight: .infinity)
                    } else if viewModel.filteredTransfers.isEmpty && !viewModel.isLoading {
                        EmptyStateView()
                            .frame(maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(viewModel.filteredTransfers, id: \.id) { transfer in
                                    NavigationLink(destination: TransferDetailView(transferId: transfer.id, apiClient: apiClient)) {
                                        TransferCard(
                                            manifestNumber: transfer.manifestNumber ?? "Unknown",
                                            status: transfer.status,
                                            originName: transfer.shipperFacilityName ?? "Unknown",
                                            destinationName: transfer.destinations?.first?.recipientFacilityName ?? "Unknown",
                                            packageCount: transfer.packageCount ?? 0,
                                            driverName: transfer.driverName ?? "Pending",
                                            vehicleId: transfer.vehiclePlate ?? "TBD"
                                        )
                                    }
                                    .onAppear {
                                        // Load more when approaching end
                                        if transfer.id == viewModel.filteredTransfers.last?.id {
                                            Task {
                                                await viewModel.loadMore()
                                            }
                                        }
                                    }
                                }

                                // Loading indicator for pagination
                                if viewModel.isLoading && !viewModel.transfers.isEmpty {
                                    HStack {
                                        Spacer()
                                        ProgressView()
                                            .tint(BuneColors.accentPrimary)
                                        Spacer()
                                    }
                                    .padding(.vertical, 16)
                                }
                            }
                            .padding(20)
                        }
                        .refreshable {
                            await viewModel.refresh()
                        }
                    }

                    // Error message
                    if let errorMessage = viewModel.errorMessage {
                        VStack(spacing: 8) {
                            HStack(spacing: 10) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundColor(BuneColors.errorColor)

                                Text(errorMessage)
                                    .font(.caption)
                                    .foregroundColor(BuneColors.textPrimary)

                                Spacer()

                                Button(action: { viewModel.errorMessage = nil }) {
                                    Image(systemName: "xmark")
                                        .foregroundColor(BuneColors.textTertiary)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(BuneColors.errorColor.opacity(0.15))
                            )
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)
                    }
                }
            }
            .onAppear {
                Task {
                    await viewModel.loadTransfers()
                    // Pull the latest demo flag so the banner reflects
                    // toggles from another user/device without needing
                    // the settings screen to be visited first.
                    await demoModeService.refresh()
                }
            }
        }
    }
}

// MARK: - Category Tab Component
private struct CategoryTab: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(isSelected ? .white : BuneColors.textSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(
                            isSelected
                                ? BuneColors.accentPrimary
                                : BuneColors.glassFill
                        )
                )
                .overlay(
                    Capsule()
                        .stroke(
                            isSelected
                                ? BuneColors.accentPrimary.opacity(0.5)
                                : BuneColors.glassBorder,
                            lineWidth: 1
                        )
                )
        }
    }
}

// MARK: - Empty State View
private struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "shippingbox")
                .font(.system(size: 48))
                .foregroundColor(BuneColors.textTertiary)
                .opacity(0.5)

            VStack(spacing: 8) {
                Text("No Transfers Found")
                    .font(.headline)
                    .foregroundColor(BuneColors.textPrimary)

                Text("Try adjusting your filters or checking back later")
                    .font(.caption)
                    .foregroundColor(BuneColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(40)
    }
}

// MARK: - Preview
#Preview {
    TransferListView(apiClient: TransportAPIClient(authService: AuthService()))
}
