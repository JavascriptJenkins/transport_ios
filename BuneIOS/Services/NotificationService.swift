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
        // Badge count is owned by UNUserNotificationCenter (iOS 17+); leaving
        // content.badge nil defers to whatever setBadgeCount() was last called with.

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
        // Badge count is owned by UNUserNotificationCenter (iOS 17+); leaving
        // content.badge nil defers to whatever setBadgeCount() was last called with.

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
        // Badge count is owned by UNUserNotificationCenter (iOS 17+); leaving
        // content.badge nil defers to whatever setBadgeCount() was last called with.

        let request = UNNotificationRequest(
            identifier: "msg-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - ETA + Overdue Notifications (scheduled, not immediate)

    /// How many minutes before the ETA the "arriving soon" alert fires.
    var etaWarningMinutes: Int = 15

    /// How many minutes past the ETA we consider a transfer "overdue".
    var overdueGraceMinutes: Int = 15

    /// Schedule an "ETA approaching" alert for a transfer. Silently no-ops if
    /// the ETA is in the past or the warning window has already elapsed, so
    /// callers can scan every transfer on every refresh without extra gating.
    func scheduleETAApproaching(transferId: Int, manifestNumber: String, arrivalAt: Date) {
        let fireAt = arrivalAt.addingTimeInterval(TimeInterval(-etaWarningMinutes * 60))
        scheduleAt(
            fireAt,
            identifier: "eta-\(transferId)",
            title: "ETA Approaching",
            body: "Transfer \(manifestNumber) arriving in \(etaWarningMinutes) minutes",
            transferId: transferId
        )
    }

    /// Schedule an overdue alert that fires after the ETA + grace window.
    func scheduleOverdueAlert(transferId: Int, manifestNumber: String, arrivalAt: Date) {
        let fireAt = arrivalAt.addingTimeInterval(TimeInterval(overdueGraceMinutes * 60))
        scheduleAt(
            fireAt,
            identifier: "overdue-\(transferId)",
            title: "Transfer Overdue",
            body: "Transfer \(manifestNumber) has not been marked delivered",
            transferId: transferId
        )
    }

    /// Cancel any pending ETA/overdue alerts for a transfer. Call when the
    /// transfer is delivered, canceled, or the ETA is rescheduled.
    func cancelPendingAlerts(transferId: Int) {
        let identifiers = ["eta-\(transferId)", "overdue-\(transferId)"]
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    /// Scan a batch of transfers (typically the dashboard list) and schedule
    /// alerts for any active ones with an ETA. Delivered / canceled transfers
    /// have their pending alerts cleared.
    func refreshScheduledAlerts(for transfers: [Transfer]) {
        let parser = ISO8601DateFormatter()
        for transfer in transfers {
            let status = transfer.status.uppercased()
            if status == "DELIVERED" || status == "ACCEPTED" || status == "CANCELED" {
                cancelPendingAlerts(transferId: transfer.id)
                continue
            }
            guard let iso = transfer.estimatedArrivalDateTime,
                  let arrival = parser.date(from: iso) else { continue }

            let manifest = transfer.manifestNumber ?? "transfer \(transfer.id)"
            scheduleETAApproaching(transferId: transfer.id, manifestNumber: manifest, arrivalAt: arrival)
            scheduleOverdueAlert(transferId: transfer.id, manifestNumber: manifest, arrivalAt: arrival)
        }
    }

    // MARK: - Scheduling Internals

    private func scheduleAt(
        _ fireDate: Date,
        identifier: String,
        title: String,
        body: String,
        transferId: Int
    ) {
        // Drop past fire times so we don't flood with stale alerts on
        // background refresh after the app has been closed for a while.
        let interval = fireDate.timeIntervalSinceNow
        guard interval > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = ["transferId": transferId]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        // Replace any previously-scheduled alert with the same identifier so
        // shifted ETAs bump the fire time instead of producing duplicates.
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Clear Notifications

    func clearAllNotifications() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        UNUserNotificationCenter.current().setBadgeCount(0) { _ in }
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
