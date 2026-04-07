//
//  ChatView.swift
//  BuneIOS
//
//  Created by techvvs001 on 4/6/26.
//

import SwiftUI

// MARK: - Chat View
struct ChatView: View {
    @StateObject private var viewModel: TransferDetailViewModel
    @State private var messageText: String = ""
    @State private var scrollTarget: Int?
    @Environment(\.scenePhase) var scenePhase
    @EnvironmentObject var authService: AuthService

    let transferId: Int
    let apiClient: TransportAPIClient

    private let quickReplies = [
        "On my way",
        "Arrived",
        "Running late",
        "Need assistance"
    ]

    init(transferId: Int, apiClient: TransportAPIClient) {
        self.transferId = transferId
        self.apiClient = apiClient
        _viewModel = StateObject(
            wrappedValue: TransferDetailViewModel(transferId: transferId, apiClient: apiClient)
        )
    }

    var body: some View {
        ZStack {
            // Background
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

            VStack(spacing: 0) {
                // MARK: - Message List
                ScrollViewReader { scrollProxy in
                    ScrollView {
                        VStack(spacing: 12) {
                            if viewModel.messages.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "bubble.left")
                                        .font(.title)
                                        .foregroundColor(BuneColors.textTertiary)

                                    Text("No messages yet")
                                        .font(.caption)
                                        .foregroundColor(BuneColors.textSecondary)

                                    Text("Start a conversation")
                                        .font(.caption2)
                                        .foregroundColor(BuneColors.textTertiary)
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                                .padding(20)
                            } else {
                                ForEach(viewModel.messages, id: \.id) { message in
                                    ChatBubble(
                                        message: message,
                                        isCurrentUser: message.sender.lowercased() == "driver"
                                    )
                                    .id(message.id)
                                }
                            }
                        }
                        .padding(16)
                        .onChange(of: viewModel.messages.count) {
                            scrollTarget = viewModel.messages.last?.id
                        }
                    }
                    .scrollPosition(id: $scrollTarget)
                    .onAppear {
                        scrollTarget = viewModel.messages.last?.id
                    }
                }

                // MARK: - Quick Reply Chips
                if !quickReplies.isEmpty {
                    QuickReplyChips(chips: quickReplies) { chip in
                        Task {
                            await viewModel.sendMessage(chip)
                            messageText = ""
                        }
                    }
                    .padding(.vertical, 8)
                }

                // MARK: - Input Bar
                HStack(spacing: 12) {
                    TextField("Type a message...", text: $messageText)
                        .font(.caption)
                        .foregroundColor(BuneColors.textPrimary)
                        .glassTextField()

                    Button(action: {
                        Task {
                            await viewModel.sendMessage(messageText)
                            messageText = ""
                        }
                    }) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title3)
                            .foregroundColor(
                                messageText.trimmingCharacters(in: .whitespaces).isEmpty
                                    ? BuneColors.textTertiary
                                    : BuneColors.accentPrimary
                            )
                    }
                    .disabled(messageText.trimmingCharacters(in: .whitespaces).isEmpty)

                    Spacer()
                        .frame(width: 4)
                }
                .padding(12)
            }
        }
        .task {
            await viewModel.loadMessages()
            viewModel.startMessagePolling()
        }
        .onDisappear {
            viewModel.stopMessagePolling()
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                viewModel.startMessagePolling()
            } else if newPhase == .background {
                viewModel.stopMessagePolling()
            }
        }
        .navigationTitle("Messages")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Preview
#Preview {
    let mockAPIClient = TransportAPIClient(authService: AuthService())
    return NavigationStack {
        ChatView(transferId: 1, apiClient: mockAPIClient)
    }
    .environmentObject(AuthService())
}
