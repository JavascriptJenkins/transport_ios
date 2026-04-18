//
//  BarcodeScannerService.swift
//  BuneIOS
//
//  Created by techvvs001 on 4/6/26.
//

import AVFoundation
import UIKit

// Delegate protocol for scan results
protocol BarcodeScannerDelegate: AnyObject {
    func barcodeScannerDidScan(_ barcode: String)
    func barcodeScannerDidFail(_ error: Error)
}

@MainActor
class BarcodeScannerService: NSObject, ObservableObject {
    @Published var scannedCode: String?
    @Published var isScanning = false
    @Published var hasPermission = false
    @Published var lastError: String?

    weak var delegate: BarcodeScannerDelegate?

    let captureSession = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var lastScanTime: Date = .distantPast
    private let scanDebounceInterval: TimeInterval = 0.5

    // MARK: - Camera Permission

    func requestCameraPermission() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .video)

        switch status {
        case .authorized:
            DispatchQueue.main.async {
                self.hasPermission = true
            }
            return true
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            DispatchQueue.main.async {
                self.hasPermission = granted
            }
            return granted
        case .denied, .restricted:
            DispatchQueue.main.async {
                self.hasPermission = false
                self.lastError = "Camera access denied. Please enable in Settings."
            }
            return false
        @unknown default:
            return false
        }
    }

    // MARK: - Capture Session Setup

    func setupCaptureSession() {
        guard hasPermission else {
            lastError = "Camera permission not granted"
            return
        }

        captureSession.beginConfiguration()

        // Configure input
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            lastError = "Unable to access camera device"
            captureSession.commitConfiguration()
            return
        }

        do {
            let videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
            if captureSession.canAddInput(videoInput) {
                captureSession.addInput(videoInput)
            }

            // Configure metadata output for barcode detection
            let metadataOutput = AVCaptureMetadataOutput()
            if captureSession.canAddOutput(metadataOutput) {
                captureSession.addOutput(metadataOutput)
                metadataOutput.setMetadataObjectsDelegate(self, queue: .main)

                // Support Code 128 (METRC tags) and QR codes
                metadataOutput.metadataObjectTypes = [.code128, .qr]
            }

            captureSession.commitConfiguration()
        } catch {
            lastError = "Failed to setup camera: \(error.localizedDescription)"
            captureSession.commitConfiguration()
            delegate?.barcodeScannerDidFail(error)
        }
    }

    // MARK: - Scanning Control

    func startScanning() {
        DispatchQueue.global(qos: .background).async {
            if !self.captureSession.isRunning {
                self.captureSession.startRunning()
            }
            DispatchQueue.main.async {
                self.isScanning = true
                // Keep screen awake during scanning
                UIApplication.shared.isIdleTimerDisabled = true
            }
        }
    }

    func stopScanning() {
        DispatchQueue.global(qos: .background).async {
            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
            }
            DispatchQueue.main.async {
                self.isScanning = false
                // Allow screen to sleep
                UIApplication.shared.isIdleTimerDisabled = false
            }
        }
    }

    // MARK: - METRC Validation

    /// Validate METRC tag format: 24 alphanumeric characters
    static func isValidMETRCTag(_ code: String) -> Bool {
        code.count == 24 && code.allSatisfy { $0.isLetter || $0.isNumber }
    }

    // MARK: - Haptic Feedback

    private func playSuccessHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    private func playErrorHaptic() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }
}

// MARK: - AVCaptureMetadataOutputObjectsDelegate

extension BarcodeScannerService: @preconcurrency AVCaptureMetadataOutputObjectsDelegate {

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard let metadataObject = metadataObjects.first else { return }

        // Extract barcode string
        guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
              let stringValue = readableObject.stringValue else {
            playErrorHaptic()
            return
        }

        // Apply debounce to prevent duplicate scans
        let now = Date()
        guard now.timeIntervalSince(lastScanTime) >= scanDebounceInterval else {
            return
        }
        lastScanTime = now

        // Validate METRC format
        guard Self.isValidMETRCTag(stringValue) else {
            lastError = "Invalid barcode format (expected 24 alphanumeric characters)"
            playErrorHaptic()
            delegate?.barcodeScannerDidFail(NSError(
                domain: "BarcodeScannerService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid METRC tag format"]
            ))
            return
        }

        // Play success haptic
        playSuccessHaptic()

        // Publish result
        DispatchQueue.main.async {
            self.scannedCode = stringValue
            self.lastError = nil
            self.delegate?.barcodeScannerDidScan(stringValue)
        }
    }
}
