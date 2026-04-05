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
    let startDate: Date
    let endDate: Date
    let selectedDays: Set<Int>   // 1=일, 2=월, 3=화, 4=수, 5=목, 6=금, 7=토
    let deadline: Date
}

// MARK: - DateCardType

enum DateCardType {
    case start, end, time

    var icon: String {
        switch self {
        case .start, .end: return "calendar"
        case .time: return "clock"
        }
    }

    var text: String {
        switch self {
        case .start:  return "시작하는 날"
        case .end:    return "끝나는 날"
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
    private let startDateSubject = PublishSubject<Date>()
    private let endDateSubject = PublishSubject<Date>()
    private let dayToggledSubject = PublishSubject<Int>()
    private let allDaysToggledSubject = PublishSubject<Void>()
    private let timeSubject = PublishSubject<Date>()
    private let ctaTappedSubject = PublishSubject<Void>()

    // Current State for Picker bounds
    private var currentStartDate: Date = Date()
    private var currentEndDate: Date = Date()
    private var currentTime: Date = Date()

    // MARK: - UI Components

    private let titleLabel = UILabel()

    private let startCard = DateCard(type: .start)
    private let endCard = DateCard(type: .end)

    private let daySelector = DaySelector()

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
        view.addSubview(startCard)
        view.addSubview(endCard)
        view.addSubview(daySelector)
        view.addSubview(timeCard)
        view.addSubview(ctaButton)
    }

    override func configureLayout() {
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(32)
            make.leading.trailing.equalToSuperview().inset(24)
        }

        startCard.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(40)
            make.leading.trailing.equalToSuperview().inset(24)
        }

        endCard.snp.makeConstraints { make in
            make.top.equalTo(startCard.snp.bottom).offset(12)
            make.leading.trailing.equalToSuperview().inset(24)
        }

        daySelector.snp.makeConstraints { make in
            make.top.equalTo(endCard.snp.bottom).offset(16)
            make.leading.trailing.equalToSuperview().inset(24)
        }

        timeCard.snp.makeConstraints { make in
            make.top.equalTo(daySelector.snp.bottom).offset(12)
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

        startCard.onTap = { [weak self] in self?.handleStartCardTap() }
        endCard.onTap = { [weak self] in self?.handleEndCardTap() }
        timeCard.onTap = { [weak self] in self?.handleTimeCardTap() }

        daySelector.onDayToggled = { [weak self] day in
            self?.dayToggledSubject.onNext(day)
        }
        daySelector.onAllToggled = { [weak self] in
            self?.allDaysToggledSubject.onNext(())
        }

        ctaButton.onTap = { [weak self] in self?.ctaTappedSubject.onNext(()) }
    }

    // MARK: - Binding

    private func bindViewModel() {
        let input = RoutineSelectViewModel.Input(
            startDateSelected: startDateSubject.asObservable(),
            endDateSelected: endDateSubject.asObservable(),
            dayToggled: dayToggledSubject.asObservable(),
            allDaysToggled: allDaysToggledSubject.asObservable(),
            timeSelected: timeSubject.asObservable(),
            ctaTapped: ctaTappedSubject.asObservable()
        )

        let output = viewModel.transform(input: input)

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

        output.selectedTime
            .drive(onNext: { [weak self] time in
                self?.currentTime = time
                self?.timeCard.setTime(time)
            })
            .disposed(by: disposeBag)

        output.showDaySelector
            .drive(onNext: { [weak self] show in
                guard let self else { return }
                self.daySelector.isHidden = !show
                self.timeCard.snp.remakeConstraints { make in
                    if show {
                        make.top.equalTo(self.daySelector.snp.bottom).offset(12)
                    } else {
                        make.top.equalTo(self.endCard.snp.bottom).offset(12)
                    }
                    make.leading.trailing.equalToSuperview().inset(24)
                }
                UIView.animate(withDuration: 0.2) {
                    self.view.layoutIfNeeded()
                }
            })
            .disposed(by: disposeBag)

        output.availableDays
            .drive(onNext: { [weak self] days in
                self?.daySelector.updateAvailableDays(days)
            })
            .disposed(by: disposeBag)

        output.selectedDays
            .drive(onNext: { [weak self] days in
                self?.daySelector.updateSelectedDays(days)
            })
            .disposed(by: disposeBag)

        output.isCtaEnabled
            .drive(onNext: { [weak self] enabled in
                self?.ctaButton.isEnabled = enabled
            })
            .disposed(by: disposeBag)

        output.routineConfirmed
            .emit(onNext: { [weak self] routine in
                guard let self, let location = self.pendingLocation else { return }
                self.onRoutineConfirmed?(location, routine)
            })
            .disposed(by: disposeBag)
    }

    // MARK: - Picker Actions

    private func handleStartCardTap() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let maxStart = cal.date(byAdding: .month, value: -1, to: GTTDateService.shared.historyMaxDate) ?? GTTDateService.shared.historyMaxDate
        
        let sheet = DatePickerSheetViewController(initial: currentStartDate, minDate: today, maxDate: maxStart)
        sheet.onConfirm = { [weak self] selected in
            self?.startDateSubject.onNext(selected)
        }
        present(sheet, animated: true)
    }

    private func handleEndCardTap() {
        let cal = Calendar.current
        let minEnd = currentStartDate
        let maxEnd = cal.date(byAdding: .month, value: 1, to: currentStartDate) ?? currentStartDate
        let sheet = DatePickerSheetViewController(initial: currentEndDate, minDate: minEnd, maxDate: maxEnd)
        sheet.onConfirm = { [weak self] selected in
            self?.endDateSubject.onNext(selected)
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

// MARK: - DaySelector

private final class DaySelector: UIView {

    var onDayToggled: ((Int) -> Void)?
    var onAllToggled: (() -> Void)?

    // 일=1, 월=2, 화=3, 수=4, 목=5, 금=6, 토=7
    private let dayLabels = ["일", "월", "화", "수", "목", "금", "토"]
    private let dayValues = [1, 2, 3, 4, 5, 6, 7]

    private var dayButtons: [UIButton] = []
    private let allToggle = UISwitch()
    private let allLabel = UILabel()

    private var availableDays: Set<Int> = Set(1...7)
    private var selectedDays: Set<Int> = Set(1...7)

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        // "매일" 토글
        allLabel.text = "매일"
        allLabel.font = GTTFont.calendarDay.font
        allLabel.textColor = GTTColor.textPrimary

        allToggle.onTintColor = GTTColor.brand
        allToggle.isOn = true
        allToggle.addTarget(self, action: #selector(didToggleAll), for: .valueChanged)

        let toggleRow = UIStackView(arrangedSubviews: [allLabel, allToggle])
        toggleRow.axis = .horizontal
        toggleRow.alignment = .center
        toggleRow.spacing = 8
        addSubview(toggleRow)

        // 요일 버튼 생성
        let buttonStack = UIStackView()
        buttonStack.axis = .horizontal
        buttonStack.distribution = .fillEqually
        buttonStack.spacing = 6

        for (i, label) in dayLabels.enumerated() {
            let btn = UIButton()
            btn.setTitle(label, for: .normal)
            btn.titleLabel?.font = GTTFont.calendarDay.font
            btn.layer.cornerRadius = 20
            btn.layer.borderWidth = 1.5
            btn.tag = dayValues[i]
            btn.addTarget(self, action: #selector(didTapDay(_:)), for: .touchUpInside)
            dayButtons.append(btn)
            buttonStack.addArrangedSubview(btn)
        }

        addSubview(buttonStack)

        toggleRow.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.equalToSuperview()
        }

        buttonStack.snp.makeConstraints { make in
            make.top.equalTo(toggleRow.snp.bottom).offset(10)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(40)
            make.bottom.equalToSuperview()
        }

        applyStyles()
    }

    func updateAvailableDays(_ days: Set<Int>) {
        availableDays = days
        applyStyles()
    }

    func updateSelectedDays(_ days: Set<Int>) {
        selectedDays = days
        applyStyles()
    }

    private func applyStyles() {
        let allAvailableSelected = availableDays.isSubset(of: selectedDays) && !availableDays.isEmpty
        allToggle.setOn(allAvailableSelected, animated: true)

        for btn in dayButtons {
            let day = btn.tag
            let available = availableDays.contains(day)
            let selected = selectedDays.contains(day)

            btn.isEnabled = available

            if !available {
                btn.backgroundColor = GTTColor.surface
                btn.setTitleColor(GTTColor.textMuted, for: .normal)
                btn.layer.borderColor = UIColor.clear.cgColor
            } else if selected {
                btn.backgroundColor = GTTColor.brand
                btn.setTitleColor(GTTColor.white, for: .normal)
                btn.layer.borderColor = GTTColor.brand.cgColor
            } else {
                btn.backgroundColor = GTTColor.white
                btn.setTitleColor(GTTColor.textPrimary, for: .normal)
                btn.layer.borderColor = GTTColor.divider.cgColor
            }
        }
    }

    @objc private func didTapDay(_ sender: UIButton) {
        onDayToggled?(sender.tag)
    }

    @objc private func didToggleAll() {
        onAllToggled?()
    }
}

// MARK: - DateCard

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
