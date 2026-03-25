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
        dashboard.tabBarItem = UITabBarItem(title: "미션", image: nil, tag: 0)

        let history = UINavigationController(rootViewController: HistoryViewController())
        history.tabBarItem = UITabBarItem(title: "기록", image: nil, tag: 1)

        viewControllers = [dashboard, history]
    }
}
