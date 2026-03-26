import UIKit
import SnapKit

// MARK: - Layout Constants

private enum Layout {
    static let cardCornerRadius: CGFloat = 20
    static let cardPadding: CGFloat = 16
    static let cardBorderWidth: CGFloat = 1.5
    static let badgePaddingH: CGFloat = 10
    static let badgePaddingV: CGFloat = 4
    static let badgeToMainGap: CGFloat = 8
    static let mainToCaptionGap: CGFloat = 8
}

// MARK: - State Enum

enum DashBoardMessageCardState {
    case noMission
    case commutingOnTime(leftTime: String, time: String, location: String)
    case commutingLate(lateTime: String, location: String)
    case successOnTime(earlyMinutes: Int)
    case successLate(lateTime: String)
    case failed

    var badgeText: String {
        switch self {
        case .noMission:                         return "출근 미설정"
        case .commutingOnTime, .commutingLate:   return "출근중"
        case .successOnTime, .successLate:       return "출근 완료"
        case .failed:                            return "출근 실패"
        }
    }

    var mainText: String {
        switch self {
        case .noMission:
            return "아직 출근 미션을 설정하지 않으셨어요"
        case let .commutingOnTime(leftTime, _, _):
            return "세이프까지 남은 시간: \(leftTime)"
        case let .commutingLate(lateTime, _):
            return "\(lateTime) 지각이에요"
        case let .successOnTime(earlyMinutes):
            return "\(earlyMinutes)분이나 일찍 왔어요!"
        case .successLate:
            return "그래도 포기하지 않고 출근했네요!"
        case .failed:
            return "3시간 내에 도착하지 못했어요"
        }
    }

    var captionText: String {
        switch self {
        case .noMission:
            return "도착지와 시간을 설정하면 GPS 출근 인증이 시작됩니다"
        case let .commutingOnTime(_, time, location):
            return "\(time)까지 \(location) 감자!"
        case let .commutingLate(_, location):
            return "아직 괜찮아! \(location) 감자!"
        case .successOnTime:
            return "내일도 이 기세로 달려봐요!"
        case let .successLate(lateTime):
            return "\(lateTime) 지각"
        case .failed:
            return "오늘 실패는 잊고, 내일은 갓생 감자!"
        }
    }
}

// MARK: - Card Style

private struct CardStyle {
    let badgeBgColor: UIColor
    let badgeTextColor: UIColor
    let cardBgColor: UIColor
    let cardBorderColor: UIColor
    let mainTextColor: UIColor
    let captionColor: UIColor
    let mainFont: UIFont
    let captionFont: UIFont

    static func make(for state: DashBoardMessageCardState) -> CardStyle {
        switch state {
        case .noMission:
            return CardStyle(
                badgeBgColor: GTTColor.divider,
                badgeTextColor: GTTColor.textQuiet,
                cardBgColor: GTTColor.white,
                cardBorderColor: GTTColor.divider,
                mainTextColor: GTTColor.black,
                captionColor: GTTColor.textSecondary,
                mainFont: GTTFont.subHeading.font,
                captionFont: GTTFont.captionSmall.font
            )
        case .commutingOnTime:
            return CardStyle(
                badgeBgColor: GTTColor.infoBorder,
                badgeTextColor: GTTColor.infoLight,
                cardBgColor: GTTColor.infoLight,
                cardBorderColor: GTTColor.infoBorder,
                mainTextColor: GTTColor.textPrimary,
                captionColor: GTTColor.infoBorder,
                mainFont: GTTFont.subHeading.font,
                captionFont: GTTFont.captionSmall.font
            )
        case .commutingLate:
            return CardStyle(
                badgeBgColor: GTTColor.brandAmber,
                badgeTextColor: GTTColor.warningBrown,
                cardBgColor: GTTColor.bgCard,
                cardBorderColor: GTTColor.warningBorder,
                mainTextColor: GTTColor.textPrimary,
                captionColor: GTTColor.warningOrange,
                mainFont: GTTFont.bodySecondary.font,
                captionFont: GTTFont.badge.font
            )
        case .successOnTime, .successLate:
            return CardStyle(
                badgeBgColor: GTTColor.success,
                badgeTextColor: GTTColor.white,
                cardBgColor: GTTColor.successCard,
                cardBorderColor: GTTColor.success,
                mainTextColor: GTTColor.textPrimary,
                captionColor: GTTColor.success,
                mainFont: GTTFont.bodySecondary.font,
                captionFont: GTTFont.badge.font
            )
        case .failed:
            return CardStyle(
                badgeBgColor: GTTColor.errorSolid,
                badgeTextColor: GTTColor.errorPale,
                cardBgColor: GTTColor.errorCard,
                cardBorderColor: GTTColor.errorSolid,
                mainTextColor: GTTColor.textPrimary,
                captionColor: GTTColor.errorSolid,
                mainFont: GTTFont.bodySecondary.font,
                captionFont: GTTFont.badge.font
            )
        }
    }
}

// MARK: - DashBoardMessageCardView

final class DashBoardMessageCardView: UIView {

    // MARK: - UI Components

    private let cardContainerView = UIView()
    private let badgeLabel = PaddedLabel(insets: UIEdgeInsets(
        top: Layout.badgePaddingV,
        left: Layout.badgePaddingH,
        bottom: Layout.badgePaddingV,
        right: Layout.badgePaddingH
    ))
    private let mainLabel = UILabel()
    private let captionLabel = UILabel()

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

    // MARK: - Setup

    private func setupHierarchy() {
        addSubview(cardContainerView)
        cardContainerView.addSubview(badgeLabel)
        cardContainerView.addSubview(mainLabel)
        cardContainerView.addSubview(captionLabel)
    }

    private func setupLayout() {
        cardContainerView.snp.makeConstraints { $0.edges.equalToSuperview() }

        badgeLabel.snp.makeConstraints {
            $0.top.leading.equalToSuperview().inset(Layout.cardPadding)
        }

        mainLabel.snp.makeConstraints {
            $0.top.equalTo(badgeLabel.snp.bottom).offset(Layout.badgeToMainGap)
            $0.leading.trailing.equalToSuperview().inset(Layout.cardPadding)
        }

        captionLabel.snp.makeConstraints {
            $0.top.equalTo(mainLabel.snp.bottom).offset(Layout.mainToCaptionGap)
            $0.leading.trailing.equalToSuperview().inset(Layout.cardPadding)
            $0.bottom.equalToSuperview().inset(Layout.cardPadding)
        }
    }

    private func setupStyle() {
        cardContainerView.layer.cornerRadius = Layout.cardCornerRadius
        cardContainerView.layer.borderWidth = Layout.cardBorderWidth

        badgeLabel.font = GTTFont.captionSmall.font
        badgeLabel.clipsToBounds = true

        mainLabel.numberOfLines = 2
        captionLabel.numberOfLines = 2
    }

    // MARK: - Configure

    func configure(state: DashBoardMessageCardState) {
        let style = CardStyle.make(for: state)

        badgeLabel.text = state.badgeText
        badgeLabel.backgroundColor = style.badgeBgColor
        badgeLabel.textColor = style.badgeTextColor

        cardContainerView.backgroundColor = style.cardBgColor
        cardContainerView.layer.borderColor = style.cardBorderColor.cgColor

        mainLabel.text = state.mainText
        mainLabel.font = style.mainFont
        mainLabel.textColor = style.mainTextColor

        captionLabel.text = state.captionText
        captionLabel.font = style.captionFont
        captionLabel.textColor = style.captionColor
    }
}

// MARK: - PaddedLabel

private final class PaddedLabel: UILabel {

    var contentInsets: UIEdgeInsets

    init(insets: UIEdgeInsets) {
        self.contentInsets = insets
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2
    }

    override var intrinsicContentSize: CGSize {
        let base = super.intrinsicContentSize
        return CGSize(
            width: base.width + contentInsets.left + contentInsets.right,
            height: base.height + contentInsets.top + contentInsets.bottom
        )
    }

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: contentInsets))
    }
}
