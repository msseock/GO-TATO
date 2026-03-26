import UIKit
import SnapKit

// MARK: - State

enum MissionFailCardState {
    case normal
    case committed

    var captionText: String {
        switch self {
        case .normal:
            return "오늘의 갓생은 잠시 로그아웃...\n내일 더 멀리 뛰기 위해 잠시 멈춘 것뿐이에요! 🥺"
        case .committed:
            return "부활 완료! 내일은 1초도 안 늦는 독기 가득 감자 출동! 🔥"
        }
    }

    var potatoImageName: String {
        switch self {
        case .normal:    return "PotatoSad"
        case .committed: return "PotatoFighting"
        }
    }
}

// MARK: - Layout Constants

private enum Layout {
    static let cornerRadius: CGFloat = 20
    static let borderWidth: CGFloat = 1.5
    static let titleTop: CGFloat = 40
    static let titleHorizontalInset: CGFloat = 16
    static let titleToCaptionGap: CGFloat = 3
    static let potatoTop: CGFloat = 88
    static let potatoSize: CGFloat = 200
    static let cardHeight: CGFloat = 215
}

// MARK: - MissionFailCardView

final class MissionFailCardView: UIView {

    // MARK: - UI Components

    private let potatoImageView = UIImageView()
    private let titleLabel = UILabel()
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

    // MARK: - Intrinsic Size

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: Layout.cardHeight)
    }

    // MARK: - Setup

    private func setupHierarchy() {
        addSubview(potatoImageView)
        addSubview(titleLabel)
        addSubview(captionLabel)
    }

    private func setupLayout() {
        potatoImageView.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Layout.potatoTop)
            $0.centerX.equalToSuperview()
            $0.width.height.equalTo(Layout.potatoSize)
        }

        titleLabel.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Layout.titleTop)
            $0.leading.trailing.equalToSuperview().inset(Layout.titleHorizontalInset)
        }

        captionLabel.snp.makeConstraints {
            $0.top.equalTo(titleLabel.snp.bottom).offset(Layout.titleToCaptionGap)
            $0.leading.trailing.equalToSuperview().inset(Layout.titleHorizontalInset)
        }
    }

    private func setupStyle() {
        backgroundColor = GTTColor.white
        layer.cornerRadius = Layout.cornerRadius
        layer.borderWidth = Layout.borderWidth
        layer.borderColor = GTTColor.errorLight.cgColor
        clipsToBounds = true

        titleLabel.text = "오늘은 출석하지 못했어요"
        titleLabel.font = GTTFont.cardTitle.font
        titleLabel.textColor = GTTColor.textPrimary
        titleLabel.textAlignment = .center

        captionLabel.font = GTTFont.badge.font
        captionLabel.textColor = GTTColor.textSecondary
        captionLabel.textAlignment = .center
        captionLabel.numberOfLines = 2

        potatoImageView.contentMode = .scaleAspectFit
    }

    // MARK: - Configure

    func configure(state: MissionFailCardState) {
        captionLabel.text = state.captionText
        potatoImageView.image = UIImage(named: state.potatoImageName)
    }
}
