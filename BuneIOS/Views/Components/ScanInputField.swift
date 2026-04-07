//
//  ScanInputField.swift
//  BuneIOS
//
//  Created by techvvs001 on 4/6/26.
//

import SwiftUI

// MARK: - Scan Input Field
struct ScanInputField: View {
    @Binding var text: String
    let placeholder: String
    let onSubmit: () -> Void

    @FocusState private var isFocused: Bool

    private let metrrcBarcodeLengthMax = 24

    var isValidBarcode: Bool {
        text.count == metrrcBarcodeLengthMax || text.isEmpty
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: "barcode.viewfinder")
                    .font(.system(size: 20))
                    .foregroundColor(
                        isValidBarcode
                            ? BuneColors.accentPrimary
                            : BuneColors.errorColor
                    )

                TextField(
                    "",
                    text: $text,
                    prompt: Text(placeholder)
                        .foregroundColor(BuneColors.textMuted)
                )
                .font(.system(size: 24, weight: .semibold, design: .monospaced))
                .foregroundColor(BuneColors.textPrimary)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .focused($isFocused)
                .onChange(of: text) { oldValue, newValue in
                    if newValue.count > metrrcBarcodeLengthMax {
                        text = String(newValue.prefix(metrrcBarcodeLengthMax))
                    }
                }
                .onSubmit {
                    if isValidBarcode && !text.isEmpty {
                        onSubmit()
                        text = ""
                    }
                }
                .submitLabel(.send)

                if !text.isEmpty {
                    Button(action: { text = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(BuneColors.textTertiary)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.07))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(
                                isFocused
                                    ? BuneColors.glassBorderFocused
                                    : (isValidBarcode ? BuneColors.glassBorder : BuneColors.errorColor.opacity(0.5)),
                                lineWidth: 1.5
                            )
                    )
            )

            // Validation status
            if !text.isEmpty && !isValidBarcode {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(BuneColors.errorColor)

                    Text("Barcode must be \(metrrcBarcodeLengthMax) characters (METRC format)")
                        .font(.caption2)
                        .foregroundColor(BuneColors.errorColor)

                    Spacer()
                }
            } else if !text.isEmpty && isValidBarcode {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(BuneColors.successColor)

                    Text("Ready to scan")
                        .font(.caption2)
                        .foregroundColor(BuneColors.successColor)

                    Spacer()
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        LinearGradient(
            colors: [
                BuneColors.backgroundPrimary,
                BuneColors.backgroundSecondary,
                BuneColors.backgroundTertiary
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        VStack(spacing: 20) {
            Text("Scan Input Field")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(BuneColors.textPrimary)

            GlassCard {
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Pickup Scan")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(BuneColors.textSecondary)

                        ScanInputField(
                            text: .constant(""),
                            placeholder: "Scan METRC barcode",
                            onSubmit: { print("Submitted") }
                        )
                    }

                    Divider()
                        .background(Color.white.opacity(0.1))

                    VStack(alignment: .leading, spacing: 8) {
                        Text("With Valid Input (24 chars)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(BuneColors.textSecondary)

                        ScanInputField(
                            text: .constant("123456789012345678901234"),
                            placeholder: "Scan METRC barcode",
                            onSubmit: { print("Submitted") }
                        )
                    }

                    Divider()
                        .background(Color.white.opacity(0.1))

                    VStack(alignment: .leading, spacing: 8) {
                        Text("With Invalid Input (less than 24)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(BuneColors.textSecondary)

                        ScanInputField(
                            text: .constant("123456"),
                            placeholder: "Scan METRC barcode",
                            onSubmit: { print("Submitted") }
                        )
                    }
                }
                .padding(20)
            }

            Spacer()
        }
        .padding(20)
    }
}
