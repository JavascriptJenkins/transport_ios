//
//  TransferCard.swift
//  BuneIOS
//
//  Created by techvvs001 on 4/6/26.
//

import SwiftUI

// MARK: - Transfer Card
struct TransferCard: View {
    let manifestNumber: String
    let status: String
    let originName: String
    let destinationName: String
    let packageCount: Int
    let driverName: String
    let vehicleId: String

    var statusColor: Color {
        BuneColors.statusColor(for: status)
    }

    var body: some View {
        GlassCard {
            VStack(spacing: 0) {
                // Top row: Manifest + Status Badge
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Manifest #")
                            .font(.caption2)
                            .foregroundColor(BuneColors.textTertiary)

                        Text(manifestNumber)
                            .font(.system(.subheadline, design: .monospaced))
                            .fontWeight(.semibold)
                            .foregroundColor(BuneColors.textPrimary)
                    }

                    Spacer()

                    StatusBadge(status: status)
                }
                .padding(16)

                // Divider
                Divider()
                    .background(Color.white.opacity(0.1))

                // Origin -> Destination
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("From")
                            .font(.caption2)
                            .foregroundColor(BuneColors.textTertiary)

                        Text(originName)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(BuneColors.textPrimary)
                            .lineLimit(1)
                    }

                    Image(systemName: "arrow.right")
                        .foregroundColor(BuneColors.textTertiary)
                        .font(.caption)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("To")
                            .font(.caption2)
                            .foregroundColor(BuneColors.textTertiary)

                        Text(destinationName)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(BuneColors.textPrimary)
                            .lineLimit(1)
                    }

                    Spacer()
                }
                .padding(16)

                // Divider
                Divider()
                    .background(Color.white.opacity(0.1))

                // Bottom row: Details + Progress
                VStack(spacing: 12) {
                    HStack(spacing: 16) {
                        // Package count
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Packages")
                                .font(.caption2)
                                .foregroundColor(BuneColors.textTertiary)

                            Text("\(packageCount)")
                                .font(.system(.subheadline, design: .default))
                                .fontWeight(.semibold)
                                .foregroundColor(BuneColors.textPrimary)
                        }

                        Divider()
                            .frame(height: 32)

                        // Driver
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Driver")
                                .font(.caption2)
                                .foregroundColor(BuneColors.textTertiary)

                            Text(driverName)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(BuneColors.textPrimary)
                                .lineLimit(1)
                        }

                        Divider()
                            .frame(height: 32)

                        // Vehicle
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Vehicle")
                                .font(.caption2)
                                .foregroundColor(BuneColors.textTertiary)

                            Text(vehicleId)
                                .font(.system(.caption, design: .monospaced))
                                .fontWeight(.medium)
                                .foregroundColor(BuneColors.textPrimary)
                                .lineLimit(1)
                        }

                        Spacer()
                    }

                    // Mini progress bar
                    TransferProgressBar(currentStatus: status, compact: true)
                }
                .padding(16)
            }
        }
    }
}

// MARK: - Preview
#Preview {
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
            Text("Transfer Cards")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(BuneColors.textPrimary)
                .padding(.horizontal, 20)

            ScrollView {
                VStack(spacing: 16) {
                    TransferCard(
                        manifestNumber: "DEMO-0000001",
                        status: "IN_TRANSIT",
                        originName: "Origin Hub",
                        destinationName: "Destination Hub",
                        packageCount: 5,
                        driverName: "John Smith",
                        vehicleId: "VEH-1234"
                    )

                    TransferCard(
                        manifestNumber: "DEMO-0000002",
                        status: "DELIVERED",
                        originName: "Port Area",
                        destinationName: "Downtown",
                        packageCount: 8,
                        driverName: "Jane Doe",
                        vehicleId: "VEH-5678"
                    )

                    TransferCard(
                        manifestNumber: "DEMO-0000003",
                        status: "CREATED",
                        originName: "Warehouse A",
                        destinationName: "Warehouse B",
                        packageCount: 12,
                        driverName: "Pending",
                        vehicleId: "TBD"
                    )
                }
                .padding(20)
            }
        }
    }
}
