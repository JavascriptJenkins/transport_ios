//
//  ScanPhaseView.swift
//  BuneIOS
//
//  Created by techvvs001 on 4/6/26.
//

import SwiftUI

// MARK: - Scan Phase View

struct ScanPhaseView: View {
    @ObservedObject var viewModel: SessionBuilderViewModel
    @State private var scanInput: String = ""
    @State private var showPackageBrowser = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Scan Packages")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(BuneColors.textPrimary)

                    Text("Start by scanning package barcodes to add them to the manifest")
                        .font(.subheadline)
                        .foregroundColor(BuneColors.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 8)

                // Barcode scan input
                VStack(spacing: 16) {
                    ScanInputField(
                        text: $scanInput,
                        placeholder: "Scan METRC barcode",
                        onSubmit: {
                            Task {
                                await viewModel.addPackage(tag: scanInput)
                            }
                        }
                    )

                    // Browse button
                    Button(action: { showPackageBrowser = true }) {
                        HStack(spacing: 12) {
                            Image(systemName: "list.bullet.clipboard")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Browse All Packages")
                                .font(.system(size: 16, weight: .semibold))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(BuneColors.glassFill)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(BuneColors.glassBorder, lineWidth: 1)
                                )
                        )
                        .foregroundColor(BuneColors.textPrimary)
                    }
                }
                .padding(.horizontal, 20)

                // Package count
                HStack(spacing: 12) {
                    Image(systemName: "shippingbox.fill")
                        .font(.system(size: 18))
                        .foregroundColor(BuneColors.accentPrimary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Scanned Packages")
                            .font(.caption)
                            .foregroundColor(BuneColors.textTertiary)

                        Text("\(viewModel.scannedPackages.count) package\(viewModel.scannedPackages.count != 1 ? "s" : "")")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(BuneColors.textPrimary)
                    }

                    Spacer()
                }
                .padding(16)
                .glassCard(cornerRadius: 16)
                .padding(.horizontal, 20)

                // Scanned packages list
                if !viewModel.scannedPackages.isEmpty {
                    VStack(spacing: 0) {
                        HStack(spacing: 12) {
                            Text("Package Details")
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
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(BuneColors.backgroundSecondary)
                        .cornerRadius(16, corners: [.topLeft, .topRight])

                        Divider()
                            .background(BuneColors.glassBorder)

                        VStack(spacing: 0) {
                            ForEach(viewModel.scannedPackages.indices, id: \.self) { index in
                                PackageRow(
                                    package: viewModel.scannedPackages[index],
                                    onRemove: {
                                        Task {
                                            await viewModel.removePackage(
                                                label: viewModel.scannedPackages[index].packageLabel
                                            )
                                        }
                                    }
                                )

                                if index < viewModel.scannedPackages.count - 1 {
                                    Divider()
                                        .background(BuneColors.glassBorder)
                                }
                            }
                        }
                        .padding(.vertical, 12)
                    }
                    .glassCard(cornerRadius: 16)
                    .padding(.horizontal, 20)
                }

                // Navigation buttons
                HStack(spacing: 12) {
                    Spacer()

                    Button(action: { viewModel.advancePhase() }) {
                        HStack(spacing: 8) {
                            Text("Next: Configure")
                                .font(.system(size: 16, weight: .semibold))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 14, weight: .semibold))
                        }
                    }
                    .accentButton()
                    .opacity(viewModel.scannedPackages.count >= 1 ? 1.0 : 0.5)
                    .disabled(viewModel.scannedPackages.count < 1)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 20)
            }
        }
        .sheet(isPresented: $showPackageBrowser) {
            Text("Package browser coming soon")
                .font(.headline)
                .padding()
        }
    }
}

// MARK: - Package Row Component

struct PackageRow: View {
    let package: SessionPackage
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(package.packageLabel)
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(BuneColors.accentPrimary)

                if let productName = package.productName {
                    Text(productName)
                        .font(.caption)
                        .foregroundColor(BuneColors.textSecondary)
                        .lineLimit(1)
                }

                if let quantity = package.quantity, let unit = package.unitOfMeasure {
                    HStack(spacing: 4) {
                        Text("\(String(format: "%.1f", quantity))")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(BuneColors.textTertiary)

                        Text(unit)
                            .font(.caption2)
                            .foregroundColor(BuneColors.textMuted)
                    }
                }
            }

            Spacer()

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(BuneColors.errorColor.opacity(0.7))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Corner Radius Extension

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Preview

#Preview {
    let mockAuthService = AuthService()
    let mockAPIClient = TransportAPIClient(authService: mockAuthService)
    let viewModel = SessionBuilderViewModel(apiClient: mockAPIClient)

    ZStack {
        BuneColors.backgroundPrimary.ignoresSafeArea()

        ScanPhaseView(viewModel: viewModel)
    }
}
