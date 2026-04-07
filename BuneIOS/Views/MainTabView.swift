//
//  MainTabView.swift
//  BuneIOS
//
//  Created by techvvs001 on 4/6/26.
//

import SwiftUI

// MARK: - Main Tab Navigation View
struct MainTabView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var offlineSyncService: OfflineSyncService
    @EnvironmentObject var localCacheService: LocalCacheService
    @EnvironmentObject var notificationService: NotificationService

    @State private var selectedTab = 0
    @State private var apiClient: TransportAPIClient?

    var body: some View {
        ZStack {
            if let apiClient = apiClient {
                TabView(selection: $selectedTab) {
                    // Tab 1: Dashboard/Transfers — everyone sees this
                    TransferListView(apiClient: apiClient)
                        .tabItem { Label("Transfers", systemImage: "shippingbox") }
                        .tag(0)

                    // Tab 2: Pickup Scan — drivers and managers only
                    if authService.canScan {
                        PickupScanView(apiClient: apiClient)
                            .tabItem { Label("Pickup", systemImage: "barcode.viewfinder") }
                            .tag(1)
                    }

                    // Tab 3: Delivery Scan — drivers and managers only
                    if authService.canScan {
                        DeliveryScanView(apiClient: apiClient)
                            .tabItem { Label("Deliver", systemImage: "checkmark.circle") }
                            .tag(2)
                    }

                    // Tab 4: Create Manifest — managers and admin only
                    if authService.canCreateTransfers {
                        SessionBuilderView(apiClient: apiClient)
                            .tabItem { Label("Create", systemImage: "plus.circle") }
                            .tag(3)
                    }

                    // Tab 5: Tracking/Map — everyone
                    TrackingTabView(apiClient: apiClient)
                        .tabItem { Label("Track", systemImage: "map") }
                        .tag(4)

                    // Tab 6: Settings — everyone
                    SettingsView()
                        .tabItem { Label("Settings", systemImage: "gearshape") }
                        .tag(5)
                }
                .tint(BuneColors.accentPrimary)

                // Offline banner overlay at top
                VStack {
                    OfflineBanner()
                    Spacer()
                }
                .allowsHitTesting(false)
            } else {
                // Loading state while API client initializes
                ZStack {
                    BuneColors.backgroundPrimary
                        .ignoresSafeArea()
                    ProgressView()
                        .tint(BuneColors.accentPrimary)
                }
            }
        }
        .onAppear {
            if apiClient == nil {
                let client = TransportAPIClient(authService: authService)
                apiClient = client
                offlineSyncService.configure(apiClient: client)
            }
        }
    }
}

// MARK: - Tracking Tab View
// Wraps tracking in a NavigationStack since LiveTrackingView needs a transfer to track
struct TrackingTabView: View {
    let apiClient: TransportAPIClient
    @State private var selectedTransferId: Int?

    var body: some View {
        NavigationStack {
            ZStack {
                BuneColors.backgroundPrimary
                    .ignoresSafeArea()

                if let transferId = selectedTransferId {
                    LiveTrackingView(transferId: transferId, apiClient: apiClient)
                } else {
                    // Prompt user to select a transfer to track
                    VStack(spacing: 20) {
                        Image(systemName: "map")
                            .font(.system(size: 56))
                            .foregroundColor(BuneColors.statusInTransit)

                        Text("Live Tracking")
                            .font(.title2.bold())
                            .foregroundColor(BuneColors.textPrimary)

                        Text("Select a transfer from the Transfers tab\nto view live tracking on the map.")
                            .font(.subheadline)
                            .foregroundColor(BuneColors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Track")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthService())
        .environmentObject(OfflineSyncService())
        .environmentObject(LocalCacheService())
        .environmentObject(NotificationService())
}
