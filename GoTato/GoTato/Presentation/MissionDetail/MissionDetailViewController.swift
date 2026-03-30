//
//  MissionDetailViewController.swift
//  GoTato
//

import UIKit
import SnapKit
import RxSwift
import RxCocoa
import CoreData

// MARK: - Delegate

protocol MissionDetailDelegate: AnyObject {
    func missionDetailDidUpdate()
    func missionDetailDidDelete()
}

// MARK: - MissionDetailViewController

final class MissionDetailViewController: BaseViewController {

    // MARK: - Properties

    weak var delegate: MissionDetailDelegate?
    private let viewModel: MissionDetailViewModel
    private let disposeBag = DisposeBag()
    private var latestInfo: MissionDetailState?

    // Input relays
    private let viewWillAppearRelay  = PublishRelay<Void>()
    private let editTitleRelay       = PublishRelay<String>()
    private let editLocationRelay    = PublishRelay<String>()
    private let editDeadlineRelay    = PublishRelay<Date>()
    private let extendEndDateRelay   = PublishRelay<Date>()
    private let deleteTappedRelay    = PublishRelay<Void>()

    // MARK: - UI

    private let scrollView    = UIScrollView()
    private let contentStack  = UIStackView()
    private let infoSection   = MissionInfoSectionView()
    private let statsSection  = MissionStatsSectionView()
    private let calendarSection = MissionCalendarSectionView()
    private let listSection   = AttendanceListSectionView()
    private let extendButton  = GTTMainButton(title: "미션 기간 연장하기", style: .primary)

    // MARK: - Init

    init(missionID: UUID) {
        self.viewModel = MissionDetailViewModel(missionID: missionID)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - BaseViewController

    override func configureHierarchy() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)
        [infoSection, statsSection, calendarSection, listSection, extendButton].forEach {
            contentStack.addArrangedSubview($0)
        }
    }

    override func configureLayout() {
        scrollView.snp.makeConstraints { $0.edges.equalToSuperview() }
        contentStack.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(UIEdgeInsets(top: 16, left: 20, bottom: 32, right: 20))
            $0.width.equalTo(scrollView).offset(-40)
        }
        extendButton.snp.makeConstraints { $0.height.equalTo(52) }
    }

    override func configureView() {
        view.backgroundColor = GTTColor.bgPrimary
        contentStack.axis    = .vertical
        contentStack.spacing = 16

        calendarSection.isHidden = true
        extendButton.isHidden    = true

        navigationItem.title = "미션 상세"
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "ellipsis"),
            style: .plain,
            target: nil,
            action: nil
        )
        navigationItem.rightBarButtonItem?.tintColor = GTTColor.textPrimary

        extendButton.addTarget(self, action: #selector(didTapExtend), for: .touchUpInside)
    }

    override func bind() {
        let input = MissionDetailViewModel.Input(
            viewWillAppear:   viewWillAppearRelay.asObservable(),
            editTitle:        editTitleRelay.asObservable(),
            editLocationName: editLocationRelay.asObservable(),
            editDeadline:     editDeadlineRelay.asObservable(),
            extendEndDate:    extendEndDateRelay.asObservable(),
            deleteTapped:     deleteTappedRelay.asObservable()
        )

        let output = viewModel.transform(input: input)

        output.missionInfo
            .drive(onNext: { [weak self] info in
                guard let self else { return }
                self.latestInfo = info
                self.infoSection.configure(
                    title:        info.title,
                    locationName: info.locationName,
                    startDate:    info.startDate,
                    endDate:      info.endDate,
                    deadline:     info.deadline
                )
                self.statsSection.configure(
                    successCount:   info.successCount,
                    lateCount:      info.lateCount,
                    failCount:      info.failCount,
                    totalCompleted: info.totalCompleted
                )
                self.calendarSection.isHidden = !info.isMultiDay
            })
            .disposed(by: disposeBag)

        output.calendarStatuses
            .drive(onNext: { [weak self] statuses in
                guard let self, let info = self.latestInfo else { return }
                self.calendarSection.configure(
                    startDate: info.startDate,
                    endDate:   info.endDate,
                    statuses:  statuses
                )
            })
            .disposed(by: disposeBag)

        output.attendanceList
            .drive(onNext: { [weak self] items in
                self?.listSection.configure(items: items)
            })
            .disposed(by: disposeBag)

        output.showExtendButton
            .drive(onNext: { [weak self] show in
                self?.extendButton.isHidden = !show
            })
            .disposed(by: disposeBag)

        output.isMissionEnded
            .drive(onNext: { [weak self] ended in
                self?.updateMenu(isMissionEnded: ended)
            })
            .disposed(by: disposeBag)

        output.editResult
            .emit(onNext: { [weak self] result in
                guard let self else { return }
                switch result {
                case .success:
                    self.delegate?.missionDetailDidUpdate()
                case .failure(let error):
                    self.showErrorAlert(message: error.localizedDescription)
                }
            })
            .disposed(by: disposeBag)

        output.extendResult
            .emit(onNext: { [weak self] result in
                guard let self else { return }
                switch result {
                case .success:
                    self.delegate?.missionDetailDidUpdate()
                case .failure(let error):
                    if case RepositoryError.tooManyActiveMissions = error {
                        self.showErrorAlert(message: "동시 진행 가능한 미션은 최대 10개입니다.")
                    } else {
                        self.showErrorAlert(message: error.localizedDescription)
                    }
                }
            })
            .disposed(by: disposeBag)

        output.deleteResult
            .emit(onNext: { [weak self] result in
                guard let self else { return }
                switch result {
                case .success:
                    self.delegate?.missionDetailDidDelete()
                    self.navigationController?.popViewController(animated: true)
                case .failure(let error):
                    self.showErrorAlert(message: error.localizedDescription)
                }
            })
            .disposed(by: disposeBag)
    }

    // MARK: - Lifecycle

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewWillAppearRelay.accept(())
    }

    // MARK: - Menu

    private func updateMenu(isMissionEnded: Bool) {
        var actions: [UIAction] = []

        actions.append(UIAction(title: "미션 이름 수정", image: UIImage(systemName: "pencil")) { [weak self] _ in
            self?.presentEditTitleSheet()
        })

        if !isMissionEnded {
            if latestInfo?.locationName != nil {
                actions.append(UIAction(title: "위치 이름 수정", image: UIImage(systemName: "mappin")) { [weak self] _ in
                    self?.presentEditLocationNameSheet()
                })
            }
            actions.append(UIAction(title: "마감 시각 수정", image: UIImage(systemName: "clock")) { [weak self] _ in
                self?.presentEditDeadlineSheet()
            })
        }

        actions.append(UIAction(
            title: "미션 삭제",
            image: UIImage(systemName: "trash"),
            attributes: .destructive
        ) { [weak self] _ in
            self?.showDeleteConfirmation()
        })

        navigationItem.rightBarButtonItem?.menu = UIMenu(title: "", children: actions)
    }

    // MARK: - Edit Sheets

    private func presentEditTitleSheet() {
        guard let info = latestInfo else { return }
        let allTitles = fetchAllMissionTitles()
        let forbidden = allTitles.filter { $0 != info.title }
        let sheet = EditTitleSheetViewController(currentTitle: info.title, forbiddenTitles: forbidden)
        sheet.onConfirm = { [weak self] newTitle in self?.editTitleRelay.accept(newTitle) }
        presentSheet(sheet)
    }

    private func presentEditLocationNameSheet() {
        guard let info = latestInfo, let name = info.locationName else { return }
        let sheet = EditLocationNameSheetViewController(currentName: name)
        sheet.onConfirm = { [weak self] newName in self?.editLocationRelay.accept(newName) }
        presentSheet(sheet)
    }

    private func presentEditDeadlineSheet() {
        guard let info = latestInfo else { return }
        let sheet = GTTTimePickerSheetViewController(
            title: "마감 시각 수정",
            initialDate: info.deadline,
            showCancel: true
        )
        sheet.onConfirm = { [weak self] newDate in self?.editDeadlineRelay.accept(newDate) }
        presentSheet(sheet)
    }

    @objc private func didTapExtend() {
        guard let info = latestInfo else { return }
        let sheet = ExtendDatePickerSheet(currentEndDate: info.endDate)
        sheet.onConfirm = { [weak self] newEnd in self?.extendEndDateRelay.accept(newEnd) }
        presentSheet(sheet)
    }

    private func showDeleteConfirmation() {
        let alert = UIAlertController(
            title: "미션을 삭제하시겠습니까?",
            message: "출근 기록이 모두 삭제됩니다. 이 작업은 되돌릴 수 없습니다.",
            preferredStyle: .actionSheet
        )
        alert.addAction(UIAlertAction(title: "삭제", style: .destructive) { [weak self] _ in
            self?.deleteTappedRelay.accept(())
        })
        alert.addAction(UIAlertAction(title: "취소", style: .cancel))
        present(alert, animated: true)
    }

    // MARK: - Helpers

    private func presentSheet(_ vc: UIViewController) {
        vc.modalPresentationStyle = .pageSheet
        if let sheet = vc.sheetPresentationController {
            sheet.detents = [.medium()]
            sheet.prefersGrabberVisible = true
        }
        present(vc, animated: true)
    }

    private func fetchAllMissionTitles() -> [String] {
        let request = Mission.fetchRequest()
        return (try? CoreDataStack.shared.viewContext.fetch(request))?.compactMap { $0.title } ?? []
    }

    private func showErrorAlert(message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
    }
}
