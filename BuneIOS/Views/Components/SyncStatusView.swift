//
//  SyncStatusView.swift
//  BuneIOS
//
//  Settings screen view showing sync status, cache info,
//  and manual sync/cache clear controls.
//

import SwiftUI

struct SyncStatusView: View {
    @EnvironmentObject var syncService: OfflineSyncService
    @EnvironmentObject var cacheService: LocalCacheService
    @State private var showClearConfirmation = false
    @State private var isManualSyncing = false

    var body: some View {
        VStack(spacing: 16) {
            // MARK: - Online Status Card
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: syncService.isOnline ? "wifi" : "wifi.slash")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(syncService.isOnline ? BuneColors.successColor : BuneColors.warningColor)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Connection Status")
                            .font(.subheadline)
                            .foregroundColor(BuneColors.textSecondary)

                        Text(syncService.isOnline ? "Online" : "Offline")
                            .font(.headline)
                            .foregroundColor(BuneColors.textPrimary)
                    }

                    Spacer()
                }
                .padding(16)
                .glassCard()
            }

            // MARK: - Pending Operations Card
            if syncService.pendingOperationCount > 0 {
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "clock.badge.exclamationmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(BuneColors.warningColor)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Pending Operations")
                                .font(.subheadline)
                                .foregroundColor(BuneColors.textSecondary)

                            Text("\(syncService.pendingOperationCount) waiting to sync")
                                .font(.headline)
                                .foregroundColor(BuneColors.textPrimary)
                        }

                        Spacer()

                        if syncService.isSyncing {
                            ProgressView()
                                .tint(BuneColors.accentPrimary)
                        }
                    }
                    .padding(16)
                    .glassCard()
                }
            }

            // MARK: - Last Sync Time Card
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(BuneColors.successColor)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Last Sync")
                            .font(.subheadline)
                            .foregroundColor(BuneColors.textSecondary)

                        if let lastSync = syncService.lastSyncAt {
                            Text(formatDate(lastSync))
                                .font(.headline)
                                .foregroundColor(BuneColors.textPrimary)
                        } else {
                            Text("Never synced")
                                .font(.headline)
                                .foregroundColor(BuneColors.textMuted)
                        }
                    }

                    Spacer()
                }
                .padding(16)
                .glassCard()
            }

            // MARK: - Cache Status Card
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "internaldrive")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(BuneColors.accentPrimary)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Cached Data")
                            .font(.subheadline)
                            .foregroundColor(BuneColors.textSecondary)

                        VStack(alignment: .leading, spacing: 6) {
                            CacheItemRow(label: "Transfers", count: cacheService.cachedTransfers.count)
                            CacheItemRow(label: "Drivers", count: cacheService.cachedDrivers.count)
                            CacheItemRow(label: "Vehicles", count: cacheService.cachedVehicles.count)
                            CacheItemRow(label: "Routes", count: cacheService.cachedRoutes.count)
                            CacheItemRow(label: "Destinations", count: cacheService.cachedDestinations.count)
                        }
                    }

                    Spacer()
                }
                .padding(16)
                .glassCard()
            }

            // MARK: - Last Cache Refresh
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.clockwise.circle")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(BuneColors.infoColor)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Last Cache Refresh")
                            .font(.subheadline)
                            .foregroundColor(BuneColors.textSecondary)

                        if let lastRefresh = cacheService.lastRefreshAt {
                            Text(formatDate(lastRefresh))
                                .font(.headline)
                                .foregroundColor(BuneColors.textPrimary)
                        } else {
                            Text("Not refreshed yet")
                                .font(.headline)
                                .foregroundColor(BuneColors.textMuted)
                        }
                    }

                    Spacer()
                }
                .padding(16)
                .glassCard()
            }

            Spacer()

            // MARK: - Action Buttons
            VStack(spacing: 12) {
                Button {
                    Task {
                        isManualSyncing = true
                        await syncService.drainQueue()
                        isManualSyncing = false
                    }
                } label: {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Sync Now")
                    }
                    .frame(maxWidth: .infinity)
                }
                .accentButton()
                .disabled(syncService.isSyncing || isManualSyncing || syncService.pendingOperationCount == 0)
                .opacity((syncService.isSyncing || isManualSyncing || syncService.pendingOperationCount == 0) ? 0.6 : 1.0)

                Button {
                    showClearConfirmation = true
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("Clear Cache")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(BuneColors.errorColor, lineWidth: 1)
                )
                .foregroundColor(BuneColors.errorColor)
            }
            .confirmationDialog(
                "Clear Cache",
                isPresented: $showClearConfirmation,
                actions: {
                    Button("Clear", role: .destructive) {
                        cacheService.clearAll()
                    }
                    Button("Cancel", role: .cancel) {}
                },
                message: {
                    Text("This will permanently delete all cached data. You can download it again when online.")
                }
            )
        }
        .padding(16)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Cache Item Row

private struct CacheItemRow: View {
    let label: String
    let count: Int

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundColor(BuneColors.textSecondary)

            Spacer()

            Text("\(count)")
                .font(.caption)
                .foregroundColor(BuneColors.textPrimary)
                .fontWeight(.semibold)
        }
    }
}

private struct SyncStatusViewPreview: View {
    @StateObject var syncService = OfflineSyncService()
    @StateObject var cacheService = LocalCacheService()

    var body: some View {
        NavigationStack {
            ScrollView {
                SyncStatusView()
                    .environmentObject(syncService)
                    .environmentObject(cacheService)
            }
            .background(BuneColors.backgroundPrimary)
            .ignoresSafeArea()
        }
    }
}

#Preview {
    SyncStatusViewPreview()
}
