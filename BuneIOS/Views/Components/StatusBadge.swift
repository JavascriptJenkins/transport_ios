//
//  StatusBadge.swift
//  BuneIOS
//
//  Created by techvvs001 on 4/6/26.
//

import SwiftUI

// MARK: - Status Badge
struct StatusBadge: View {
    let status: String

    var statusColor: Color {
        BuneColors.statusColor(for: status)
    }

    var displayText: String {
        status
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }

    var body: some View {
        Text(displayText)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(statusColor.opacity(0.8))
                    .overlay(
                        Capsule()
                            .stroke(statusColor.opacity(0.5), lineWidth: 1)
                    )
            )
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
            Text("Status Badges")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(BuneColors.textPrimary)

            VStack(spacing: 12) {
                StatusBadge(status: "CREATED")
                StatusBadge(status: "DISPATCH")
                StatusBadge(status: "AT_HUB")
                StatusBadge(status: "IN_TRANSIT")
                StatusBadge(status: "DELIVERED")
                StatusBadge(status: "ACCEPTED")
                StatusBadge(status: "CANCELED")
            }
            .padding(20)
            .glassCard()

            Spacer()
        }
        .padding(20)
    }
}
