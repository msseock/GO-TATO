//
//  AttendanceRecordCardView.swift
//  GoTato
//

import UIKit
import SnapKit

// MARK: - AttendanceRecordState

enum AttendanceRecordState {
    /// 당일 미션 없음
    case noMission
    /// 출근 성공 (status=1)
    case success(locationName: String, minutesDiff: Int)
    /// 지각 후 도착 (status=2)
    case late(locationName: String, minutesDiff: Int)
    /// 출근 진행 중 (status=0, 오늘만 가능)
    case inProgress(locationName: String)
    /// 출근 실패 (status=3, 4)
    case failure(locationName: String)

    var caption: String {
        switch self {
        case .noMission:
            return ""
        case .success(_, let diff):
            // status=1: minutesDiff = planDate - recordDate → 양수 (일찍 도착한 분 수)
            return "\(diff)분 일찍 도착!"
        case .late(_, let diff):
            // status=2: recordDate >= planDate → diff >= 0
            if diff == 0 { return "딱 맞게 도착!" }
            let h = diff / 60
            let m = diff % 60
            let timeText = h > 0 ? "\(h)시간 \(m)분" : "\(m)분"
            return timeText + " 지각이지만, 도착!"
        case .inProgress:
            return "갈 준비 중"
        case .failure:
            return "3시간 내에 도착하지 못했어요"
        }
    }

    fileprivate var locationName: String? {
        switch self {
        case .noMission:
            return nil
        case .success(let name, _),
             .late(let name, _),
             .inProgress(let name),
             .failure(let name):
            return name
        }
    }

    fileprivate var image: UIImage? {
        switch self {
        case .noMission:
            return UIImage(named: "PotatoSad")
        case .success, .late:
            return UIImage(named: "PotatoNametag")
        case .inProgress:
            return UIImage(named: "PotatoDefault")
        case .failure:
            return UIImage(named: "PotatoSprout")
        }
    }

    fileprivate var borderColor: UIColor {
        switch self {
        case .noMission:
            return GTTColor.divider
        case .success, .late:
            return GTTColor.successBg
        case .inProgress:
            return GTTColor.warningBg
        case .failure:
            return GTTColor.errorLight
        }
    }
}

// MARK: - Layout Constants

private enum Layout {
    static let cornerRadius: CGFloat = 16
    static let borderWidth: CGFloat = 1.5
    static let padding: CGFloat = 16
    static let imageSize: CGFloat = 100
    static let imageTextSpacing: CGFloat = 12
    static let textGap: CGFloat = 2
}

// MARK: - AttendanceRecordCardView

final class AttendanceRecordCardView: UIView {

    // MARK: - UI Components

    private let potatoImageView = UIImageView()
    private let messageLabel    = UILabel()
    private let textStack       = UIStackView()
    private let locationLabel   = UILabel()
    private let captionLabel    = UILabel()

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
        addSubview(potatoImageView)
        addSubview(messageLabel)
        textStack.addArrangedSubview(locationLabel)
        textStack.addArrangedSubview(captionLabel)
        addSubview(textStack)
    }

    private func setupLayout() {
        potatoImageView.snp.makeConstraints {
            $0.leading.top.bottom.equalToSuperview().inset(Layout.padding)
            $0.width.height.equalTo(Layout.imageSize)
        }

        messageLabel.snp.makeConstraints {
            $0.leading.equalTo(potatoImageView.snp.trailing).offset(Layout.imageTextSpacing)
            $0.trailing.equalToSuperview().inset(Layout.padding)
            $0.centerY.equalToSuperview()
        }

        textStack.snp.makeConstraints {
            $0.leading.equalTo(potatoImageView.snp.trailing).offset(Layout.imageTextSpacing)
            $0.trailing.equalToSuperview().inset(Layout.padding)
            $0.centerY.equalToSuperview()
        }
    }

    private func setupStyle() {
        backgroundColor = GTTColor.white
        layer.cornerRadius = Layout.cornerRadius
        layer.borderWidth = Layout.borderWidth
        clipsToBounds = true

        potatoImageView.contentMode = .scaleAspectFit

        messageLabel.font = GTTFont.bodySecondary.font
        messageLabel.textColor = GTTColor.black
        messageLabel.numberOfLines = 0

        textStack.axis = .vertical
        textStack.spacing = Layout.textGap
        textStack.alignment = .leading

        locationLabel.font = GTTFont.subHeading.font
        locationLabel.textColor = GTTColor.black

        captionLabel.font = GTTFont.bodySecondary.font
        captionLabel.textColor = GTTColor.labelSecondary
    }

    // MARK: - Configure

    func configure(state: AttendanceRecordState) {
        potatoImageView.image = state.image
        layer.borderColor = state.borderColor.cgColor

        switch state {
        case .noMission:
            messageLabel.isHidden = false
            textStack.isHidden = true
            messageLabel.text = "오늘의 미션이 없어요.\n미션을 만들어서 확인해보세요"
        case .success, .late, .inProgress, .failure:
            messageLabel.isHidden = true
            textStack.isHidden = false
            locationLabel.text = state.locationName
            captionLabel.text = state.caption
        }
    }
}
