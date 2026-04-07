//
//  StopMarkerView.swift
//  BuneIOS
//
//  Created by techvvs001 on 4/6/26.
//

import SwiftUI

struct StopMarkerView: View {
    let stopNumber: Int
    let name: String

    var body: some View {
        VStack(spacing: 6) {
            // Numbered circle marker
            ZStack {
                Circle()
                    .fill(BuneColors.backgroundSecondary)
                    .frame(width: 36, height: 36)
                    .overlay(
                        Circle()
                            .stroke(BuneColors.accentPrimary, lineWidth: 2)
                    )

                Text("\(stopNumber)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(BuneColors.accentPrimary)
            }

            // Name label (if name is not empty)
            if !name.isEmpty {
                Text(name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(BuneColors.textPrimary)
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(BuneColors.glassFill)
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(BuneColors.glassBorder, lineWidth: 0.5)
                    )
            }
        }
        .padding(4)
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        StopMarkerView(stopNumber: 1, name: "Pickup Point")
        StopMarkerView(stopNumber: 2, name: "Distribution Hub")
        StopMarkerView(stopNumber: 3, name: "Final Delivery")
    }
    .padding()
    .background(BuneColors.backgroundPrimary)
}
