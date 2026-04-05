//
//  MainTabBarController.swift
//  GoTato
//
//  Created by 석민솔 on 3/25/26.
//

import UIKit

final class MainTabBarController: UITabBarController {
    override func viewDidLoad() {
        super.viewDidLoad()

        let dashboard = UINavigationController(rootViewController: DashboardViewController())
        dashboard.tabBarItem = UITabBarItem(
            title: "미션",
            image: UIImage(named: "potpotato_black"),
            selectedImage: UIImage(named: "potpotato_accent")
        )

        let history = UINavigationController(rootViewController: HistoryViewController())
        let config = UIImage.SymbolConfiguration(weight: .light)
        history.tabBarItem = UITabBarItem(
            title: "기록",
            image: UIImage(systemName: "calendar", withConfiguration: config),
            selectedImage: UIImage(systemName: "calendar", withConfiguration: config)
        )

        viewControllers = [dashboard, history]

        #if DEBUG
        let developer = UINavigationController(rootViewController: DeveloperModeViewController())
        developer.tabBarItem = UITabBarItem(
            title: "개발자",
            image: UIImage(systemName: "gearshape", withConfiguration: config),
            selectedImage: UIImage(systemName: "gearshape.fill", withConfiguration: config)
        )
        viewControllers?.append(developer)
        #endif
    }
}
