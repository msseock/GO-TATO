//
//  CalendarSectionView.swift
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
    static let cellRowHeight:       CGFloat = 40     // 36 cell + 4 row-gap
    static let cellHorizontalInset: CGFloat = 1.5    // ×2 = 3px gap between adjacent cells
    static let cellCornerRadius:    CGFloat = 8
    static let gridHeight:          CGFloat = 6 * cellRowHeight  // 240pt (max 6 rows)
}

// MARK: - DayStatus

private enum DayStatus {
    case pending, success, late, fail, today, scheduled

    init(rawValue: Int16?) {
        switch rawValue {
        case 1:  self = .success
        case 2:  self = .late
        case 3, 4: self = .fail  // 3=fail, 4=failCommitted (동일 시각)
        default: self = .pending
        }
    }

    var backgroundColor: UIColor {
        switch self {
        case .today:      return GTTColor.infoLight
        case .pending, .success, .late, .fail, .scheduled:
            return GTTColor.white
        }
    }

    var textColor: UIColor {
        switch self {
        case .pending:    return GTTColor.tan
        case .today:      return GTTColor.infoText
        default:          return GTTColor.textQuiet
        }
    }

    var dotColor: UIColor {
        switch self {
        case .pending:    return GTTColor.tan
        case .success:    return GTTColor.success       // #79BF8B 초록
        case .late:       return GTTColor.streakToday   // #F5B748 노랑
        case .fail:       return GTTColor.error         // #F44336 빨강
        case .today:      return GTTColor.info          // #5B8DEF 파랑
        case .scheduled:  return GTTColor.textQuiet
        }
    }
}

// MARK: - CalendarDayCell

private final class CalendarDayCell: FSCalendarCell {

    let bgView = UIView()
    var useBoldFont = false
    var dotColors: [UIColor] = []

    private let dotView = UIView()
    private var segmentLayers: [CALayer] = []

    private enum Dot {
        static let height: CGFloat = 4
        static let unitWidth: CGFloat = 4
        static let padding: CGFloat = 2
        static let topGap: CGFloat = 9   // titleLabel centerY 기준 아래 오프셋
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.insertSubview(bgView, at: 0)
        bgView.layer.cornerRadius = Layout.cellCornerRadius
        bgView.clipsToBounds = true
        dotView.clipsToBounds = true
        contentView.addSubview(dotView)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let inset = Layout.cellHorizontalInset
        let h     = Layout.cellHeight
        let top   = (bounds.height - h) / 2
        bgView.frame    = CGRect(x: inset, y: top, width: bounds.width - inset * 2, height: h)
        // FSCalendar은 titleLabel을 셀 상단 2/3 영역에 배치하므로 bgView와 centerY가 맞지 않음.
        // bgView의 y·height와 동일하게 덮어써서 정렬.
        titleLabel.frame = CGRect(x: 0, y: top, width: bounds.width, height: h)
        // appearance 시스템이 폰트를 덮어쓸 수 있으므로 layoutSubviews에서 직접 설정
        titleLabel.font = useBoldFont ? GTTFont.calendarDayBold.font : GTTFont.calendarDay.font

        // 미션별 색상 세그먼트 pill dot
        segmentLayers.forEach { $0.removeFromSuperlayer() }
        segmentLayers.removeAll()

        if !dotColors.isEmpty {
            dotView.isHidden = false
            dotView.backgroundColor = .clear
            let count = dotColors.count
            let maxWidth = bounds.width - Dot.padding * 2
            let dotW = min(CGFloat(count) * Dot.unitWidth, maxWidth)
            let dotY = titleLabel.frame.midY + Dot.topGap
            dotView.frame = CGRect(
                x: (bounds.width - dotW) / 2,
                y: dotY,
                width: dotW,
                height: Dot.height
            )
            dotView.layer.cornerRadius = Dot.height / 2

            let segWidth = dotW / CGFloat(count)
            for (i, color) in dotColors.enumerated() {
                let layer = CALayer()
                layer.frame = CGRect(x: segWidth * CGFloat(i), y: 0, width: segWidth, height: Dot.height)
                layer.backgroundColor = color.cgColor
                dotView.layer.addSublayer(layer)
                segmentLayers.append(layer)
            }
        } else {
            dotView.isHidden = true
        }
    }
}

// MARK: - CalendarSectionView

final class CalendarSectionView: UIView {

    // MARK: - Properties

    /// key: startOfDay 기준 Date, value: 해당 날짜의 Attendance.status 목록 (다중 미션 지원)
    private var statusMap: [Date: [Int16]] = [:]

    /// 부모 VC에서 새 달 데이터를 로드할 때 사용
    var onMonthChanged: ((Date) -> Void)?

    /// 날짜 탭 시 호출. date는 탭된 날짜 (startOfDay 아님)
    var onDateSelected: ((Date) -> Void)?

    // MARK: - UI Components

    private let titleLabel   = UILabel()
    private let monthNavView = UIView()
    private let monthLabel   = UILabel()
    private let chevronIcon  = UIImageView()
    private let weekdayStack = UIStackView()
    private let fsCalendar   = FSCalendar()

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupHierarchy()
        setupLayout()
        setupStyle()
        setupCalendar()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Public API

    /// 날짜별 출석 status 목록을 주입하면 셀 색상이 업데이트됩니다.
    /// 다중 미션을 지원하기 위해 날짜당 [Int16] 배열을 받습니다.
    func configure(with statuses: [Date: [Int16]]) {
        let cal = Calendar.current
        var normalized: [Date: [Int16]] = [:]
        for (date, values) in statuses {
            let key = cal.startOfDay(for: date)
            normalized[key, default: []].append(contentsOf: values)
        }
        statusMap = normalized
        updateHeaderLabels(for: fsCalendar.currentPage)
        fsCalendar.reloadData()
    }

    // MARK: - Setup

    private func setupHierarchy() {
        addSubview(titleLabel)
        addSubview(monthNavView)
        monthNavView.addSubview(monthLabel)
        monthNavView.addSubview(chevronIcon)
        addSubview(weekdayStack)
        addSubview(fsCalendar)
    }

    private func setupLayout() {
        monthNavView.snp.makeConstraints {
            $0.top.trailing.equalToSuperview()
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

        titleLabel.snp.makeConstraints {
            $0.leading.equalToSuperview()
            $0.centerY.equalTo(monthNavView)
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
        titleLabel.font      = GTTFont.body.font
        titleLabel.textColor = GTTColor.textPrimary

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
        fsCalendar.register(CalendarDayCell.self, forCellReuseIdentifier: "day")

        // 커스텀 weekday stack 사용 → FSCalendar 헤더/요일 영역 숨김
        fsCalendar.headerHeight = 0
        fsCalendar.calendarHeaderView.isHidden = true
        fsCalendar.weekdayHeight = 0
        fsCalendar.calendarWeekdayView.isHidden = true

        fsCalendar.rowHeight    = Layout.cellRowHeight
        fsCalendar.locale       = Locale(identifier: "ko_KR")
        fsCalendar.firstWeekday = 1   // 일요일 시작

        fsCalendar.scrollEnabled   = true
        fsCalendar.allowsSelection = true
        fsCalendar.placeholderType = .none

        // custom cell이 배경을 담당 → FSCalendar 기본 shape 투명 처리
        fsCalendar.appearance.borderRadius        = 0
        fsCalendar.appearance.todayColor          = .clear
        fsCalendar.appearance.selectionColor      = .clear
        fsCalendar.appearance.titleTodayColor     = nil
        fsCalendar.appearance.eventDefaultColor   = .clear
        fsCalendar.appearance.eventSelectionColor = .clear
        fsCalendar.appearance.titleFont           = GTTFont.calendarDay.font

        fsCalendar.backgroundColor = .clear

        updateHeaderLabels(for: fsCalendar.currentPage)
    }

    // MARK: - Header

    private func updateHeaderLabels(for pageDate: Date) {
        let comps = Calendar.current.dateComponents([.year, .month], from: pageDate)
        guard let year = comps.year, let month = comps.month else { return }
        titleLabel.text = "\(month)월 출근 기록"
        monthLabel.text = "\(year)년 \(month)월"
    }

    // MARK: - Month Navigation

    @objc private func didTapMonthNav() {
        guard let vc = findViewController() else { return }

        let picker = GTTMonthPickerSheetViewController(currentDate: fsCalendar.currentPage)
        picker.onConfirm = { [weak self] selectedDate in
            guard let self else { return }
            let comps = Calendar.current.dateComponents([.year, .month], from: selectedDate)
            guard let targetDate = Calendar.current.date(from: comps) else { return }
            // setCurrentPage가 calendarCurrentPageDidChange를 트리거하므로
            // onMonthChanged는 거기서 한 번만 발화됨
            self.fsCalendar.setCurrentPage(targetDate, animated: true)
        }

        let nav = UINavigationController(rootViewController: picker)
        nav.modalPresentationStyle = .pageSheet
        if let controller = nav.sheetPresentationController {
            // navBar(44) + picker(216) + grabber 영역(20) = 280
            controller.detents = [.custom(identifier: .init("monthPicker")) { _ in 280 }]
            controller.prefersGrabberVisible = true
        }
        vc.present(nav, animated: true)
    }

    private func findViewController() -> UIViewController? {
        var responder: UIResponder? = self
        while let r = responder {
            if let vc = r as? UIViewController { return vc }
            responder = r.next
        }
        return nil
    }
}

// MARK: - FSCalendarDataSource

extension CalendarSectionView: FSCalendarDataSource {
    func calendar(_ calendar: FSCalendar, cellFor date: Date, at position: FSCalendarMonthPosition) -> FSCalendarCell {
        let cell = calendar.dequeueReusableCell(withIdentifier: "day", for: date, at: position) as! CalendarDayCell
        let status = dayStatus(for: date)
        let cal = Calendar.current
        let key = cal.startOfDay(for: date)

        if position == .current {
            let isSelected = calendar.selectedDates.contains(date)
            cell.bgView.backgroundColor = isSelected ? GTTColor.surface : status.backgroundColor
            cell.useBoldFont = (status == .scheduled)

            let statuses = statusMap[key] ?? []
            if statuses.isEmpty {
                cell.dotColors = []
            } else if status == .today || status == .scheduled {
                // 오늘·미래: 모든 세그먼트 동일 색상
                cell.dotColors = statuses.map { _ in status.dotColor }
            } else {
                // 과거: 미션별 개별 status 색상
                cell.dotColors = statuses.map { DayStatus(rawValue: $0).dotColor }
            }
        } else {
            cell.bgView.backgroundColor = .clear
            cell.useBoldFont = false
            cell.dotColors = []
        }
        return cell
    }
}

// MARK: - FSCalendarDelegate

extension CalendarSectionView: FSCalendarDelegate {
    func calendarCurrentPageDidChange(_ calendar: FSCalendar) {
        updateHeaderLabels(for: calendar.currentPage)
        onMonthChanged?(calendar.currentPage)
    }

    func calendar(_ calendar: FSCalendar, didSelect date: Date, at monthPosition: FSCalendarMonthPosition) {
        guard monthPosition == .current else { return }
        calendar.reloadData()
        onDateSelected?(date)
    }

    func calendar(_ calendar: FSCalendar, didDeselect date: Date, at monthPosition: FSCalendarMonthPosition) {
        calendar.reloadData()
    }
}

// MARK: - FSCalendarDelegateAppearance

extension CalendarSectionView: FSCalendarDelegateAppearance {
    func calendar(_ calendar: FSCalendar, appearance: FSCalendarAppearance, fillDefaultColorFor date: Date) -> UIColor? {
        .clear  // 배경은 CalendarDayCell.bgView 가 담당
    }

    func calendar(_ calendar: FSCalendar, appearance: FSCalendarAppearance, titleDefaultColorFor date: Date) -> UIColor? {
        dayStatus(for: date).textColor
    }

    func calendar(_ calendar: FSCalendar, appearance: FSCalendarAppearance, titleSelectionColorFor date: Date) -> UIColor? {
        let status = dayStatus(for: date)
        if status == .today {
            return GTTColor.textQuiet
        }
        return status.textColor
    }

    func calendar(_ calendar: FSCalendar, appearance: FSCalendarAppearance, borderDefaultColorFor date: Date) -> UIColor? {
        .clear
    }

    // MARK: - Private Helper

    private func dayStatus(for date: Date) -> DayStatus {
        let cal = Calendar.current
        let key = cal.startOfDay(for: date)

        // 오늘은 항상 파랑
        if cal.isDateInToday(date) { return .today }

        // 미래: 미션이 존재하면 scheduled, 아니면 pending
        if key > cal.startOfDay(for: Date()) {
            return statusMap[key] != nil ? .scheduled : .pending
        }

        // 과거: 해당 날짜의 status 목록을 집계
        let statuses = statusMap[key] ?? []
        if statuses.isEmpty { return .pending }

        let hasSuccess = statuses.contains(1)
        let hasLate    = statuses.contains(2)
        let hasFail    = statuses.contains(where: { $0 == 3 || $0 == 4 })

        if hasSuccess && (hasLate || hasFail) { return .late }   // 혼재 → 노랑
        if hasSuccess { return .success }                         // 전체 성공 → 초록
        if hasLate && !hasFail { return .late }                   // 전체 지각 → 노랑
        return .fail                                              // 전체 실패 → 빨강
    }
}
