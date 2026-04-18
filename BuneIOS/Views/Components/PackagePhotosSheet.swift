//
//  PackagePhotosSheet.swift
//  BuneIOS
//
//  Per-package photo list + uploader. Lets drivers attach damage shots,
//  delivery context, or receipt photos to a METRC package label.
//

import SwiftUI
import PhotosUI

struct PackagePhotosSheet: View {
    let packageLabel: String
    let apiClient: TransportAPIClient

    @Environment(\.dismiss) private var dismiss

    @State private var media: [PackageMedia] = []
    @State private var isLoading = false
    @State private var loadError: String?

    @State private var pickerItem: PhotosPickerItem?
    @State private var isUploading = false
    @State private var uploadError: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && media.isEmpty {
                    ProgressView().tint(BuneColors.accentPrimary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if media.isEmpty {
                    emptyState
                } else {
                    photoList
                }
            }
            .background(
                LinearGradient(
                    colors: [
                        BuneColors.backgroundPrimary,
                        BuneColors.backgroundSecondary
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
            .navigationTitle("Package Photos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundColor(BuneColors.accentPrimary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    PhotosPicker(
                        selection: $pickerItem,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        if isUploading {
                            ProgressView().tint(BuneColors.accentPrimary)
                        } else {
                            Image(systemName: "plus")
                        }
                    }
                    .disabled(isUploading)
                }
            }
            .task { await loadMedia() }
            .onChange(of: pickerItem) { _, newItem in
                guard let newItem = newItem else { return }
                Task { await handlePicked(newItem) }
            }
            .alert("Upload Failed", isPresented: Binding(
                get: { uploadError != nil },
                set: { if !$0 { uploadError = nil } }
            )) {
                Button("OK", role: .cancel) { uploadError = nil }
            } message: {
                Text(uploadError ?? "")
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 44))
                .foregroundColor(BuneColors.textTertiary)
            Text("No photos yet")
                .font(.headline)
                .foregroundColor(BuneColors.textPrimary)
            Text("Tap + to attach a photo to package\n\(packageLabel)")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundColor(BuneColors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var photoList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(media) { item in
                    HStack(spacing: 12) {
                        Image(systemName: "photo.fill")
                            .foregroundColor(BuneColors.accentPrimary)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.originalFilename ?? item.filename ?? "photo")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(BuneColors.textPrimary)
                                .lineLimit(1)
                            if let by = item.uploadedBy {
                                Text("Uploaded by \(by)")
                                    .font(.caption2)
                                    .foregroundColor(BuneColors.textTertiary)
                            }
                            if let at = item.uploadedAt {
                                Text(at)
                                    .font(.caption2)
                                    .foregroundColor(BuneColors.textTertiary)
                            }
                        }
                        Spacer()
                    }
                    .padding(12)
                    .background(BuneColors.backgroundTertiary.opacity(0.5))
                    .cornerRadius(10)
                }
            }
            .padding(16)
        }
    }

    // MARK: - Actions

    @MainActor
    private func loadMedia() async {
        isLoading = true
        defer { isLoading = false }
        do {
            media = try await apiClient.getPackageMedia(packageLabel: packageLabel)
        } catch {
            loadError = error.localizedDescription
        }
    }

    @MainActor
    private func handlePicked(_ item: PhotosPickerItem) async {
        defer { pickerItem = nil }
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            uploadError = "Could not read selected photo."
            return
        }
        isUploading = true
        defer { isUploading = false }

        let filename = "\(UUID().uuidString).jpg"
        do {
            let uploaded = try await apiClient.uploadPackageMedia(
                packageLabel: packageLabel,
                imageData: data,
                filename: filename
            )
            media.insert(uploaded, at: 0)
        } catch {
            uploadError = "Upload failed: \(error.localizedDescription)"
        }
    }
}
