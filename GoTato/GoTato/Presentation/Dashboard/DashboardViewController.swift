//
//  DashboardViewController.swift
//  GoTato
//
//  Created by 석민솔 on 3/24/26.
//

import RxCocoa
import RxSwift
import SnapKit
import UIKit

final class DashboardViewController: BaseViewController {

    // MARK: - ViewModel

    private let viewModel = DashboardViewModel()
    private let bag = DisposeBag()

    // MARK: - Input relays

    private let viewWillAppearRelay = PublishRelay<Void>()
    private let pullToRefreshRelay = PublishRelay<Void>()
    private let missionAddedRelay = PublishRelay<Void>()
    private let refreshButtonTappedRelay = PublishRelay<Int>()
    private let checkInButtonTappedRelay = PublishRelay<Int>()
    private let commitButtonTappedRelay = PublishRelay<Int>()

    // MARK: - No-mission view

    private let noMissionView = UIView()
    private let noMissionMessageCard = DashBoardMessageCardView()
    private let setMissionButtonView = SetMissionButtonView()

    // MARK: - Page view controller

    private let pageVC = UIPageViewController(
        transitionStyle: .scroll,
        navigationOrientation: .horizontal
    )
    private let pageControl = UIPageControl()
    private let refreshControl = UIRefreshControl()

    // MARK: - State

    private var pageVCs: [DashboardPageContentViewController] = []
    private var currentPageIndex = 0

    // MARK: - Lifecycle

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewWillAppearRelay.accept(())
    }

    // MARK: - BaseViewController

    override func configureHierarchy() {
        // No-mission view
        view.addSubview(noMissionView)
        noMissionView.addSubview(noMissionMessageCard)
        noMissionView.addSubview(setMissionButtonView)

        // Page view controller
        addChild(pageVC)
        view.addSubview(pageVC.view)
        pageVC.didMove(toParent: self)
        pageVC.dataSource = self
        pageVC.delegate = self

        // Page control
        view.addSubview(pageControl)
    }

    override func configureLayout() {
        noMissionView.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide).offset(16)
            $0.leading.trailing.equalToSuperview().inset(20)
            $0.bottom.lessThanOrEqualTo(view.safeAreaLayoutGuide).inset(16)
        }

        noMissionMessageCard.snp.makeConstraints {
            $0.top.leading.trailing.equalToSuperview()
        }

        setMissionButtonView.snp.makeConstraints {
            $0.top.equalTo(noMissionMessageCard.snp.bottom).offset(12)
            $0.leading.trailing.bottom.equalToSuperview()
        }

        pageVC.view.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide)
            $0.leading.trailing.bottom.equalToSuperview()
        }

        pageControl.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.bottom.equalTo(view.safeAreaLayoutGuide).inset(16)
        }
    }

    override func configureView() {
        noMissionMessageCard.configure(state: .noMission)

        setMissionButtonView.onTap = { [weak self] in
            self?.presentMissionSetup()
        }

        pageControl.pageIndicatorTintColor = GTTColor.divider
        pageControl.currentPageIndicatorTintColor = GTTColor.brand
        pageControl.addTarget(self, action: #selector(didChangePageControlValue), for: .valueChanged)
    }

    override func bind() {
        let input = DashboardViewModel.Input(
            viewDidLoad: Observable.just(()),
            viewWillAppear: viewWillAppearRelay.asObservable(),
            pullToRefresh: pullToRefreshRelay.asObservable(),
            missionAdded: missionAddedRelay.asObservable(),
            refreshButtonTapped: refreshButtonTappedRelay,
            checkInButtonTapped: checkInButtonTappedRelay,
            commitButtonTapped: commitButtonTappedRelay
        )

        let output = viewModel.transform(input: input)

        output.missionStates
            .drive(onNext: { [weak self] states in
                self?.updateUI(with: states)
            })
            .disposed(by: bag)

        output.isRefreshing
            .drive(onNext: { [weak self] isRefreshing in
                if !isRefreshing {
                    self?.pageVCs.forEach { $0.endRefreshing() }
                }
            })
            .disposed(by: bag)
    }

    // MARK: - UI update

    private func updateUI(with states: [DashboardMissionState]) {
        if states.isEmpty {
            noMissionView.isHidden = false
            pageVC.view.isHidden = true
            pageControl.isHidden = true
            return
        }

        noMissionView.isHidden = true
        pageVC.view.isHidden = false
        pageControl.isHidden = states.count < 2

        updatePageVCs(with: states)
        pageControl.numberOfPages = states.count
        pageControl.currentPage = currentPageIndex
    }

    private func updatePageVCs(with states: [DashboardMissionState]) {
        if states.count != pageVCs.count {
            // Rebuild page VCs
            pageVCs = states.enumerated().map { index, state in
                let vc = DashboardPageContentViewController()
                vc.configure(state: state)
                configurePageVC(vc, index: index)
                return vc
            }

            currentPageIndex = min(currentPageIndex, max(0, pageVCs.count - 1))
            if let currentVC = pageVCs[safe: currentPageIndex] {
                pageVC.setViewControllers([currentVC], direction: .forward, animated: false)
            }
        } else {
            // Update in place
            for (index, (vc, state)) in zip(pageVCs, states).enumerated() {
                vc.configure(state: state)
                configurePageVC(vc, index: index)
            }
        }
    }

    private func configurePageVC(_ vc: DashboardPageContentViewController, index: Int) {
        vc.onCheckInTapped = { [weak self] in
            self?.checkInButtonTappedRelay.accept(index)
        }
        vc.onCommitTapped = { [weak self] in
            self?.commitButtonTappedRelay.accept(index)
        }
        vc.onRefreshPulled = { [weak self] in
            self?.handleRefresh()
        }
        vc.onRefreshTapped = { [weak self] in
            self?.refreshButtonTappedRelay.accept(index)
        }
        vc.onSetMissionTapped = { [weak self] in
            self?.presentMissionSetup()
        }
    }

    // MARK: - Actions

    @objc private func didChangePageControlValue() {
        let index = pageControl.currentPage
        guard index != currentPageIndex,
              let targetVC = pageVCs[safe: index] else { return }

        let direction: UIPageViewController.NavigationDirection = index > currentPageIndex ? .forward : .reverse
        pageVC.setViewControllers([targetVC], direction: direction, animated: true)
        currentPageIndex = index
    }

    @objc private func handleRefresh() {
        pullToRefreshRelay.accept(())
    }

    private func presentMissionSetup() {
        let vc = MissionSetupViewController(isFromOnboarding: false)
        vc.delegate = self
        present(vc, animated: true)
    }
}

// MARK: - UIPageViewControllerDataSource

extension DashboardViewController: UIPageViewControllerDataSource {
    func pageViewController(
        _ pageViewController: UIPageViewController,
        viewControllerBefore viewController: UIViewController
    ) -> UIViewController? {
        guard let vc = viewController as? DashboardPageContentViewController,
              let index = pageVCs.firstIndex(where: { $0 === vc }),
              index > 0 else { return nil }
        return pageVCs[index - 1]
    }

    func pageViewController(
        _ pageViewController: UIPageViewController,
        viewControllerAfter viewController: UIViewController
    ) -> UIViewController? {
        guard let vc = viewController as? DashboardPageContentViewController,
              let index = pageVCs.firstIndex(where: { $0 === vc }),
              index < pageVCs.count - 1 else { return nil }
        return pageVCs[index + 1]
    }
}

// MARK: - UIPageViewControllerDelegate

extension DashboardViewController: UIPageViewControllerDelegate {
    func pageViewController(
        _ pageViewController: UIPageViewController,
        didFinishAnimating finished: Bool,
        previousViewControllers: [UIViewController],
        transitionCompleted completed: Bool
    ) {
        guard completed,
              let current = pageViewController.viewControllers?.first as? DashboardPageContentViewController,
              let index = pageVCs.firstIndex(where: { $0 === current }) else { return }
        currentPageIndex = index
        pageControl.currentPage = index
    }
}

// MARK: - MissionSetupDelegate

extension DashboardViewController: MissionSetupDelegate {
    func missionSetupDidComplete(_ vc: MissionSetupViewController) {
        missionAddedRelay.accept(())
    }
}

// MARK: - Array safe subscript

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
