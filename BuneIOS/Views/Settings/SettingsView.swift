//
//  SettingsView.swift
//  BuneIOS
//
//  Created by techvvs001 on 4/6/26.
//

import SwiftUI

// MARK: - Settings View
struct SettingsView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                BuneColors.backgroundPrimary
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // MARK: - User Info Section
                        VStack(spacing: 16) {
                            HStack {
                                Text("Account")
                                    .font(.headline)
                                    .foregroundColor(BuneColors.textPrimary)
                                Spacer()
                            }

                            VStack(spacing: 12) {
                                // User Roles
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Roles")
                                        .font(.caption)
                                        .foregroundColor(BuneColors.textTertiary)
                                        .textCase(.uppercase)

                                    if authService.userRoles.isEmpty {
                                        Text("No roles assigned")
                                            .font(.subheadline)
                                            .foregroundColor(BuneColors.textSecondary)
                                    } else {
                                        FlowLayout(spacing: 8) {
                                            ForEach(authService.userRoles, id: \.self) { role in
                                                RoleBadge(role: role)
                                            }
                                        }
                                    }
                                }
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(BuneColors.backgroundSecondary)
                                )
                            }
                            .glassCard(cornerRadius: 16)
                        }
                        .padding(.horizontal)

                        // MARK: - Capabilities Section
                        if authService.canScan || authService.canCreateTransfers || authService.canManage {
                            VStack(spacing: 16) {
                                HStack {
                                    Text("Permissions")
                                        .font(.headline)
                                        .foregroundColor(BuneColors.textPrimary)
                                    Spacer()
                                }

                                VStack(spacing: 12) {
                                    PermissionRow(
                                        icon: "barcode.viewfinder",
                                        title: "Scanning",
                                        subtitle: "Pickup and delivery scans",
                                        isEnabled: authService.canScan
                                    )

                                    PermissionRow(
                                        icon: "plus.circle",
                                        title: "Create Transfers",
                                        subtitle: "Create manifests and sessions",
                                        isEnabled: authService.canCreateTransfers
                                    )

                                    PermissionRow(
                                        icon: "checkmark.circle",
                                        title: "Management",
                                        subtitle: "Transfer management tools",
                                        isEnabled: authService.canManage
                                    )
                                }
                                .glassCard(cornerRadius: 16)
                            }
                            .padding(.horizontal)
                        }

                        // MARK: - Data & Cache Section
                        VStack(spacing: 16) {
                            HStack {
                                Text("Data & Cache")
                                    .font(.headline)
                                    .foregroundColor(BuneColors.textPrimary)
                                Spacer()
                            }

                            SyncStatusView()
                                .glassCard(cornerRadius: 16)
                        }
                        .padding(.horizontal)

                        // MARK: - App Info Section
                        VStack(spacing: 16) {
                            HStack {
                                Text("About")
                                    .font(.headline)
                                    .foregroundColor(BuneColors.textPrimary)
                                Spacer()
                            }

                            VStack(spacing: 12) {
                                SettingsInfoRow(label: "App Name", value: "BuneIOS")
                                Divider()
                                    .opacity(0.2)
                                SettingsInfoRow(label: "Version", value: "1.0.0")
                                Divider()
                                    .opacity(0.2)
                                SettingsInfoRow(label: "Build", value: "2026.04.06")
                                Divider()
                                    .opacity(0.2)
                                SettingsInfoRow(label: "Environment", value: "Production")
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(BuneColors.backgroundSecondary)
                            )
                            .glassCard(cornerRadius: 16)
                        }
                        .padding(.horizontal)

                        // MARK: - Sign Out Button
                        VStack(spacing: 12) {
                            Button(action: {
                                authService.logout()
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "arrow.right.circle")
                                    Text("Sign Out")
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(BuneColors.errorColor.opacity(0.8))
                                )
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 16)
                    }
                    .padding(.vertical, 24)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - Role Badge Component
struct RoleBadge: View {
    let role: String

    var badgeColor: Color {
        switch role.uppercased() {
        case let r where r.contains("DRIVER"):
            return BuneColors.statusDispatch
        case let r where r.contains("MANAGER"):
            return BuneColors.statusAtHub
        case let r where r.contains("CLIENT"):
            return BuneColors.statusInTransit
        case let r where r.contains("ADMIN"):
            return BuneColors.errorColor
        default:
            return BuneColors.accentPrimary
        }
    }

    var displayName: String {
        let parts = role.split(separator: "_")
        return parts.last.map(String.init) ?? role
    }

    var body: some View {
        Text(displayName)
            .font(.caption.bold())
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(badgeColor.opacity(0.7))
            .cornerRadius(8)
    }
}

// MARK: - Permission Row Component
struct PermissionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let isEnabled: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(isEnabled ? BuneColors.accentPrimary : BuneColors.textMuted)
                .frame(width: 32, alignment: .center)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundColor(BuneColors.textPrimary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(BuneColors.textSecondary)
            }

            Spacer()

            Image(systemName: isEnabled ? "checkmark.circle.fill" : "xmark.circle")
                .font(.system(size: 18))
                .foregroundColor(isEnabled ? BuneColors.statusDelivered : BuneColors.textMuted)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(BuneColors.backgroundTertiary)
        )
    }
}

// MARK: - Settings Info Row Component
struct SettingsInfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(BuneColors.textSecondary)

            Spacer()

            Text(value)
                .font(.subheadline.bold())
                .foregroundColor(BuneColors.textPrimary)
        }
    }
}

// MARK: - Flow Layout Helper (wrapping horizontal layout)
struct FlowLayout<Content: View>: View {
    let spacing: CGFloat
    let content: () -> Content

    init(spacing: CGFloat = 8, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        // Simple wrapping: use a LazyVGrid with adaptive columns
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 80), spacing: spacing)],
            alignment: .leading,
            spacing: spacing
        ) {
            content()
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AuthService())
}
