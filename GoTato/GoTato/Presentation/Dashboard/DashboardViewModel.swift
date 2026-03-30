//
//  DashboardViewModel.swift
//  GoTato
//

import CoreLocation
import Foundation
import NMapsMap
import RxCocoa
import RxSwift

final class DashboardViewModel: BaseViewModel {

    struct Input {
        let viewDidLoad: Observable<Void>
        let viewWillAppear: Observable<Void>
        let pullToRefresh: Observable<Void>
        let missionAdded: Observable<Void>
        let refreshButtonTapped: PublishRelay<Int>
        let checkInButtonTapped: PublishRelay<Int>
        let commitButtonTapped: PublishRelay<Int>
    }

    struct Output {
        let missionStates: Driver<[DashboardMissionState]>
        let isRefreshing: Driver<Bool>
    }

    private let missionRepository: MissionRepositoryProtocol
    private let attendanceRepository: AttendanceRepositoryProtocol
    private let locationService = LocationService.shared
    private let bag = DisposeBag()

    private var rawPairs: [(mission: Mission, attendance: Attendance)] = []
    private var currentLocation: CLLocation?

    private let statesRelay = BehaviorRelay<[DashboardMissionState]>(value: [])

    init(
        missionRepository: MissionRepositoryProtocol = MissionRepository.shared,
        attendanceRepository: AttendanceRepositoryProtocol = AttendanceRepository.shared
    ) {
        self.missionRepository = missionRepository
        self.attendanceRepository = attendanceRepository
    }

    func transform(input: Input) -> Output {
        let isRefreshingRelay = BehaviorRelay<Bool>(value: false)

        // MARK: - Fetch trigger
        let fetchTrigger = Observable.merge(
            input.viewDidLoad,
            input.viewWillAppear,
            input.pullToRefresh,
            input.missionAdded
        )

        // Set isRefreshing true when pull-to-refresh fires
        input.pullToRefresh
            .map { true }
            .bind(to: isRefreshingRelay)
            .disposed(by: bag)

        // Fetch mission-attendance pairs on any trigger
        fetchTrigger
            .flatMapLatest { [weak self] _ -> Observable<[(Mission, Attendance)]> in
                guard let self else { return .just([]) }
                return self.fetchPairs()
            }
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] pairs in
                guard let self else { return }
                self.rawPairs = pairs
                self.recalculateStates()
                isRefreshingRelay.accept(false)
            })
            .disposed(by: bag)

        // Location authorization change → recalculate
        locationService.authorizationStatus
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] _ in
                self?.recalculateStates()
            })
            .disposed(by: bag)

        // Location update → update currentLocation and recalculate
        locationService.currentLocation
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] location in
                self?.currentLocation = location
                self?.recalculateStates()
            })
            .disposed(by: bag)

        // Refresh button → recalculate with latest location
        input.refreshButtonTapped
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] _ in
                self?.recalculateStates()
            })
            .disposed(by: bag)

        // Location service control based on ongoing missions
        statesRelay
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] states in
                let hasOngoing = states.contains {
                    if case .ongoing = $0.mainActionState { return true }
                    return false
                }
                if hasOngoing {
                    self?.locationService.startUpdatingLocation()
                } else {
                    self?.locationService.stopUpdatingLocation()
                }
            })
            .disposed(by: bag)

        // Check-in button
        input.checkInButtonTapped
            .observe(on: MainScheduler.instance)
            .flatMapFirst { [weak self] index -> Observable<Void> in
                guard let self, index < self.rawPairs.count else { return .empty() }
                let attendance = self.rawPairs[index].attendance
                guard let attendanceID = attendance.id else { return .empty() }

                // Immediately disable button while processing
                var states = self.statesRelay.value
                if index < states.count {
                    let s = states[index]
                    states[index] = DashboardMissionState(
                        title: s.title,
                        deadline: s.deadline,
                        messageCardState: s.messageCardState,
                        mainActionState: s.mainActionState,
                        bottomButtonState: .checkIn(isEnabled: false),
                        attendanceID: s.attendanceID,
                        missionID: s.missionID
                    )
                    self.statesRelay.accept(states)
                }

                return self.attendanceRepository
                    .recordAttendance(attendanceID: attendanceID, recordDate: Date())
                    .asObservable()
                    .catch { _ in .just(()) }
            }
            .observe(on: MainScheduler.instance)
            .flatMap { [weak self] _ -> Observable<[(Mission, Attendance)]> in
                guard let self else { return .just([]) }
                return self.fetchPairs()
            }
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] pairs in
                self?.rawPairs = pairs
                self?.recalculateStates()
            })
            .disposed(by: bag)

        // Commit button → DB에 failCommitted(4) 저장
        input.commitButtonTapped
            .observe(on: MainScheduler.instance)
            .flatMapFirst { [weak self] index -> Observable<Void> in
                guard let self, index < self.rawPairs.count else { return .empty() }
                guard let attendanceID = self.rawPairs[index].attendance.id else { return .empty() }

                // 즉시 UI 반영 (Optimistic update)
                var states = self.statesRelay.value
                if index < states.count {
                    let s = states[index]
                    states[index] = DashboardMissionState(
                        title: s.title,
                        deadline: s.deadline,
                        messageCardState: s.messageCardState,
                        mainActionState: .failedCommitted,
                        bottomButtonState: .hidden,
                        attendanceID: s.attendanceID,
                        missionID: s.missionID
                    )
                    self.statesRelay.accept(states)
                }

                return self.attendanceRepository
                    .commitAttendance(attendanceID: attendanceID)
                    .asObservable()
                    .catch { _ in .just(()) }
            }
            .observe(on: MainScheduler.instance)
            .flatMap { [weak self] _ -> Observable<[(Mission, Attendance)]> in
                guard let self else { return .just([]) }
                return self.fetchPairs()
            }
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] pairs in
                self?.rawPairs = pairs
                self?.recalculateStates()
            })
            .disposed(by: bag)

        return Output(
            missionStates: statesRelay.asDriver(),
            isRefreshing: isRefreshingRelay.asDriver()
        )
    }

    // MARK: - Public helpers

    func missionID(at index: Int) -> UUID? {
        let states = statesRelay.value
        guard index < states.count else { return nil }
        return states[index].missionID
    }

    // MARK: - Private helpers

    private func fetchPairs() -> Observable<[(Mission, Attendance)]> {
        return missionRepository.fetchTodayActiveMissions()
            .asObservable()
            .flatMap { [weak self] missions -> Observable<[(Mission, Attendance)]> in
                guard let self else { return .just([]) }
                guard !missions.isEmpty else { return .just([]) }

                let singles = missions.compactMap { mission -> Single<(Mission, Attendance)?> in
                    guard let missionID = mission.id else { return .just(nil) }
                    return self.attendanceRepository
                        .fetchTodayAttendance(for: missionID)
                        .map { attendance -> (Mission, Attendance)? in
                            guard let attendance else { return nil }
                            return (mission, attendance)
                        }
                }

                return Single.zip(singles)
                    .map { pairs -> [(Mission, Attendance)] in
                        let valid = pairs.compactMap { $0 }
                        let now = Date()
                        return valid.sorted { l, r in
                            let lActive = l.1.recordDate == nil &&
                                now < l.1.planDate!.addingTimeInterval(3 * 3600)
                            let rActive = r.1.recordDate == nil &&
                                now < r.1.planDate!.addingTimeInterval(3 * 3600)
                            
                            // 1. 진행 중인 미션(Active)을 우선순위로 둠
                            if lActive != rActive { return lActive }
                            
                            if lActive {
                                // 2. 진행 중인 미션끼리는 계획된 시간 순서대로 (빠른 시간부터)
                                return l.1.planDate! < r.1.planDate!
                            } else {
                                // 3. 확정된 미션(성공/실패)끼리는 현재 시간과 가까운 순서대로
                                let lDiff = abs(l.1.planDate!.timeIntervalSince(now))
                                let rDiff = abs(r.1.planDate!.timeIntervalSince(now))
                                return lDiff < rDiff
                            }
                        }
                    }
                    .asObservable()
            }
            .catch { _ in .just([]) }
    }

    private func recalculateStates() {
        let states = rawPairs.map { calculateState(for: $0) }
        statesRelay.accept(states)
    }

    private func calculateState(for pair: (mission: Mission, attendance: Attendance)) -> DashboardMissionState {
        let now = Date()
        let attendance = pair.attendance
        let mission = pair.mission
        let planDate = attendance.planDate!
        let threeHoursAfterPlan = planDate.addingTimeInterval(3 * 3600)
        let locationName = mission.location?.name ?? ""
        let attendanceID = attendance.id
        let missionID = mission.id
        let deadlineStr = formatDeadline(planDate)

        let authStatus = locationService.authorizationStatus.value
        let isLocationDenied = authStatus == .denied || authStatus == .restricted

        // failCommitted: DB에 저장된 status 4
        if attendance.attendanceStatus == .failCommitted {
            return DashboardMissionState(
                title: mission.title ?? "",
                deadline: deadlineStr,
                messageCardState: .failed,
                mainActionState: .failedCommitted,
                bottomButtonState: .hidden,
                attendanceID: attendanceID,
                missionID: missionID
            )
        }

        if let recordDate = attendance.recordDate {
            if recordDate <= planDate {
                // 정상출근 성공 (1.3)
                let earlyMinutes = Int(planDate.timeIntervalSince(recordDate) / 60)
                return DashboardMissionState(
                    title: mission.title ?? "",
                    deadline: deadlineStr,
                    messageCardState: .successOnTime(earlyMinutes: earlyMinutes),
                    mainActionState: .success(recordDate: recordDate, locationName: locationName),
                    bottomButtonState: .hidden,
                    attendanceID: attendanceID,
                    missionID: missionID
                )
            } else {
                // 지각출근 성공 (1.4)
                let lateStr = formatDuration(recordDate.timeIntervalSince(planDate))
                return DashboardMissionState(
                    title: mission.title ?? "",
                    deadline: deadlineStr,
                    messageCardState: .successLate(lateTime: lateStr),
                    mainActionState: .success(recordDate: recordDate, locationName: locationName),
                    bottomButtonState: .hidden,
                    attendanceID: attendanceID,
                    missionID: missionID
                )
            }
        } else if now >= threeHoursAfterPlan {
            // 미션 실패 (1.5)
            return DashboardMissionState(
                title: mission.title ?? "",
                deadline: deadlineStr,
                messageCardState: .failed,
                mainActionState: .failed,
                bottomButtonState: .commit,
                attendanceID: attendanceID,
                missionID: missionID
            )
        } else if now >= planDate {
            // 지각출근중 (1.2)
            let lateStr = formatDuration(now.timeIntervalSince(planDate))
            if isLocationDenied {
                return DashboardMissionState(
                    title: mission.title ?? "",
                    deadline: deadlineStr,
                    messageCardState: .commutingLate(lateTime: lateStr, location: locationName),
                    mainActionState: .locationPermissionDenied,
                    bottomButtonState: .checkIn(isEnabled: false),
                    attendanceID: attendanceID,
                    missionID: missionID
                )
            }
            let ongoing = buildOngoingState(mission: mission)
            return DashboardMissionState(
                title: mission.title ?? "",
                deadline: deadlineStr,
                messageCardState: .commutingLate(lateTime: lateStr, location: locationName),
                mainActionState: .ongoing(ongoing.cardState),
                bottomButtonState: .checkIn(isEnabled: ongoing.isNear),
                attendanceID: attendanceID,
                missionID: missionID
            )
        } else {
            // 정상출근중 (1.1)
            let leftStr = formatDuration(planDate.timeIntervalSince(now))
            let planTimeStr = formatPlanTime(planDate)
            if isLocationDenied {
                return DashboardMissionState(
                    title: mission.title ?? "",
                    deadline: deadlineStr,
                    messageCardState: .commutingOnTime(leftTime: leftStr, time: planTimeStr, location: locationName),
                    mainActionState: .locationPermissionDenied,
                    bottomButtonState: .checkIn(isEnabled: false),
                    attendanceID: attendanceID,
                    missionID: missionID
                )
            }
            let ongoing = buildOngoingState(mission: mission)
            return DashboardMissionState(
                title: mission.title ?? "",
                deadline: deadlineStr,
                messageCardState: .commutingOnTime(leftTime: leftStr, time: planTimeStr, location: locationName),
                mainActionState: .ongoing(ongoing.cardState),
                bottomButtonState: .checkIn(isEnabled: ongoing.isNear),
                attendanceID: attendanceID,
                missionID: missionID
            )
        }
    }

    /// 진행 중인 미션의 카드 상태와 20m 이내 여부를 함께 반환
    private func buildOngoingState(mission: Mission) -> (cardState: OngoingMissionCardState, isNear: Bool) {
        let locationName = mission.location?.name ?? ""
        let destLat = mission.location?.lati ?? 0
        let destLng = mission.location?.longi ?? 0
        let destCoord = NMGLatLng(lat: destLat, lng: destLng)

        guard let current = currentLocation else {
            return (
                .farFromDestination(
                    locationName: locationName,
                    currentCoord: destCoord,
                    destinationCoord: destCoord,
                    distance: "---"
                ),
                false
            )
        }

        let destCLLocation = CLLocation(latitude: destLat, longitude: destLng)
        let distance = current.distance(from: destCLLocation)
        let currentCoord = NMGLatLng(
            lat: current.coordinate.latitude,
            lng: current.coordinate.longitude
        )

        if distance <= 50 {
            return (
                .nearDestination(
                    locationName: locationName,
                    currentCoord: currentCoord,
                    destinationCoord: destCoord
                ),
                true
            )
        } else {
            return (
                .farFromDestination(
                    locationName: locationName,
                    currentCoord: currentCoord,
                    destinationCoord: destCoord,
                    distance: formatDistance(distance)
                ),
                false
            )
        }
    }

    // MARK: - Formatters

    func formatDuration(_ interval: TimeInterval) -> String {
        let totalMinutes = Int(interval / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return "\(hours)시간 \(minutes)분"
        }
        return "\(minutes)분"
    }

    func formatDistance(_ meters: Double) -> String {
        if meters < 1000 {
            return "\(Int(meters))m"
        }
        let km = floor(meters / 100) / 10
        if km.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(km))km"
        }
        return "\(String(format: "%.1f", km))km"
    }

    private func formatPlanTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func formatDeadline(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "a h시"
        let hourStr = formatter.string(from: date)

        let calendar = Calendar.current
        let minutes = calendar.component(.minute, from: date)

        if minutes == 0 {
            return "\(hourStr)까지"
        } else {
            return "\(hourStr) \(minutes)분까지"
        }
    }
}
