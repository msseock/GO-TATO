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
    let didEnterRegion = PublishRelay<CLRegion>()

    private override init() {
        authorizationStatus = BehaviorRelay(value: manager.authorizationStatus)
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.distanceFilter = 10
        manager.allowsBackgroundLocationUpdates = true
    }

    // MARK: - Authorization

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

    func requestAlwaysAuthorization() {
        manager.requestAlwaysAuthorization()
    }

    // MARK: - Location Updates (포그라운드 폴링용)

    func startUpdatingLocation() {
        manager.startUpdatingLocation()
    }

    func stopUpdatingLocation() {
        manager.stopUpdatingLocation()
    }

    // MARK: - Region Monitoring (지오펜싱)

    func startMonitoringRegion(center: CLLocationCoordinate2D, radius: CLLocationDistance, identifier: String) {
        guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else { return }
        guard authorizationStatus.value == .authorizedAlways else { return }

        let region = CLCircularRegion(center: center, radius: radius, identifier: identifier)
        region.notifyOnEntry = true
        region.notifyOnExit = false
        manager.startMonitoring(for: region)
    }

    func stopMonitoringRegion(identifier: String) {
        for region in manager.monitoredRegions {
            if region.identifier == identifier {
                manager.stopMonitoring(for: region)
                break
            }
        }
    }

    var monitoredRegionIdentifiers: Set<String> {
        Set(manager.monitoredRegions.map(\.identifier))
    }

    func stopMonitoringAllRegions() {
        for region in manager.monitoredRegions {
            manager.stopMonitoring(for: region)
        }
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

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        didEnterRegion.accept(region)
    }

    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {}

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}
