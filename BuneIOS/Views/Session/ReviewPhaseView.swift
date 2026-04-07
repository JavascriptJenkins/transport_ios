//
//  ReviewPhaseView.swift
//  BuneIOS
//
//  Created by techvvs001 on 4/6/26.
//

import SwiftUI

// MARK: - Review Phase View

struct ReviewPhaseView: View {
    @ObservedObject var viewModel: SessionBuilderViewModel

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 24) {
                    if viewModel.submissionResult?.success == true {
                        successState
                    } else {
                        reviewState
                    }
                }
            }
        }
    }

    // MARK: - Review State

    private var reviewState: some View {
        VStack(spacing: 24) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text("Review Manifest")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(BuneColors.textPrimary)

                Text("Verify all details before submitting to METRC")
                    .font(.subheadline)
                    .foregroundColor(BuneColors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)

            // Validation warnings
            if !viewModel.isReviewPhaseValid() {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(BuneColors.warningColor)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Missing Information")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(BuneColors.warningColor)

                        Text("Please complete all required fields before submitting")
                            .font(.caption2)
                            .foregroundColor(BuneColors.warningColor)
                    }

                    Spacer()
                }
                .padding(12)
                .background(BuneColors.warningColor.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal, 20)
            }

            // Transfer Summary
            GlassCard {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Transfer Summary")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(BuneColors.textPrimary)

                    Divider()
                        .background(BuneColors.glassBorder)

                    // Transporter
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Transporter")
                                .font(.caption)
                                .foregroundColor(BuneColors.textTertiary)
                            Text(
                                viewModel.transporters.first(where: { $0.id == viewModel.selectedTransporterId })?.name
                                    ?? "Not Selected"
                            )
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(BuneColors.textPrimary)
                        }
                        Spacer()
                    }

                    Divider()
                        .background(BuneColors.glassBorder)

                    // Recipient
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Recipient Facility")
                                .font(.caption)
                                .foregroundColor(BuneColors.textTertiary)
                            Text(
                                viewModel.destinations.first(where: { $0.id == viewModel.selectedDestinationId })?.name
                                    ?? "Not Selected"
                            )
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(BuneColors.textPrimary)
                        }
                        Spacer()
                    }

                    Divider()
                        .background(BuneColors.glassBorder)

                    // Transfer Type
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Transfer Type")
                                .font(.caption)
                                .foregroundColor(BuneColors.textTertiary)
                            Text(viewModel.selectedTransferType ?? "Not Selected")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(BuneColors.textPrimary)
                        }
                        Spacer()
                    }

                    Divider()
                        .background(BuneColors.glassBorder)

                    // Driver
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Driver")
                                .font(.caption)
                                .foregroundColor(BuneColors.textTertiary)
                            Text(
                                viewModel.drivers.first(where: { $0.id == viewModel.selectedDriverId })?.name
                                    ?? "Not Selected"
                            )
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(BuneColors.textPrimary)
                        }
                        Spacer()
                    }

                    Divider()
                        .background(BuneColors.glassBorder)

                    // Vehicle
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Vehicle")
                                .font(.caption)
                                .foregroundColor(BuneColors.textTertiary)
                            if let vehicle = viewModel.vehicles.first(where: { $0.id == viewModel.selectedVehicleId }) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(vehicle.plate)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(BuneColors.textPrimary)
                                    Text("\(vehicle.make ?? "Unknown") \(vehicle.model ?? "")")
                                        .font(.caption2)
                                        .foregroundColor(BuneColors.textSecondary)
                                }
                            } else {
                                Text("Not Selected")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(BuneColors.textPrimary)
                            }
                        }
                        Spacer()
                    }

                    // Route (if selected)
                    if let route = viewModel.routes.first(where: { $0.id == viewModel.selectedRouteId }) {
                        Divider()
                            .background(BuneColors.glassBorder)

                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Route")
                                    .font(.caption)
                                    .foregroundColor(BuneColors.textTertiary)
                                Text(route.name)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(BuneColors.textPrimary)
                            }
                            Spacer()
                        }
                    }

                    Divider()
                        .background(BuneColors.glassBorder)

                    // Schedule
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Departure")
                                .font(.caption)
                                .foregroundColor(BuneColors.textTertiary)
                            Text(formatDate(viewModel.estimatedDeparture))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(BuneColors.textPrimary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Arrival")
                                .font(.caption)
                                .foregroundColor(BuneColors.textTertiary)
                            Text(formatDate(viewModel.estimatedArrival))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(BuneColors.textPrimary)
                        }
                    }

                    // Notes (if present)
                    if !viewModel.notes.isEmpty {
                        Divider()
                            .background(BuneColors.glassBorder)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Notes")
                                .font(.caption)
                                .foregroundColor(BuneColors.textTertiary)
                            Text(viewModel.notes)
                                .font(.system(size: 13))
                                .foregroundColor(BuneColors.textSecondary)
                                .lineLimit(3)
                        }
                    }
                }
                .padding(16)
            }
            .padding(.horizontal, 20)

            // Packages Summary
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Text("Packages")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(BuneColors.textPrimary)

                        Spacer()

                        Text("\(viewModel.scannedPackages.count)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(BuneColors.accentPrimary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(BuneColors.accentPrimary.opacity(0.2))
                            .cornerRadius(6)
                    }

                    Divider()
                        .background(BuneColors.glassBorder)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(viewModel.scannedPackages.prefix(5)) { package in
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(package.packageLabel)
                                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                            .foregroundColor(BuneColors.accentPrimary)

                                        if let productName = package.productName {
                                            Text(productName)
                                                .font(.caption2)
                                                .foregroundColor(BuneColors.textSecondary)
                                                .lineLimit(1)
                                        }
                                    }
                                    Spacer()
                                }
                                .padding(8)
                                .background(BuneColors.backgroundSecondary)
                                .cornerRadius(8)
                            }

                            if viewModel.scannedPackages.count > 5 {
                                HStack {
                                    Text("+ \(viewModel.scannedPackages.count - 5) more packages")
                                        .font(.caption)
                                        .foregroundColor(BuneColors.textTertiary)
                                    Spacer()
                                }
                                .padding(.top, 8)
                            }
                        }
                    }
                    .frame(maxHeight: 250)
                }
                .padding(16)
            }
            .padding(.horizontal, 20)

            // Navigation buttons
            HStack(spacing: 12) {
                Button(action: { viewModel.goBackPhase() }) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Back")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(BuneColors.glassFill)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(BuneColors.glassBorder, lineWidth: 1))
                .foregroundColor(BuneColors.textPrimary)

                Button(action: {
                    Task {
                        await viewModel.submitSession()
                    }
                }) {
                    HStack(spacing: 8) {
                        if viewModel.isSubmitting {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.white)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        Text(viewModel.isSubmitting ? "Submitting..." : "Submit to METRC")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                .frame(maxWidth: .infinity)
                .accentButton()
                .opacity(viewModel.isReviewPhaseValid() ? 1.0 : 0.5)
                .disabled(viewModel.isReviewPhaseValid() == false || viewModel.isSubmitting)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Success State

    private var successState: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(BuneColors.statusDelivered.opacity(0.2))
                        .frame(width: 80, height: 80)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(BuneColors.statusDelivered)
                }

                VStack(spacing: 8) {
                    Text("Transfer Created")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(BuneColors.textPrimary)

                    Text("Your manifest has been successfully submitted to METRC")
                        .font(.subheadline)
                        .foregroundColor(BuneColors.textSecondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Text("Manifest Number")
                            .font(.caption)
                            .foregroundColor(BuneColors.textTertiary)
                        Spacer()
                        Text(viewModel.submissionResult?.manifestNumber ?? "Pending")
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                            .foregroundColor(BuneColors.accentPrimary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(BuneColors.glassFill)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(BuneColors.glassBorder, lineWidth: 1)
                            )
                    )

                    HStack(spacing: 12) {
                        Text("Transfer ID")
                            .font(.caption)
                            .foregroundColor(BuneColors.textTertiary)
                        Spacer()
                        Text("#\(viewModel.submissionResult?.transferId ?? 0)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(BuneColors.accentPrimary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(BuneColors.glassFill)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(BuneColors.glassBorder, lineWidth: 1)
                            )
                    )
                }
            }
            .padding(.horizontal, 20)

            Spacer()

            HStack(spacing: 12) {
                Spacer()

                Button(action: {
                    Task {
                        await viewModel.abandonSession()
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Done")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                .accentButton()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Helper Methods

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview {
    let mockAuthService = AuthService()
    let mockAPIClient = TransportAPIClient(authService: mockAuthService)
    let viewModel = SessionBuilderViewModel(apiClient: mockAPIClient)

    ZStack {
        BuneColors.backgroundPrimary.ignoresSafeArea()

        ReviewPhaseView(viewModel: viewModel)
    }
}
