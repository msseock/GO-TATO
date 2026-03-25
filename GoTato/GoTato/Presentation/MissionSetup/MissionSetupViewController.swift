//
//  MissionSetupViewController.swift
//  GoTato
//
//  Created by 석민솔 on 3/24/26.
//

import UIKit
import SnapKit

protocol MissionSetupDelegate: AnyObject {
    func missionSetupDidComplete(_ vc: MissionSetupViewController)
}

final class MissionSetupViewController: BaseViewController {

    var isFromOnboarding: Bool
    weak var delegate: MissionSetupDelegate?

    private let doneButton = UIButton(type: .system)

    init(isFromOnboarding: Bool) {
        self.isFromOnboarding = isFromOnboarding
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func configureHierarchy() {
        view.addSubview(doneButton)
    }

    override func configureLayout() {
        doneButton.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
    }

    override func configureView() {
        doneButton.setTitle("완료", for: .normal)
        doneButton.addTarget(self, action: #selector(didTapDone), for: .touchUpInside)
    }

    @objc private func didTapDone() {
        if isFromOnboarding {
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
            guard let window = view.window else { return }
            window.rootViewController = MainTabBarController()
            UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve, animations: nil)
        } else {
            delegate?.missionSetupDidComplete(self)
            dismiss(animated: true)
        }
    }
}
