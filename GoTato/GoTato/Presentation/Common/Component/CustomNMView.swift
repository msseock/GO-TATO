//
//  CustomNMView.swift
//  GoTato
//
//  Created by 석민솔 on 3/25/26.
//

import NMapsMap
import SnapKit
import UIKit

/// 현재위치와 목표 위치를 입력하면 네이버 지도로 마커를 찍어주는 커스텀뷰
class CustomNMView: UIView {

    private let mapView = NMFMapView()
    private let cameraBounds: NMGLatLngBounds
    private var didMoveCamera = false

    init(currentCoord: NMGLatLng, destinationCoord: NMGLatLng) {
        let sw = NMGLatLng(
            lat: min(currentCoord.lat, destinationCoord.lat),
            lng: min(currentCoord.lng, destinationCoord.lng)
        )
        let ne = NMGLatLng(
            lat: max(currentCoord.lat, destinationCoord.lat),
            lng: max(currentCoord.lng, destinationCoord.lng)
        )
        cameraBounds = NMGLatLngBounds(southWest: sw, northEast: ne)
        super.init(frame: .zero)

        mapView.isScrollGestureEnabled = false
        mapView.isZoomGestureEnabled = false
        addSubview(mapView)
        mapView.snp.makeConstraints { $0.edges.equalToSuperview() }

        let marker1 = NMFMarker(position: currentCoord)
        marker1.iconImage = NMFOverlayImage(name: "PotatoPin")
        marker1.width = 60
        marker1.height = 60
        marker1.mapView = mapView

        let marker2 = NMFMarker(position: destinationCoord)
        marker2.iconImage = NMFOverlayImage(name: "destinationMark")
        marker2.width = 25
        marker2.height = 25
        marker2.mapView = mapView
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !didMoveCamera else { return }
        didMoveCamera = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let cameraUpdate = NMFCameraUpdate(
                fit: self.cameraBounds,
                padding: 70
            )
            self.mapView.moveCamera(cameraUpdate)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
