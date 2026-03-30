//
//  HistoryViewModel.swift
//  GoTato
//
//  Created by 석민솔 on 3/24/26.
//

import Foundation
import RxSwift
import RxCocoa

final class HistoryViewModel: BaseViewModel {

    private let disposeBag = DisposeBag()
    private let missionRepository: MissionRepositoryProtocol
    private let attendanceRepository: AttendanceRepositoryProtocol

    init(
        missionRepository: MissionRepositoryProtocol = MissionRepository.shared,
        attendanceRepository: AttendanceRepositoryProtocol = AttendanceRepository.shared
    ) {
        self.missionRepository = missionRepository
        self.attendanceRepository = attendanceRepository
    }

    struct Input {
        let viewWillAppear: Observable<Void>
        let monthChanged: Observable<Date>
        let dateSelected: Observable<Date>
        let addMissionTap: Observable<Void>
        let setMissionButtonTap: Observable<Void>
    }

    struct Output {
        let hasMission: Driver<Bool>
        let stats: Driver<(rate: Int, lateCount: Int, savedMinutes: Int)>
        let calendarStatusMap: Driver<[Date: [Int16]]>
        let recordsData: Driver<(title: String, items: [(missionID: UUID?, state: AttendanceRecordState)])>
        let navigateToMissionSetup: Signal<Void>
    }

    func transform(input: Input) -> Output {
        // 전체 미션 목록: viewWillAppear마다 재조회 (MissionSetup에서 복귀 후 갱신용)
        let missions = input.viewWillAppear
            .flatMapLatest { [weak self] _ -> Observable<[Mission]> in
                guard let self else { return .just([]) }
                return self.missionRepository.fetchAllMissions()
                    .asObservable()
                    .catchAndReturn([])
            }
            .share(replay: 1)

        let hasMission = missions
            .map { !$0.isEmpty }
            .asDriver(onErrorJustReturn: false)

        // 현재 표시 중인 월: 첫 진입 시 오늘 기준, 이후 사용자 조작으로만 변경
        let currentMonth = Observable.merge(
            input.viewWillAppear.take(1).map { Date() },
            input.monthChanged
        )
        .share(replay: 1)

        // 현재 월의 전체 Attendance (미션별 병렬 조회 후 병합)
        let monthAttendances = Observable.combineLatest(missions, currentMonth)
            .flatMapLatest { [weak self] (missions, month) -> Observable<[Attendance]> in
                guard let self else { return .just([]) }
                guard !missions.isEmpty else { return .just([]) }
                let singles = missions.compactMap { mission -> Observable<[Attendance]>? in
                    guard let id = mission.id else { return nil }
                    return self.attendanceRepository
                        .fetchAttendances(for: id, in: month)
                        .asObservable()
                        .catchAndReturn([])
                }
                guard !singles.isEmpty else { return .just([]) }
                return Observable.zip(singles).map { $0.flatMap { $0 } }
            }
            .share(replay: 1)

        // 통계: 출석률 · 지각 횟수 · 절약 시간
        let stats = monthAttendances
            .map { attendances -> (rate: Int, lateCount: Int, savedMinutes: Int) in
                let total = attendances.count
                guard total > 0 else { return (rate: 0, lateCount: 0, savedMinutes: 0) }

                let attendedCount = attendances.filter { $0.status == 1 || $0.status == 2 }.count
                let lateCount     = attendances.filter { $0.status == 2 }.count
                // status=1이면 recordDate < planDate → 일찍 도착한 분(min) 합산
                let savedMinutes  = attendances
                    .filter { $0.status == 1 }
                    .reduce(0) { sum, a in
                        guard let record = a.recordDate, let plan = a.planDate else { return sum }
                        return sum + max(0, Int(plan.timeIntervalSince(record) / 60))
                    }
                let rate = Int(Double(attendedCount) / Double(total) * 100)
                return (rate, lateCount, savedMinutes)
            }
            .asDriver(onErrorJustReturn: (rate: 0, lateCount: 0, savedMinutes: 0))

        // 캘린더 상태 맵: [startOfDay: [status]] — 다중 미션 지원
        let calendarStatusMap = monthAttendances
            .map { attendances -> [Date: [Int16]] in
                let cal = Calendar.current
                var map: [Date: [Int16]] = [:]
                for attendance in attendances {
                    guard let planDate = attendance.planDate else { continue }
                    let day = cal.startOfDay(for: planDate)
                    map[day, default: []].append(attendance.status)
                }
                return map
            }
            .asDriver(onErrorJustReturn: [:])

        // 선택된 날짜: 첫 진입 시 오늘, 월 변경 시 해당 월의 기준일로 리셋, 날짜 탭 시 업데이트
        let selectedDate = Observable.merge(
            input.viewWillAppear.take(1).map { Date() },
            input.monthChanged.map { month -> Date in
                let cal = Calendar.current
                // 현재 월이면 오늘, 다른 월이면 해당 월 1일
                return cal.isDate(month, equalTo: Date(), toGranularity: .month)
                    ? Date()
                    : cal.date(from: cal.dateComponents([.year, .month], from: month)) ?? month
            },
            input.dateSelected
        )
        .share(replay: 1)

        // 출근 기록 섹션: 선택 날짜의 미션별 카드 상태 (missionID 포함)
        let recordsData = Observable.combineLatest(monthAttendances, selectedDate)
            .map { (attendances, selected) -> (title: String, items: [(missionID: UUID?, state: AttendanceRecordState)]) in
                let cal = Calendar.current
                let selectedDay = cal.startOfDay(for: selected)
                let todayDay    = cal.startOfDay(for: Date())
                let isTodayOrFuture = selectedDay >= todayDay

                let title: String
                if cal.isDateInToday(selected) {
                    title = "오늘의 출근 기록"
                } else {
                    let month = cal.component(.month, from: selected)
                    let day   = cal.component(.day,   from: selected)
                    title = "\(month)월 \(day)일 출근 기록"
                }

                let dayAttendances = attendances.filter { a in
                    guard let planDate = a.planDate else { return false }
                    return cal.startOfDay(for: planDate) == selectedDay
                }

                guard !dayAttendances.isEmpty else {
                    return (title, [(nil, .noMission)])
                }

                let items: [(missionID: UUID?, state: AttendanceRecordState)] = dayAttendances.map { attendance in
                    let missionID    = attendance.mission?.id
                    let locationName = attendance.mission?.location?.name ?? ""
                    let state: AttendanceRecordState
                    switch attendance.attendanceStatus {
                    case .pending:
                        state = isTodayOrFuture
                            ? .inProgress(locationName: locationName)
                            : .failure(locationName: locationName)
                    case .success:
                        let diff = attendance.recordDate.flatMap { r in
                            attendance.planDate.map { Int($0.timeIntervalSince(r) / 60) }
                        } ?? 0
                        state = .success(locationName: locationName, minutesDiff: diff)
                    case .late:
                        let diff = attendance.recordDate.flatMap { r in
                            attendance.planDate.map { Int(r.timeIntervalSince($0) / 60) }
                        } ?? 0
                        state = .late(locationName: locationName, minutesDiff: diff)
                    case .fail, .failCommitted:
                        state = .failure(locationName: locationName)
                    }
                    return (missionID, state)
                }
                return (title, items)
            }
            .asDriver(onErrorJustReturn: (title: "오늘의 출근 기록", items: [(nil, .noMission)]))

        // 미션 추가/출근 설정 버튼 → MissionSetupViewController 이동
        let navigateToMissionSetup = Observable.merge(
            input.addMissionTap,
            input.setMissionButtonTap
        )
        .asSignal(onErrorSignalWith: .empty())

        return Output(
            hasMission: hasMission,
            stats: stats,
            calendarStatusMap: calendarStatusMap,
            recordsData: recordsData,
            navigateToMissionSetup: navigateToMissionSetup
        )
    }
}
