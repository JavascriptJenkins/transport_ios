//
//  PackageBrowserSheet.swift
//  BuneIOS
//
//  Presents the active license's package inventory with search so dispatchers
//  can build manifests without typing METRC labels by hand.
//

import SwiftUI

struct PackageBrowserSheet: View {
    let apiClient: TransportAPIClient
    /// Callback invoked when the user taps Add on a package.
    let onAdd: (BrowsablePackage) async -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var searchText: String = ""
    @State private var results: [BrowsablePackage] = []
    @State private var allPackages: [BrowsablePackage] = []
    @State private var isLoading = false
    @State private var loadError: String?
    @State private var addingLabels: Set<String> = []
    @State private var addedLabels: Set<String> = []

    /// Debounce timer task so we don't hammer the search endpoint on every keystroke.
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [BuneColors.backgroundPrimary, BuneColors.backgroundSecondary],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    searchField
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)

                    if isLoading && results.isEmpty {
                        Spacer()
                        ProgressView().tint(BuneColors.accentPrimary)
                        Spacer()
                    } else if let loadError = loadError, results.isEmpty {
                        Spacer()
                        Text(loadError)
                            .font(.footnote)
                            .foregroundColor(BuneColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                        Spacer()
                    } else if results.isEmpty {
                        Spacer()
                        Text(searchText.isEmpty
                             ? "No packages in inventory."
                             : "No matches for \"\(searchText)\".")
                            .font(.footnote)
                            .foregroundColor(BuneColors.textSecondary)
                        Spacer()
                    } else {
                        list
                    }
                }
            }
            .navigationTitle("Browse Packages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundColor(BuneColors.accentPrimary)
                }
            }
            .task { await loadAll() }
            .onChange(of: searchText) { _, newValue in scheduleSearch(newValue) }
        }
    }

    // MARK: - Subviews

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(BuneColors.textTertiary)
            TextField("", text: $searchText,
                      prompt: Text("Search by label or product").foregroundColor(BuneColors.textTertiary))
                .foregroundColor(BuneColors.textPrimary)
                .autocorrectionDisabled(true)
                .autocapitalization(.none)
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(BuneColors.textTertiary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(BuneColors.glassFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(BuneColors.glassBorder, lineWidth: 1)
                )
        )
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(results) { pkg in
                    packageRow(pkg)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
    }

    @ViewBuilder
    private func packageRow(_ pkg: BrowsablePackage) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(pkg.packageLabel)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(BuneColors.accentPrimary)
                if !pkg.productName.isEmpty {
                    Text(pkg.productName)
                        .font(.footnote)
                        .foregroundColor(BuneColors.textPrimary)
                        .lineLimit(1)
                }
                HStack(spacing: 8) {
                    if let qty = pkg.quantity, let unit = pkg.unitOfMeasure {
                        Text("\(formatQuantity(qty)) \(unit)")
                            .font(.caption2)
                            .foregroundColor(BuneColors.textSecondary)
                    }
                    if let lab = pkg.labTestingState, !lab.isEmpty {
                        Text(lab)
                            .font(.caption2)
                            .foregroundColor(BuneColors.textTertiary)
                    }
                }
            }
            Spacer()
            addButton(for: pkg)
        }
        .padding(12)
        .background(BuneColors.backgroundTertiary.opacity(0.5))
        .cornerRadius(10)
    }

    @ViewBuilder
    private func addButton(for pkg: BrowsablePackage) -> some View {
        if addedLabels.contains(pkg.packageLabel) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(BuneColors.statusDelivered)
                .font(.title3)
        } else if addingLabels.contains(pkg.packageLabel) {
            ProgressView().tint(BuneColors.accentPrimary)
        } else {
            Button {
                Task { await add(pkg) }
            } label: {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(BuneColors.accentPrimary)
                    .font(.title3)
            }
        }
    }

    // MARK: - Actions

    @MainActor
    private func loadAll() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let packages = try await apiClient.browsePackages()
            allPackages = packages
            if searchText.isEmpty { results = packages }
        } catch {
            loadError = "Could not load inventory: \(error.localizedDescription)"
        }
    }

    private func scheduleSearch(_ text: String) {
        searchTask?.cancel()
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            results = allPackages
            return
        }
        searchTask = Task { [trimmed] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            if Task.isCancelled { return }
            await runSearch(trimmed)
        }
    }

    @MainActor
    private func runSearch(_ query: String) async {
        // Short queries fall back to in-memory filter over the browse list
        // so the user gets instant feedback.
        if query.count < 2 {
            let lower = query.lowercased()
            results = allPackages.filter {
                $0.packageLabel.lowercased().contains(lower) ||
                $0.productName.lowercased().contains(lower)
            }
            return
        }
        do {
            results = try await apiClient.searchPackages(query: query)
        } catch {
            // Fall back to filtering the cached browse list.
            let lower = query.lowercased()
            results = allPackages.filter {
                $0.packageLabel.lowercased().contains(lower) ||
                $0.productName.lowercased().contains(lower)
            }
        }
    }

    @MainActor
    private func add(_ pkg: BrowsablePackage) async {
        addingLabels.insert(pkg.packageLabel)
        defer { addingLabels.remove(pkg.packageLabel) }
        await onAdd(pkg)
        addedLabels.insert(pkg.packageLabel)
    }

    private func formatQuantity(_ q: Double) -> String {
        if q == q.rounded() { return String(format: "%.0f", q) }
        return String(format: "%.2f", q)
    }
}
