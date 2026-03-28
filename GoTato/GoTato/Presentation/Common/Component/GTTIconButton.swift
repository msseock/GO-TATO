import UIKit
import SnapKit

// MARK: - GTTIconButton

/// 아이콘 하나를 품은 원형 버튼 컴포넌트.
/// - Parameters:
///   - icon: SF Symbol 이름 또는 UIImage
///   - iconColor: 아이콘 틴트 색상 (기본: GTTColor.black)
///   - backgroundColor: 버튼 배경 색상 (기본: GTTColor.cardBorder)
///   - size: 버튼 한 변의 길이 (기본: 40)
final class GTTIconButton: UIControl {

    // MARK: - Callback

    var onTap: (() -> Void)?

    // MARK: - UI

    private let iconView = UIImageView()

    // MARK: - Private

    private let buttonSize: CGFloat

    // MARK: - UIControl Overrides

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: isHighlighted ? 0.1 : 0.15) {
                self.alpha = self.isHighlighted ? 0.7 : 1.0
            }
        }
    }

    // MARK: - Init

    init(
        icon: UIImage?,
        iconColor: UIColor = GTTColor.black,
        backgroundColor: UIColor = GTTColor.cardBorder,
        size: CGFloat = 40
    ) {
        self.buttonSize = size
        super.init(frame: .zero)
        setupHierarchy()
        setupLayout()
        setupStyle(icon: icon, iconColor: iconColor, backgroundColor: backgroundColor)
        addTarget(self, action: #selector(handleTap), for: .touchUpInside)
    }

    convenience init(
        systemName: String,
        symbolConfig: UIImage.SymbolConfiguration? = nil,
        iconColor: UIColor = GTTColor.black,
        backgroundColor: UIColor = GTTColor.cardBorder,
        size: CGFloat = 40
    ) {
        let image = symbolConfig != nil
            ? UIImage(systemName: systemName, withConfiguration: symbolConfig!)
            : UIImage(systemName: systemName)
        self.init(icon: image, iconColor: iconColor, backgroundColor: backgroundColor, size: size)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Intrinsic Size

    override var intrinsicContentSize: CGSize {
        CGSize(width: buttonSize, height: buttonSize)
    }

    // MARK: - Setup

    private func setupHierarchy() {
        addSubview(iconView)
    }

    private func setupLayout() {
        snp.makeConstraints {
            $0.width.height.equalTo(buttonSize)
        }

        iconView.snp.makeConstraints {
            $0.center.equalToSuperview()
            $0.width.height.equalTo(buttonSize * 0.5)
        }
    }

    private func setupStyle(icon: UIImage?, iconColor: UIColor, backgroundColor: UIColor) {
        self.backgroundColor = backgroundColor
        layer.cornerRadius = buttonSize / 2
        clipsToBounds = true

        iconView.image = icon
        iconView.tintColor = iconColor
        iconView.contentMode = .scaleAspectFit
        iconView.isUserInteractionEnabled = false
    }

    // MARK: - Configure

    func configure(icon: UIImage? = nil, iconColor: UIColor? = nil, backgroundColor: UIColor? = nil) {
        if let icon { iconView.image = icon }
        if let iconColor { iconView.tintColor = iconColor }
        if let backgroundColor { self.backgroundColor = backgroundColor }
    }

    // MARK: - Action

    @objc private func handleTap() {
        onTap?()
    }
}
