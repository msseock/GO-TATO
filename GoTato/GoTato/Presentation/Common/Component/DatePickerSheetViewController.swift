//
//  DatePickerSheetViewController.swift
//  GoTato
//

import UIKit
import SnapKit

final class DatePickerSheetViewController: UIViewController {

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
