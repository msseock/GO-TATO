//
//  NotificationService.swift
//  GoTato
//

import UserNotifications

final class NotificationService {
    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()
    private let sentKey = "GeofenceNotificationSentDates"

    private init() {}

    // MARK: - Authorization

    func requestAuthorization(completion: ((Bool) -> Void)? = nil) {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                completion?(granted)
            }
        }
    }

    // MARK: - Send Notification

    func sendNearLocationNotification(missionID: UUID, locationName: String) {
        guard !hasAlreadySentToday(for: missionID) else { return }

        let content = UNMutableNotificationContent()
        content.title = "일단감자"
        content.body = "\(locationName) 근처에 도착했어요! 출근 인증하시겠어요?"
        content.sound = .default
        content.userInfo = ["missionID": missionID.uuidString]

        let request = UNNotificationRequest(
            identifier: "geofence-\(missionID.uuidString)",
            content: content,
            trigger: nil
        )

        center.add(request)
        markAsSentToday(for: missionID)
    }

    // MARK: - Daily Limit

    private func hasAlreadySentToday(for missionID: UUID) -> Bool {
        guard let dict = UserDefaults.standard.dictionary(forKey: sentKey) as? [String: Date] else {
            return false
        }
        guard let lastSent = dict[missionID.uuidString] else {
            return false
        }
        return Calendar.current.isDateInToday(lastSent)
    }

    private func markAsSentToday(for missionID: UUID) {
        var dict = (UserDefaults.standard.dictionary(forKey: sentKey) as? [String: Date]) ?? [:]
        dict[missionID.uuidString] = Date()
        UserDefaults.standard.set(dict, forKey: sentKey)
    }
}
