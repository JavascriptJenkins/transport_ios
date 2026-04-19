//
//  DemoModeBanner.swift
//  BuneIOS
//
//  Compact orange banner rendered above the tab bar overlay when demo mode
//  is active on the backend. Mirrors the "DEMO MODE ACTIVE" banner on the
//  web dashboard so there's no chance a user confuses synthetic data for
//  real METRC transfers.
//

import SwiftUI

struct DemoModeBanner: View {
    @EnvironmentObject var demoModeService: DemoModeService

    var body: some View {
        if demoModeService.isActive {
            HStack(spacing: 10) {
                Image(systemName: "theatermasks.fill")
                    .font(.caption)
                Text("DEMO MODE ACTIVE")
                    .font(.caption.bold())
                    .tracking(1)
                Text("— data is synthetic")
                    .font(.caption)
                    .opacity(0.85)
                Spacer()
            }
            .foregroundColor(Color(red: 1.0, green: 0.84, blue: 0.5))
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.48, green: 0.23, blue: 0.0),
                        Color(red: 0.63, green: 0.31, blue: 0.0)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .overlay(
                Rectangle()
                    .frame(height: 2)
                    .foregroundColor(Color(red: 0.95, green: 0.61, blue: 0.07)),
                alignment: .bottom
            )
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}
