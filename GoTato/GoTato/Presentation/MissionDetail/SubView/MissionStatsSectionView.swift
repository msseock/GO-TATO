//
//  MissionStatsSectionView.swift
//  GoTato
//

import UIKit
import SnapKit

final class MissionStatsSectionView: UIView {

    // MARK: - UI

    private let successCell = StatCell(
        label: "성공",
        bg: GTTColor.successBg,
        textColor: GTTColor.successText
    )
    private let lateCell = StatCell(
        label: "지각",
        bg: GTTColor.warningBg,
        textColor: GTTColor.warningBrown
    )
    private let failCell = StatCell(
        label: "실패",
        bg: GTTColor.errorLight,
        textColor: GTTColor.error
    )

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        let stack = UIStackView(arrangedSubviews: [successCell, lateCell, failCell])
        stack.axis         = .horizontal
        stack.distribution = .fillEqually
        stack.spacing      = 8
        addSubview(stack)
        stack.snp.makeConstraints { $0.edges.equalToSuperview() }
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Configure

    func configure(successCount: Int, lateCount: Int, failCount: Int, totalCompleted: Int) {
        let rate = totalCompleted > 0 ? Int(Double(successCount) / Double(totalCompleted) * 100) : 0
        successCell.configure(count: successCount, rate: rate)
        lateCell.configure(count: lateCount, rate: nil)
        failCell.configure(count: failCount, rate: nil)
    }
}

// MARK: - StatCell

private final class StatCell: UIView {

    private let countLabel = UILabel()
    private let badgeLabel = UILabel()
    private let cellBg: UIColor
    private let cellText: UIColor
    private let baseLabelText: String

    init(label: String, bg: UIColor, textColor: UIColor) {
        self.cellBg        = bg
        self.cellText      = textColor
        self.baseLabelText = label
        super.init(frame: .zero)

        backgroundColor    = bg
        layer.cornerRadius = 10
        clipsToBounds      = true

        countLabel.font          = GTTFont.cardTitle.font
        countLabel.textColor     = textColor
        countLabel.textAlignment = .center

        badgeLabel.font          = GTTFont.badge.font
        badgeLabel.textColor     = textColor
        badgeLabel.textAlignment = .center

        let stack = UIStackView(arrangedSubviews: [countLabel, badgeLabel])
        stack.axis    = .vertical
        stack.spacing = 2
        addSubview(stack)
        stack.snp.makeConstraints {
            $0.center.equalToSuperview()
            $0.leading.trailing.equalToSuperview().inset(8)
        }
        snp.makeConstraints { $0.height.equalTo(72) }
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(count: Int, rate: Int?) {
        countLabel.text = "\(count)"
        if let rate {
            badgeLabel.text = "\(baseLabelText) \(rate)%"
        } else {
            badgeLabel.text = baseLabelText
        }
    }
}
