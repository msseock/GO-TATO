//
//  HistoryViewController.swift
//  GoTato
//
//  Created by 석민솔 on 3/24/26.
//

import UIKit
import SnapKit
import RxSwift
import RxCocoa

final class HistoryViewController: BaseViewController {

    // MARK: - ViewModel

    private let viewModel = HistoryViewModel()
    private let disposeBag = DisposeBag()

    // MARK: - Input relays

    private let viewWillAppearRelay  = PublishRelay<Void>()
    private let monthChangedSubject  = PublishSubject<Date>()
    private let dateSelectedSubject  = PublishSubject<Date>()
    private let addMissionSubject    = PublishSubject<Void>()
    private let setMissionSubject    = PublishSubject<Void>()

    // MARK: - Header

    private let headerStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .center
        stack.distribution = .fill
        return stack
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "출근 기록"
        label.font = GTTFont.dashboardTitle.font
        label.textColor = GTTColor.textPrimary
        return label
    }()

    private let addMissionButton: GTTIconButton = {
        let config = UIImage.SymbolConfiguration(pointSize: 15, weight: .heavy)
        return GTTIconButton(
            systemName: "plus",
            symbolConfig: config,
            iconColor: GTTColor.white,
            backgroundColor: GTTColor.brand,
            size: 32
        )
    }()

    // MARK: - Scroll

    private let scrollView    = UIScrollView()
    private let contentStack  = UIStackView()

    // MARK: - 섹션 2: 통계 or 출근 설정

    private let statsCardView        = StatsCardView(attendanceRate: 0, lateCount: 0, savedMinutes: 0)
    private let setMissionButtonView = SetMissionButtonView()

    // MARK: - 섹션 3: 캘린더

    private let calendarSection = CalendarSectionView()

    // MARK: - 섹션 4: 출근 기록

    private let recordSection      = UIStackView()
    private let recordTitleLabel   = UILabel()
    private let recordCardsStack   = UIStackView()

    // MARK: - Lifecycle

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewWillAppearRelay.accept(())
    }

    // MARK: - BaseViewController

    override func configureHierarchy() {
        view.addSubview(scrollView)

        // Header 내부: 타이틀 + 여백 + 버튼
        let spacer = UIView()
        headerStack.addArrangedSubview(titleLabel)
        headerStack.addArrangedSubview(spacer)
        headerStack.addArrangedSubview(addMissionButton)

        // contentStack: Header → 섹션 2 → 3 → 4
        [headerStack, statsCardView, setMissionButtonView, calendarSection, recordSection].forEach {
            contentStack.addArrangedSubview($0)
        }
        scrollView.addSubview(contentStack)

        // 섹션 4 내부: 타이틀 + 카드 스택
        recordSection.addArrangedSubview(recordTitleLabel)
        recordSection.addArrangedSubview(recordCardsStack)
    }

    override func configureLayout() {
        scrollView.snp.makeConstraints {
            $0.edges.equalTo(view.safeAreaLayoutGuide)
        }

        contentStack.snp.makeConstraints {
            $0.top.bottom.equalToSuperview().inset(20)
            $0.leading.trailing.equalToSuperview().inset(20)
            $0.width.equalTo(scrollView).offset(-40)
        }
    }

    override func configureView() {
        view.backgroundColor = GTTColor.bgPrimary

        addMissionButton.onTap = { [weak self] in
            self?.addMissionSubject.onNext(())
        }
        setMissionButtonView.onTap = { [weak self] in
            self?.setMissionSubject.onNext(())
        }

        // contentStack
        contentStack.axis      = .vertical
        contentStack.spacing   = 20
        contentStack.setCustomSpacing(24, after: calendarSection)

        // 섹션 4
        recordSection.axis    = .vertical
        recordSection.spacing = 12

        recordTitleLabel.font      = GTTFont.subHeading.font
        recordTitleLabel.textColor = GTTColor.textPrimary

        recordCardsStack.axis    = .vertical
        recordCardsStack.spacing = 12

        // 캘린더 콜백
        calendarSection.onMonthChanged = { [weak self] date in
            self?.monthChangedSubject.onNext(date)
        }
        calendarSection.onDateSelected = { [weak self] date in
            self?.dateSelectedSubject.onNext(date)
        }
    }

    // MARK: - Binding

    override func bind() {
        let input = HistoryViewModel.Input(
            viewWillAppear:      viewWillAppearRelay.asObservable(),
            monthChanged:        monthChangedSubject.asObservable(),
            dateSelected:        dateSelectedSubject.asObservable(),
            addMissionTap:       addMissionSubject.asObservable(),
            setMissionButtonTap: setMissionSubject.asObservable()
        )
        let output = viewModel.transform(input: input)

        // 미션 유무 → 섹션 2 뷰 전환 및 추가 버튼 표시 여부
        output.hasMission
            .drive(onNext: { [weak self] has in
                guard let self else { return }
                self.statsCardView.isHidden        = !has
                self.setMissionButtonView.isHidden = has
                self.addMissionButton.isHidden     = !has
            })
            .disposed(by: disposeBag)

        // 통계 갱신
        output.stats
            .drive(onNext: { [weak self] stats in
                self?.statsCardView.update(
                    attendanceRate: stats.rate,
                    lateCount:      stats.lateCount,
                    savedMinutes:   stats.savedMinutes
                )
            })
            .disposed(by: disposeBag)

        // 캘린더 상태 맵 갱신
        output.calendarStatusMap
            .drive(onNext: { [weak self] statusMap in
                self?.calendarSection.configure(with: statusMap)
            })
            .disposed(by: disposeBag)

        // 출근 기록 섹션 갱신
        output.recordsData
            .drive(onNext: { [weak self] (title, items) in
                guard let self else { return }
                self.recordTitleLabel.text = title

                self.recordCardsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
                for (missionID, state) in items {
                    let card = AttendanceRecordCardView()
                    card.configure(state: state)
                    if let id = missionID {
                        card.onDetailTapped = { [weak self] in
                            self?.navigateToMissionDetail(missionID: id)
                        }
                    }
                    self.recordCardsStack.addArrangedSubview(card)
                }
            })
            .disposed(by: disposeBag)

        // MissionSetupViewController present
        output.navigateToMissionSetup
            .emit(onNext: { [weak self] in
                let vc = MissionSetupViewController(isFromOnboarding: false)
                vc.modalPresentationStyle = .pageSheet
                self?.present(vc, animated: true)
            })
            .disposed(by: disposeBag)
    }

    // MARK: - Navigation

    private func navigateToMissionDetail(missionID: UUID) {
        let detailVC = MissionDetailViewController(missionID: missionID)
        detailVC.delegate = self
        navigationController?.pushViewController(detailVC, animated: true)
    }
}

// MARK: - MissionDetailDelegate

extension HistoryViewController: MissionDetailDelegate {
    func missionDetailDidUpdate() {
        viewWillAppearRelay.accept(())
    }

    func missionDetailDidDelete() {
        viewWillAppearRelay.accept(())
    }
}
