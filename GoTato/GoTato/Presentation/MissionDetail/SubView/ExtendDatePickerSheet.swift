//
//  ExtendDatePickerSheet.swift
//  GoTato
//

import UIKit
import SnapKit

final class ExtendDatePickerSheet: UIViewController {

    // MARK: - Callback

    var onConfirm: ((Date) -> Void)?

    // MARK: - UI

    private let titleLabel    = UILabel()
    private let datePicker    = UIDatePicker()
    private let cancelButton  = UIButton(type: .system)
    private let confirmButton = UIButton(type: .system)

    // MARK: - Init

    private let currentEndDate: Date

    init(currentEndDate: Date) {
        self.currentEndDate = currentEndDate
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = GTTColor.bgPrimary

        setupUI()
        setupLayout()
    }

    // MARK: - Setup

    private func setupUI() {
        titleLabel.text      = "연장할 날짜를 선택하세요"
        titleLabel.font      = GTTFont.subHeading.font
        titleLabel.textColor = GTTColor.textPrimary
        titleLabel.textAlignment = .center

        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: currentEndDate)!
        let maxDate  = Calendar.current.date(byAdding: .month, value: 1, to: currentEndDate)!

        datePicker.datePickerMode  = .date
        datePicker.preferredDatePickerStyle = .inline
        datePicker.minimumDate = tomorrow
        datePicker.maximumDate = maxDate
        datePicker.date        = tomorrow
        datePicker.locale      = Locale(identifier: "ko_KR")

        cancelButton.setTitle("취소", for: .normal)
        cancelButton.titleLabel?.font = GTTFont.body.font
        cancelButton.setTitleColor(GTTColor.textSecondary, for: .normal)
        cancelButton.addTarget(self, action: #selector(didTapCancel), for: .touchUpInside)

        confirmButton.setTitle("확인", for: .normal)
        confirmButton.titleLabel?.font = GTTFont.subHeading.font
        confirmButton.setTitleColor(GTTColor.brand, for: .normal)
        confirmButton.addTarget(self, action: #selector(didTapConfirm), for: .touchUpInside)

        [titleLabel, datePicker, cancelButton, confirmButton].forEach { view.addSubview($0) }
    }

    private func setupLayout() {
        titleLabel.snp.makeConstraints {
            $0.top.equalToSuperview().offset(24)
            $0.centerX.equalToSuperview()
        }
        datePicker.snp.makeConstraints {
            $0.top.equalTo(titleLabel.snp.bottom).offset(12)
            $0.leading.trailing.equalToSuperview().inset(16)
        }
        cancelButton.snp.makeConstraints {
            $0.top.equalTo(datePicker.snp.bottom).offset(16)
            $0.leading.equalToSuperview().inset(24)
            $0.bottom.lessThanOrEqualTo(view.safeAreaLayoutGuide).inset(20)
        }
        confirmButton.snp.makeConstraints {
            $0.centerY.equalTo(cancelButton)
            $0.trailing.equalToSuperview().inset(24)
        }
    }

    // MARK: - Actions

    @objc private func didTapConfirm() {
        onConfirm?(datePicker.date)
        dismiss(animated: true)
    }

    @objc private func didTapCancel() {
        dismiss(animated: true)
    }
}
