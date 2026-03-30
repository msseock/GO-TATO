//
//  RoutineSelectViewController.swift
//  GoTato
//

import UIKit
import SnapKit
import RxSwift
import RxCocoa

// MARK: - MissionRoutine

struct MissionRoutine {
    enum Mode { case daily, once }
    let mode: Mode
    let startDate: Date
    let endDate: Date?   // mode == .daily 일 때만 유효
    let deadline: Date
}

// MARK: - DateCardType

enum DateCardType {
    case start, end, single, time

    var icon: String {
        switch self {
        case .start, .end, .single: return "calendar"
        case .time: return "clock"
        }
    }

    var text: String {
        switch self {
        case .start:  return "시작하는 날"
        case .end:    return "끝나는 날"
        case .single: return "날짜"
        case .time:   return "도착목표 시간"
        }
    }
}

// MARK: - RoutineSelectViewController

final class RoutineSelectViewController: BaseViewController {

    // MARK: - Callbacks

    var onRoutineConfirmed: ((SelectedLocation, MissionRoutine) -> Void)?

    // location 화면에서 전달받은 선택 위치
    var pendingLocation: SelectedLocation?

    // MARK: - Properties

    private let viewModel = RoutineSelectViewModel()
    private let disposeBag = DisposeBag()

    // Inputs (Subjects for ViewModel)
    private let segmentSubject = PublishSubject<Int>()
    private let startDateSubject = PublishSubject<Date>()
    private let endDateSubject = PublishSubject<Date>()
    private let singleDateSubject = PublishSubject<Date>()
    private let timeSubject = PublishSubject<Date>()
    private let ctaTappedSubject = PublishSubject<Void>()

    // Current State for Picker bounds
    private var currentStartDate: Date = Date()
    private var currentEndDate: Date = Date()
    private var currentSingleDate: Date = Date()
    private var currentTime: Date = Date()

    // MARK: - UI Components

    private let titleLabel = UILabel()
    private let segmentControl = GTTSegmentControl(titles: ["매일매일", "하루만"])

    // 매일매일 카드
    private let startCard = DateCard(type: .start)
    private let endCard = DateCard(type: .end)

    // 하루만 카드
    private let singleCard = DateCard(type: .single)

    // 시간 카드
    private let timeCard = DateCard(type: .time)

    private let ctaButton = GTTMainButton(
        title: "미션 만들기",
        icon: UIImage(systemName: "checkmark"),
        style: .primary
    )

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        bindViewModel()
    }

    // MARK: - BaseViewController Overrides

    override func configureHierarchy() {
        view.addSubview(titleLabel)
        view.addSubview(segmentControl)
        view.addSubview(startCard)
        view.addSubview(endCard)
        view.addSubview(singleCard)
        view.addSubview(timeCard)
        view.addSubview(ctaButton)
    }

    override func configureLayout() {
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(32)
            make.leading.trailing.equalToSuperview().inset(24)
        }

        segmentControl.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(40)
            make.leading.trailing.equalToSuperview().inset(24)
            make.height.equalTo(60)
        }

        startCard.snp.makeConstraints { make in
            make.top.equalTo(segmentControl.snp.bottom).offset(16)
            make.leading.trailing.equalToSuperview().inset(24)
        }

        endCard.snp.makeConstraints { make in
            make.top.equalTo(startCard.snp.bottom).offset(12)
            make.leading.trailing.equalToSuperview().inset(24)
        }

        singleCard.snp.makeConstraints { make in
            make.top.equalTo(segmentControl.snp.bottom).offset(16)
            make.leading.trailing.equalToSuperview().inset(24)
        }

        // 초기(매일매일 모드): endCard 아래에 위치
        timeCard.snp.makeConstraints { make in
            make.top.equalTo(endCard.snp.bottom).offset(12)
            make.leading.trailing.equalToSuperview().inset(24)
        }

        ctaButton.snp.makeConstraints { make in
            make.bottom.equalTo(view.safeAreaLayoutGuide).inset(24)
            make.leading.trailing.equalToSuperview().inset(24)
            make.height.equalTo(52)
        }
    }

    override func configureView() {
        view.backgroundColor = GTTColor.white

        titleLabel.text = "출근할 루틴을\n정해볼까요?"
        titleLabel.font = GTTFont.dashboardTitle.font
        titleLabel.textColor = GTTColor.textPrimary
        titleLabel.numberOfLines = 2

        segmentControl.onSelectionChanged = { [weak self] index in
            self?.segmentSubject.onNext(index)
        }

        startCard.onTap = { [weak self] in self?.handleStartCardTap() }
        endCard.onTap = { [weak self] in self?.handleEndCardTap() }
        singleCard.onTap = { [weak self] in self?.handleSingleCardTap() }
        timeCard.onTap = { [weak self] in self?.handleTimeCardTap() }

        ctaButton.onTap = { [weak self] in self?.ctaTappedSubject.onNext(()) }

        singleCard.isHidden = true
    }

    // MARK: - Binding

    private func bindViewModel() {
        let input = RoutineSelectViewModel.Input(
            segmentSelected: segmentSubject.asObservable(),
            startDateSelected: startDateSubject.asObservable(),
            endDateSelected: endDateSubject.asObservable(),
            singleDateSelected: singleDateSubject.asObservable(),
            timeSelected: timeSubject.asObservable(),
            ctaTapped: ctaTappedSubject.asObservable()
        )

        let output = viewModel.transform(input: input)

        output.mode
            .drive(onNext: { [weak self] mode in
                self?.updateUIMode(mode)
            })
            .disposed(by: disposeBag)

        output.startDate
            .drive(onNext: { [weak self] date in
                self?.currentStartDate = date
                self?.startCard.setDate(date)
            })
            .disposed(by: disposeBag)

        output.endDate
            .drive(onNext: { [weak self] date in
                self?.currentEndDate = date
                self?.endCard.setDate(date)
            })
            .disposed(by: disposeBag)

        output.singleDate
            .drive(onNext: { [weak self] date in
                self?.currentSingleDate = date
                self?.singleCard.setDate(date)
            })
            .disposed(by: disposeBag)

        output.selectedTime
            .drive(onNext: { [weak self] time in
                self?.currentTime = time
                self?.timeCard.setTime(time)
            })
            .disposed(by: disposeBag)

        output.routineConfirmed
            .emit(onNext: { [weak self] routine in
                guard let self, let location = self.pendingLocation else { return }
                self.onRoutineConfirmed?(location, routine)
            })
            .disposed(by: disposeBag)
    }

    private func updateUIMode(_ mode: SegmentMode) {
        if mode == .once {
            timeCard.snp.remakeConstraints { make in
                make.top.equalTo(singleCard.snp.bottom).offset(12)
                make.leading.trailing.equalToSuperview().inset(24)
            }
        } else {
            timeCard.snp.remakeConstraints { make in
                make.top.equalTo(endCard.snp.bottom).offset(12)
                make.leading.trailing.equalToSuperview().inset(24)
            }
        }

        UIView.animate(withDuration: 0.2) {
            self.startCard.isHidden = mode == .once
            self.endCard.isHidden = mode == .once
            self.singleCard.isHidden = mode == .daily
            self.view.layoutIfNeeded()
        }
    }

    // MARK: - Picker Actions

    private func handleStartCardTap() {
        let today = Calendar.current.startOfDay(for: Date())
        let sheet = DatePickerSheetViewController(initial: currentStartDate, minDate: today, maxDate: nil)
        sheet.onConfirm = { [weak self] selected in
            self?.startDateSubject.onNext(selected)
        }
        present(sheet, animated: true)
    }

    private func handleEndCardTap() {
        let cal = Calendar.current
        let minEnd = cal.date(byAdding: .day, value: 1, to: currentStartDate) ?? currentStartDate
        let maxEnd = cal.date(byAdding: .month, value: 1, to: currentStartDate) ?? currentStartDate
        let sheet = DatePickerSheetViewController(initial: currentEndDate, minDate: minEnd, maxDate: maxEnd)
        sheet.onConfirm = { [weak self] selected in
            self?.endDateSubject.onNext(selected)
        }
        present(sheet, animated: true)
    }

    private func handleSingleCardTap() {
        let today = Calendar.current.startOfDay(for: Date())
        let sheet = DatePickerSheetViewController(initial: currentSingleDate, minDate: today, maxDate: nil)
        sheet.onConfirm = { [weak self] selected in
            self?.singleDateSubject.onNext(selected)
        }
        present(sheet, animated: true)
    }

    private func handleTimeCardTap() {
        let sheet = GTTTimePickerSheetViewController(initialDate: currentTime, minuteInterval: 5)
        sheet.onConfirm = { [weak self] selected in
            self?.timeSubject.onNext(selected)
        }
        present(sheet, animated: true)
    }
}

// MARK: - Custom Views

private final class GTTSegmentControl: UIView {

    var onSelectionChanged: ((Int) -> Void)?

    private let background = UIView()
    private let indicator = UIView()
    private var buttons: [UIButton] = []
    private var indicatorLeadingConstraint: Constraint?
    private var selectedIndex = 0
    private let titles: [String]

    init(titles: [String]) {
        self.titles = titles
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        backgroundColor = GTTColor.surface
        layer.cornerRadius = 30

        addSubview(indicator)
        indicator.backgroundColor = GTTColor.brand
        indicator.layer.cornerRadius = 26

        for (i, title) in titles.enumerated() {
            let btn = UIButton()
            btn.setTitle(title, for: .normal)
            btn.tag = i
            btn.titleLabel?.font = GTTFont.segmentLabel.font
            btn.addTarget(self, action: #selector(didTapSegment(_:)), for: .touchUpInside)
            buttons.append(btn)
            addSubview(btn)
        }

        buttons.first?.setTitleColor(GTTColor.white, for: .normal)
        buttons.dropFirst().forEach { $0.setTitleColor(GTTColor.textQuiet, for: .normal) }

        setupConstraints()
    }

    private func setupConstraints() {
        let padding: CGFloat = 4
        let count = CGFloat(titles.count)

        indicator.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview().inset(padding)
            make.width.equalToSuperview().multipliedBy(1.0 / count).offset(-padding)
            indicatorLeadingConstraint = make.leading.equalToSuperview().offset(padding).constraint
        }

        for (i, btn) in buttons.enumerated() {
            btn.snp.makeConstraints { make in
                make.top.bottom.equalToSuperview().inset(padding)
                make.width.equalToSuperview().multipliedBy(1.0 / count)
                if i == 0 {
                    make.leading.equalToSuperview()
                } else {
                    make.leading.equalTo(buttons[i - 1].snp.trailing)
                }
            }
        }
    }

    @objc private func didTapSegment(_ sender: UIButton) {
        let index = sender.tag
        guard index != selectedIndex else { return }
        selectedIndex = index

        let segmentWidth = bounds.width / CGFloat(titles.count)
        let targetLeading: CGFloat = index == 0 ? 4 : segmentWidth + 4

        UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseInOut) {
            self.indicatorLeadingConstraint?.update(offset: targetLeading)
            self.layoutIfNeeded()
        }

        buttons.enumerated().forEach { i, btn in
            btn.setTitleColor(i == index ? GTTColor.white : GTTColor.textQuiet, for: .normal)
        }

        onSelectionChanged?(index)
    }
}

private final class DateCard: UIView {

    var onTap: (() -> Void)?
    private let dateLabel = UILabel()
    private let cardType: DateCardType

    init(type: DateCardType) {
        self.cardType = type
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        backgroundColor = GTTColor.white
        layer.cornerRadius = 16
        layer.borderColor = GTTColor.divider.cgColor
        layer.borderWidth = 1.5

        let icon = UIImageView(image: UIImage(systemName: cardType.icon))
        icon.tintColor = GTTColor.brand
        icon.contentMode = .scaleAspectFit

        let cardLabelView = UILabel()
        cardLabelView.text = cardType.text
        cardLabelView.font = GTTFont.calendarDay.font
        cardLabelView.textColor = GTTColor.textSecondary

        let labelRow = UIStackView(arrangedSubviews: [icon, cardLabelView])
        labelRow.axis = .horizontal
        labelRow.spacing = 6
        labelRow.alignment = .center

        dateLabel.font = GTTFont.subHeading.font
        dateLabel.textColor = GTTColor.textPrimary

        let infoStack = UIStackView(arrangedSubviews: [labelRow, dateLabel])
        infoStack.axis = .vertical
        infoStack.spacing = 4

        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor = GTTColor.textMuted
        chevron.contentMode = .scaleAspectFit

        addSubview(infoStack)
        addSubview(chevron)

        icon.snp.makeConstraints { make in make.size.equalTo(13) }

        infoStack.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.top.bottom.equalToSuperview().inset(16)
            make.trailing.lessThanOrEqualTo(chevron.snp.leading).offset(-8)
        }

        chevron.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(20)
            make.centerY.equalToSuperview()
            make.size.equalTo(18)
        }

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(tapped))
        addGestureRecognizer(tapGesture)
    }

    func setDate(_ date: Date) {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy년 M월 d일"
        dateLabel.text = formatter.string(from: date)
    }

    func setTime(_ date: Date) {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "a h:mm"
        dateLabel.text = formatter.string(from: date)
    }

    @objc private func tapped() { onTap?() }
}

// MARK: - Picker View Controllers

private final class DatePickerSheetViewController: UIViewController {

    var onConfirm: ((Date) -> Void)?

    private let datePicker = UIDatePicker()
    private let confirmButton = GTTMainButton(title: "확인", icon: UIImage(systemName: "checkmark"), style: .primary)

    init(initial: Date, minDate: Date?, maxDate: Date?) {
        super.init(nibName: nil, bundle: nil)
        datePicker.date = initial
        datePicker.minimumDate = minDate
        datePicker.maximumDate = maxDate
        datePicker.datePickerMode = .date
        datePicker.preferredDatePickerStyle = .inline
        datePicker.locale = Locale(identifier: "ko_KR")

        modalPresentationStyle = .pageSheet
        if let sheet = sheetPresentationController {
            sheet.detents = [.medium()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 20
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = GTTColor.white

        view.addSubview(datePicker)
        view.addSubview(confirmButton)

        datePicker.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(8)
            make.leading.trailing.equalToSuperview().inset(16)
        }

        confirmButton.snp.makeConstraints { make in
            make.top.equalTo(datePicker.snp.bottom).offset(16)
            make.leading.trailing.equalToSuperview().inset(24)
            make.height.equalTo(52)
        }

        confirmButton.onTap = { [weak self] in
            guard let self else { return }
            self.onConfirm?(self.datePicker.date)
            self.dismiss(animated: true)
        }
    }
}
