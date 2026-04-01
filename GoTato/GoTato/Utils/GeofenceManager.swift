//
//  GeofenceManager.swift
//  GoTato
//

import CoreLocation
import CoreData
import RxCocoa
import RxSwift

final class GeofenceManager {
    static let shared = GeofenceManager()

    private let locationService = LocationService.shared
    private let notificationService = NotificationService.shared
    private let stack = CoreDataStack.shared
    private let bag = DisposeBag()

    static let regionRadius: CLLocationDistance = 100
    static let regionPrefix = "geofence-"

    private init() {
        observeRegionEntry()
    }

    // MARK: - Region Registration

    func registerRegion(for mission: Mission) {
        guard let missionID = mission.id,
              let location = mission.location else { return }

        let center = CLLocationCoordinate2D(latitude: location.lati, longitude: location.longi)
        let identifier = Self.regionPrefix + missionID.uuidString

        locationService.startMonitoringRegion(
            center: center,
            radius: Self.regionRadius,
            identifier: identifier
        )
    }

    func registerRegion(missionID: UUID, latitude: Double, longitude: Double) {
        let center = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let identifier = Self.regionPrefix + missionID.uuidString
        locationService.startMonitoringRegion(
            center: center,
            radius: Self.regionRadius,
            identifier: identifier
        )
    }

    func unregisterRegion(for missionID: UUID) {
        let identifier = Self.regionPrefix + missionID.uuidString
        locationService.stopMonitoringRegion(identifier: identifier)
    }

    /// endDate가 지난 미션의 리전을 정리한다. 포그라운드 진입 시 호출.
    func cleanUpExpiredRegions() {
        let context = stack.viewContext
        let monitoredIDs = locationService.monitoredRegionIdentifiers

        for identifier in monitoredIDs {
            guard identifier.hasPrefix(Self.regionPrefix) else { continue }
            let uuidString = String(identifier.dropFirst(Self.regionPrefix.count))
            guard let missionID = UUID(uuidString: uuidString) else { continue }

            let request = Mission.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", missionID as CVarArg)
            request.fetchLimit = 1

            guard let mission = try? context.fetch(request).first else {
                // 미션이 삭제된 경우 — 리전도 해제
                locationService.stopMonitoringRegion(identifier: identifier)
                continue
            }

            if let endDate = mission.endDate, endDate < Date() {
                locationService.stopMonitoringRegion(identifier: identifier)
            }
        }
    }

    /// 앱 실행 시 활성 미션의 리전이 누락되었으면 재등록한다.
    func restoreRegionsIfNeeded() {
        guard locationService.authorizationStatus.value == .authorizedAlways else { return }

        let context = stack.viewContext
        let request = Mission.fetchRequest()
        request.predicate = NSPredicate(format: "endDate >= %@", Date() as CVarArg)

        guard let missions = try? context.fetch(request) else { return }
        let monitoredIDs = locationService.monitoredRegionIdentifiers

        for mission in missions {
            guard let missionID = mission.id else { continue }
            let identifier = Self.regionPrefix + missionID.uuidString
            if !monitoredIDs.contains(identifier) {
                registerRegion(for: mission)
            }
        }
    }

    // MARK: - Region Entry Handling

    private func observeRegionEntry() {
        locationService.didEnterRegion
            .subscribe(onNext: { [weak self] region in
                self?.handleRegionEntry(region)
            })
            .disposed(by: bag)
    }

    private func handleRegionEntry(_ region: CLRegion) {
        guard region.identifier.hasPrefix(Self.regionPrefix) else { return }
        let uuidString = String(region.identifier.dropFirst(Self.regionPrefix.count))
        guard let missionID = UUID(uuidString: uuidString) else { return }

        let context = stack.viewContext
        let now = Date()

        // 미션 조회
        let missionRequest = Mission.fetchRequest()
        missionRequest.predicate = NSPredicate(format: "id == %@", missionID as CVarArg)
        missionRequest.fetchLimit = 1
        guard let mission = try? context.fetch(missionRequest).first else { return }

        // 오늘의 Attendance 조회
        let (todayStart, todayEnd) = GTTDateService.shared.todayBounds()
        let attRequest = Attendance.fetchRequest()
        attRequest.predicate = NSPredicate(
            format: "mission.id == %@ AND planDate >= %@ AND planDate < %@",
            missionID as CVarArg,
            todayStart as CVarArg,
            todayEnd as CVarArg
        )
        attRequest.fetchLimit = 1
        guard let attendance = try? context.fetch(attRequest).first else { return }

        // pending 또는 ongoing 상태인지 확인 (planDate 전후 3시간)
        guard let planDate = attendance.planDate else { return }
        let windowStart = planDate.addingTimeInterval(-3 * 3600)
        let windowEnd = planDate.addingTimeInterval(3 * 3600)

        guard now >= windowStart && now < windowEnd else { return }

        // 이미 성공/실패 처리된 건 스킵
        let status = attendance.attendanceStatus
        guard status == .pending || status == .late else { return }

        // recordDate가 있으면 이미 체크인한 것 → 스킵
        guard attendance.recordDate == nil else { return }

        let locationName = mission.location?.name ?? ""
        notificationService.sendNearLocationNotification(
            missionID: missionID,
            locationName: locationName
        )
    }
}
