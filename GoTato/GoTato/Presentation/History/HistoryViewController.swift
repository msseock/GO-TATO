//
//  HistoryViewController.swift
//  GoTato
//
//  Created by 석민솔 on 3/24/26.
//

import UIKit
import SnapKit

final class HistoryViewController: BaseViewController {

    private let titleLabel = UILabel()
    private let addMissionButton = UIButton(type: .system)

    override func configureHierarchy() {
        view.addSubview(titleLabel)
        view.addSubview(addMissionButton)
    }

    override func configureLayout() {
        titleLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        addMissionButton.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(24)
            make.centerX.equalToSuperview()
        }
    }

    override func configureView() {
        titleLabel.text = "History"
        titleLabel.font = .systemFont(ofSize: 24, weight: .semibold)

        addMissionButton.setTitle("미션 추가", for: .normal)
        addMissionButton.addTarget(self, action: #selector(didTapAddMission), for: .touchUpInside)
    }

    @objc private func didTapAddMission() {
        let vc = MissionSetupViewController(isFromOnboarding: false)
        vc.delegate = self
        present(vc, animated: true)
    }
}

extension HistoryViewController: MissionSetupDelegate {
    func missionSetupDidComplete(_ vc: MissionSetupViewController) { }
}
