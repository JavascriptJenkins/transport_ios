//
//  ShareSheet.swift
//  BuneIOS
//
//  Thin SwiftUI wrapper around UIActivityViewController for sharing
//  file URLs (manifest PDFs, receipts, etc.) via the system share sheet.
//

import SwiftUI
import UIKit

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
