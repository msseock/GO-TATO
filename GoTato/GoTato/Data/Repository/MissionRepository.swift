//
//  MissionRepository.swift
//  GoTato
//

import Foundation
import CoreData
import RxSwift

protocol MissionRepositoryProtocol {
    func fetchAllMissions() -> Single<[Mission]>
    func fetchActiveMissions() -> Single<[Mission]>
    func fetchTodayActiveMissions() -> Single<[Mission]>
    func createMission(title: String, deadline: Date, startDate: Date, endDate: Date, location: Location) -> Single<Void>
    func updateDeadline(missionID: UUID, newDeadline: Date) -> Single<Void>
    func deleteMission(missionID: UUID) -> Single<Void>
}

final class MissionRepository: MissionRepositoryProtocol {
    static let shared = MissionRepository()

    private let stack: CoreDataStack

    init(stack: CoreDataStack = .shared) {
        self.stack = stack
    }

    // MARK: - Read

    func fetchAllMissions() -> Single<[Mission]> {
        let context = stack.viewContext
        return Single.create { observer in
            let request = Mission.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: true)]
            do {
                let results = try context.fetch(request)
                #if DEBUG
                print("[DB][Mission] fetchAllMissions → \(results.count)개")
                #endif
                observer(.success(results))
            } catch {
                #if DEBUG
                print("[DB][Mission] fetchAllMissions 실패: \(error)")
                #endif
                observer(.failure(error))
            }
            return Disposables.create()
        }
    }

    /// endDate >= today인 미션 반환 (시작 전 미션 포함)
    func fetchActiveMissions() -> Single<[Mission]> {
        let context = stack.viewContext
        return Single.create { observer in
            let request = Mission.fetchRequest()
            request.predicate = NSPredicate(format: "endDate >= %@", Date() as CVarArg)
            request.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: true)]
            do {
                let results = try context.fetch(request)
                #if DEBUG
                print("[DB][Mission] fetchActiveMissions → \(results.count)개")
                #endif
                observer(.success(results))
            } catch {
                #if DEBUG
                print("[DB][Mission] fetchActiveMissions 실패: \(error)")
                #endif
                observer(.failure(error))
            }
            return Disposables.create()
        }
    }

    /// 오늘 활성 미션: startDate <= todayEnd AND endDate >= todayStart
    func fetchTodayActiveMissions() -> Single<[Mission]> {
        let context = stack.viewContext
        let (todayStart, todayEnd) = GTTDateService.shared.todayBounds()
        return Single.create { observer in
            let request = Mission.fetchRequest()
            request.predicate = NSPredicate(
                format: "startDate <= %@ AND endDate >= %@",
                todayEnd as CVarArg,
                todayStart as CVarArg
            )
            request.sortDescriptors = [NSSortDescriptor(key: "deadline", ascending: true)]
            do {
                let results = try context.fetch(request)
                #if DEBUG
                print("[DB][Mission] fetchTodayActiveMissions → \(results.count)개")
                #endif
                observer(.success(results))
            } catch {
                #if DEBUG
                print("[DB][Mission] fetchTodayActiveMissions 실패: \(error)")
                #endif
                observer(.failure(error))
            }
            return Disposables.create()
        }
    }

    // MARK: - Write

    /// 미션 생성.
    /// 사이드 이펙트: startDate~endDate 각 날짜에 Attendance 일괄 생성.
    /// DATABASE.md 제약 조건: 기간 오버랩 미션 10개 제한, deadline ±5분 충돌, 기간 1달 초과.
    func createMission(title: String, deadline: Date, startDate: Date, endDate: Date, location: Location) -> Single<Void> {
        let locationID = location.objectID

        return stack.performBackgroundTask { ctx in
            #if DEBUG
            print("[DB][Mission] createMission 시작 - title: \"\(title)\", startDate: \(startDate), endDate: \(endDate), deadline: \(deadline)")
            #endif

            let dateService = GTTDateService.shared

            // 기간 오버랩 미션 조회: 새 미션 기간(startDate~endDate)과 하루라도 겹치는 기존 미션
            // 겹침 조건: 기존미션.startDate <= newEnd AND 기존미션.endDate >= newStart
            let overlapFetch = Mission.fetchRequest()
            overlapFetch.predicate = NSPredicate(
                format: "startDate <= %@ AND endDate >= %@",
                endDate as CVarArg,
                startDate as CVarArg
            )
            let overlappingMissions = try ctx.fetch(overlapFetch)

            #if DEBUG
            print("[DB][Mission] 기간 겹치는 기존 미션: \(overlappingMissions.count)개")
            #endif

            // 1. 기간 겹치는 미션 10개 이상 → 생성 불가
            guard overlappingMissions.count < 10 else {
                #if DEBUG
                print("[DB][Mission] ❌ createMission 차단 - 오버랩 미션 \(overlappingMissions.count)개 (10개 이상)")
                #endif
                throw RepositoryError.tooManyActiveMissions
            }

            // 2. 기간이 겹치는 기존 미션의 deadline 시각과 ±5분 이내 충돌
            for existing in overlappingMissions {
                guard dateService.minutesBetweenTimesOfDay(deadline, existing.deadline!) > 5 else {
                    #if DEBUG
                    print("[DB][Mission] ❌ createMission 차단 - deadline 충돌 (기존 미션: \"\(existing.title ?? "")\", deadline: \(existing.deadline!))")
                    #endif
                    throw RepositoryError.deadlineConflict
                }
            }

            // 3. 기간 1달 초과
            let oneMonthLater = Calendar.current.date(byAdding: .month, value: 1, to: startDate)!
            guard endDate <= oneMonthLater else {
                #if DEBUG
                print("[DB][Mission] ❌ createMission 차단 - 기간 1달 초과 (endDate: \(endDate), 한도: \(oneMonthLater))")
                #endif
                throw RepositoryError.missionPeriodTooLong
            }

            // Mission 생성 (id는 awakeFromInsert에서 자동 할당)
            let mission = Mission(context: ctx)
            mission.title     = title
            mission.deadline  = deadline
            mission.startDate = startDate
            mission.endDate   = endDate
            // NSManagedObject는 컨텍스트 간 직접 전달 불가 → objectID로 재조회
            mission.location  = ctx.object(with: locationID) as? Location

            // Attendance 일괄 생성 (사이드 이펙트)
            let days = dateService.calendarDays(from: startDate, through: endDate)
            for day in days {
                let attendance = Attendance(context: ctx)
                attendance.planDate = dateService.combining(date: day, timeFrom: deadline)
                attendance.mission  = mission
                // status 기본값 0 (pending) — CoreData 모델 default 설정
            }

            #if DEBUG
            print("[DB][Mission] ✅ createMission 완료 - title: \"\(title)\", Attendance \(days.count)개 생성")
            #endif
        }
    }

    /// deadline 수정.
    /// 사이드 이펙트: status 0(pending) Attendance의 planDate를 새 deadline 시각으로 일괄 업데이트.
    /// status 1/2/3 Attendance는 수정하지 않는다.
    func updateDeadline(missionID: UUID, newDeadline: Date) -> Single<Void> {
        return stack.performBackgroundTask { ctx in
            #if DEBUG
            print("[DB][Mission] updateDeadline 시작 - missionID: \(missionID), newDeadline: \(newDeadline)")
            #endif

            let request = Mission.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", missionID as CVarArg)
            request.fetchLimit = 1
            guard let mission = try ctx.fetch(request).first else {
                #if DEBUG
                print("[DB][Mission] ❌ updateDeadline 실패 - missionID \(missionID) 찾을 수 없음")
                #endif
                throw RepositoryError.notFound
            }

            let oldDeadline = mission.deadline!
            mission.deadline = newDeadline

            // pending Attendance의 planDate만 업데이트
            let attendanceFetch = Attendance.fetchRequest()
            attendanceFetch.predicate = NSPredicate(format: "mission == %@ AND status == 0", mission)
            let pending = try ctx.fetch(attendanceFetch)

            let dateService = GTTDateService.shared
            for attendance in pending {
                attendance.planDate = dateService.combining(date: attendance.planDate!, timeFrom: newDeadline)
            }

            #if DEBUG
            print("[DB][Mission] ✅ updateDeadline 완료 - \"\(mission.title ?? "")\" \(oldDeadline) → \(newDeadline), pending Attendance \(pending.count)개 갱신")
            #endif
        }
    }

    /// 미션 삭제. Cascade 규칙에 의해 연결된 Attendance 전체 자동 삭제.
    func deleteMission(missionID: UUID) -> Single<Void> {
        return stack.performBackgroundTask { ctx in
            #if DEBUG
            print("[DB][Mission] deleteMission 시작 - missionID: \(missionID)")
            #endif

            let request = Mission.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", missionID as CVarArg)
            request.fetchLimit = 1
            guard let mission = try ctx.fetch(request).first else {
                #if DEBUG
                print("[DB][Mission] ❌ deleteMission 실패 - missionID \(missionID) 찾을 수 없음")
                #endif
                throw RepositoryError.notFound
            }

            #if DEBUG
            print("[DB][Mission] ✅ deleteMission 완료 - \"\(mission.title ?? "")\" 삭제 (연결 Attendance 전체 Cascade 삭제)")
            #endif
            ctx.delete(mission)
        }
    }
}
