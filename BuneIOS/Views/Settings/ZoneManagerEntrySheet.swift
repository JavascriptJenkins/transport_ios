//
//  ZoneManagerEntrySheet.swift
//  BuneIOS
//
//  Location picker that gates entry to the standalone ZoneManagerView.
//  Zones are location-scoped on the backend, so we can't render
//  ZoneManagerView until we know which location's zones to load.
//  Surfaced from Settings → Admin for managers + admins.
//

import SwiftUI

struct ZoneManagerEntrySheet: View {
    let apiClient: TransportAPIClient
    @Environment(\.dismiss) private var dismiss

    @State private var locations: [Location] = []
    @State private var isLoading = false
    @State private var loadError: String?

    var body: some View {
        NavigationStack {
            ZStack {
                BuneColors.backgroundPrimary.ignoresSafeArea()

                Group {
                    if isLoading && locations.isEmpty {
                        ProgressView().tint(BuneColors.accentPrimary)
                    } else if let loadError = loadError, locations.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 36))
                                .foregroundColor(BuneColors.errorColor)
                            Text(loadError)
                                .font(.footnote)
                                .foregroundColor(BuneColors.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }
                    } else if locations.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "square.dashed")
                                .font(.system(size: 36))
                                .foregroundColor(BuneColors.textTertiary)
                            Text("No locations configured")
                                .font(.headline)
                                .foregroundColor(BuneColors.textPrimary)
                            Text("Add a location on the web dashboard first.")
                                .font(.caption)
                                .multilineTextAlignment(.center)
                                .foregroundColor(BuneColors.textSecondary)
                        }
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 10) {
                                Text("Choose a location to manage its zones, scan packages into them, and review recent scans.")
                                    .font(.footnote)
                                    .foregroundColor(BuneColors.textSecondary)
                                    .padding(.bottom, 6)

                                ForEach(locations) { location in
                                    NavigationLink {
                                        ZoneManagerView(apiClient: apiClient, location: location)
                                    } label: {
                                        locationRow(location)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(20)
                        }
                    }
                }
            }
            .navigationTitle("Zone Manager")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundColor(BuneColors.accentPrimary)
                }
            }
            .task { await loadLocations() }
        }
    }

    private func locationRow(_ location: Location) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "building.2.fill")
                .font(.title3)
                .foregroundColor(BuneColors.accentPrimary)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(location.name ?? "Location \(location.id)")
                    .font(.subheadline.bold())
                    .foregroundColor(BuneColors.textPrimary)
                if let license = location.licenseNumber, !license.isEmpty {
                    Text(license)
                        .font(.caption2)
                        .foregroundColor(BuneColors.textTertiary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(BuneColors.textTertiary)
        }
        .padding(12)
        .background(BuneColors.backgroundTertiary.opacity(0.5))
        .cornerRadius(10)
    }

    @MainActor
    private func loadLocations() async {
        isLoading = true
        defer { isLoading = false }
        do {
            locations = try await apiClient.listLocations()
        } catch {
            loadError = "Could not load locations: \(error.localizedDescription)"
        }
    }
}
