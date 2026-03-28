import NMapsMap
import SnapKit
import UIKit

// MARK: - State

enum OngoingMissionCardState {
    case farFromDestination(
        locationName: String,
        currentCoord: NMGLatLng,
        destinationCoord: NMGLatLng,
        distance: String
    )
    case nearDestination(
        locationName: String,
        currentCoord: NMGLatLng,
        destinationCoord: NMGLatLng
    )

    var locationName: String {
        switch self {
        case let .farFromDestination(name, _, _, _): return name
        case let .nearDestination(name, _, _):       return name
        }
    }

    var currentCoord: NMGLatLng {
        switch self {
        case let .farFromDestination(_, coord, _, _): return coord
        case let .nearDestination(_, coord, _):       return coord
        }
    }

    var destinationCoord: NMGLatLng {
        switch self {
        case let .farFromDestination(_, _, dest, _): return dest
        case let .nearDestination(_, _, dest):       return dest
        }
    }

    var chipText: String {
        switch self {
        case let .farFromDestination(_, _, _, distance): return "약 \(distance) 남았어요"
        case .nearDestination:                           return "근처에 도착했어요!"
        }
    }

    var showSubLabel: Bool {
        switch self {
        case .farFromDestination: return true
        case .nearDestination:    return false
        }
    }
}

// MARK: - Layout Constants

private enum Layout {
    static let cornerRadius: CGFloat = 20
    static let borderWidth: CGFloat = 1
    static let missionLabelTop: CGFloat = 25
    static let locationLabelTop: CGFloat = 51
    static let textLeading: CGFloat = 24
    static let mapTop: CGFloat = 80
    static let mapLeading: CGFloat = 19
    static let mapWidth: CGFloat = 326
    static let mapHeight: CGFloat = 220
    static let mapCornerRadius: CGFloat = 14
    static let chipTopGap: CGFloat = 7
    static let chipLeading: CGFloat = 19
    static let chipWidth: CGFloat = 184
    static let chipHeight: CGFloat = 66
    static let chipCornerRadius: CGFloat = 14
    static let chipIconLeading: CGFloat = 14
    static let chipIconSize: CGFloat = 20
    static let chipTextLeading: CGFloat = 12
    static let potatoWidth: CGFloat = 200
    static let potatoTop: CGFloat = 230
    static let refreshButtonSize: CGFloat = 40
    static let cardHeight: CGFloat = 389
}

// MARK: - OngoingMissionCardView

final class OngoingMissionCardView: UIView {

    // MARK: - UI Components

    private let headerStack = UIStackView()
    private let labelStack = UIStackView()
    private let missionLabel = UILabel()
    private let locationNameLabel = UILabel()
    private let refreshButton = GTTIconButton(
        systemName: "arrow.trianglehead.counterclockwise",
        symbolConfig: UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold),
        iconColor: GTTColor.black,
        backgroundColor: GTTColor.cardBorder
    )
    private let mapContainer = UIView()
    private var currentMapView: CustomNMView?

    private let distanceChip = UIView()
    private let chipIconView = UIImageView()
    private let chipSubLabel = UILabel()
    private let chipMainLabel = UILabel()
    private let chipTextStack = UIStackView()
    private let potatoImage = UIImageView()

    // MARK: - Callback

    var onRefreshTap: (() -> Void)?

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
        labelStack.addArrangedSubview(missionLabel)
        labelStack.addArrangedSubview(locationNameLabel)
        headerStack.addArrangedSubview(labelStack)
        headerStack.addArrangedSubview(refreshButton)
        addSubview(headerStack)
        addSubview(mapContainer)
        addSubview(potatoImage)
        addSubview(distanceChip)
        distanceChip.addSubview(chipIconView)
        distanceChip.addSubview(chipTextStack)
        chipTextStack.addArrangedSubview(chipSubLabel)
        chipTextStack.addArrangedSubview(chipMainLabel)
    }

    private func setupLayout() {
        refreshButton.snp.makeConstraints {
            $0.width.height.equalTo(Layout.refreshButtonSize)
        }

        headerStack.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Layout.missionLabelTop)
            $0.leading.equalToSuperview().offset(Layout.textLeading)
            $0.trailing.equalToSuperview().inset(Layout.textLeading)
        }

        mapContainer.snp.makeConstraints {
            $0.top.equalTo(headerStack.snp.bottom).offset(16)
            $0.leading.equalToSuperview().offset(Layout.mapLeading)
            $0.width.equalToSuperview().inset(16)
            $0.height.equalTo(Layout.mapHeight)
        }

        distanceChip.snp.makeConstraints {
            $0.top.equalTo(mapContainer.snp.bottom).offset(Layout.chipTopGap)
            $0.leading.equalToSuperview().offset(Layout.chipLeading)
            $0.width.equalTo(Layout.chipWidth)
            $0.height.equalTo(Layout.chipHeight)
        }

        chipIconView.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(Layout.chipIconLeading)
            $0.centerY.equalToSuperview()
            $0.width.height.equalTo(Layout.chipIconSize)
        }

        chipTextStack.snp.makeConstraints {
            $0.leading.equalTo(chipIconView.snp.trailing).offset(Layout.chipTextLeading)
            $0.trailing.equalToSuperview().inset(12)
            $0.centerY.equalToSuperview()
        }

        potatoImage.snp.makeConstraints {
            $0.trailing.equalToSuperview().offset(20)
            $0.top.equalTo(mapContainer.snp.bottom).offset(-50)
            $0.width.height.equalTo(Layout.potatoWidth)
        }
    }

    private func setupStyle() {
        backgroundColor = GTTColor.white
        layer.cornerRadius = Layout.cornerRadius
        layer.borderWidth = Layout.borderWidth
        layer.borderColor = GTTColor.cardBorder.cgColor
        clipsToBounds = true

        headerStack.axis = .horizontal
        headerStack.alignment = .center
        headerStack.distribution = .fill

        labelStack.axis = .vertical
        labelStack.spacing = 4

        missionLabel.text = "오늘의 미션"
        missionLabel.font = GTTFont.captionSmall.font
        missionLabel.textColor = GTTColor.textQuiet

        locationNameLabel.font = GTTFont.subHeading.font
        locationNameLabel.textColor = GTTColor.black

        refreshButton.onTap = { [weak self] in self?.onRefreshTap?() }

        mapContainer.layer.cornerRadius = Layout.mapCornerRadius
        mapContainer.clipsToBounds = true

        distanceChip.backgroundColor = GTTColor.infoLight
        distanceChip.layer.cornerRadius = Layout.chipCornerRadius
        distanceChip.layer.maskedCorners = [
            .layerMinXMinYCorner,
            .layerMaxXMinYCorner,
            .layerMinXMaxYCorner
        ]

        chipIconView.image = UIImage(systemName: "location")
        chipIconView.tintColor = GTTColor.infoBorder
        chipIconView.contentMode = .scaleAspectFit

        chipTextStack.axis = .vertical
        chipTextStack.spacing = 3
        chipTextStack.alignment = .leading

        chipSubLabel.text = "도착 위치까지"
        chipSubLabel.font = GTTFont.miniLabel.font
        chipSubLabel.textColor = GTTColor.textSecondary

        chipMainLabel.font = GTTFont.bodySecondary.font
        chipMainLabel.textColor = GTTColor.infoBorder

        potatoImage.image = UIImage(named: "PotatoFighting")
        potatoImage.contentMode = .scaleAspectFit
    }

    // MARK: - Configure

    func configure(state: OngoingMissionCardState) {
        locationNameLabel.text = state.locationName
        chipMainLabel.text = state.chipText
        chipSubLabel.isHidden = !state.showSubLabel
        updateMap(currentCoord: state.currentCoord, destinationCoord: state.destinationCoord)
    }

    private func updateMap(currentCoord: NMGLatLng, destinationCoord: NMGLatLng) {
        currentMapView?.removeFromSuperview()
        let mapView = CustomNMView(currentCoord: currentCoord, destinationCoord: destinationCoord)
        mapContainer.addSubview(mapView)
        mapView.snp.makeConstraints { $0.edges.equalToSuperview() }
        currentMapView = mapView
    }
}
