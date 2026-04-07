//
//  NotificationService.swift
//  BuneIOS
//
//  Created by techvvs001 on 4/6/26.
//

import UserNotifications
import SwiftUI

@MainActor
class NotificationService: ObservableObject {
    @Published var isAuthorized = false

    func requestPermission() async {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            isAuthorized = granted
        } catch {
            isAuthorized = false
        }
    }

    // MARK: - Status Change Notifications

    func notifyStatusChange(transferId: Int, manifestNumber: String, newStatus: String) {
        let content = UNMutableNotificationContent()
        content.title = "Transfer Update"
        content.body = "Transfer \(manifestNumber) is now \(newStatus.replacingOccurrences(of: "_", with: " ").lowercased())"
        content.sound = .default
        content.userInfo = ["transferId": transferId]
        content.badge = NSNumber(value: UIApplication.shared.applicationIconBadgeNumber + 1)

        let request = UNNotificationRequest(
            identifier: "status-\(transferId)-\(newStatus)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Geofence Alerts

    func notifyGeofenceAlert(type: String, zoneName: String) {
        let content = UNMutableNotificationContent()
        content.title = type == "DEVIATION" ? "Route Alert" : "Zone Alert"
        content.body = type == "ENTERED" ? "Arriving at \(zoneName)" :
                       type == "EXITED" ? "Departed \(zoneName)" :
                       "Vehicle off-route alert"
        content.sound = type == "DEVIATION" ? .default : .default
        content.badge = NSNumber(value: UIApplication.shared.applicationIconBadgeNumber + 1)

        let request = UNNotificationRequest(
            identifier: "geo-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Message Notifications

    func notifyNewMessage(senderName: String, text: String, transferId: Int) {
        let content = UNMutableNotificationContent()
        content.title = senderName
        content.body = text
        content.sound = .default
        content.userInfo = ["transferId": transferId]
        content.categoryIdentifier = "CHAT_MESSAGE"
        content.badge = NSNumber(value: UIApplication.shared.applicationIconBadgeNumber + 1)

        let request = UNNotificationRequest(
            identifier: "msg-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - ETA Notifications

    func notifyETAApproaching(manifestNumber: String, minutesRemaining: Int) {
        let content = UNMutableNotificationContent()
        content.title = "ETA Approaching"
        content.body = "Transfer \(manifestNumber) arriving in \(minutesRemaining) minutes"
        content.sound = .default
        content.badge = NSNumber(value: UIApplication.shared.applicationIconBadgeNumber + 1)

        let request = UNNotificationRequest(
            identifier: "eta-\(manifestNumber)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Overdue Notifications

    func notifyOverdue(manifestNumber: String) {
        let content = UNMutableNotificationContent()
        content.title = "Transfer Overdue"
        content.body = "Transfer \(manifestNumber) is now overdue"
        content.sound = .default
        content.badge = NSNumber(value: UIApplication.shared.applicationIconBadgeNumber + 1)

        let request = UNNotificationRequest(
            identifier: "overdue-\(manifestNumber)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Clear Notifications

    func clearAllNotifications() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        UIApplication.shared.applicationIconBadgeNumber = 0
    }

    func clearNotification(identifier: String) {
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [identifier])
    }

    // MARK: - Register Notification Categories

    func registerCategories() {
        let replyAction = UNNotificationAction(
            identifier: "REPLY",
            title: "Reply",
            options: .foreground
        )

        let chatCategory = UNNotificationCategory(
            identifier: "CHAT_MESSAGE",
            actions: [replyAction],
            intentIdentifiers: [],
            options: .customDismissAction
        )

        UNUserNotificationCenter.current().setNotificationCategories([chatCategory])
    }
}
