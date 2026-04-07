//
//  OfflineBanner.swift
//  BuneIOS
//
//  A reusable offline indicator banner that displays network status
//  and pending operation count.
//

import SwiftUI

struct OfflineBanner: View {
    @EnvironmentObject var syncService: OfflineSyncService

    var body: some View {
        if !syncService.isOnline {
            HStack(spacing: 8) {
                Image(systemName: "wifi.slash")
                    .font(.caption)

                Text("Offline")
                    .font(.caption)

                if syncService.pendingOperationCount > 0 {
                    Text("• \(syncService.pendingOperationCount) pending")
                        .font(.caption)
                }

                Spacer()

                if syncService.isSyncing {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.8)
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(BuneColors.warningColor.opacity(0.8))
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

private struct OfflineBannerPreview: View {
    @StateObject var syncService = OfflineSyncService()

    var body: some View {
        VStack(spacing: 0) {
            OfflineBanner()
                .environmentObject(syncService)

            Spacer()
        }
        .background(BuneColors.backgroundPrimary)
    }
}

#Preview {
    OfflineBannerPreview()
}
