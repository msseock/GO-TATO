//
//  DashboardPageContentViewController.swift
//  GoTato
//

import SnapKit
import UIKit

final class DashboardPageContentViewController: UIViewController {

    // MARK: - Callbacks

    var onCheckInTapped: (() -> Void)?
    var onCommitTapped: (() -> Void)?
    var onRefreshPulled: (() -> Void)?
    var onRefreshTapped: (() -> Void)?
    var onSetMissionTapped: (() -> Void)?

    // MARK: - UI

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let titleLabel = UILabel()
    private let deadlineLabel = UILabel()
    private let messageCardView = DashBoardMessageCardView()
    private let mainActionContainer = UIView()
    private let bottomButtonContainer = UIView()
    private let refreshControl = UIRefreshControl()

    private var currentMainView: UIView?
    private var bottomButton: GTTMainButton?
    private var mainActionHeightConstraint: NSLayoutConstraint?

    // MARK: - State

    private var pendingState: DashboardMissionState?

    // MARK: - Init

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupHierarchy()
        setupLayout()
        setupStyle()
        if let state = pendingState {
            applyState(state)
            pendingState = nil
        }
    }

    // MARK: - Public

    func configure(state: DashboardMissionState) {
        if isViewLoaded {
            applyState(state)
        } else {
            pendingState = state
        }
    }

    func endRefreshing() {
        refreshControl.endRefreshing()
    }

    // MARK: - Setup

    private func setupHierarchy() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)
        contentStack.addArrangedSubview(titleLabel)
        contentStack.addArrangedSubview(deadlineLabel)
        contentStack.addArrangedSubview(messageCardView)
        contentStack.addArrangedSubview(mainActionContainer)
        contentStack.addArrangedSubview(bottomButtonContainer)
    }

    private func setupLayout() {
        scrollView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

        contentStack.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(UIEdgeInsets(top: 16, left: 20, bottom: 32, right: 20))
            $0.width.equalTo(scrollView).offset(-40)
        }

        bottomButtonContainer.snp.makeConstraints {
            $0.height.equalTo(52)
        }
    }

    private func setupStyle() {
        view.backgroundColor = .white

        titleLabel.font = GTTFont.dashboardTitle.font
        titleLabel.textColor = GTTColor.textPrimary
        titleLabel.textAlignment = .left

        deadlineLabel.font = GTTFont.bodySecondary.font
        deadlineLabel.textColor = GTTColor.textSecondary
        deadlineLabel.textAlignment = .left

        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = false
        scrollView.refreshControl = refreshControl
        refreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)

        contentStack.axis = .vertical
        contentStack.spacing = 12
        contentStack.setCustomSpacing(4, after: titleLabel)
        contentStack.setCustomSpacing(16, after: mainActionContainer)
    }

    // MARK: - Actions

    @objc private func handleRefresh() {
        onRefreshPulled?()
    }

    // MARK: - State Application

    private func applyState(_ state: DashboardMissionState) {
        titleLabel.text = state.title
        deadlineLabel.text = state.deadline
        messageCardView.configure(state: state.messageCardState)
        updateMainAction(state.mainActionState)
        updateBottomButton(state.bottomButtonState)
    }

    private func updateMainAction(_ mainState: MainActionState) {
        // Optimise: update OngoingMissionCardView in place to avoid map reload
        if case .ongoing(let cardState) = mainState,
           let existingCard = currentMainView as? OngoingMissionCardView {
            existingCard.configure(state: cardState)
            return
        }

        currentMainView?.removeFromSuperview()
        mainActionHeightConstraint?.isActive = false
        mainActionHeightConstraint = nil

        let newView: UIView
        switch mainState {
        case .noMission:
            let v = SetMissionButtonView()
            v.onTap = { [weak self] in self?.onSetMissionTapped?() }
            newView = v

        case .ongoing(let cardState):
            let v = OngoingMissionCardView()
            v.configure(state: cardState)
            v.onRefreshTap = { [weak self] in self?.onRefreshTapped?() }
            newView = v

        case .locationPermissionDenied:
            newView = LocationPermissionRequiredView()

        case .success(let recordDate, let locationName):
            let v = MissionSuccessCardView()
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            v.configure(arrivalTime: formatter.string(from: recordDate), arrivalLocation: locationName)
            newView = v

        case .failed:
            let v = MissionFailCardView()
            v.configure(state: .normal)
            newView = v

        case .failedCommitted:
            let v = MissionFailCardView()
            v.configure(state: .committed)
            newView = v
        }

        mainActionContainer.addSubview(newView)
        newView.snp.makeConstraints { $0.edges.equalToSuperview() }

        let intrinsicHeight = newView.intrinsicContentSize.height
        if intrinsicHeight != UIView.noIntrinsicMetric {
            let c = mainActionContainer.heightAnchor.constraint(equalToConstant: intrinsicHeight)
            c.isActive = true
            mainActionHeightConstraint = c
        }

        currentMainView = newView
    }

    private func updateBottomButton(_ buttonState: BottomButtonState) {
        bottomButton?.removeFromSuperview()
        bottomButton = nil

        switch buttonState {
        case .hidden:
            bottomButtonContainer.isHidden = true

        case .checkIn(let isEnabled):
            bottomButtonContainer.isHidden = false
            let icon: UIImage? = isEnabled ? nil : UIImage(systemName: "lock")
            let style: GTTButtonStyle = isEnabled ? .primary : .secondary
            let btn = GTTMainButton(title: "출근 인증하기", icon: icon, style: style)
            btn.isEnabled = isEnabled
            btn.onTap = { [weak self] in self?.onCheckInTapped?() }
            bottomButtonContainer.addSubview(btn)
            btn.snp.makeConstraints { $0.edges.equalToSuperview() }
            bottomButton = btn

        case .commit:
            bottomButtonContainer.isHidden = false
            let btn = GTTMainButton(title: "다짐하기", style: .primary)
            btn.onTap = { [weak self] in self?.onCommitTapped?() }
            bottomButtonContainer.addSubview(btn)
            btn.snp.makeConstraints { $0.edges.equalToSuperview() }
            bottomButton = btn
        }
    }
}
