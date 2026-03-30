//
//  GTTTimePickerSheetViewController.swift
//  GoTato
//

import UIKit
import SnapKit

final class GTTTimePickerSheetViewController: UIViewController {

    // MARK: - Callback

    var onConfirm: ((Date) -> Void)?

    // MARK: - UI Components

    private let titleLabel    = UILabel()
    private let timePicker    = UIDatePicker()
    private let confirmButton = GTTMainButton(title: "확인", icon: UIImage(systemName: "checkmark"), style: .primary)
    private let cancelButton  = UIButton(type: .system)

    // MARK: - Properties

    private let initialDate: Date
    private let minuteInterval: Int
    private let showCancel: Bool

    // MARK: - Init

    init(title: String? = nil, initialDate: Date, minuteInterval: Int = 1, showCancel: Bool = false) {
        self.initialDate = initialDate
        self.minuteInterval = minuteInterval
        self.showCancel = showCancel
        super.init(nibName: nil, bundle: nil)
        
        self.titleLabel.text = title
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = GTTColor.white
        setupUI()
        setupLayout()
        setupSheet()
    }

    // MARK: - Setup

    private func setupUI() {
        titleLabel.font      = GTTFont.subHeading.font
        titleLabel.textColor = GTTColor.textPrimary
        titleLabel.textAlignment = .center
        titleLabel.isHidden  = titleLabel.text == nil

        timePicker.datePickerMode = .time
        timePicker.preferredDatePickerStyle = .wheels
        timePicker.locale = Locale(identifier: "ko_KR")
        timePicker.minuteInterval = minuteInterval
        timePicker.date = initialDate

        confirmButton.onTap = { [weak self] in
            guard let self else { return }
            self.onConfirm?(self.timePicker.date)
            self.dismiss(animated: true)
        }

        cancelButton.setTitle("취소", for: .normal)
        cancelButton.titleLabel?.font = GTTFont.body.font
        cancelButton.setTitleColor(GTTColor.textSecondary, for: .normal)
        cancelButton.addTarget(self, action: #selector(didTapCancel), for: .touchUpInside)
        cancelButton.isHidden = !showCancel

        [titleLabel, timePicker, confirmButton, cancelButton].forEach { view.addSubview($0) }
    }

    private func setupLayout() {
        if !titleLabel.isHidden {
            titleLabel.snp.makeConstraints {
                $0.top.equalToSuperview().offset(24)
                $0.centerX.equalToSuperview()
            }
            timePicker.snp.makeConstraints {
                $0.top.equalTo(titleLabel.snp.bottom).offset(12)
                $0.leading.trailing.equalToSuperview().inset(16)
            }
        } else {
            timePicker.snp.makeConstraints {
                $0.top.equalToSuperview().offset(32)
                $0.leading.trailing.equalToSuperview().inset(16)
            }
        }

        confirmButton.snp.makeConstraints {
            $0.top.equalTo(timePicker.snp.bottom).offset(16)
            $0.leading.trailing.equalToSuperview().inset(24)
            $0.height.equalTo(52)
        }

        if showCancel {
            cancelButton.snp.makeConstraints {
                $0.top.equalTo(confirmButton.snp.bottom).offset(12)
                $0.centerX.equalToSuperview()
                $0.bottom.equalTo(view.safeAreaLayoutGuide).inset(20)
            }
        } else {
            confirmButton.snp.makeConstraints {
                $0.bottom.equalTo(view.safeAreaLayoutGuide).inset(24)
            }
        }
    }

    private func setupSheet() {
        modalPresentationStyle = .pageSheet
        if let sheet = sheetPresentationController {
            sheet.detents = [.medium()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 24
        }
    }

    // MARK: - Actions

    @objc private func didTapCancel() {
        dismiss(animated: true)
    }
}
