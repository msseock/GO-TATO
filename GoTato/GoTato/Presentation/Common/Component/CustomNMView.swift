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
    private var cameraBounds: NMGLatLngBounds?
    private var singleCoord: NMGLatLng?
    private var didMoveCamera = false
    private var marker: NMFMarker?

    init(currentCoord: NMGLatLng, destinationCoord: NMGLatLng) {
        let sw = NMGLatLng(
            lat: min(currentCoord.lat, destinationCoord.lat),
            lng: min(currentCoord.lng, destinationCoord.lng)
        )
        let ne = NMGLatLng(
            lat: max(currentCoord.lat, destinationCoord.lat),
            lng: max(currentCoord.lng, destinationCoord.lng)
        )
        self.cameraBounds = NMGLatLngBounds(southWest: sw, northEast: ne)
        self.singleCoord = nil
        super.init(frame: .zero)

        mapView.isScrollGestureEnabled = false
        mapView.isZoomGestureEnabled = false
        mapView.isUserInteractionEnabled = false
        addSubview(mapView)
        mapView.snp.makeConstraints { $0.edges.equalToSuperview() }

        let marker1 = NMFMarker(position: currentCoord)
        marker1.iconImage = NMFOverlayImage(name: "PotatoPin")
        marker1.width = 60
        marker1.height = 60
        marker1.mapView = mapView

        let marker2 = NMFMarker(position: destinationCoord)
        marker2.iconImage = NMFOverlayImage(name: "destinationMark")
        marker2.anchor = CGPoint(x: 0.5, y: 0.5)
        marker2.width = 25
        marker2.height = 25
        marker2.mapView = mapView
        self.marker = marker2
    }
    
    init(mapx: Int, mapy: Int) {
        
        let tm128 = NMGTm128(x: Double(mapx), y: Double(mapy))
        let coord = tm128.toLatLng()
        
        self.cameraBounds = nil
        self.singleCoord = coord
        super.init(frame: .zero)
        
        mapView.isScrollGestureEnabled = true
        mapView.isZoomGestureEnabled = true
        addSubview(mapView)
        mapView.snp.makeConstraints { $0.edges.equalToSuperview() }
        
        let marker = NMFMarker(position: coord)
        marker.iconImage = NMFOverlayImage(name: "destinationMark")
        marker.anchor = CGPoint(x: 0.5, y: 0.5)
        marker.width = 25
        marker.height = 25
        marker.mapView = mapView
        self.marker = marker
    }

    init(coord: NMGLatLng, isInteractive: Bool = false) {
        self.cameraBounds = nil
        self.singleCoord = coord
        super.init(frame: .zero)

        mapView.isScrollGestureEnabled = isInteractive
        mapView.isZoomGestureEnabled = isInteractive
        mapView.isUserInteractionEnabled = isInteractive
        addSubview(mapView)
        mapView.snp.makeConstraints { $0.edges.equalToSuperview() }

        let marker = NMFMarker(position: coord)
        marker.iconImage = NMFOverlayImage(name: "destinationMark")
        marker.anchor = CGPoint(x: 0.5, y: 0.5)
        marker.width = 25
        marker.height = 25
        marker.mapView = mapView
        self.marker = marker
    }

    func updateCoord(coord: NMGLatLng) {
        self.singleCoord = coord
        if marker == nil {
            let newMarker = NMFMarker(position: coord)
            newMarker.iconImage = NMFOverlayImage(name: "destinationMark")
            newMarker.anchor = CGPoint(x: 0.5, y: 0.5)
            newMarker.width = 25
            newMarker.height = 25
            self.marker = newMarker
        }
        marker?.position = coord
        marker?.mapView = mapView
        
        let update = NMFCameraUpdate(scrollTo: coord)
        update.animation = .easeIn
        mapView.moveCamera(update)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !didMoveCamera else { return }
        didMoveCamera = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            
            if let bounds = self.cameraBounds {
                let cameraUpdate = NMFCameraUpdate(
                    fit: bounds,
                    padding: 70
                )
                self.mapView.moveCamera(cameraUpdate)
            } else if let coord = self.singleCoord {
                let cameraUpdate = NMFCameraUpdate(scrollTo: coord)
                self.mapView.moveCamera(cameraUpdate)
            }
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
