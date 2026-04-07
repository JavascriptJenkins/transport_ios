//
//  SignatureCaptureView.swift
//  BuneIOS
//
//  Created by techvvs001 on 4/6/26.
//

import SwiftUI

// MARK: - Signature Capture View

struct SignatureCaptureView: View {
    @Binding var signatureImage: UIImage?
    @State private var lines: [[CGPoint]] = []
    @State private var currentLine: [CGPoint] = []
    @State private var showClearConfirm = false

    var body: some View {
        VStack(spacing: 16) {
            // Title
            VStack(alignment: .leading, spacing: 8) {
                Text("Draw Your Signature")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(BuneColors.textPrimary)

                Text("Use your finger to sign in the box below")
                    .font(.caption)
                    .foregroundColor(BuneColors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Signature Canvas
            Canvas { context, size in
                // White strokes on glass background
                for line in lines {
                    var path = Path()
                    if let first = line.first {
                        path.move(to: first)
                        for point in line.dropFirst() {
                            path.addLine(to: point)
                        }
                    }
                    context.stroke(
                        path,
                        with: .color(.white),
                        lineWidth: 3
                    )
                }

                // Current line being drawn
                if !currentLine.isEmpty {
                    var path = Path()
                    path.move(to: currentLine[0])
                    for point in currentLine.dropFirst() {
                        path.addLine(to: point)
                    }
                    context.stroke(
                        path,
                        with: .color(.white),
                        lineWidth: 3
                    )
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.07))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(BuneColors.glassBorder, lineWidth: 1)
                    )
            )
            .frame(height: 180)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let location = value.location
                        currentLine.append(location)
                    }
                    .onEnded { _ in
                        if !currentLine.isEmpty {
                            lines.append(currentLine)
                            currentLine = []
                        }
                    }
            )

            // Clear Button
            HStack {
                Spacer()
                Button(action: { showClearConfirm = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "trash.fill")
                        Text("Clear")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(BuneColors.errorColor)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(BuneColors.errorColor.opacity(0.15))
                    )
                }
            }

            Spacer()
        }
        .padding(20)
        .alert("Clear Signature", isPresented: $showClearConfirm) {
            Button("Clear", role: .destructive) {
                lines = []
                currentLine = []
                signatureImage = nil
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to clear the signature?")
        }
        .onChange(of: lines) { _, _ in
            updateSignatureImage()
        }
    }

    private func updateSignatureImage() {
        guard !lines.isEmpty else {
            signatureImage = nil
            return
        }

        let renderer = ImageRenderer(
            content: Canvas { context, size in
                for line in lines {
                    var path = Path()
                    if let first = line.first {
                        path.move(to: first)
                        for point in line.dropFirst() {
                            path.addLine(to: point)
                        }
                    }
                    context.stroke(
                        path,
                        with: .color(.white),
                        lineWidth: 3
                    )
                }
            }
            .frame(width: 350, height: 180)
        )

        signatureImage = renderer.uiImage
    }
}

// MARK: - UIImage Extension

extension UIImage {
    var base64PNGString: String? {
        pngData()?.base64EncodedString()
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

        VStack {
            SignatureCaptureView(signatureImage: .constant(nil))
                .glassCard(cornerRadius: 24)
                .padding(20)

            Spacer()
        }
    }
}
