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

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService)
                .preferredColorScheme(.dark)
        }
    }
}
