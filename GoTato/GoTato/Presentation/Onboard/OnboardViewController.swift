//
//  OnboardViewController.swift
//  GoTato
//
//  Created by 석민솔 on 3/23/26.
//

import UIKit
import SnapKit

final class OnboardViewController: BaseViewController {

    private let titleLabel = UILabel()
    private let missionButton = UIButton(type: .system)
    private let browseButton = UIButton(type: .system)

    override func configureHierarchy() {
        view.addSubview(titleLabel)
        view.addSubview(missionButton)
        view.addSubview(browseButton)
    }

    override func configureLayout() {
        titleLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        missionButton.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(32)
            make.centerX.equalToSuperview()
        }
        browseButton.snp.makeConstraints { make in
            make.top.equalTo(missionButton.snp.bottom).offset(16)
            make.centerX.equalToSuperview()
        }
    }

    override func configureView() {
        titleLabel.text = "일단감자"
        titleLabel.font = .systemFont(ofSize: 32, weight: .bold)

        missionButton.setTitle("미션 만들기", for: .normal)
        missionButton.addTarget(self, action: #selector(didTapMission), for: .touchUpInside)

        browseButton.setTitle("둘러보기", for: .normal)
        browseButton.addTarget(self, action: #selector(didTapBrowse), for: .touchUpInside)
    }

    @objc private func didTapMission() {
        let vc = MissionSetupViewController(isFromOnboarding: true)
        navigationController?.pushViewController(vc, animated: true)
    }

    @objc private func didTapBrowse() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        guard let window = view.window else { return }
        window.rootViewController = MainTabBarController()
        UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve, animations: nil)
    }
}
