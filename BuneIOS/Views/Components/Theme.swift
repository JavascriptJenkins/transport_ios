//
//  Theme.swift
//  BuneIOS
//
//  Created by techvvs001 on 4/6/26.
//

import SwiftUI

// MARK: - Color Palette
struct BuneColors {
    static let backgroundPrimary = Color(red: 0.05, green: 0.05, blue: 0.12)
    static let backgroundSecondary = Color(red: 0.08, green: 0.06, blue: 0.18)
    static let backgroundTertiary = Color(red: 0.04, green: 0.04, blue: 0.10)

    static let glassFill = Color.white.opacity(0.07)
    static let glassBorder = Color.white.opacity(0.12)
    static let glassBorderFocused = Color.white.opacity(0.25)

    static let accentPrimary = Color(red: 0.35, green: 0.25, blue: 0.65)
    static let accentSecondary = Color(red: 0.25, green: 0.18, blue: 0.50)

    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.7)
    static let textTertiary = Color.white.opacity(0.45)
    static let textMuted = Color.white.opacity(0.35)

    // Status colors
    static let statusCreated = Color(red: 0.5, green: 0.5, blue: 0.5)  // Gray
    static let statusDispatch = Color(red: 0.2, green: 0.5, blue: 1.0)  // Blue
    static let statusAtHub = Color(red: 1.0, green: 0.6, blue: 0.2)     // Orange
    static let statusInTransit = Color(red: 0.7, green: 0.3, blue: 1.0) // Purple
    static let statusDelivered = Color(red: 0.2, green: 0.8, blue: 0.4) // Green
    static let statusAccepted = Color(red: 0.0, green: 1.0, blue: 0.5)  // Bright Green
    static let statusCanceled = Color(red: 1.0, green: 0.3, blue: 0.3)  // Red

    // Alert colors
    static let successColor = Color(red: 0.0, green: 1.0, blue: 0.5)
    static let warningColor = Color(red: 1.0, green: 0.6, blue: 0.2)
    static let errorColor = Color(red: 1.0, green: 0.3, blue: 0.3)
    static let infoColor = Color(red: 0.2, green: 0.5, blue: 1.0)

    static func statusColor(for status: String) -> Color {
        switch status.uppercased() {
        case "CREATED":
            return statusCreated
        case "DISPATCH":
            return statusDispatch
        case "AT_HUB":
            return statusAtHub
        case "IN_TRANSIT":
            return statusInTransit
        case "DELIVERED":
            return statusDelivered
        case "ACCEPTED":
            return statusAccepted
        case "CANCELED":
            return statusCanceled
        default:
            return statusCreated
        }
    }
}

// MARK: - Glass Card Modifier
struct GlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 20

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .opacity(0.55)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.2),
                                        Color.white.opacity(0.05),
                                        Color.clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: Color.black.opacity(0.3), radius: 30, x: 0, y: 15)
            )
    }
}

// MARK: - Glass TextField Modifier
struct GlassTextFieldModifier: ViewModifier {
    @FocusState var isFocused: Bool

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.07))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(
                                isFocused
                                    ? Color.white.opacity(0.25)
                                    : Color.white.opacity(0.08),
                                lineWidth: 1
                            )
                    )
            )
            .focused($isFocused)
    }
}

// MARK: - Accent Button Style
struct AccentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            BuneColors.accentPrimary,
                            BuneColors.accentSecondary
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .shadow(
                    color: BuneColors.accentPrimary.opacity(0.4),
                    radius: 12,
                    y: 6
                )
                .opacity(configuration.isPressed ? 0.8 : 1.0)

            configuration.label
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .tracking(1)
        }
        .frame(height: 52)
    }
}

// MARK: - View Extensions
extension View {
    func glassCard(cornerRadius: CGFloat = 20) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius))
    }

    func glassTextField() -> some View {
        modifier(GlassTextFieldModifier())
    }

    func accentButton() -> some View {
        buttonStyle(AccentButtonStyle())
    }
}
