//
//  LocationPermissionRequiredView.swift
//  GoTato
//

import SnapKit
import UIKit

// MARK: - Layout Constants

private enum Layout {
    static let cornerRadius: CGFloat = 20
    static let borderWidth: CGFloat = 1.5
    static let titleTop: CGFloat = 40
    static let titleHorizontalInset: CGFloat = 16
    static let titleToCaptionGap: CGFloat = 3
    static let captionToButtonGap: CGFloat = 24
    static let buttonHorizontalInset: CGFloat = 16
    static let buttonBottom: CGFloat = 24
    static let potatoTop: CGFloat = 120
    static let potatoSize: CGFloat = 220
    static let cardHeight: CGFloat = 340
}

// MARK: - LocationPermissionRequiredView

final class LocationPermissionRequiredView: UIView {

    // MARK: - UI Components

    private let potatoImageView = UIImageView()
    private let titleLabel = UILabel()
    private let captionLabel = UILabel()
    private let settingsButton = GTTMainButton(title: "환경설정으로 이동하기")

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
        addSubview(potatoImageView) // Background
        addSubview(titleLabel)
        addSubview(captionLabel)
        addSubview(settingsButton)
        sendSubviewToBack(potatoImageView)
    }

    private func setupLayout() {
        titleLabel.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Layout.titleTop)
            $0.leading.trailing.equalToSuperview().inset(Layout.titleHorizontalInset)
        }

        captionLabel.snp.makeConstraints {
            $0.top.equalTo(titleLabel.snp.bottom).offset(Layout.titleToCaptionGap)
            $0.leading.trailing.equalToSuperview().inset(Layout.titleHorizontalInset)
        }

        settingsButton.snp.makeConstraints {
            $0.top.equalTo(captionLabel.snp.bottom).offset(Layout.captionToButtonGap)
            $0.leading.trailing.equalToSuperview().inset(Layout.buttonHorizontalInset)
            $0.bottom.lessThanOrEqualToSuperview().inset(Layout.buttonBottom)
        }
        
        potatoImageView.snp.makeConstraints {
            $0.top.equalTo(settingsButton.snp.bottom).offset(20)
            $0.centerX.equalToSuperview()
            $0.width.height.equalTo(Layout.potatoSize)
        }
        
    }

    private func setupStyle() {
        backgroundColor = GTTColor.white
        layer.cornerRadius = Layout.cornerRadius
        layer.borderWidth = Layout.borderWidth
        layer.borderColor = GTTColor.cardBorder.cgColor
        clipsToBounds = true

        potatoImageView.image = UIImage(named: "PotatoSad")
        potatoImageView.contentMode = .scaleAspectFit

        titleLabel.text = "위치를 알 수 없어요"
        titleLabel.font = GTTFont.cardTitle.font
        titleLabel.textColor = GTTColor.textPrimary
        titleLabel.textAlignment = .center

        captionLabel.text = "아래 버튼을 눌러 환경설정에서\n위치 권한을 허용해주세요"
        captionLabel.font = GTTFont.badge.font
        captionLabel.textColor = GTTColor.textSecondary
        captionLabel.textAlignment = .center
        captionLabel.numberOfLines = 2

        settingsButton.onTap = {
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            UIApplication.shared.open(url)
        }
    }
}
