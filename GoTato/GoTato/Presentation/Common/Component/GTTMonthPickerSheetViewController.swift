//
//  GTTMonthPickerSheetViewController.swift
//  GoTato
//

import UIKit
import SnapKit

final class GTTMonthPickerSheetViewController: UIViewController {

    // MARK: - Callback

    var onConfirm: ((Date) -> Void)?

    // MARK: - UI

    private let pickerView = UIPickerView()

    // MARK: - Properties

    private let years: [Int]
    private let months = Array(1...12)
    private let initialDate: Date

    // MARK: - Init

    /// - Parameters:
    ///   - currentDate: 피커의 초기 선택 날짜
    ///   - minDate: 선택 가능한 최소 날짜 (nil이면 현재 연도 기준 -5년)
    ///   - maxDate: 선택 가능한 최대 날짜 (nil이면 현재 연도 기준 +1년)
    init(currentDate: Date, minDate: Date? = nil, maxDate: Date? = nil) {
        self.initialDate = currentDate
        let cal = Calendar.current
        if let minDate, let maxDate {
            let minYear = cal.component(.year, from: minDate)
            let maxYear = cal.component(.year, from: maxDate)
            self.years = Array(minYear...max(minYear, maxYear))
        } else {
            let current = cal.component(.year, from: Date())
            self.years = Array((current - 5)...(current + 1))
        }
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = GTTColor.bgPrimary

        pickerView.dataSource = self
        pickerView.delegate   = self
        view.addSubview(pickerView)
        pickerView.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide)
            $0.leading.trailing.equalToSuperview()
            $0.bottom.equalTo(view.safeAreaLayoutGuide)
        }

        title = "월 선택"
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "확인",
            style: .done,
            target: self,
            action: #selector(didTapConfirm)
        )

        selectInitialRows()
    }

    // MARK: - Private

    private func selectInitialRows() {
        let cal   = Calendar.current
        let year  = cal.component(.year, from: initialDate)
        let month = cal.component(.month, from: initialDate)
        if let yearRow = years.firstIndex(of: year) {
            pickerView.selectRow(yearRow, inComponent: 0, animated: false)
        }
        pickerView.selectRow(month - 1, inComponent: 1, animated: false)
    }

    @objc private func didTapConfirm() {
        let year  = years[pickerView.selectedRow(inComponent: 0)]
        let month = months[pickerView.selectedRow(inComponent: 1)]
        var comps  = DateComponents()
        comps.year  = year
        comps.month = month
        comps.day   = 1
        if let date = Calendar.current.date(from: comps) {
            onConfirm?(date)
        }
        dismiss(animated: true)
    }
}

// MARK: - UIPickerViewDataSource & Delegate

extension GTTMonthPickerSheetViewController: UIPickerViewDataSource, UIPickerViewDelegate {
    func numberOfComponents(in pickerView: UIPickerView) -> Int { 2 }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        component == 0 ? years.count : months.count
    }

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        component == 0 ? "\(years[row])년" : "\(months[row])월"
    }
}
