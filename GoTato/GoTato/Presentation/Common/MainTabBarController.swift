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
    }
}
