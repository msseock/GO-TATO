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

    private var years: [Int] = []
    private let initialDate: Date
    private let minDate: Date?
    private let maxDate: Date?

    // MARK: - Init

    /// - Parameters:
    ///   - currentDate: 피커의 초기 선택 날짜
    ///   - minDate: 선택 가능한 최소 날짜 (nil이면 GTTDateService.shared.historyMinDate)
    ///   - maxDate: 선택 가능한 최대 날짜 (nil이면 GTTDateService.shared.historyMaxDate)
    init(currentDate: Date, minDate: Date? = nil, maxDate: Date? = nil) {
        self.initialDate = currentDate
        self.minDate = minDate
        self.maxDate = maxDate
        
        let cal = Calendar.current
        
        let startYear: Int
        if let minDate = minDate {
            startYear = cal.component(.year, from: minDate)
        } else {
            startYear = cal.component(.year, from: GTTDateService.shared.historyMinDate)
        }
        
        let endYear: Int
        if let maxDate = maxDate {
            endYear = cal.component(.year, from: maxDate)
        } else {
            endYear = cal.component(.year, from: GTTDateService.shared.historyMaxDate)
        }
        
        self.years = Array(startYear...max(startYear, endYear))
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

    private func availableMonths(for year: Int) -> [Int] {
        let cal = Calendar.current
        var first = 1
        var last = 12
        
        if let minDate = minDate {
            let minYear = cal.component(.year, from: minDate)
            if year == minYear {
                first = cal.component(.month, from: minDate)
            }
        }
        
        if let maxDate = maxDate {
            let maxYear = cal.component(.year, from: maxDate)
            if year == maxYear {
                last = cal.component(.month, from: maxDate)
            }
        }
        
        return Array(first...last)
    }

    private func selectInitialRows() {
        let cal   = Calendar.current
        let year  = cal.component(.year, from: initialDate)
        let month = cal.component(.month, from: initialDate)
        
        if let yearRow = years.firstIndex(of: year) {
            pickerView.selectRow(yearRow, inComponent: 0, animated: false)
            
            let months = availableMonths(for: year)
            if let monthRow = months.firstIndex(of: month) {
                pickerView.selectRow(monthRow, inComponent: 1, animated: false)
            } else if month < (months.first ?? 1) {
                pickerView.selectRow(0, inComponent: 1, animated: false)
            } else if month > (months.last ?? 12) {
                pickerView.selectRow(months.count - 1, inComponent: 1, animated: false)
            }
        }
    }

    @objc private func didTapConfirm() {
        let yearRow = pickerView.selectedRow(inComponent: 0)
        let monthRow = pickerView.selectedRow(inComponent: 1)
        
        guard yearRow >= 0 && yearRow < years.count else { return }
        
        let year = years[yearRow]
        let months = availableMonths(for: year)
        
        guard monthRow >= 0 && monthRow < months.count else { return }
        let month = months[monthRow]
        
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
        if component == 0 {
            return years.count
        } else {
            let yearRow = pickerView.selectedRow(inComponent: 0)
            guard yearRow >= 0 && yearRow < years.count else { return 0 }
            let selectedYear = years[yearRow]
            return availableMonths(for: selectedYear).count
        }
    }

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        if component == 0 {
            return "\(years[row])년"
        } else {
            let yearRow = pickerView.selectedRow(inComponent: 0)
            guard yearRow >= 0 && yearRow < years.count else { return nil }
            let selectedYear = years[yearRow]
            let months = availableMonths(for: selectedYear)
            guard row >= 0 && row < months.count else { return nil }
            return "\(months[row])월"
        }
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        if component == 0 {
            pickerView.reloadComponent(1)
        }
    }
}
