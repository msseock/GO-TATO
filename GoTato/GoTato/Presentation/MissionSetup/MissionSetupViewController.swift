//
//  MissionSetupViewController.swift
//  GoTato
//
//  Created by 석민솔 on 3/24/26.
//

import UIKit
import SnapKit
import RxSwift
import RxCocoa

protocol MissionSetupDelegate: AnyObject {
    func missionSetupDidComplete(_ vc: MissionSetupViewController)
}

final class MissionSetupViewController: BaseViewController {

    // MARK: - Properties

    var isFromOnboarding: Bool
    weak var delegate: MissionSetupDelegate?

    private let viewModel = MissionSetupViewModel()
    private let disposeBag = DisposeBag()

    private let createMissionSubject = PublishSubject<(SelectedLocation, MissionRoutine)>()

    // MARK: - Child View Controllers

    private let locationVC = LocationSelectViewController()
    private let routineVC = RoutineSelectViewController()

    // MARK: - UI

    private let containerView = UIView()

    // MARK: - Init

    init(isFromOnboarding: Bool) {
        self.isFromOnboarding = isFromOnboarding
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupChildViewControllers()
    }

    override func configureHierarchy() {
        view.addSubview(containerView)
    }

    override func configureLayout() {
        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    override func configureView() { }

    override func bind() {
        let input = MissionSetupViewModel.Input(
            createMission: createMissionSubject.asObservable()
        )
        let output = viewModel.transform(input: input)

        output.missionCreated
            .emit(onNext: { [weak self] in
                self?.handleMissionCreated()
            })
            .disposed(by: disposeBag)

        output.errorMessage
            .emit(onNext: { [weak self] message in
                self?.showErrorAlert(message: message)
            })
            .disposed(by: disposeBag)
    }

    // MARK: - Child VC Setup

    private func setupChildViewControllers() {
        addChild(locationVC)
        containerView.addSubview(locationVC.view)
        locationVC.view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        locationVC.didMove(toParent: self)

        addChild(routineVC)
        containerView.addSubview(routineVC.view)
        routineVC.view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        routineVC.didMove(toParent: self)
        routineVC.view.isHidden = true

        locationVC.onLocationConfirmed = { [weak self] location in
            self?.routineVC.pendingLocation = location
            self?.transitionToRoutine()
        }

        routineVC.onRoutineConfirmed = { [weak self] location, routine in
            self?.createMissionSubject.onNext((location, routine))
        }
    }

    // MARK: - Location → Routine 전환

    private func transitionToRoutine() {
        UIView.transition(
            with: containerView,
            duration: 0.3,
            options: .transitionCrossDissolve
        ) {
            self.locationVC.view.isHidden = true
            self.routineVC.view.isHidden = false
        }
    }

    // MARK: - Mission Created

    private func handleMissionCreated() {
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

    private func showErrorAlert(message: String) {
        let alert = UIAlertController(title: "미션 생성 실패", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
    }
}
