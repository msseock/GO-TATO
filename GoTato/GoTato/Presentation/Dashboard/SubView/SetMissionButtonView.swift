import UIKit
import SnapKit

// MARK: - Layout Constants

private enum Layout {
    static let cornerRadius: CGFloat = 20
    static let titleTop: CGFloat = 34
    static let textLeading: CGFloat = 24
    static let titleToSubtitleGap: CGFloat = 9
    static let potatoLeading: CGFloat = 199
    static let potatoTop: CGFloat = 53
    static let potatoSize: CGFloat = 219
    static let cardHeight: CGFloat = 192
}

// MARK: - SetMissionButtonView

final class SetMissionButtonView: UIView {

    // MARK: - UI Components

    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let potatoImageView = UIImageView()

    // MARK: - Callback

    var onTap: (() -> Void)?

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupHierarchy()
        setupLayout()
        setupStyle()
        setupGesture()
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
        addSubview(subtitleLabel)
    }

    private func setupLayout() {
        titleLabel.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Layout.titleTop)
            $0.leading.equalToSuperview().offset(Layout.textLeading)
            $0.trailing.equalToSuperview().inset(Layout.textLeading)
        }

        subtitleLabel.snp.makeConstraints {
            $0.top.equalTo(titleLabel.snp.bottom).offset(Layout.titleToSubtitleGap)
            $0.leading.equalToSuperview().offset(Layout.textLeading)
            $0.trailing.equalToSuperview().inset(24)
        }

        potatoImageView.snp.makeConstraints {
            $0.top.equalTo(titleLabel.snp.bottom).offset(-10)
            $0.trailing.equalToSuperview().offset(50)
            
            // 부모 뷰(superview) 너비의 2/3 만큼 설정
            $0.width.equalToSuperview().multipliedBy(2.0 / 3.0)
            
            // 만약 정사각형으로 만들고 싶다면 너비에 맞춤
            $0.height.equalTo(potatoImageView.snp.width)
        }
    }

    private func setupStyle() {
        backgroundColor = GTTColor.brand
        layer.cornerRadius = Layout.cornerRadius
        clipsToBounds = true

        titleLabel.text = "출근 설정하기"
        titleLabel.font = GTTFont.missionTitle.font
        titleLabel.textColor = GTTColor.white

        subtitleLabel.text = "도착 장소와 시간을 설정해\n미션을 만들어보세요"
        subtitleLabel.font = GTTFont.subHeading.font
        subtitleLabel.textColor = GTTColor.white
        subtitleLabel.numberOfLines = 2

        potatoImageView.image = UIImage(named: "PotatoSparkle")
        potatoImageView.contentMode = .scaleAspectFit
    }

    private func setupGesture() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tap)
        isUserInteractionEnabled = true
    }

    @objc private func handleTap() {
        onTap?()
    }
}
