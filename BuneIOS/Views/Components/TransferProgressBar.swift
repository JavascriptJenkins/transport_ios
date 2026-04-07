//
//  TransferProgressBar.swift
//  BuneIOS
//
//  Created by techvvs001 on 4/6/26.
//

import SwiftUI

// MARK: - Transfer Progress Bar
struct TransferProgressBar: View {
    let currentStatus: String
    let compact: Bool

    private let steps = ["CREATED", "DISPATCH", "AT_HUB", "IN_TRANSIT", "DELIVERED", "ACCEPTED"]

    private var currentStepIndex: Int {
        steps.firstIndex(of: currentStatus.uppercased()) ?? 0
    }

    var body: some View {
        VStack(spacing: compact ? 4 : 12) {
            // Progress circles and connecting lines
            HStack(spacing: 0) {
                ForEach(0..<steps.count, id: \.self) { index in
                    VStack(spacing: 0) {
                        // Circle
                        ZStack {
                            Circle()
                                .fill(
                                    index <= currentStepIndex
                                        ? BuneColors.statusColor(for: steps[index])
                                        : Color.white.opacity(0.2)
                                )
                                .frame(width: compact ? 24 : 32, height: compact ? 24 : 32)

                            if index == currentStepIndex {
                                Circle()
                                    .stroke(
                                        BuneColors.statusColor(for: steps[index]),
                                        lineWidth: 2
                                    )
                                    .frame(width: compact ? 24 : 32, height: compact ? 24 : 32)
                                    .scaleEffect(1.3)
                                    .opacity(0.6)
                                    .animation(
                                        Animation.easeInOut(duration: 1.5).repeatForever(),
                                        value: currentStepIndex
                                    )
                            }
                        }

                        if !compact {
                            Text(steps[index].replacingOccurrences(of: "_", with: "\n"))
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(
                                    index <= currentStepIndex
                                        ? BuneColors.textPrimary
                                        : BuneColors.textTertiary
                                )
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .frame(height: 28)
                        }
                    }

                    // Connecting line
                    if index < steps.count - 1 {
                        VStack {
                            Rectangle()
                                .fill(
                                    index < currentStepIndex
                                        ? BuneColors.statusColor(for: steps[index])
                                        : Color.white.opacity(0.1)
                                )
                                .frame(height: 2)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
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

        VStack(spacing: 32) {
            Text("Transfer Progress Examples")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(BuneColors.textPrimary)

            GlassCard {
                VStack(spacing: 20) {
                    Text("Standard View")
                        .font(.caption)
                        .foregroundColor(BuneColors.textSecondary)

                    TransferProgressBar(currentStatus: "IN_TRANSIT", compact: false)
                        .padding(16)
                }
            }

            GlassCard {
                VStack(spacing: 16) {
                    Text("Compact View")
                        .font(.caption)
                        .foregroundColor(BuneColors.textSecondary)

                    TransferProgressBar(currentStatus: "AT_HUB", compact: true)
                        .padding(12)
                }
            }

            GlassCard {
                VStack(spacing: 20) {
                    Text("Completed")
                        .font(.caption)
                        .foregroundColor(BuneColors.textSecondary)

                    TransferProgressBar(currentStatus: "ACCEPTED", compact: false)
                        .padding(16)
                }
            }

            Spacer()
        }
        .padding(20)
    }
}
