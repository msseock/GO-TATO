//
//  AppDelegate.swift
//  GoTato
//
//  Created by 석민솔 on 3/23/26.
//

import UIKit
import UserNotifications
import NMapsMap

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        _ = CoreDataStack.shared   // 초기화 트리거 (lazy 방지)
        _ = GeofenceManager.shared // 지오펜스 이벤트 구독 시작
        NMFAuthManager.shared().ncpKeyId = SecretConstants.naverMapClientID

        UNUserNotificationCenter.current().delegate = self

        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) { }
}

// MARK: - UNUserNotificationCenterDelegate

extension AppDelegate: UNUserNotificationCenterDelegate {

    /// 앱이 포그라운드일 때도 알림 배너를 표시
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    /// 알림 탭 시 대시보드의 해당 미션 페이지로 이동
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        if let missionIDString = userInfo["missionID"] as? String,
           let missionID = UUID(uuidString: missionIDString) {
            NotificationCenter.default.post(
                name: .didTapGeofenceNotification,
                object: nil,
                userInfo: ["missionID": missionID]
            )
        }
        completionHandler()
    }
}

// MARK: - Notification Name

extension Notification.Name {
    static let didTapGeofenceNotification = Notification.Name("didTapGeofenceNotification")
}
