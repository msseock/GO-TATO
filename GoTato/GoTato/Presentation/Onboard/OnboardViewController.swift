//
//  OnboardViewController.swift
//  GoTato
//
//  Created by 석민솔 on 3/23/26.
//

import UIKit
import SnapKit
import RxSwift
import RxCocoa

final class OnboardViewController: BaseViewController {

    // MARK: - Properties

    private let viewModel = OnboardViewModel()
    private let disposeBag = DisposeBag()

    // MARK: - UI

    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let potatoImageView = UIImageView()
    private let missionButton = GTTMainButton(title: "미션 만들기", style: .primary)
    private let browseButton = GTTMainButton(title: "둘러보기", style: .secondary)

    // MARK: - Configure

    override func configureHierarchy() {
        view.addSubview(titleLabel)
        view.addSubview(subtitleLabel)
        view.addSubview(potatoImageView)
        view.addSubview(missionButton)
        view.addSubview(browseButton)
    }

    override func configureLayout() {
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(60)
            make.centerX.equalToSuperview()
        }

        potatoImageView.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(30)
            make.centerX.equalToSuperview()
            make.width.height.equalTo(200)
        }

        subtitleLabel.snp.makeConstraints { make in
            make.top.equalTo(potatoImageView.snp.bottom).offset(45)
            make.centerX.equalToSuperview()
        }

        missionButton.snp.makeConstraints { make in
            make.top.equalTo(subtitleLabel.snp.bottom).offset(24)
            make.horizontalEdges.equalToSuperview().inset(20)
        }

        browseButton.snp.makeConstraints { make in
            make.top.equalTo(missionButton.snp.bottom).offset(16)
            make.horizontalEdges.equalToSuperview().inset(20)
        }
    }

    override func configureView() {
        view.backgroundColor = GTTColor.bgPrimary

        titleLabel.text = "반갑습니다!"
        titleLabel.font = GTTFont.heroTitle.font
        titleLabel.textColor = GTTColor.textPrimary

        subtitleLabel.text = "설레는 내일 아침,\n감자와 함께 미션을 시작해볼까요?"
        subtitleLabel.font = GTTFont.body.font
        subtitleLabel.textColor = GTTColor.textSecondary
        subtitleLabel.numberOfLines = 0
        subtitleLabel.textAlignment = .center

        potatoImageView.image = UIImage(named: "PotatoSparkle")
        potatoImageView.contentMode = .scaleAspectFit
    }

    override func bind() {
        let input = OnboardViewModel.Input(
            missionTap: missionButton.rx.controlEvent(.touchUpInside).map { },
            browseTap: browseButton.rx.controlEvent(.touchUpInside).map { }
        )
        let output = viewModel.transform(input: input)

        output.navigateToMission
            .emit(onNext: { [weak self] in
                let vc = MissionSetupViewController(isFromOnboarding: true)
                self?.navigationController?.pushViewController(vc, animated: true)
            })
            .disposed(by: disposeBag)

        output.navigateToDashboard
            .emit(onNext: { [weak self] in
                guard let window = self?.view.window else { return }
                window.rootViewController = MainTabBarController()
                UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve, animations: nil)
            })
            .disposed(by: disposeBag)
    }
}
