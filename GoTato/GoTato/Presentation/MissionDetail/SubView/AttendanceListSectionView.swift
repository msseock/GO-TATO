//
//  AttendanceListSectionView.swift
//  GoTato
//

import UIKit
import SnapKit

struct AttendanceItem {
    let planDate: Date
    let recordDate: Date?
    let status: Int16
}

final class AttendanceListSectionView: UIView {

    // MARK: - UI

    private let rowStack = UIStackView()

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        rowStack.axis    = .vertical
        rowStack.spacing = 0
        addSubview(rowStack)
        rowStack.snp.makeConstraints { $0.edges.equalToSuperview() }
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Configure

    func configure(items: [AttendanceItem]) {
        rowStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (index, item) in items.enumerated() {
            let row = AttendanceRowView()
            row.configure(with: item)
            if index > 0 {
                let divider = UIView()
                divider.backgroundColor = GTTColor.divider
                divider.snp.makeConstraints { $0.height.equalTo(1) }
                rowStack.addArrangedSubview(divider)
            }
            rowStack.addArrangedSubview(row)
        }
    }
}

// MARK: - AttendanceRowView

private final class AttendanceRowView: UIView {

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

    override init(frame: CGRect) {
        super.init(frame: frame)

        dateLabel.font      = GTTFont.bodySecondary.font
        dateLabel.textColor = GTTColor.textPrimary

        timeLabel.font      = GTTFont.bodySecondary.font
        timeLabel.textColor = GTTColor.textSecondary
        timeLabel.textAlignment = .center

        addSubview(dateLabel)
        addSubview(timeLabel)
        addSubview(badgeView)

        snp.makeConstraints { $0.height.equalTo(52) }

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
