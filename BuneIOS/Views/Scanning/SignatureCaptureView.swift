//
//  SignatureCaptureView.swift
//  BuneIOS
//
//  Created by techvvs001 on 4/6/26.
//

import SwiftUI

// MARK: - Signature Capture View
//
// Draws a near-black stroke on a solid white canvas to match the web's
// SignaturePad (penColor #1a1a2e, backgroundColor white — see
// templates/transport/delivery-scan.html:225). The backend inlines the
// PNG directly into the delivery-confirmation email as
// `<img src="${signatureData}">`, so the stored image MUST have visible
// strokes on a white-ish background — a white-on-transparent rendering
// invisibly disappears in most email clients.
//
// The canvas sits on a white card instead of the usual glassCard so the
// driver can see the signature as they draw it even in the dark-themed
// shell.

struct SignatureCaptureView: View {
    @Binding var signatureImage: UIImage?
    @State private var lines: [[CGPoint]] = []
    @State private var currentLine: [CGPoint] = []
    @State private var showClearConfirm = false

    /// Matches SignaturePad's default pen color (#1a1a2e) so the exported
    /// PNG looks the same on iPhone-submitted and web-submitted deliveries.
    private static let strokeColor = Color(red: 0x1a / 255.0, green: 0x1a / 255.0, blue: 0x2e / 255.0)

    /// Render dimensions pinned to 350×180 to match the on-screen canvas
    /// so gesture coordinates translate 1:1 into the exported image.
    private static let canvasSize = CGSize(width: 350, height: 180)

    var body: some View {
        VStack(spacing: 16) {
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

            Canvas { context, _ in
                for line in lines {
                    context.stroke(strokePath(line), with: .color(Self.strokeColor), lineWidth: 3)
                }
                if !currentLine.isEmpty {
                    context.stroke(strokePath(currentLine), with: .color(Self.strokeColor), lineWidth: 3)
                }
            }
            .background(Color.white)
            .frame(width: Self.canvasSize.width, height: Self.canvasSize.height)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        currentLine.append(value.location)
                    }
                    .onEnded { _ in
                        if !currentLine.isEmpty {
                            lines.append(currentLine)
                            currentLine = []
                        }
                    }
            )

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

    private func strokePath(_ points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for p in points.dropFirst() { path.addLine(to: p) }
        return path
    }

    private func updateSignatureImage() {
        guard !lines.isEmpty else {
            signatureImage = nil
            return
        }

        // Render the final PNG on a solid white background — same way the
        // web canvas does, so email clients render a visible signature.
        let renderer = ImageRenderer(
            content: ZStack {
                Color.white
                Canvas { context, _ in
                    for line in lines {
                        context.stroke(strokePath(line), with: .color(Self.strokeColor), lineWidth: 3)
                    }
                }
            }
            .frame(width: Self.canvasSize.width, height: Self.canvasSize.height)
        )
        renderer.scale = 2  // retina-crisp PNG for the email / PDF
        signatureImage = renderer.uiImage
    }
}

// MARK: - UIImage Extension

extension UIImage {
    /// Full `data:image/png;base64,…` URL — the format the backend email
    /// template (DeliveryHandoffController.sendDeliveryEmailAsync) inlines
    /// directly into `<img src="${signatureData}">`. Returning just the
    /// bare base64 breaks the email's signature block.
    var base64PNGDataURL: String? {
        guard let data = pngData() else { return nil }
        return "data:image/png;base64,\(data.base64EncodedString())"
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
