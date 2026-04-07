//
//  VehicleMarkerView.swift
//  BuneIOS
//
//  Created by techvvs001 on 4/6/26.
//

import SwiftUI

struct VehicleMarkerView: View {
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            // Pulsing ring animation
            Circle()
                .stroke(BuneColors.accentPrimary, lineWidth: 2)
                .frame(width: 60, height: 60)
                .scaleEffect(isAnimating ? 1.3 : 0.8)
                .opacity(isAnimating ? 0 : 0.8)

            // Inner circle marker
            ZStack {
                Circle()
                    .fill(BuneColors.accentPrimary)
                    .frame(width: 44, height: 44)
                    .shadow(
                        color: BuneColors.accentPrimary.opacity(0.6),
                        radius: 8,
                        x: 0,
                        y: 4
                    )

                Image(systemName: "car.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .onAppear {
            withAnimation(
                Animation.easeInOut(duration: 1.5)
                    .repeatForever(autoreverses: true)
            ) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        BuneColors.backgroundPrimary
            .ignoresSafeArea()

        VehicleMarkerView()
    }
}
