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
                HomeView()
            } else {
                LoginView()
            }
        }
        .animation(.easeInOut(duration: 0.4), value: authService.isAuthenticated)
    }
}

// MARK: - Home View (placeholder post-login)
struct HomeView: View {

    @EnvironmentObject var authService: AuthService

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.12)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Image("BuneLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                Text("Welcome to Bune")
                    .font(.title2.bold())
                    .foregroundColor(.white)

                Text("You're signed in.")
                    .font(.subheadline)
                    .foregroundColor(Color.white.opacity(0.5))

                Button {
                    authService.logout()
                } label: {
                    Text("Sign Out")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthService())
}
