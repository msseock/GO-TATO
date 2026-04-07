//
//  AttendanceListSectionView.swift
//  GoTato
//

import UIKit
import SnapKit

struct AttendanceItem {
    let id: UUID
    let planDate: Date
    let recordDate: Date?
    let status: Int16
}

final class AttendanceListSectionView: UIView {

    // MARK: - Callbacks

    var onDelete: ((UUID) -> Void)?

    // MARK: - Properties

    private var items: [AttendanceItem] = []

    // MARK: - UI

    private let tableView = UITableView(frame: .zero, style: .plain)
    private var tableHeightConstraint: Constraint?

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupTableView()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Setup

    private func setupTableView() {
        tableView.register(AttendanceCell.self, forCellReuseIdentifier: AttendanceCell.reuseID)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.separatorStyle = .none
        tableView.isScrollEnabled = false
        tableView.backgroundColor = .clear
        tableView.rowHeight = 52

        addSubview(tableView)
        tableView.snp.makeConstraints {
            $0.edges.equalToSuperview()
            tableHeightConstraint = $0.height.equalTo(0).constraint
        }
    }

    // MARK: - Configure

    func configure(items: [AttendanceItem]) {
        self.items = items
        tableView.reloadData()
        updateHeight()
    }

    private func updateHeight() {
        let height = CGFloat(items.count) * 52
        tableHeightConstraint?.update(offset: height)
    }
}

// MARK: - UITableViewDataSource

extension AttendanceListSectionView: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: AttendanceCell.reuseID, for: indexPath) as! AttendanceCell
        cell.configure(with: items[indexPath.row])
        cell.showDivider = indexPath.row > 0
        return cell
    }
}

// MARK: - UITableViewDelegate

extension AttendanceListSectionView: UITableViewDelegate {
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let item = items[indexPath.row]
        let deleteAction = UIContextualAction(style: .destructive, title: "삭제") { [weak self] _, _, completion in
            guard let self else { return completion(false) }
            self.items.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .automatic)
            self.updateHeight()
            self.onDelete?(item.id)
            completion(true)
        }
        return UISwipeActionsConfiguration(actions: [deleteAction])
    }
}

// MARK: - AttendanceCell

private final class AttendanceCell: UITableViewCell {

    static let reuseID = "AttendanceCell"

    private static let dateFmt: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일 (E)"
        return f
    }()

    private static let timeFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    private let dateLabel  = UILabel()
    private let timeLabel  = UILabel()
    private let badgeView  = BadgeView()
    private let divider    = UIView()

    var showDivider: Bool = false {
        didSet { divider.isHidden = !showDivider }
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear

        dateLabel.font      = GTTFont.bodySecondary.font
        dateLabel.textColor = GTTColor.textPrimary

        timeLabel.font      = GTTFont.bodySecondary.font
        timeLabel.textColor = GTTColor.textSecondary
        timeLabel.textAlignment = .center

        divider.backgroundColor = GTTColor.divider

        contentView.addSubview(divider)
        contentView.addSubview(dateLabel)
        contentView.addSubview(timeLabel)
        contentView.addSubview(badgeView)

        divider.snp.makeConstraints {
            $0.top.leading.trailing.equalToSuperview()
            $0.height.equalTo(1)
        }

        dateLabel.snp.makeConstraints {
            $0.leading.equalToSuperview().inset(4)
            $0.centerY.equalToSuperview()
            $0.width.equalToSuperview().multipliedBy(0.42)
        }
        timeLabel.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.centerY.equalToSuperview()
        }
        badgeView.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(4)
            $0.centerY.equalToSuperview()
            $0.height.equalTo(24)
            $0.width.greaterThanOrEqualTo(44)
        }

        divider.isHidden = true
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(with item: AttendanceItem) {
        dateLabel.text = Self.dateFmt.string(from: item.planDate)
        if let rec = item.recordDate {
            timeLabel.text = Self.timeFmt.string(from: rec)
        } else if item.status == 0 {
            timeLabel.text = "-"
        } else {
            timeLabel.text = "미출석"
        }
        badgeView.configure(status: item.status)
    }
}

// MARK: - BadgeView

private final class BadgeView: UIView {

    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.cornerRadius = 6
        clipsToBounds = true
        addSubview(label)
        label.font = GTTFont.badge.font
        label.textAlignment = .center
        label.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8))
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(status: Int16) {
        switch status {
        case 0:
            backgroundColor = GTTColor.infoLight
            label.textColor = GTTColor.infoText
            label.text      = "예정"
        case 1:
            backgroundColor = GTTColor.successBg
            label.textColor = GTTColor.successText
            label.text      = "성공"
        case 2:
            backgroundColor = GTTColor.warningBg
            label.textColor = GTTColor.warningBrown
            label.text      = "지각"
        default:
            backgroundColor = GTTColor.errorLight
            label.textColor = GTTColor.error
            label.text      = "실패"
        }
    }
}
