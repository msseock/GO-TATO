//
//  GTTMainButton.swift
//  GoTato
//

import UIKit
import SnapKit

// MARK: - GTTButtonStyle

enum GTTButtonStyle {
    case primary   // 강조색 (기본)
    case secondary // 비활성 스타일

    var backgroundColor: UIColor {
        switch self {
        case .primary:   return GTTColor.brand
        case .secondary: return GTTColor.divider
        }
    }

    var foregroundColor: UIColor {
        switch self {
        case .primary:   return GTTColor.white
        case .secondary: return GTTColor.textQuiet
        }
    }
}

// MARK: - Layout Constants

private enum Layout {
    static let height: CGFloat = 52
    static let cornerRadius: CGFloat = 14
    static let iconSize: CGFloat = 17
    static let gap: CGFloat = 8
}

// MARK: - GTTMainButton

final class GTTMainButton: UIControl {

    // MARK: - Callback

    var onTap: (() -> Void)?

    // MARK: - State

    private var activeStyle: GTTButtonStyle = .primary

    // MARK: - UIControl Overrides

    /// isEnabled = false 시 자동으로 secondary 스타일로 전환
    override var isEnabled: Bool {
        get { super.isEnabled }
        set {
            super.isEnabled = newValue
            applyStyle(newValue ? activeStyle : .secondary)
        }
    }

    /// 터치 피드백
    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: isHighlighted ? 0.1 : 0.15) {
                self.alpha = self.isHighlighted ? 0.8 : 1.0
            }
        }
    }

    // MARK: - UI Components

    private let contentStack = UIStackView()
    private let iconView     = UIImageView()
    private let titleLabel   = UILabel()

    // MARK: - Init

    init(title: String, icon: UIImage? = nil, style: GTTButtonStyle = .primary) {
        self.activeStyle = style
        super.init(frame: .zero)
        setupHierarchy()
        setupLayout()
        setupStyle(title: title, icon: icon, style: style)
        addTarget(self, action: #selector(handleTap), for: .touchUpInside)
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
        contentStack.addArrangedSubview(iconView)
        contentStack.addArrangedSubview(titleLabel)
        addSubview(contentStack)
    }

    private func setupLayout() {
        contentStack.snp.makeConstraints {
            $0.center.equalToSuperview()
        }

        iconView.snp.makeConstraints {
            $0.width.height.equalTo(Layout.iconSize)
        }
    }

    private func setupStyle(title: String, icon: UIImage?, style: GTTButtonStyle) {
        layer.cornerRadius = Layout.cornerRadius
        clipsToBounds = true

        contentStack.axis = .horizontal
        contentStack.spacing = Layout.gap
        contentStack.alignment = .center
        contentStack.isUserInteractionEnabled = false

        iconView.image = icon
        iconView.contentMode = .scaleAspectFit
        iconView.isHidden = icon == nil

        titleLabel.text = title
        titleLabel.font = GTTFont.bodySecondary.font
        titleLabel.isUserInteractionEnabled = false

        applyStyle(style)
    }

    private func applyStyle(_ style: GTTButtonStyle) {
        backgroundColor = style.backgroundColor
        titleLabel.textColor = style.foregroundColor
        iconView.tintColor = style.foregroundColor
    }

    // MARK: - Action

    @objc private func handleTap() {
        onTap?()
    }

    // MARK: - Configure

    func configure(title: String? = nil, icon: UIImage? = nil, style: GTTButtonStyle? = nil) {
        if let title { titleLabel.text = title }
        if let style {
            activeStyle = style
            if isEnabled { applyStyle(style) }
        }
        if let icon {
            iconView.image = icon
            iconView.isHidden = false
        }
    }
}
