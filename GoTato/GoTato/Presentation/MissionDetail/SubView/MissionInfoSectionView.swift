//
//  MissionInfoSectionView.swift
//  GoTato
//

import UIKit
import SnapKit

final class MissionInfoSectionView: UIView {

    // MARK: - UI

    private let titleLabel    = UILabel()
    private let locationRow   = InfoRowView(icon: "mappin.and.ellipse")
    private let periodRow     = InfoRowView(icon: "calendar")
    private let deadlineRow   = InfoRowView(icon: "clock")
    private let infoStack     = UIStackView()

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupHierarchy()
        setupLayout()
        setupStyle()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Setup

    private func setupHierarchy() {
        addSubview(titleLabel)
        infoStack.addArrangedSubview(locationRow)
        infoStack.addArrangedSubview(periodRow)
        infoStack.addArrangedSubview(deadlineRow)
        addSubview(infoStack)
    }

    private func setupLayout() {
        titleLabel.snp.makeConstraints {
            $0.top.equalToSuperview().inset(20)
            $0.leading.trailing.equalToSuperview().inset(16)
        }
        infoStack.snp.makeConstraints {
            $0.top.equalTo(titleLabel.snp.bottom).offset(12)
            $0.leading.trailing.equalToSuperview().inset(16)
            $0.bottom.equalToSuperview().inset(20)
        }
    }

    private func setupStyle() {
        backgroundColor    = GTTColor.bgCard
        layer.cornerRadius = 12
        clipsToBounds      = true

        titleLabel.font          = GTTFont.sectionHeading.font
        titleLabel.textColor     = GTTColor.textPrimary
        titleLabel.numberOfLines = 0

        infoStack.axis    = .vertical
        infoStack.spacing = 6
    }

    // MARK: - Configure

    func configure(title: String, locationName: String?, startDate: Date, endDate: Date, deadline: Date) {
        titleLabel.text = title

        if let name = locationName, !name.isEmpty {
            locationRow.configure(text: name)
            locationRow.isHidden = false
        } else {
            locationRow.isHidden = true
        }

        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "ko_KR")
        fmt.dateFormat = "M월 d일"
        let cal = Calendar.current
        if cal.isDate(startDate, inSameDayAs: endDate) {
            periodRow.configure(text: fmt.string(from: startDate))
        } else {
            periodRow.configure(text: "\(fmt.string(from: startDate)) ~ \(fmt.string(from: endDate))")
        }

        let timeFmt = DateFormatter()
        timeFmt.dateFormat = "HH:mm"
        deadlineRow.configure(text: timeFmt.string(from: deadline))
    }
}

// MARK: - InfoRowView

private final class InfoRowView: UIView {

    private let iconView  = UIImageView()
    private let textLabel = UILabel()

    init(icon: String) {
        super.init(frame: .zero)
        let config = UIImage.SymbolConfiguration(pointSize: 13, weight: .medium)
        iconView.image     = UIImage(systemName: icon, withConfiguration: config)
        iconView.tintColor = GTTColor.textSecondary
        iconView.contentMode = .scaleAspectFit

        textLabel.font      = GTTFont.caption.font
        textLabel.textColor = GTTColor.textSecondary
        textLabel.numberOfLines = 0

        addSubview(iconView)
        addSubview(textLabel)

        iconView.snp.makeConstraints {
            $0.leading.equalToSuperview()
            $0.centerY.equalTo(textLabel)
            $0.width.height.equalTo(16)
        }
        textLabel.snp.makeConstraints {
            $0.leading.equalTo(iconView.snp.trailing).offset(6)
            $0.top.bottom.trailing.equalToSuperview()
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(text: String) { textLabel.text = text }
}
