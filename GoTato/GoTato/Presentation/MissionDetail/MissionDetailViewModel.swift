//
//  MissionDetailViewModel.swift
//  GoTato
//

import Foundation
import RxSwift
import RxCocoa

// MARK: - MissionDetailState

struct MissionDetailState {
    let title: String
    let locationName: String?
    let locationID: UUID?
    let locationLat: Double?
    let locationLng: Double?
    let startDate: Date
    let endDate: Date
    let deadline: Date
    let selectedDays: Set<Int>
    let wifiSSID: String?
    let successCount: Int
    let lateCount: Int
    let failCount: Int
    let totalCompleted: Int
    let successRate: Double
    let isMultiDay: Bool
}

// MARK: - MissionDetailViewModel

final class MissionDetailViewModel: BaseViewModel {

    // MARK: - Dependencies

    private let missionID: UUID
    private let missionRepo: MissionRepositoryProtocol
    private let attendanceRepo: AttendanceRepositoryProtocol
    private let locationRepo: LocationRepositoryProtocol
    private let disposeBag = DisposeBag()

    init(
        missionID: UUID,
        missionRepo: MissionRepositoryProtocol       = MissionRepository.shared,
        attendanceRepo: AttendanceRepositoryProtocol  = AttendanceRepository.shared,
        locationRepo: LocationRepositoryProtocol      = LocationRepository.shared
    ) {
        self.missionID      = missionID
        self.missionRepo    = missionRepo
        self.attendanceRepo = attendanceRepo
        self.locationRepo   = locationRepo
    }

    // MARK: - Input / Output

    struct Input {
        let viewWillAppear:       Observable<Void>
        let editTitle:            Observable<String>
        let editLocationName:     Observable<String>
        let editDeadline:         Observable<Date>
        let editSelectedDays:     Observable<Set<Int>>
        let editWifiSSID:         Observable<String?>
        let extendEndDate:        Observable<Date>
        let deleteTapped:         Observable<Void>
        let selectedDate:         Observable<Date?>
        let deleteAttendance:     Observable<UUID>
    }

    struct Output {
        let missionInfo:      Driver<MissionDetailState>
        let attendanceList:   Driver<[AttendanceItem]>
        let calendarStatuses: Driver<[Date: [Int16]]>
        let showExtendButton: Driver<Bool>
        let isMissionEnded:   Driver<Bool>
        let editResult:       Signal<Result<Void, Error>>
        let deleteResult:     Signal<Result<Void, Error>>
        let extendResult:     Signal<Result<Void, Error>>
    }

    func transform(input: Input) -> Output {
        let editResultRelay   = PublishRelay<Result<Void, Error>>()
        let deleteResultRelay = PublishRelay<Result<Void, Error>>()
        let extendResultRelay = PublishRelay<Result<Void, Error>>()

        // 내부 refresh trigger
        let refreshSubject = PublishSubject<Void>()
        let refresh = Observable.merge(input.viewWillAppear, refreshSubject.asObservable())

        // MARK: Fetch mission

        let mission = refresh
            .flatMapLatest { [weak self] _ -> Observable<Mission> in
                guard let self else { return .empty() }
                return self.missionRepo.fetchMission(id: self.missionID)
                    .asObservable()
                    .compactMap { $0 }
                    .catch { _ in .empty() }
            }
            .share(replay: 1)

        // MARK: Derived state

        let missionInfo = mission
            .map { m -> MissionDetailState in
                let attendances = (m.attendances as? Set<Attendance>) ?? []
                let successCount = attendances.filter { $0.status == 1 }.count
                let lateCount    = attendances.filter { $0.status == 2 }.count
                let failCount    = attendances.filter { $0.status == 3 || $0.status == 4 }.count
                let total        = attendances.filter { $0.status != 0 }.count
                let rate         = total > 0 ? Double(successCount) / Double(total) : 0
                let cal          = Calendar.current
                let isMultiDay   = !cal.isDate(m.startDate!, inSameDayAs: m.endDate!)
                return MissionDetailState(
                    title:          m.title ?? "",
                    locationName:   m.location?.name,
                    locationID:     m.location?.id,
                    locationLat:    m.location?.lati,
                    locationLng:    m.location?.longi,
                    startDate:      m.startDate!,
                    endDate:        m.endDate!,
                    deadline:       m.deadline!,
                    selectedDays:   m.selectedDays,
                    wifiSSID:       m.wifiSSID,
                    successCount:   successCount,
                    lateCount:      lateCount,
                    failCount:      failCount,
                    totalCompleted: total,
                    successRate:    rate,
                    isMultiDay:     isMultiDay
                )
            }
            .asDriver(onErrorDriveWith: .empty())

        let isMissionEnded = missionInfo.map { state -> Bool in
            Calendar.current.startOfDay(for: Date()) >= Calendar.current.startOfDay(for: state.endDate)
        }

        let showExtendButton = missionInfo.map { state -> Bool in
            guard state.isMultiDay else { return false }
            let cal    = Calendar.current
            let today  = cal.startOfDay(for: Date())
            let endDay = cal.startOfDay(for: state.endDate)
            guard today < endDay else { return false }
            let sevenBefore = cal.date(byAdding: .day, value: -7, to: endDay)!
            return today >= sevenBefore
        }

        let attendanceList = Observable
            .combineLatest(mission, input.selectedDate.startWith(nil))
            .map { m, selectedDate -> [AttendanceItem] in
                let cal = Calendar.current
                let set = (m.attendances as? Set<Attendance>) ?? []

                if let selectedDate {
                    // 선택된 날짜의 모든 attendance (예정 포함)
                    let dayStart = cal.startOfDay(for: selectedDate)
                    let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart)!
                    return set
                        .filter { a in
                            guard let p = a.planDate else { return false }
                            return p >= dayStart && p < dayEnd
                        }
                        .sorted { ($0.planDate ?? .distantPast) > ($1.planDate ?? .distantPast) }
                        .map { AttendanceItem(id: $0.id!, planDate: $0.planDate!, recordDate: $0.recordDate, status: $0.status) }
                } else {
                    // 기본: 기록된 것(status != 0)만, 오늘까지
                    let todayEnd = cal.date(bySettingHour: 23, minute: 59, second: 59, of: Date())!
                    return set
                        .filter { a in
                            guard let p = a.planDate else { return false }
                            return p <= todayEnd && a.status != 0
                        }
                        .sorted { ($0.planDate ?? .distantPast) > ($1.planDate ?? .distantPast) }
                        .map { AttendanceItem(id: $0.id!, planDate: $0.planDate!, recordDate: $0.recordDate, status: $0.status) }
                }
            }
            .asDriver(onErrorJustReturn: [])

        let calendarStatuses = mission
            .map { m -> [Date: [Int16]] in
                let cal = Calendar.current
                var map: [Date: [Int16]] = [:]
                for a in (m.attendances as? Set<Attendance>) ?? [] {
                    guard let p = a.planDate else { continue }
                    let day = cal.startOfDay(for: p)
                    map[day, default: []].append(a.status)
                }
                return map
            }
            .asDriver(onErrorJustReturn: [:])

        // MARK: Edit title

        input.editTitle
            .withLatestFrom(missionInfo) { (newTitle: $0, info: $1) }
            .flatMapLatest { [weak self] pair -> Observable<Result<Void, Error>> in
                guard let self else { return .just(.failure(AppError.unknown)) }
                return self.missionRepo.fetchAllMissions()
                    .flatMap { all -> Single<Void> in
                        let others = all.filter { $0.id != self.missionID }.compactMap { $0.title }
                        if others.contains(pair.newTitle) {
                            return .error(MissionDetailError.duplicateTitle)
                        }
                        return self.missionRepo.updateTitle(missionID: self.missionID, newTitle: pair.newTitle)
                    }
                    .map { Result<Void, Error>.success(()) }
                    .catch { .just(.failure($0)) }
                    .asObservable()
                    .do(onNext: { result in
                        if case .success = result { refreshSubject.onNext(()) }
                    })
            }
            .bind(to: editResultRelay)
            .disposed(by: disposeBag)

        // MARK: Edit location name

        input.editLocationName
            .withLatestFrom(missionInfo) { (newName: $0, info: $1) }
            .flatMapLatest { [weak self] pair -> Observable<Result<Void, Error>> in
                guard let self, let locationID = pair.info.locationID else {
                    return .just(.failure(AppError.unknown))
                }
                return self.locationRepo.updateLocationName(locationID: locationID, newName: pair.newName)
                    .map { Result<Void, Error>.success(()) }
                    .catch { .just(.failure($0)) }
                    .asObservable()
                    .do(onNext: { result in
                        if case .success = result { refreshSubject.onNext(()) }
                    })
            }
            .bind(to: editResultRelay)
            .disposed(by: disposeBag)

        // MARK: Edit deadline

        input.editDeadline
            .withLatestFrom(missionInfo) { (newDeadline: $0, info: $1) }
            .flatMapLatest { [weak self] pair -> Observable<Result<Void, Error>> in
                guard let self else { return .just(.failure(AppError.unknown)) }
                return self.missionRepo.fetchAllMissions()
                    .flatMap { allMissions -> Single<Void> in
                        let start = pair.info.startDate
                        let end   = pair.info.endDate
                        let overlapping = allMissions.filter { m in
                            guard m.id != self.missionID,
                                  let ms = m.startDate, let me = m.endDate else { return false }
                            return ms <= end && me >= start
                        }
                        let hasConflict = overlapping.contains { m in
                            guard let md = m.deadline else { return false }
                            let diff = abs(GTTDateService.shared.minutesBetweenTimesOfDay(pair.newDeadline, md))
                            return diff <= 5
                        }
                        if hasConflict { return .error(RepositoryError.deadlineConflict) }
                        return self.missionRepo.updateDeadline(missionID: self.missionID, newDeadline: pair.newDeadline)
                    }
                    .map { Result<Void, Error>.success(()) }
                    .catch { .just(.failure($0)) }
                    .asObservable()
                    .do(onNext: { result in
                        if case .success = result { refreshSubject.onNext(()) }
                    })
            }
            .bind(to: editResultRelay)
            .disposed(by: disposeBag)

        // MARK: Delete attendance

        input.deleteAttendance
            .flatMapLatest { [weak self] attendanceID -> Observable<Result<Void, Error>> in
                guard let self else { return .just(.failure(AppError.unknown)) }
                return self.attendanceRepo.deleteAttendance(attendanceID: attendanceID)
                    .map { Result<Void, Error>.success(()) }
                    .catch { .just(.failure($0)) }
                    .asObservable()
                    .do(onNext: { result in
                        if case .success = result { refreshSubject.onNext(()) }
                    })
            }
            .bind(to: editResultRelay)
            .disposed(by: disposeBag)

        // MARK: Edit selected days

        input.editSelectedDays
            .flatMapLatest { [weak self] newDays -> Observable<Result<Void, Error>> in
                guard let self else { return .just(.failure(AppError.unknown)) }
                return self.missionRepo.updateSelectedDays(missionID: self.missionID, newDays: newDays)
                    .map { Result<Void, Error>.success(()) }
                    .catch { .just(.failure($0)) }
                    .asObservable()
                    .do(onNext: { result in
                        if case .success = result { refreshSubject.onNext(()) }
                    })
            }
            .bind(to: editResultRelay)
            .disposed(by: disposeBag)

        // MARK: Edit WiFi SSID

        input.editWifiSSID
            .flatMapLatest { [weak self] newSSID -> Observable<Result<Void, Error>> in
                guard let self else { return .just(.failure(AppError.unknown)) }
                return self.missionRepo.updateWifiSSID(missionID: self.missionID, newSSID: newSSID)
                    .map { Result<Void, Error>.success(()) }
                    .catch { .just(.failure($0)) }
                    .asObservable()
                    .do(onNext: { result in
                        if case .success = result { refreshSubject.onNext(()) }
                    })
            }
            .bind(to: editResultRelay)
            .disposed(by: disposeBag)

        // MARK: Extend end date

        input.extendEndDate
            .flatMapLatest { [weak self] newEnd -> Observable<Result<Void, Error>> in
                guard let self else { return .just(.failure(AppError.unknown)) }
                return self.missionRepo.extendMission(missionID: self.missionID, newEndDate: newEnd)
                    .map { Result<Void, Error>.success(()) }
                    .catch { .just(.failure($0)) }
                    .asObservable()
                    .do(onNext: { result in
                        if case .success = result { refreshSubject.onNext(()) }
                    })
            }
            .bind(to: extendResultRelay)
            .disposed(by: disposeBag)

        // MARK: Delete

        input.deleteTapped
            .flatMapLatest { [weak self] _ -> Observable<Result<Void, Error>> in
                guard let self else { return .just(.failure(AppError.unknown)) }
                return self.missionRepo.deleteMission(missionID: self.missionID)
                    .do(onSuccess: { [weak self] in
                        guard let self else { return }
                        GeofenceManager.shared.unregisterRegion(for: self.missionID)
                    })
                    .map { Result<Void, Error>.success(()) }
                    .catch { .just(.failure($0)) }
                    .asObservable()
            }
            .bind(to: deleteResultRelay)
            .disposed(by: disposeBag)

        return Output(
            missionInfo:      missionInfo,
            attendanceList:   attendanceList,
            calendarStatuses: calendarStatuses,
            showExtendButton: showExtendButton,
            isMissionEnded:   isMissionEnded,
            editResult:       editResultRelay.asSignal(),
            deleteResult:     deleteResultRelay.asSignal(),
            extendResult:     extendResultRelay.asSignal()
        )
    }
}

// MARK: - Errors

enum MissionDetailError: LocalizedError {
    case duplicateTitle

    var errorDescription: String? {
        switch self {
        case .duplicateTitle: return "이미 사용 중인 미션 이름입니다."
        }
    }
}

private enum AppError: Error {
    case unknown
}
