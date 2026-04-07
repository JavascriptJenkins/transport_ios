//
//  BarcodeScannerView.swift
//  BuneIOS
//
//  Created by techvvs001 on 4/6/26.
//

import SwiftUI
import AVFoundation

struct BarcodeScannerView: View {
    @StateObject private var scanner = BarcodeScannerService()
    let onScan: (String) -> Void

    var body: some View {
        ZStack {
            // Camera preview layer
            CameraPreviewView(session: scanner.captureSession)
                .ignoresSafeArea()

            // Scanning overlay with animation
            ScanOverlayView()

            // Content overlay
            VStack(spacing: 0) {
                // Top spacer to position text
                Spacer()

                // Instruction text above scan area
                Text("Scan METRC Package Tag")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(BuneColors.textPrimary)
                    .padding(.bottom, 24)

                Spacer()

                // Bottom info bar with scanned code
                if let code = scanner.scannedCode {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(BuneColors.statusAccepted)

                        Text(code)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(BuneColors.textPrimary)

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(BuneColors.glassFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(BuneColors.glassBorder, lineWidth: 1)
                    )
                    .cornerRadius(12)
                    .padding()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                Spacer()
                    .frame(height: 60)
            }

            // Error display
            if let error = scanner.lastError {
                VStack(spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(BuneColors.errorColor)

                        Text(error)
                            .font(.system(.caption, design: .default))
                            .foregroundColor(BuneColors.textSecondary)
                            .lineLimit(2)

                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(BuneColors.glassFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(BuneColors.errorColor.opacity(0.3), lineWidth: 1)
                    )
                    .cornerRadius(8)

                    Spacer()
                }
                .padding()
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .onAppear {
            Task {
                let granted = await scanner.requestCameraPermission()
                if granted {
                    scanner.setupCaptureSession()
                    scanner.startScanning()
                }
            }
        }
        .onDisappear {
            scanner.stopScanning()
        }
        .onChange(of: scanner.scannedCode) { _, newValue in
            if let code = newValue {
                onScan(code)
            }
        }
    }
}

// MARK: - Camera Preview UIViewRepresentable

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)

        context.coordinator.previewLayer = previewLayer
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let previewLayer = context.coordinator.previewLayer {
            previewLayer.frame = uiView.bounds
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var previewLayer: AVCaptureVideoPreviewLayer?
    }
}

// MARK: - Scanning Overlay with Animated Line

struct ScanOverlayView: View {
    @State private var animateScanner = false

    let scanAreaSize: CGFloat = 280
    let cornerBracketLength: CGFloat = 40
    let cornerBracketWidth: CGFloat = 3

    var body: some View {
        ZStack {
            // Semi-transparent dark overlays on top/bottom/sides
            VStack(spacing: 0) {
                // Top overlay
                Color.black.opacity(0.6)

                Spacer()

                // Bottom overlay
                Color.black.opacity(0.6)
            }

            // Side overlays
            HStack(spacing: 0) {
                Color.black.opacity(0.6)

                Spacer()

                Color.black.opacity(0.6)
            }

            // Clear scan area with decorative elements
            VStack(spacing: 0) {
                Spacer()

                HStack(spacing: 0) {
                    Spacer()

                    // Main scan area container
                    ZStack {
                        // Animated scanning line
                        VStack(spacing: 0) {
                            if animateScanner {
                                Spacer()
                                    .frame(height: scanAreaSize * 0.3)
                            } else {
                                Spacer()
                                    .frame(height: scanAreaSize * 0.7)
                            }

                            // Animated green/purple line
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    BuneColors.accentPrimary.opacity(0),
                                    BuneColors.accentPrimary,
                                    BuneColors.accentPrimary.opacity(0)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .frame(height: 2)
                            .shadow(color: BuneColors.accentPrimary, radius: 6, x: 0, y: 0)

                            Spacer()
                        }
                        .frame(height: scanAreaSize)

                        // Corner brackets
                        CornerBracketsView(
                            size: scanAreaSize,
                            bracketLength: cornerBracketLength,
                            bracketWidth: cornerBracketWidth
                        )
                    }
                    .frame(width: scanAreaSize, height: scanAreaSize)

                    Spacer()
                }

                Spacer()
            }
        }
        .onAppear {
            withAnimation(
                Animation.easeInOut(duration: 1.5)
                    .repeatForever(autoreverses: true)
            ) {
                animateScanner = true
            }
        }
    }
}

// MARK: - Corner Brackets

struct CornerBracketsView: View {
    let size: CGFloat
    let bracketLength: CGFloat
    let bracketWidth: CGFloat

    var body: some View {
        ZStack {
            // Top-left bracket
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    VStack(spacing: 0) {
                        Color.white
                            .frame(width: bracketWidth, height: bracketLength)

                        Spacer()
                    }
                    .frame(height: bracketLength)

                    Spacer()
                }

                Spacer()
            }

            // Top-right bracket
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Spacer()

                    VStack(spacing: 0) {
                        Color.white
                            .frame(width: bracketWidth, height: bracketLength)

                        Spacer()
                    }
                    .frame(height: bracketLength)
                }

                Spacer()
            }

            // Bottom-left bracket
            VStack(spacing: 0) {
                Spacer()

                HStack(spacing: 0) {
                    VStack(spacing: 0) {
                        Spacer()

                        Color.white
                            .frame(width: bracketWidth, height: bracketLength)
                    }
                    .frame(height: bracketLength)

                    Spacer()
                }
            }

            // Bottom-right bracket
            VStack(spacing: 0) {
                Spacer()

                HStack(spacing: 0) {
                    Spacer()

                    VStack(spacing: 0) {
                        Spacer()

                        Color.white
                            .frame(width: bracketWidth, height: bracketLength)
                    }
                    .frame(height: bracketLength)
                }
            }

            // Horizontal top bracket parts
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Color.white
                        .frame(height: bracketWidth)
                        .offset(x: 0, y: -bracketLength / 2)

                    Spacer()

                    Color.white
                        .frame(height: bracketWidth)
                        .offset(x: 0, y: -bracketLength / 2)
                }
                .padding(.horizontal, bracketLength)

                Spacer()
            }

            // Horizontal bottom bracket parts
            VStack(spacing: 0) {
                Spacer()

                HStack(spacing: 0) {
                    Color.white
                        .frame(height: bracketWidth)
                        .offset(x: 0, y: bracketLength / 2)

                    Spacer()

                    Color.white
                        .frame(height: bracketWidth)
                        .offset(x: 0, y: bracketLength / 2)
                }
                .padding(.horizontal, bracketLength)
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Preview

#Preview {
    BarcodeScannerView { code in
        print("Scanned: \(code)")
    }
}
