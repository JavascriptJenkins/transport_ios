//
//  QuickReplyChips.swift
//  BuneIOS
//
//  Created by techvvs001 on 4/6/26.
//

import SwiftUI

// MARK: - Quick Reply Chips
struct QuickReplyChips: View {
    let chips: [String]
    let onTap: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(chips, id: \.self) { chip in
                    Button(action: { onTap(chip) }) {
                        Text(chip)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(BuneColors.textPrimary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.08))
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                                    )
                            )
                    }
                }

                Spacer()
                    .frame(width: 4)
            }
            .padding(.horizontal, 16)
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

        VStack(spacing: 20) {
            Text("Quick Reply Chips")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(BuneColors.textPrimary)

            GlassCard {
                VStack(spacing: 16) {
                    Text("Chat Quick Replies")
                        .font(.caption)
                        .foregroundColor(BuneColors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    QuickReplyChips(
                        chips: [
                            "What's my ETA?",
                            "Package status",
                            "Need assistance",
                            "Reschedule delivery"
                        ],
                        onTap: { chip in
                            print("Tapped: \(chip)")
                        }
                    )
                }
                .padding(16)
            }

            GlassCard {
                VStack(spacing: 16) {
                    Text("Action Chips")
                        .font(.caption)
                        .foregroundColor(BuneColors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    QuickReplyChips(
                        chips: [
                            "Start Pickup",
                            "Complete Scan",
                            "Call Driver",
                            "View Route"
                        ],
                        onTap: { chip in
                            print("Action: \(chip)")
                        }
                    )
                }
                .padding(16)
            }

            Spacer()
        }
        .padding(20)
    }
}
