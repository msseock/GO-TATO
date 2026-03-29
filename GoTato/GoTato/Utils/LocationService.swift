//
//  LocationService.swift
//  GoTato
//

import CoreLocation
import RxCocoa
import RxSwift

final class LocationService: NSObject {
    static let shared = LocationService()

    private let manager = CLLocationManager()
    let authorizationStatus: BehaviorRelay<CLAuthorizationStatus>
    let currentLocation = PublishRelay<CLLocation>()

    private override init() {
        authorizationStatus = BehaviorRelay(value: manager.authorizationStatus)
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.distanceFilter = 10
    }

    func checkLocationAuthorization() {
        if !CLLocationManager.locationServicesEnabled() {
            authorizationStatus.accept(.denied)
            return
        }
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            authorizationStatus.accept(manager.authorizationStatus)
        case .authorizedWhenInUse, .authorizedAlways:
            authorizationStatus.accept(manager.authorizationStatus)
        @unknown default:
            break
        }
    }

    func startUpdatingLocation() {
        manager.startUpdatingLocation()
    }

    func stopUpdatingLocation() {
        manager.stopUpdatingLocation()
    }
}

extension LocationService: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        checkLocationAuthorization()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation.accept(location)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}
