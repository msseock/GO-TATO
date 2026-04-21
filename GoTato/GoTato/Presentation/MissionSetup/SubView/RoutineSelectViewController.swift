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
    case start, end, time, wifi, photo

    var icon: String {
        switch self {
        case .start, .end: return "calendar"
        case .time: return "clock"
        case .wifi: return "wifi"
        case .photo: return "camera"
        }
    }

    var text: String {
        switch self {
        case .start:  return "시작하는 날"
        case .end:    return "끝나는 날"
        case .time:   return "도착목표 시간"
        case .wifi:   return "WiFi 인증 추가 (선택)"
        case .photo:  return "사진 인증 추가 (선택)"
        }
    }
}

// MARK: - RoutineSelectViewController

final class RoutineSelectViewController: BaseViewController {

    // MARK: - Callbacks

    var onRoutineConfirmed: ((SelectedLocation, MissionRoutine) -> Void)?
    var onAddWifiRequested: ((SelectedLocation, MissionRoutine) -> Void)?
    var onAddPhotoRequested: ((SelectedLocation, MissionRoutine) -> Void)?

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
    private let wifiTappedSubject = PublishSubject<Void>()
    private let photoTappedSubject = PublishSubject<Void>()

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
    private let wifiCard = DateCard(type: .wifi)
    private let photoCard = DateCard(type: .photo)

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
        view.addSubview(wifiCard)
        view.addSubview(photoCard)
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

        wifiCard.snp.makeConstraints { make in
            make.top.equalTo(timeCard.snp.bottom).offset(12)
            make.leading.trailing.equalToSuperview().inset(24)
        }

        photoCard.snp.makeConstraints { make in
            make.top.equalTo(wifiCard.snp.bottom).offset(12)
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
        wifiCard.onTap = { [weak self] in self?.wifiTappedSubject.onNext(()) }
        photoCard.onTap = { [weak self] in self?.photoTappedSubject.onNext(()) }

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
            ctaTapped: ctaTappedSubject.asObservable(),
            wifiTapped: wifiTappedSubject.asObservable(),
            photoTapped: photoTappedSubject.asObservable()
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

        output.wifiRequested
            .emit(onNext: { [weak self] routine in
                guard let self, let location = self.pendingLocation else { return }
                self.onAddWifiRequested?(location, routine)
            })
            .disposed(by: disposeBag)

        output.photoRequested
            .emit(onNext: { [weak self] routine in
                guard let self, let location = self.pendingLocation else { return }
                self.onAddPhotoRequested?(location, routine)
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
