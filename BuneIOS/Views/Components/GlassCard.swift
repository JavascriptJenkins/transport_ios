//
//  GlassCard.swift
//  BuneIOS
//
//  Created by techvvs001 on 4/6/26.
//

import SwiftUI

// MARK: - Glass Card Container
struct GlassCard<Content: View>: View {
    let cornerRadius: CGFloat
    let content: Content

    init(cornerRadius: CGFloat = 20, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        content
            .glassCard(cornerRadius: cornerRadius)
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
            GlassCard {
                VStack(spacing: 12) {
                    Text("Glass Card Example")
                        .font(.headline)
                        .foregroundColor(BuneColors.textPrimary)

                    Text("This is a reusable glassmorphic container")
                        .font(.caption)
                        .foregroundColor(BuneColors.textSecondary)
                }
                .padding(20)
                .frame(maxWidth: .infinity)
            }

            GlassCard(cornerRadius: 16) {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(BuneColors.statusDelivered)

                    Text("Status Complete")
                        .font(.subheadline)
                        .foregroundColor(BuneColors.textPrimary)

                    Spacer()
                }
                .padding(16)
            }
        }
        .padding(20)
    }
}
