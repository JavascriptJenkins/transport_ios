//
//  TOTPSettingsSheet.swift
//  BuneIOS
//
//  Self-service 2FA management for an already-authenticated user.
//  Backend flow:
//    Enable:  POST /oauth2/totp/setup        — emails verification code
//             POST /oauth2/totp/verify-setup — activates 2FA with the code
//    Disable: POST /oauth2/totp/disable      — deactivates with current code
//

import SwiftUI

struct TOTPSettingsSheet: View {
    enum Mode {
        case enable
        case disable
    }

    let mode: Mode
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) var dismiss

    @State private var step: Step = .intro
    @State private var code: String = ""
    @State private var isWorking = false
    @State private var errorMessage: String?

    enum Step {
        case intro
        case enterCode
        case done
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BuneColors.backgroundPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        switch step {
                        case .intro:     introContent
                        case .enterCode: codeEntryContent
                        case .done:      doneContent
                        }
                    }
                    .padding(24)
                }
            }
            .navigationTitle(mode == .enable ? "Enable 2FA" : "Disable 2FA")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundColor(BuneColors.accentPrimary)
                }
            }
        }
    }

    // MARK: - Step 1: Intro / explanation

    @ViewBuilder
    private var introContent: some View {
        VStack(spacing: 18) {
            Image(systemName: mode == .enable ? "lock.shield.fill" : "lock.open.fill")
                .font(.system(size: 48))
                .foregroundColor(BuneColors.accentPrimary)

            Text(mode == .enable ? "Turn on Two-Factor Authentication" : "Turn off Two-Factor Authentication")
                .font(.title3.bold())
                .foregroundColor(BuneColors.textPrimary)
                .multilineTextAlignment(.center)

            Text(
                mode == .enable
                ? "We'll email a 6-digit verification code to the address on your account. Enter it on the next screen to finish enabling 2FA. After that, signing in will require both your password and a code from email."
                : "Disabling 2FA means you'll sign in with just your password — less secure. You'll need a current 6-digit code to confirm. If you don't have a recent code, trigger a new one by signing out and signing in again."
            )
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundColor(BuneColors.textSecondary)

            if let errorMessage = errorMessage {
                errorBanner(errorMessage)
            }

            Button {
                Task { await startFlow() }
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(mode == .enable ? BuneColors.accentPrimary : BuneColors.errorColor.opacity(0.85))
                        .frame(height: 50)
                    if isWorking {
                        ProgressView().tint(.white)
                    } else {
                        Text(mode == .enable ? "Send me a code" : "I have a code, continue")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                }
            }
            .disabled(isWorking)
            .padding(.top, 4)
        }
        .padding(.top, 8)
    }

    // MARK: - Step 2: Code entry

    @ViewBuilder
    private var codeEntryContent: some View {
        VStack(spacing: 18) {
            Image(systemName: "envelope.fill")
                .font(.system(size: 36))
                .foregroundColor(BuneColors.accentPrimary)

            Text(mode == .enable ? "Enter verification code" : "Confirm with a current code")
                .font(.title3.bold())
                .foregroundColor(BuneColors.textPrimary)

            Text(mode == .enable
                 ? "We just emailed a 6-digit code. Enter it below to activate 2FA."
                 : "Enter your most recent 6-digit code to disable 2FA.")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundColor(BuneColors.textSecondary)

            TextField("", text: $code,
                      prompt: Text("123456").foregroundColor(BuneColors.textTertiary))
                .keyboardType(.numberPad)
                .font(.system(size: 28, weight: .semibold, design: .monospaced))
                .multilineTextAlignment(.center)
                .foregroundColor(BuneColors.textPrimary)
                .padding(.vertical, 10)
                .frame(maxWidth: 220)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(BuneColors.glassFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(BuneColors.glassBorder, lineWidth: 1)
                        )
                )

            if let errorMessage = errorMessage {
                errorBanner(errorMessage)
            }

            Button {
                Task { await submitCode() }
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(mode == .enable ? BuneColors.accentPrimary : BuneColors.errorColor.opacity(0.85))
                        .frame(height: 50)
                    if isWorking {
                        ProgressView().tint(.white)
                    } else {
                        Text(mode == .enable ? "Activate 2FA" : "Disable 2FA")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                }
            }
            .disabled(isWorking || code.count < 6)
            .opacity(code.count < 6 ? 0.6 : 1.0)

            Button("Back") {
                errorMessage = nil
                step = .intro
            }
            .font(.footnote)
            .foregroundColor(BuneColors.textSecondary)
        }
        .padding(.top, 8)
    }

    // MARK: - Step 3: Done

    @ViewBuilder
    private var doneContent: some View {
        VStack(spacing: 18) {
            Image(systemName: mode == .enable ? "checkmark.seal.fill" : "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundColor(BuneColors.statusDelivered)

            Text(mode == .enable ? "2FA is active" : "2FA is disabled")
                .font(.title3.bold())
                .foregroundColor(BuneColors.textPrimary)

            Text(mode == .enable
                 ? "From now on, signing in will require a code emailed to you."
                 : "Next sign-in will only require your password. You can re-enable 2FA here anytime.")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundColor(BuneColors.textSecondary)

            Button("Done") { dismiss() }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(BuneColors.accentPrimary)
                .cornerRadius(14)
                .padding(.top, 8)
        }
        .padding(.top, 12)
    }

    // MARK: - Actions

    @MainActor
    private func startFlow() async {
        errorMessage = nil
        if mode == .enable {
            isWorking = true
            defer { isWorking = false }
            do {
                try await authService.beginTOTPSetup()
                step = .enterCode
            } catch {
                errorMessage = error.localizedDescription
            }
        } else {
            // Disable flow goes straight to code entry — backend doesn't need
            // a "request code" step because the user either still has a
            // recent one or needs to sign out + back in to generate one.
            step = .enterCode
        }
    }

    @MainActor
    private func submitCode() async {
        errorMessage = nil
        isWorking = true
        defer { isWorking = false }
        do {
            if mode == .enable {
                try await authService.completeTOTPSetup(code: code)
            } else {
                try await authService.disableTOTP(code: code)
            }
            step = .done
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Shared

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
}
