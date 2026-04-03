//
//  MissionCalendarSectionView.swift
//  GoTato
//

import UIKit
import SnapKit
import FSCalendar

// MARK: - Layout Constants

private enum Layout {
    static let headerToWeekdayGap:  CGFloat = 12
    static let weekdayToGridGap:    CGFloat = 4
    static let monthNavGap:         CGFloat = 6
    static let chevronSize:         CGFloat = 14
    static let weekdayHeight:       CGFloat = 36
    static let cellHeight:          CGFloat = 36
    static let cellRowHeight:       CGFloat = 40
    static let cellHorizontalInset: CGFloat = 1.5
    static let cellCornerRadius:    CGFloat = 8
    static let gridHeight:          CGFloat = 6 * cellRowHeight
}

// MARK: - DayStatus (same as CalendarSectionView)

private enum DayStatus {
    case pending, success, late, fail, today, scheduled

    init(rawValue: Int16?) {
        switch rawValue {
        case 1:     self = .success
        case 2:     self = .late
        case 3, 4:  self = .fail
        default:    self = .pending
        }
    }

    var backgroundColor: UIColor {
        switch self {
        case .pending, .scheduled: return GTTColor.white
        case .success: return GTTColor.successBg
        case .late:    return GTTColor.warningBg
        case .fail:    return GTTColor.errorLight
        case .today:   return GTTColor.infoLight
        }
    }

    var textColor: UIColor {
        switch self {
        case .pending:   return GTTColor.tan
        case .scheduled: return GTTColor.textQuiet
        case .success:   return GTTColor.successText
        case .late:      return GTTColor.warningBrown
        case .fail:      return GTTColor.error
        case .today:     return GTTColor.infoText
        }
    }
}

// MARK: - CalendarDayCell

private final class MissionCalendarDayCell: FSCalendarCell {
    let bgView = UIView()
    var useBoldFont = false
    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.insertSubview(bgView, at: 0)
        bgView.layer.cornerRadius = Layout.cellCornerRadius
        bgView.clipsToBounds = true
    }
    required init?(coder: NSCoder) { fatalError() }
    override func layoutSubviews() {
        super.layoutSubviews()
        let inset = Layout.cellHorizontalInset
        let h = Layout.cellHeight
        let top = (bounds.height - h) / 2
        bgView.frame = CGRect(x: inset, y: top, width: bounds.width - inset * 2, height: h)
        titleLabel.frame = CGRect(x: 0, y: top, width: bounds.width, height: h)
        titleLabel.font = useBoldFont ? GTTFont.calendarDayBold.font : GTTFont.calendarDay.font
    }
}

// MARK: - MissionCalendarSectionView

final class MissionCalendarSectionView: UIView {

    // MARK: - Properties

    private var statusMap: [Date: [Int16]] = [:]
    private var missionStartDate: Date?
    private var missionEndDate: Date?

    // MARK: - UI

    private let monthNavView  = UIView()
    private let monthLabel    = UILabel()
    private let chevronIcon   = UIImageView()
    private let weekdayStack  = UIStackView()
    private let fsCalendar    = FSCalendar()

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupHierarchy()
        setupLayout()
        setupStyle()
        setupCalendar()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Public API

    func configure(startDate: Date, endDate: Date, statuses: [Date: [Int16]]) {
        missionStartDate = startDate
        missionEndDate   = endDate
        
        fsCalendar.delegate = self

        // 현재 페이지를 오늘(미션 기간 내) 또는 startDate로
        let today = Date()
        let cal   = Calendar.current
        if today >= startDate && today <= endDate {
            fsCalendar.setCurrentPage(cal.startOfDay(for: today), animated: false)
        } else {
            fsCalendar.setCurrentPage(cal.startOfDay(for: startDate), animated: false)
        }

        let normalized = Dictionary(grouping: statuses.flatMap { (key, vals) in
            vals.map { (cal.startOfDay(for: key), $0) }
        }, by: { $0.0 }).mapValues { $0.map { $0.1 } }
        statusMap = normalized
        updateHeaderLabel(for: fsCalendar.currentPage)
        fsCalendar.reloadData()
    }

    // MARK: - Setup

    private func setupHierarchy() {
        addSubview(monthNavView)
        monthNavView.addSubview(monthLabel)
        monthNavView.addSubview(chevronIcon)
        addSubview(weekdayStack)
        addSubview(fsCalendar)
    }

    private func setupLayout() {
        monthNavView.snp.makeConstraints {
            $0.top.leading.equalToSuperview()
        }
        monthLabel.snp.makeConstraints {
            $0.top.bottom.leading.equalToSuperview()
        }
        chevronIcon.snp.makeConstraints {
            $0.leading.equalTo(monthLabel.snp.trailing).offset(Layout.monthNavGap)
            $0.trailing.equalToSuperview()
            $0.centerY.equalTo(monthLabel)
            $0.width.height.equalTo(Layout.chevronSize)
        }
        weekdayStack.snp.makeConstraints {
            $0.top.equalTo(monthNavView.snp.bottom).offset(Layout.headerToWeekdayGap)
            $0.leading.trailing.equalToSuperview()
            $0.height.equalTo(Layout.weekdayHeight)
        }
        fsCalendar.snp.makeConstraints {
            $0.top.equalTo(weekdayStack.snp.bottom).offset(Layout.weekdayToGridGap)
            $0.leading.trailing.equalToSuperview()
            $0.height.equalTo(Layout.gridHeight)
            $0.bottom.equalToSuperview()
        }
    }

    private func setupStyle() {
        monthLabel.font      = GTTFont.badge.font
        monthLabel.textColor = GTTColor.textSecondary

        let iconConfig = UIImage.SymbolConfiguration(pointSize: 10, weight: .medium)
        chevronIcon.image       = UIImage(systemName: "chevron.right", withConfiguration: iconConfig)
        chevronIcon.tintColor   = GTTColor.tan
        chevronIcon.contentMode = .scaleAspectFit

        let tap = UITapGestureRecognizer(target: self, action: #selector(didTapMonthNav))
        monthNavView.addGestureRecognizer(tap)
        monthNavView.isUserInteractionEnabled = true

        buildWeekdayStack()
    }

    private func buildWeekdayStack() {
        weekdayStack.axis         = .horizontal
        weekdayStack.distribution = .fillEqually
        weekdayStack.spacing      = 3
        for day in ["일", "월", "화", "수", "목", "금", "토"] {
            let cell = UIView()
            cell.backgroundColor    = GTTColor.white
            cell.layer.cornerRadius = Layout.cellCornerRadius
            let label = UILabel()
            label.text          = day
            label.font          = GTTFont.calendarDay.font
            label.textColor     = GTTColor.textQuiet
            label.textAlignment = .center
            cell.addSubview(label)
            label.snp.makeConstraints { $0.edges.equalToSuperview() }
            weekdayStack.addArrangedSubview(cell)
        }
    }

    private func setupCalendar() {
        fsCalendar.delegate   = self
        fsCalendar.dataSource = self
        fsCalendar.register(MissionCalendarDayCell.self, forCellReuseIdentifier: "day")

        fsCalendar.headerHeight = 0
        fsCalendar.calendarHeaderView.isHidden  = true
        fsCalendar.weekdayHeight = 0
        fsCalendar.calendarWeekdayView.isHidden = true
        fsCalendar.rowHeight      = Layout.cellRowHeight
        fsCalendar.locale         = Locale(identifier: "ko_KR")
        fsCalendar.firstWeekday   = 1
        fsCalendar.scrollEnabled  = true
        fsCalendar.allowsSelection = false
        fsCalendar.placeholderType = .none

        fsCalendar.appearance.borderRadius        = 0
        fsCalendar.appearance.todayColor          = .clear
        fsCalendar.appearance.selectionColor      = .clear
        fsCalendar.appearance.titleTodayColor     = nil
        fsCalendar.appearance.eventDefaultColor   = .clear
        fsCalendar.appearance.eventSelectionColor = .clear
        fsCalendar.appearance.titleFont           = GTTFont.calendarDay.font
        fsCalendar.backgroundColor = .clear

        updateHeaderLabel(for: fsCalendar.currentPage)
    }

    private func updateHeaderLabel(for pageDate: Date) {
        let comps = Calendar.current.dateComponents([.year, .month], from: pageDate)
        guard let year = comps.year, let month = comps.month else { return }
        monthLabel.text = "\(year)년 \(month)월"
    }

    // MARK: - Month Picker

    @objc private func didTapMonthNav() {
        guard let vc = findViewController() else { return }
        let picker = GTTMonthPickerSheetViewController(
            currentDate: fsCalendar.currentPage,
            minDate: missionStartDate,
            maxDate: missionEndDate
        )
        picker.onConfirm = { [weak self] date in
            guard let self else { return }
            let comps = Calendar.current.dateComponents([.year, .month], from: date)
            guard let target = Calendar.current.date(from: comps) else { return }
            self.fsCalendar.setCurrentPage(target, animated: true)
        }
        let nav = UINavigationController(rootViewController: picker)
        nav.modalPresentationStyle = .pageSheet
        if let ctrl = nav.sheetPresentationController {
            ctrl.detents = [.custom(identifier: .init("monthPicker")) { _ in 280 }]
            ctrl.prefersGrabberVisible = true
        }
        vc.present(nav, animated: true)
    }

    private func findViewController() -> UIViewController? {
        var r: UIResponder? = self
        while let next = r {
            if let vc = next as? UIViewController { return vc }
            r = next.next
        }
        return nil
    }
}

// MARK: - FSCalendarDataSource

extension MissionCalendarSectionView: FSCalendarDataSource {
    func calendar(_ calendar: FSCalendar, cellFor date: Date, at position: FSCalendarMonthPosition) -> FSCalendarCell {
        let cell = calendar.dequeueReusableCell(withIdentifier: "day", for: date, at: position) as! MissionCalendarDayCell
        let status = dayStatus(for: date)
        if position == .current {
            cell.bgView.backgroundColor = status.backgroundColor
            cell.useBoldFont = (status != .pending)
        } else {
            cell.bgView.backgroundColor = .clear
            cell.useBoldFont = false
        }
        return cell
    }

    func minimumDate(for calendar: FSCalendar) -> Date {
        return missionStartDate ?? Date(timeIntervalSince1970: 0)
    }

    func maximumDate(for calendar: FSCalendar) -> Date {
        return missionEndDate ?? Date().addingTimeInterval(60 * 60 * 24 * 365 * 10)
    }
}

// MARK: - FSCalendarDelegate

extension MissionCalendarSectionView: FSCalendarDelegate {
    func calendarCurrentPageDidChange(_ calendar: FSCalendar) {
        updateHeaderLabel(for: calendar.currentPage)
    }
}

// MARK: - FSCalendarDelegateAppearance

extension MissionCalendarSectionView: FSCalendarDelegateAppearance {
    func calendar(_ calendar: FSCalendar, appearance: FSCalendarAppearance, fillDefaultColorFor date: Date) -> UIColor? { .clear }
    func calendar(_ calendar: FSCalendar, appearance: FSCalendarAppearance, titleDefaultColorFor date: Date) -> UIColor? {
        dayStatus(for: date).textColor
    }
    func calendar(_ calendar: FSCalendar, appearance: FSCalendarAppearance, borderDefaultColorFor date: Date) -> UIColor? { .clear }

    private func dayStatus(for date: Date) -> DayStatus {
        let cal = Calendar.current
        let key = cal.startOfDay(for: date)
        if cal.isDateInToday(date) { return .today }
        if key > cal.startOfDay(for: Date()) {
            return statusMap[key] != nil ? .scheduled : .pending
        }
        let statuses = statusMap[key] ?? []
        if statuses.isEmpty { return .pending }
        let hasSuccess = statuses.contains(1)
        let hasLate    = statuses.contains(2)
        let hasFail    = statuses.contains(where: { $0 == 3 || $0 == 4 })
        if hasSuccess && (hasLate || hasFail) { return .late }
        if hasSuccess { return .success }
        if hasLate && !hasFail { return .late }
        return .fail
    }
}

