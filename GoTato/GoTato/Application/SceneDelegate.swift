//
//  SceneDelegate.swift
//  GoTato
//
//  Created by 석민솔 on 3/23/26.
//

import UIKit
import RxSwift

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    private let disposeBag = DisposeBag()

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let scene = (scene as? UIWindowScene) else { return }

        window = UIWindow(windowScene: scene)
        let hasCompleted = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        if hasCompleted {
            window?.rootViewController = MainTabBarController()
        } else {
            let nav = UINavigationController(rootViewController: OnboardViewController())
            window?.rootViewController = nav
        }
        window?.makeKeyAndVisible()
    }

    func sceneDidDisconnect(_ scene: UIScene) { }

    func sceneDidBecomeActive(_ scene: UIScene) { }

    func sceneWillResignActive(_ scene: UIScene) { }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // 백그라운드 복귀 시 기한 초과 Attendance를 fail로 일괄 업데이트
        AttendanceRepository.shared
            .batchMarkFailed()
            .subscribe(onSuccess: { _ in }, onFailure: { _ in })
            .disposed(by: disposeBag)
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        CoreDataStack.shared.saveViewContext()
    }
}
