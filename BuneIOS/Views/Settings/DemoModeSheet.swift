//
//  DemoModeSheet.swift
//  BuneIOS
//
//  Three-step flow mirroring TOTPSettingsSheet:
//    intro     — explain the global impact, show enable/disable action
//    confirm   — destructive confirmation before disable (one extra tap to
//                avoid accidental wipes since it cascades across users)
//    done      — success screen with the seeded manifest + package labels
//                so the user can jump straight into testing
//

import SwiftUI

struct DemoModeSheet: View {
    @EnvironmentObject var demoModeService: DemoModeService
    @Environment(\.dismiss) var dismiss

    @State private var step: Step = .intro
    @State private var isWorking = false

    enum Step {
        case intro
        case confirmDisable
        case done
    }

    private var demoOn: Bool { demoModeService.isActive }

    var body: some View {
        NavigationStack {
            ZStack {
                BuneColors.backgroundPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 22) {
                        switch step {
                        case .intro:          introContent
                        case .confirmDisable: confirmDisableContent
                        case .done:           doneContent
                        }
                    }
                    .padding(24)
                }
            }
            .navigationTitle("Demo Mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundColor(BuneColors.accentPrimary)
                }
            }
        }
    }

    // MARK: - Intro

    @ViewBuilder
    private var introContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "theatermasks.fill")
                .font(.system(size: 48))
                .foregroundColor(demoOn ? demoOrange : BuneColors.accentPrimary)

            Text(demoOn ? "Demo mode is on" : "Turn on demo mode")
                .font(.title3.bold())
                .foregroundColor(BuneColors.textPrimary)

            Text(demoOn
                 ? "Your dashboard is showing DEMO-0000001, a synthetic manifest with 5 packages staged in an originator zone. Turning it off cleans up all demo data — transfers, packages, zones, scans, and tracking events."
                 : "Creates a synthetic manifest (DEMO-0000001) with 5 packages already staged in an originator zone. Use it to test pickup scans, hub intake, and delivery without touching real METRC data.")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundColor(BuneColors.textSecondary)
        }

        globalWarningBanner

        if let error = demoModeService.errorMessage {
            errorBanner(error)
        }

        Button {
            if demoOn {
                step = .confirmDisable
            } else {
                Task { await performToggle(enable: true) }
            }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(demoOn ? BuneColors.errorColor.opacity(0.85) : demoOrange)
                    .frame(height: 50)
                if isWorking {
                    ProgressView().tint(.white)
                } else {
                    Text(demoOn ? "Disable demo mode" : "Enable demo mode")
                        .font(.headline)
                        .foregroundColor(.white)
                }
            }
        }
        .disabled(isWorking)
    }

    // MARK: - Confirm Disable

    @ViewBuilder
    private var confirmDisableContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44))
                .foregroundColor(BuneColors.errorColor)
            Text("Wipe all demo data?")
                .font(.title3.bold())
                .foregroundColor(BuneColors.textPrimary)
            Text("This will permanently remove the DEMO-0000001 manifest, its 5 packages, the originator zone, and every scan / tracking event attached to them. Real METRC records are not touched.")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundColor(BuneColors.textSecondary)
        }

        if let error = demoModeService.errorMessage {
            errorBanner(error)
        }

        Button {
            Task { await performToggle(enable: false) }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(BuneColors.errorColor.opacity(0.85))
                    .frame(height: 50)
                if isWorking {
                    ProgressView().tint(.white)
                } else {
                    Text("Yes, wipe demo data")
                        .font(.headline)
                        .foregroundColor(.white)
                }
            }
        }
        .disabled(isWorking)

        Button("Never mind") { step = .intro }
            .font(.footnote)
            .foregroundColor(BuneColors.textSecondary)
    }

    // MARK: - Done

    @ViewBuilder
    private var doneContent: some View {
        VStack(spacing: 16) {
            Image(systemName: demoOn ? "checkmark.seal.fill" : "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundColor(BuneColors.statusDelivered)

            Text(demoOn ? "Demo mode is on" : "Demo mode is off")
                .font(.title3.bold())
                .foregroundColor(BuneColors.textPrimary)

            if demoOn, let result = demoModeService.lastEnableResult {
                VStack(alignment: .leading, spacing: 10) {
                    if let manifest = result.manifestNumber {
                        labelValue("Manifest", manifest, mono: true)
                    }
                    if let id = result.transferId {
                        labelValue("Transfer ID", String(id), mono: false)
                    }
                    if let labels = result.packageLabels, !labels.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Package labels")
                                .font(.caption2)
                                .foregroundColor(BuneColors.textTertiary)
                                .textCase(.uppercase)
                            ForEach(labels, id: \.self) { label in
                                Text(label)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(BuneColors.accentPrimary)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(BuneColors.backgroundTertiary.opacity(0.5))
                .cornerRadius(10)
            } else {
                Text(demoOn
                     ? "The demo manifest is ready. Head to the Transfers tab to start testing."
                     : "Your dashboard is back to real data.")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundColor(BuneColors.textSecondary)
            }

            Button("Done") { dismiss() }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(BuneColors.accentPrimary)
                .cornerRadius(14)
                .padding(.top, 4)
        }
    }

    // MARK: - Shared

    private var demoOrange: Color {
        Color(red: 0.95, green: 0.61, blue: 0.07)
    }

    private var globalWarningBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "globe")
                .foregroundColor(demoOrange)
            VStack(alignment: .leading, spacing: 2) {
                Text("Affects every user of this backend")
                    .font(.caption.bold())
                    .foregroundColor(BuneColors.textPrimary)
                Text("Demo mode is a global server flag — everyone hitting this environment sees the same demo data. Don't toggle on a shared/production backend.")
                    .font(.caption2)
                    .foregroundColor(BuneColors.textSecondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(demoOrange.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(demoOrange.opacity(0.4), lineWidth: 1)
                )
        )
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(Color(red: 1.0, green: 0.6, blue: 0.3))
            Text(message)
                .font(.caption)
                .foregroundColor(BuneColors.textPrimary)
        }
        .padding(10)
        .background(Color(red: 0.3, green: 0.15, blue: 0.05).opacity(0.4))
        .cornerRadius(8)
    }

    private func labelValue(_ label: String, _ value: String, mono: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundColor(BuneColors.textTertiary)
                .textCase(.uppercase)
            Text(value)
                .font(mono ? .system(.body, design: .monospaced) : .body)
                .foregroundColor(BuneColors.textPrimary)
        }
    }

    // MARK: - Actions

    @MainActor
    private func performToggle(enable: Bool) async {
        isWorking = true
        defer { isWorking = false }
        let result = await demoModeService.setActive(enable)
        if result != nil {
            step = .done
        }
        // On failure, errorMessage is already published; stay on the current step.
    }
}
