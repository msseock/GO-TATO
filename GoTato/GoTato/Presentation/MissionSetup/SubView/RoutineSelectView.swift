//
//  RoutineSelectView.swift
//  GoTato
//

import UIKit
import SnapKit

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

// MARK: - RoutineSelectView

final class RoutineSelectView: UIView {

    // MARK: - Callbacks

    /// DatePicker 표시 요청: (현재 날짜, 최소 날짜, 최대 날짜, 선택 완료 핸들러)
    var requestDatePicker: ((Date, Date?, Date?, @escaping (Date) -> Void) -> Void)?
    /// TimePicker 표시 요청: (현재 시각, 선택 완료 핸들러)
    var requestTimePicker: ((Date, @escaping (Date) -> Void) -> Void)?
    var onMissionCreate: ((MissionRoutine) -> Void)?

    // MARK: - State

    private enum SegmentMode { case daily, once }
    private var segmentMode: SegmentMode = .daily

    private var startDate: Date = Calendar.current.startOfDay(for: Date())
    private var endDate: Date = {
        let cal = Calendar.current
        return cal.date(byAdding: .day, value: 31, to: cal.startOfDay(for: Date())) ?? Date()
    }()
    private var singleDate: Date = Calendar.current.startOfDay(for: Date())
    private var selectedTime: Date = {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = 9
        components.minute = 0
        components.second = 0
        return Calendar.current.date(from: components) ?? Date()
    }()

    // MARK: - UI

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

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupHierarchy()
        setupLayout()
        setupView()
        updateDateLabels()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Setup

    private func setupHierarchy() {
        addSubview(titleLabel)
        addSubview(segmentControl)
        addSubview(startCard)
        addSubview(endCard)
        addSubview(singleCard)
        addSubview(timeCard)
        addSubview(ctaButton)
    }

    private func setupLayout() {
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide).offset(32)
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
            make.bottom.equalTo(safeAreaLayoutGuide).inset(24)
            make.leading.trailing.equalToSuperview().inset(24)
            make.height.equalTo(52)
        }
    }

    private func setupView() {
        backgroundColor = GTTColor.white

        titleLabel.text = "출근할 루틴을\n정해볼까요?"
        titleLabel.font = GTTFont.dashboardTitle.font
        titleLabel.textColor = GTTColor.textPrimary
        titleLabel.numberOfLines = 2

        segmentControl.onSelectionChanged = { [weak self] index in
            self?.handleSegmentChange(index: index)
        }

        startCard.onTap = { [weak self] in self?.handleStartCardTap() }
        endCard.onTap = { [weak self] in self?.handleEndCardTap() }
        singleCard.onTap = { [weak self] in self?.handleSingleCardTap() }
        timeCard.onTap = { [weak self] in self?.handleTimeCardTap() }

        ctaButton.onTap = { [weak self] in self?.handleCTATap() }

        singleCard.isHidden = true
    }

    // MARK: - Date Labels

    private func updateDateLabels() {
        startCard.setDate(startDate)
        endCard.setDate(endDate)
        singleCard.setDate(singleDate)
        timeCard.setTime(selectedTime)
    }

    // MARK: - Segment

    private func handleSegmentChange(index: Int) {
        let newMode: SegmentMode = index == 0 ? .daily : .once

        // 날짜 값 인계
        if newMode == .once {
            singleDate = startDate
        } else {
            startDate = singleDate
            endDate = Calendar.current.date(byAdding: .day, value: 31, to: startDate) ?? startDate
        }

        segmentMode = newMode
        updateDateLabels()

        // timeCard 상단 제약 갱신
        if newMode == .once {
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
            self.startCard.isHidden = newMode == .once
            self.endCard.isHidden = newMode == .once
            self.singleCard.isHidden = newMode == .daily
            self.layoutIfNeeded()
        }
    }

    // MARK: - Card Taps

    private func handleStartCardTap() {
        let today = Calendar.current.startOfDay(for: Date())
        requestDatePicker?(startDate, today, nil) { [weak self] selected in
            guard let self else { return }
            self.startDate = selected
            
            let cal = Calendar.current
            let minEnd = cal.date(byAdding: .day, value: 1, to: selected) ?? selected
            let maxEnd = cal.date(byAdding: .month, value: 1, to: selected) ?? selected
            
            // 종료일이 범위를 벗어나면 자동 조정 (최소 1일 후 ~ 최대 1개월 후)
            if self.endDate < minEnd || self.endDate > maxEnd {
                self.endDate = cal.date(byAdding: .day, value: 7, to: selected) ?? selected
            }
            self.updateDateLabels()
        }
    }

    private func handleEndCardTap() {
        let cal = Calendar.current
        let minEnd = cal.date(byAdding: .day, value: 1, to: startDate) ?? startDate
        let maxEnd = cal.date(byAdding: .month, value: 1, to: startDate) ?? startDate
        requestDatePicker?(endDate, minEnd, maxEnd) { [weak self] selected in
            self?.endDate = selected
            self?.updateDateLabels()
        }
    }

    private func handleSingleCardTap() {
        let today = Calendar.current.startOfDay(for: Date())
        requestDatePicker?(singleDate, today, nil) { [weak self] selected in
            self?.singleDate = selected
            self?.updateDateLabels()
        }
    }

    private func handleTimeCardTap() {
        requestTimePicker?(selectedTime) { [weak self] selected in
            self?.selectedTime = selected
            self?.updateDateLabels()
        }
    }

    // MARK: - CTA

    private func handleCTATap() {
        let routine: MissionRoutine
        switch segmentMode {
        case .daily:
            routine = MissionRoutine(mode: .daily, startDate: startDate, endDate: endDate, deadline: selectedTime)
        case .once:
            routine = MissionRoutine(mode: .once, startDate: singleDate, endDate: nil, deadline: selectedTime)
        }
        onMissionCreate?(routine)
    }
}

// MARK: - GTTSegmentControl

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

// MARK: - DateCard (매일매일 모드)

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
