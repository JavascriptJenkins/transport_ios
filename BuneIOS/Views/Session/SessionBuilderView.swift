//
//  SessionBuilderView.swift
//  BuneIOS
//
//  Created by techvvs001 on 4/6/26.
//

import SwiftUI

// MARK: - Session Builder View

struct SessionBuilderView: View {
    @StateObject private var viewModel: SessionBuilderViewModel
    @Environment(\.dismiss) var dismiss

    init(apiClient: TransportAPIClient) {
        _viewModel = StateObject(wrappedValue: SessionBuilderViewModel(apiClient: apiClient))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BuneColors.backgroundPrimary.ignoresSafeArea()

                if viewModel.isLoading {
                    LoadingOverlay()
                } else {
                    VStack(spacing: 0) {
                        PhaseIndicator(currentPhase: viewModel.currentPhase, errorMessage: viewModel.errorMessage)
                            .padding(.vertical, 20)

                        switch viewModel.currentPhase {
                        case .scan:
                            ScanPhaseView(viewModel: viewModel)
                        case .configure:
                            ConfigurePhaseView(viewModel: viewModel)
                        case .review:
                            ReviewPhaseView(viewModel: viewModel)
                        }
                    }
                }
            }
            .navigationTitle("Create Manifest")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Cancel")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(BuneColors.accentPrimary)
                    }
                }
            }
            .task {
                await viewModel.createSession()
            }
        }
    }
}

// MARK: - Phase Indicator

struct PhaseIndicator: View {
    let currentPhase: SessionBuilderViewModel.Phase
    var errorMessage: String? = nil

    private let phases: [SessionBuilderViewModel.Phase] = [.scan, .configure, .review]
    private let labels = ["Scan", "Configure", "Review"]

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 0) {
                ForEach(0..<phases.count, id: \.self) { index in
                    VStack(spacing: 8) {
                        Circle()
                            .fill(phaseColor(for: phases[index]))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Circle()
                                    .stroke(
                                        phaseColor(for: phases[index]).opacity(0.3),
                                        lineWidth: 2
                                    )
                            )
                            .overlay(
                                Text(String(index + 1))
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                            )

                        Text(labels[index])
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(BuneColors.textPrimary)
                    }

                    if index < phases.count - 1 {
                        VStack {
                            Spacer()
                            HStack {
                                Rectangle()
                                    .fill(
                                        isPhaseCompleted(phases[index])
                                            ? BuneColors.accentPrimary
                                            : BuneColors.textTertiary.opacity(0.5)
                                    )
                                    .frame(height: 2)
                            }
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 8)
                    }
                }
            }
            .padding(.horizontal, 20)

            // Error message if present
            if let errorMessage = errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(BuneColors.errorColor)
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(BuneColors.errorColor)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(BuneColors.errorColor.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal, 20)
            }
        }
    }

    private func phaseColor(for phase: SessionBuilderViewModel.Phase) -> Color {
        if isPhaseCompleted(phase) {
            return BuneColors.statusDelivered
        }
        if phase == currentPhase {
            return BuneColors.accentPrimary
        }
        return BuneColors.textTertiary.opacity(0.3)
    }

    private func isPhaseCompleted(_ phase: SessionBuilderViewModel.Phase) -> Bool {
        let currentIndex = phases.firstIndex(of: currentPhase) ?? 0
        let phaseIndex = phases.firstIndex(of: phase) ?? 0
        return phaseIndex < currentIndex
    }
}

// MARK: - Loading Overlay

struct LoadingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.3).ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(BuneColors.accentPrimary)

                Text("Processing...")
                    .font(.subheadline)
                    .foregroundColor(BuneColors.textPrimary)
            }
            .padding(32)
            .glassCard()
        }
    }
}

// MARK: - Preview

#Preview {
    let mockAuthService = AuthService()
    let mockAPIClient = TransportAPIClient(authService: mockAuthService)

    SessionBuilderView(apiClient: mockAPIClient)
}
