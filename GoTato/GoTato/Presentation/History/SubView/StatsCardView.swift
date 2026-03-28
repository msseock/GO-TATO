import SnapKit
import UIKit

// MARK: - Layout Constants

private enum Layout {
    static let cornerRadius: CGFloat = 16
    static let borderWidth: CGFloat = 1.5
    static let height: CGFloat = 88
    static let itemSpacing: CGFloat = 0
    static let dividerWidth: CGFloat = 1
    static let dividerHeight: CGFloat = 40
    static let labelSpacing: CGFloat = 4
}

// MARK: - StatsCardView

final class StatsCardView: UIView {

    // MARK: - UI Components

    private let attendanceItem = StatItemView(
        color: GTTColor.successText,
        title: "출석률"
    )
    private let lateItem = StatItemView(
        color: GTTColor.warningOrange,
        title: "지각"
    )
    private let savedTimeItem = StatItemView(
        color: GTTColor.info,
        title: "절약 시간"
    )

    private let leadingDivider = makeDivider()
    private let trailingDivider = makeDivider()

    private let stackView = UIStackView()

    // MARK: - Init

    init(attendanceRate: Int, lateCount: Int, savedMinutes: Int) {
        super.init(frame: .zero)
        setupHierarchy()
        setupLayout()
        setupStyle()
        configure(attendanceRate: attendanceRate, lateCount: lateCount, savedMinutes: savedMinutes)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Intrinsic Size

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: Layout.height)
    }

    // MARK: - Setup

    private func setupHierarchy() {
        stackView.addArrangedSubview(attendanceItem)
        stackView.addArrangedSubview(leadingDivider)
        stackView.addArrangedSubview(lateItem)
        stackView.addArrangedSubview(trailingDivider)
        stackView.addArrangedSubview(savedTimeItem)
        addSubview(stackView)
    }

    private func setupLayout() {
        stackView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

        [attendanceItem, lateItem, savedTimeItem].forEach {
            $0.snp.makeConstraints { make in
                make.width.equalTo(attendanceItem).priority(.high)
            }
        }

        [leadingDivider, trailingDivider].forEach {
            $0.snp.makeConstraints { make in
                make.width.equalTo(Layout.dividerWidth)
                make.height.equalTo(Layout.dividerHeight)
            }
        }
    }

    private func setupStyle() {
        backgroundColor = GTTColor.white
        layer.cornerRadius = Layout.cornerRadius
        layer.borderWidth = Layout.borderWidth
        layer.borderColor = GTTColor.divider.cgColor

        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.distribution = .fill
        stackView.spacing = Layout.itemSpacing
    }

    // MARK: - Configure

    private func configure(attendanceRate: Int, lateCount: Int, savedMinutes: Int) {
        attendanceItem.setValue("\(attendanceRate)%")
        lateItem.setValue("\(lateCount)회")
        savedTimeItem.setValue("\(savedMinutes)분")
    }

    // MARK: - Factory

    private static func makeDivider() -> UIView {
        let view = UIView()
        view.backgroundColor = GTTColor.divider
        return view
    }
}

// MARK: - StatItemView

private final class StatItemView: UIView {

    private let valueLabel = UILabel()
    private let titleLabel = UILabel()
    private let labelStack = UIStackView()

    init(color: UIColor, title: String) {
        super.init(frame: .zero)
        setupHierarchy()
        setupLayout()
        setupStyle(color: color, title: title)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupHierarchy() {
        labelStack.addArrangedSubview(valueLabel)
        labelStack.addArrangedSubview(titleLabel)
        addSubview(labelStack)
    }

    private func setupLayout() {
        labelStack.snp.makeConstraints {
            $0.center.equalToSuperview()
        }
    }

    private func setupStyle(color: UIColor, title: String) {
        labelStack.axis = .vertical
        labelStack.alignment = .center
        labelStack.spacing = Layout.labelSpacing

        valueLabel.font = GTTFont.sectionHeading.font
        valueLabel.textColor = color
        valueLabel.textAlignment = .center

        titleLabel.text = title
        titleLabel.font = GTTFont.captionSmall.font
        titleLabel.textColor = GTTColor.textSecondary
        titleLabel.textAlignment = .center
    }

    func setValue(_ value: String) {
        valueLabel.text = value
    }
}
