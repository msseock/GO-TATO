//
//  DaySelector.swift
//  GoTato
//

import UIKit
import SnapKit

final class DaySelector: UIView {

    var onDayToggled: ((Int) -> Void)?
    var onAllToggled: (() -> Void)?

    // 일=1, 월=2, 화=3, 수=4, 목=5, 금=6, 토=7
    private let dayLabels = ["일", "월", "화", "수", "목", "금", "토"]
    private let dayValues = [1, 2, 3, 4, 5, 6, 7]

    private var dayButtons: [UIButton] = []
    private let allToggle = UISwitch()
    private let allLabel = UILabel()

    private var availableDays: Set<Int> = Set(1...7)
    private(set) var selectedDays: Set<Int> = Set(1...7)

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
