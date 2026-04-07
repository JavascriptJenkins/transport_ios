//
//  ContentView.swift
//  BuneIOS
//
//  Created by techvvs001 on 4/2/26.
//

import SwiftUI

struct ContentView: View {

    @EnvironmentObject var authService: AuthService

    var body: some View {
        Group {
            if authService.isAuthenticated {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .animation(.easeInOut(duration: 0.4), value: authService.isAuthenticated)
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthService())
        .environmentObject(OfflineSyncService())
        .environmentObject(LocalCacheService())
        .environmentObject(NotificationService())
}
