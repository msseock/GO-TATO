import UIKit
import SnapKit

// MARK: - Layout Constants

private enum Layout {
    static let cornerRadius: CGFloat = 20
    static let borderWidth: CGFloat = 1.5
    static let padding: CGFloat = 20
    static let circleSize: CGFloat = 60
    static let topGap: CGFloat = 16
    static let dividerHeight: CGFloat = 1
    static let sectionGap: CGFloat = 14
    static let rowGap: CGFloat = 16
    static let iconSize: CGFloat = 18
    static let rowIconGap: CGFloat = 12
    static let potatoWidth: CGFloat = 200
    static let cardHeight: CGFloat = 215
}

// MARK: - MissionSuccessCardView

final class MissionSuccessCardView: UIView {

    // MARK: - UI Components

    private let checkCircleView = UIView()
    private let checkIconView = UIImageView()
    private let completionTitleLabel = UILabel()
    private let completionSubtitleLabel = UILabel()
    private let dividerView = UIView()

    private let infoStack = UIStackView()

    private let timeRow = UIStackView()
    private let timeIconView = UIImageView()
    private let timeInfoStack = UIStackView()
    private let timeCaptionLabel = UILabel()
    private let timeValueLabel = UILabel()

    private let locationRow = UIStackView()
    private let locationIconView = UIImageView()
    private let locationInfoStack = UIStackView()
    private let locationCaptionLabel = UILabel()
    private let locationValueLabel = UILabel()

    private let potatoImageView = UIImageView()

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupHierarchy()
        setupLayout()
        setupStyle()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Intrinsic Size

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: Layout.cardHeight)
    }

    // MARK: - Setup

    private func setupHierarchy() {
        addSubview(checkCircleView)
        checkCircleView.addSubview(checkIconView)
        addSubview(completionTitleLabel)
        addSubview(completionSubtitleLabel)
        addSubview(dividerView)

        timeInfoStack.addArrangedSubview(timeCaptionLabel)
        timeInfoStack.addArrangedSubview(timeValueLabel)
        timeRow.addArrangedSubview(timeIconView)
        timeRow.addArrangedSubview(timeInfoStack)

        locationInfoStack.addArrangedSubview(locationCaptionLabel)
        locationInfoStack.addArrangedSubview(locationValueLabel)
        locationRow.addArrangedSubview(locationIconView)
        locationRow.addArrangedSubview(locationInfoStack)

        infoStack.addArrangedSubview(timeRow)
        infoStack.addArrangedSubview(locationRow)
        addSubview(infoStack)

        addSubview(potatoImageView)
    }

    private func setupLayout() {
        checkCircleView.snp.makeConstraints {
            $0.top.leading.equalToSuperview().inset(Layout.padding)
            $0.width.height.equalTo(Layout.circleSize)
        }

        checkIconView.snp.makeConstraints {
            $0.center.equalToSuperview()
            $0.width.height.equalTo(28)
        }

        completionTitleLabel.snp.makeConstraints {
            $0.bottom.equalTo(checkCircleView.snp.centerY).offset(4)
            $0.leading.equalTo(checkCircleView.snp.trailing).offset(Layout.topGap)
            $0.trailing.lessThanOrEqualToSuperview().inset(Layout.padding)
        }

        completionSubtitleLabel.snp.makeConstraints {
            $0.top.equalTo(completionTitleLabel.snp.bottom).offset(3)
            $0.leading.trailing.equalTo(completionTitleLabel)
        }

        dividerView.snp.makeConstraints {
            $0.top.equalTo(checkCircleView.snp.bottom).offset(Layout.topGap)
            $0.leading.trailing.equalToSuperview().inset(Layout.padding)
            $0.height.equalTo(Layout.dividerHeight)
        }

        timeIconView.snp.makeConstraints {
            $0.width.height.equalTo(Layout.iconSize)
        }

        locationIconView.snp.makeConstraints {
            $0.width.height.equalTo(Layout.iconSize)
        }

        infoStack.snp.makeConstraints {
            $0.top.equalTo(dividerView.snp.bottom).offset(Layout.sectionGap)
            $0.leading.equalToSuperview().inset(Layout.padding)
            $0.trailing.equalTo(potatoImageView.snp.leading).offset(-8)
        }

        potatoImageView.snp.makeConstraints {
            $0.trailing.equalToSuperview()
            $0.top.equalTo(dividerView.snp.bottom).offset(-10)
            $0.width.height.equalTo(Layout.potatoWidth)
        }
    }

    private func setupStyle() {
        backgroundColor = GTTColor.white
        layer.cornerRadius = Layout.cornerRadius
        layer.borderWidth = Layout.borderWidth
        layer.borderColor = GTTColor.successBorder.cgColor
        clipsToBounds = true

        checkCircleView.backgroundColor = GTTColor.success
        checkCircleView.layer.cornerRadius = Layout.circleSize / 2

        let checkConfig = UIImage.SymbolConfiguration(pointSize: 24, weight: .medium)
        checkIconView.image = UIImage(systemName: "checkmark", withConfiguration: checkConfig)
        checkIconView.tintColor = GTTColor.white
        checkIconView.contentMode = .scaleAspectFit

        completionTitleLabel.text = "오늘 미션 완료!"
        completionTitleLabel.font = GTTFont.cardTitle.font
        completionTitleLabel.textColor = GTTColor.textPrimary

        completionSubtitleLabel.text = "출근 기록이 저장되었습니다"
        completionSubtitleLabel.font = GTTFont.badge.font
        completionSubtitleLabel.textColor = GTTColor.textSecondary

        dividerView.backgroundColor = GTTColor.errorCard

        infoStack.axis = .vertical
        infoStack.spacing = Layout.rowGap

        // time row
        timeRow.axis = .horizontal
        timeRow.spacing = Layout.rowIconGap
        timeRow.alignment = .center

        let timerSymbolConfig = UIImage.SymbolConfiguration(pointSize: 16, weight: .regular)
        timeIconView.image = UIImage(systemName: "timer", withConfiguration: timerSymbolConfig)
        timeIconView.tintColor = GTTColor.textSecondary
        timeIconView.contentMode = .scaleAspectFit

        timeInfoStack.axis = .vertical
        timeInfoStack.spacing = 1

        timeCaptionLabel.text = "도착 시각"
        timeCaptionLabel.font = GTTFont.miniLabel.font
        timeCaptionLabel.textColor = GTTColor.textQuiet

        timeValueLabel.font = GTTFont.caption.font
        timeValueLabel.textColor = GTTColor.textPrimary

        // location row
        locationRow.axis = .horizontal
        locationRow.spacing = Layout.rowIconGap
        locationRow.alignment = .center

        let pinSymbolConfig = UIImage.SymbolConfiguration(pointSize: 16, weight: .regular)
        locationIconView.image = UIImage(systemName: "location", withConfiguration: pinSymbolConfig)
        locationIconView.tintColor = GTTColor.textSecondary
        locationIconView.contentMode = .scaleAspectFit

        locationInfoStack.axis = .vertical
        locationInfoStack.spacing = 1

        locationCaptionLabel.text = "도착 장소"
        locationCaptionLabel.font = GTTFont.miniLabel.font
        locationCaptionLabel.textColor = GTTColor.textQuiet

        locationValueLabel.font = GTTFont.caption.font
        locationValueLabel.textColor = GTTColor.textPrimary

        potatoImageView.image = UIImage(named: "PotatoNametag")
        potatoImageView.contentMode = .scaleAspectFit
    }

    // MARK: - Configure

    func configure(arrivalTime: String, arrivalLocation: String) {
        timeValueLabel.text = arrivalTime
        locationValueLabel.text = arrivalLocation
    }
}
