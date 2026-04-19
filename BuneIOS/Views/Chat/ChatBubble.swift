//
//  ChatBubble.swift
//  BuneIOS
//
//  Created by techvvs001 on 4/6/26.
//

import SwiftUI

// MARK: - Chat Bubble
struct ChatBubble: View {
    let message: ChatMessage
    let isCurrentUser: Bool

    private var bubbleAlignment: Alignment {
        isCurrentUser ? .trailing : .leading
    }

    private var bubbleColor: Color {
        isCurrentUser ? BuneColors.accentPrimary : Color.white.opacity(0.08)
    }

    private var textColor: Color {
        isCurrentUser ? .white : BuneColors.textPrimary
    }

    private var displayedTime: String {
        formatTimestamp(message.timestamp)
    }

    var body: some View {
        VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
            // Sender name (above bubble)
            if !isCurrentUser {
                Text(message.senderName ?? message.sender)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(BuneColors.textSecondary)
                    .padding(.horizontal, 12)
            }

            // Bubble
            HStack(spacing: 0) {
                if isCurrentUser {
                    Spacer()
                }

                VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 6) {
                    Text(message.text)
                        .font(.caption)
                        .foregroundColor(textColor)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 6) {
                        if message.isQueued == true {
                            // Offline-queued placeholder — the queue drains
                            // on reconnect and a message poll will replace
                            // this row with the real server message.
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.caption2)
                            Text("Sending when back online")
                                .font(.caption2)
                        }
                        Text(displayedTime)
                            .font(.caption2)
                    }
                    .foregroundColor(
                        isCurrentUser
                            ? Color.white.opacity(0.6)
                            : BuneColors.textTertiary
                    )
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(bubbleColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(
                                    Color.white.opacity(0.1),
                                    lineWidth: isCurrentUser ? 0 : 1
                                )
                        )
                )

                if !isCurrentUser {
                    Spacer()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: bubbleAlignment)
    }

    // MARK: - Helper Functions
    private func formatTimestamp(_ timestamp: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: timestamp) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .none
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        return timestamp
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

        ScrollView {
            VStack(spacing: 16) {
                ChatBubble(
                    message: ChatMessage(
                        messageId: 1,
                        transferId: 1,
                        sender: "admin",
                        senderName: "Dispatch",
                        text: "Your transfer is ready for pickup",
                        timestamp: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-300))
                    ),
                    isCurrentUser: false
                )

                ChatBubble(
                    message: ChatMessage(
                        messageId: 2,
                        transferId: 1,
                        sender: "driver",
                        senderName: "Driver",
                        text: "On my way to pickup location",
                        timestamp: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-200))
                    ),
                    isCurrentUser: true
                )

                ChatBubble(
                    message: ChatMessage(
                        messageId: 3,
                        transferId: 1,
                        sender: "admin",
                        senderName: "Dispatch",
                        text: "Package count confirmed. Proceeding with scan",
                        timestamp: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-100))
                    ),
                    isCurrentUser: false
                )

                ChatBubble(
                    message: ChatMessage(
                        messageId: 4,
                        transferId: 1,
                        sender: "driver",
                        senderName: "Driver",
                        text: "Pickup complete. Heading to hub.",
                        timestamp: ISO8601DateFormatter().string(from: Date())
                    ),
                    isCurrentUser: true
                )

                Spacer()
            }
            .padding(16)
        }
    }
}
