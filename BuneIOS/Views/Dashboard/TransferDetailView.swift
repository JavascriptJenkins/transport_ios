//
//  TransferDetailView.swift
//  BuneIOS
//
//  Created by techvvs001 on 4/6/26.
//

import SwiftUI

// MARK: - Transfer Detail View
struct TransferDetailView: View {
    @StateObject private var viewModel: TransferDetailViewModel
    let transferId: Int
    let apiClient: TransportAPIClient

    init(transferId: Int, apiClient: TransportAPIClient) {
        self.transferId = transferId
        self.apiClient = apiClient
        _viewModel = StateObject(
            wrappedValue: TransferDetailViewModel(transferId: transferId, apiClient: apiClient)
        )
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

            // Content
            if viewModel.isLoading && viewModel.transfer == nil {
                VStack {
                    ProgressView()
                        .tint(BuneColors.accentPrimary)
                    Text("Loading transfer details...")
                        .font(.caption)
                        .foregroundColor(BuneColors.textSecondary)
                        .padding(.top, 12)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else if let transfer = viewModel.transfer {
                ScrollView {
                    VStack(spacing: 20) {
                        // MARK: - Section 1: Header
                        VStack(spacing: 12) {
                            Text(transfer.manifestNumber ?? "Unknown")
                                .font(.system(size: 28, weight: .bold, design: .monospaced))
                                .foregroundColor(BuneColors.textPrimary)

                            StatusBadge(status: transfer.status)

                            TransferProgressBar(currentStatus: transfer.status, compact: false)
                                .padding(.top, 8)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(20)
                        .glassCard()

                        // MARK: - Section 2: Transfer Info
                        GlassCard {
                            VStack(spacing: 16) {
                                InfoRow(
                                    label: "From",
                                    value: transfer.shipperFacilityName ?? "Unknown",
                                    detail: transfer.shipperFacilityLicenseNumber
                                )

                                Divider()
                                    .opacity(0.3)

                                if let destinations = transfer.destinations, !destinations.isEmpty {
                                    let destination = destinations[0]
                                    InfoRow(
                                        label: "To",
                                        value: destination.recipientFacilityName ?? "Unknown",
                                        detail: destination.recipientFacilityLicenseNumber
                                    )
                                }

                                Divider()
                                    .opacity(0.3)

                                HStack {
                                    Text("Direction")
                                        .font(.caption)
                                        .foregroundColor(BuneColors.textSecondary)

                                    Spacer()

                                    Text(transfer.direction ?? "")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(BuneColors.accentPrimary)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(
                                            Capsule()
                                                .fill(BuneColors.accentPrimary.opacity(0.2))
                                        )
                                }
                            }
                            .padding(16)
                        }

                        // MARK: - Section 3: Logistics
                        GlassCard {
                            VStack(spacing: 14) {
                                InfoRow(
                                    label: "Driver",
                                    value: transfer.driverName ?? "Unassigned"
                                )

                                Divider()
                                    .opacity(0.3)

                                InfoRow(
                                    label: "Vehicle",
                                    value: transfer.vehiclePlate ?? "Unknown"
                                )

                                Divider()
                                    .opacity(0.3)

                                if let routeName = transfer.routeName {
                                    InfoRow(
                                        label: "Route",
                                        value: routeName
                                    )

                                    Divider()
                                        .opacity(0.3)
                                }

                                if let eta = transfer.estimatedArrivalDateTime {
                                    InfoRow(
                                        label: "ETA",
                                        value: formatDateTime(eta)
                                    )

                                    Divider()
                                        .opacity(0.3)
                                }

                                InfoRow(
                                    label: "Packages",
                                    value: String(transfer.packageCount ?? 0)
                                )
                            }
                            .padding(16)
                        }

                        // MARK: - Section 4: Action Buttons
                        VStack(spacing: 12) {
                            if shouldShowDispatchButton(transfer.status) {
                                Button(action: { Task { await viewModel.updateStatus("DISPATCH") } }) {
                                    Text("Dispatch")
                                }
                                .accentButton()
                            }

                            if shouldShowDepartButton(transfer.status) {
                                Button(action: { Task { await viewModel.updateStatus("IN_TRANSIT") } }) {
                                    Text("Depart")
                                }
                                .accentButton()
                            }

                            if shouldShowMarkDeliveredButton(transfer.status) {
                                Button(action: { Task { await viewModel.updateStatus("DELIVERED") } }) {
                                    Text("Mark Delivered")
                                }
                                .accentButton()
                            }

                            if shouldShowStartDeliveryButton(transfer.status) {
                                Button(action: { Task { await viewModel.updateStatus("ACCEPTED") } }) {
                                    Text("Start Delivery Scan")
                                }
                                .accentButton()
                            }
                        }
                        .frame(maxWidth: .infinity)

                        // MARK: - Section 5: Packages
                        GlassCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Packages (\(viewModel.packages.count))")
                                    .font(.headline)
                                    .foregroundColor(BuneColors.textPrimary)

                                Divider()
                                    .opacity(0.3)

                                VStack(spacing: 0) {
                                    ForEach(viewModel.packages, id: \.id) { package in
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(package.packageLabel)
                                                .font(.system(.caption, design: .monospaced))
                                                .foregroundColor(BuneColors.accentPrimary)

                                            if let productName = package.productName {
                                                Text(productName)
                                                    .font(.caption)
                                                    .foregroundColor(BuneColors.textSecondary)
                                            }

                                            if let qty = package.shippedQuantity, let unit = package.shippedUnit {
                                                Text("\(Int(qty)) \(unit)")
                                                    .font(.caption2)
                                                    .foregroundColor(BuneColors.textTertiary)
                                            }
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.vertical, 8)

                                        if package.id != viewModel.packages.last?.id {
                                            Divider()
                                                .opacity(0.2)
                                        }
                                    }
                                }
                            }
                            .padding(16)
                        }

                        // MARK: - Section 6: Chat
                        NavigationLink(destination: ChatView(transferId: transferId, apiClient: apiClient)) {
                            HStack {
                                Image(systemName: "bubble.right")
                                    .foregroundColor(BuneColors.accentPrimary)

                                Text("Messages")
                                    .foregroundColor(BuneColors.textPrimary)

                                Spacer()

                                if viewModel.messages.count > 0 {
                                    Text(String(viewModel.messages.count))
                                        .font(.caption2)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            Capsule()
                                                .fill(BuneColors.accentPrimary)
                                        )
                                }

                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(BuneColors.textTertiary)
                            }
                            .padding(16)
                            .glassCard()
                        }

                        // Error message
                        if let error = viewModel.errorMessage {
                            VStack(spacing: 8) {
                                HStack {
                                    Image(systemName: "exclamationmark.circle.fill")
                                        .foregroundColor(BuneColors.errorColor)

                                    Text(error)
                                        .font(.caption)
                                        .foregroundColor(BuneColors.errorColor)

                                    Spacer()
                                }
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(BuneColors.errorColor.opacity(0.1))
                            )
                        }
                    }
                    .padding(16)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title2)
                        .foregroundColor(BuneColors.warningColor)

                    Text("Unable to load transfer")
                        .font(.headline)
                        .foregroundColor(BuneColors.textPrimary)

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(BuneColors.textSecondary)
                    }

                    Button(action: {
                        Task {
                            await viewModel.loadAll()
                        }
                    }) {
                        Text("Retry")
                    }
                    .accentButton()
                    .padding(.top, 12)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
        .task {
            await viewModel.loadAll()
        }
        .navigationTitle("Transfer Details")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Helper Functions
    private func shouldShowDispatchButton(_ status: String) -> Bool {
        ["CREATED"].contains(status)
    }

    private func shouldShowDepartButton(_ status: String) -> Bool {
        ["DISPATCH", "AT_HUB"].contains(status)
    }

    private func shouldShowMarkDeliveredButton(_ status: String) -> Bool {
        ["IN_TRANSIT"].contains(status)
    }

    private func shouldShowStartDeliveryButton(_ status: String) -> Bool {
        ["DELIVERED"].contains(status)
    }

    private func formatDateTime(_ dateStr: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateStr) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .short
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        return dateStr
    }
}

// MARK: - Info Row Component
struct InfoRow: View {
    let label: String
    let value: String
    var detail: String?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(.caption)
                .foregroundColor(BuneColors.textSecondary)
                .frame(width: 50, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(BuneColors.textPrimary)

                if let detail = detail {
                    Text(detail)
                        .font(.caption2)
                        .foregroundColor(BuneColors.textTertiary)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
    }
}

// MARK: - Preview
#Preview {
    let mockAPIClient = TransportAPIClient(authService: AuthService())
    return NavigationStack {
        TransferDetailView(transferId: 1, apiClient: mockAPIClient)
    }
}
