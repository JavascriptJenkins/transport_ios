//
//  BuneIOSApp.swift
//  BuneIOS
//
//  Created by techvvs001 on 4/2/26.
//

import SwiftUI

@main
struct BuneIOSApp: App {

    @StateObject private var authService = AuthService()
    @StateObject private var offlineSyncService = OfflineSyncService()
    @StateObject private var localCacheService = LocalCacheService()
    @StateObject private var notificationService = NotificationService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService)
                .environmentObject(offlineSyncService)
                .environmentObject(localCacheService)
                .environmentObject(notificationService)
                .preferredColorScheme(.dark)
                .task {
                    await notificationService.requestPermission()
                }
        }
    }
}
