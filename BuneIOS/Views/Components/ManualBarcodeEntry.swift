//
//  ManualBarcodeEntry.swift
//  BuneIOS
//
//  Created by techvvs001 on 4/6/26.
//

import SwiftUI

struct ManualBarcodeEntry: View {
    @State private var barcodeText = ""
    @FocusState private var isFocused: Bool
    let onSubmit: (String) -> Void

    var isValidEntry: Bool {
        BarcodeScannerService.isValidMETRCTag(barcodeText)
    }

    var characterCount: Int {
        barcodeText.count
    }

    var body: some View {
        VStack(spacing: 20) {
            // Helper text
            VStack(spacing: 8) {
                Text("Manual METRC Entry")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(BuneColors.textPrimary)

                Text("Enter a 24-character METRC package tag")
                    .font(.system(size: 14))
                    .foregroundColor(BuneColors.textSecondary)
            }

            // Monospace text field with validation
            VStack(spacing: 8) {
                TextField("", text: $barcodeText)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(BuneColors.textPrimary)
                    .focused($isFocused)
                    .textInputAutocapitalization(.characters)
                    .disableAutocorrection(true)
                    .textContentType(.none)
                    .onChange(of: barcodeText) { _, newValue in
                        // Limit to 24 characters
                        if newValue.count > 24 {
                            barcodeText = String(newValue.prefix(24))
                        }
                        // Only allow alphanumeric characters
                        let filtered = newValue.filter { $0.isLetter || $0.isNumber }
                        if filtered != newValue {
                            barcodeText = filtered
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(BuneColors.glassFill)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(
                                        isFocused
                                            ? BuneColors.glassBorderFocused
                                            : BuneColors.glassBorder,
                                        lineWidth: 1
                                    )
                            )
                    )

                // Character counter with validation indicator
                HStack(spacing: 8) {
                    HStack(spacing: 6) {
                        if isValidEntry {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(BuneColors.statusAccepted)
                            Text("Valid")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(BuneColors.statusAccepted)
                        } else if characterCount > 0 {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(BuneColors.errorColor)
                            Text("Invalid format")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(BuneColors.errorColor)
                        } else {
                            Image(systemName: "circle")
                                .font(.system(size: 14))
                                .foregroundColor(BuneColors.textTertiary)
                            Text("24 characters required")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(BuneColors.textTertiary)
                        }

                        Spacer()
                    }

                    Text("\(characterCount)/24")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(BuneColors.textTertiary)
                }
                .padding(.horizontal, 4)
            }

            // Submit button
            Button(action: {
                if isValidEntry {
                    onSubmit(barcodeText)
                    barcodeText = ""
                    isFocused = false
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))

                    Text("Submit")
                        .font(.system(size: 16, weight: .semibold))
                        .tracking(0.5)
                }
                .frame(maxWidth: .infinity)
                .accentButton()
            }
            .disabled(!isValidEntry)
            .opacity(isValidEntry ? 1.0 : 0.5)

            Spacer()
        }
        .padding(24)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        BuneColors.backgroundPrimary
            .ignoresSafeArea()

        ManualBarcodeEntry { code in
            print("Submitted: \(code)")
        }
    }
}
