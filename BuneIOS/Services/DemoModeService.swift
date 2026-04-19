//
//  DemoModeService.swift
//  BuneIOS
//
//  Thin observable wrapper around the /demo/status + /demo/toggle endpoints.
//  Views subscribe to `isActive` to render banners / settings badges; the
//  toggle method optimistically updates state and reverts on failure.
//
//  Demo mode is a server-side global flag — flipping it affects every user
//  of the backend. All guards/confirms live in the UI layer; this service
//  just mirrors the server state and returns toggle results.
//

import Foundation
import Combine

@MainActor
class DemoModeService: ObservableObject {
    /// Current server-side demo-mode state. Best-effort cached locally so
    /// banners render without waiting on a network round-trip.
    @Published var isActive: Bool = false

    /// Payload returned by the most recent successful toggle-on call —
    /// surfaced by the settings sheet so the user can see which manifest +
    /// package labels got seeded.
    @Published var lastEnableResult: DemoToggleResult?

    /// Transient error from the most recent toggle or refresh.
    @Published var errorMessage: String?

    private var apiClient: TransportAPIClient?

    /// Swap out the API client after app launch (the client depends on
    /// AuthService which is an @EnvironmentObject).
    func configure(apiClient: TransportAPIClient) {
        self.apiClient = apiClient
    }

    /// Pull the current server state into `isActive`. Silent on failure —
    /// the endpoint is public and best-effort.
    func refresh() async {
        guard let apiClient = apiClient else { return }
        do {
            isActive = try await apiClient.getDemoStatus()
        } catch {
            // Ignore network hiccups; keep the last-known value.
        }
    }

    /// Flip demo mode. Optimistically updates `isActive` so the UI reflects
    /// the attempted state immediately; on failure it reverts and surfaces
    /// the error via `errorMessage`.
    @discardableResult
    func setActive(_ enabled: Bool) async -> DemoToggleResult? {
        guard let apiClient = apiClient else {
            errorMessage = "API client not configured"
            return nil
        }
        let previous = isActive
        isActive = enabled
        errorMessage = nil
        do {
            let result = try await apiClient.setDemoMode(enabled: enabled)
            isActive = result.demoMode
            if enabled { lastEnableResult = result } else { lastEnableResult = nil }
            return result
        } catch {
            isActive = previous
            errorMessage = error.localizedDescription
            return nil
        }
    }
}
