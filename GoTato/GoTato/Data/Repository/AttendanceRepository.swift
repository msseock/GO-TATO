//
//  AttendanceRepository.swift
//  GoTato
//

import Foundation
import CoreData
import RxSwift

protocol AttendanceRepositoryProtocol {
    func fetchAttendances(for missionID: UUID) -> Single<[Attendance]>
    func fetchAttendances(for missionID: UUID, in month: Date) -> Single<[Attendance]>
    func fetchTodayAttendance(for missionID: UUID) -> Single<Attendance?>
    func recordAttendance(attendanceID: UUID, recordDate: Date) -> Single<Void>
    func commitAttendance(attendanceID: UUID) -> Single<Void>
    func deleteAttendance(attendanceID: UUID) -> Single<Void>
    func batchMarkFailed() -> Single<Void>
}

final class AttendanceRepository: AttendanceRepositoryProtocol {
    static let shared = AttendanceRepository()

    private let stack: CoreDataStack

    init(stack: CoreDataStack = .shared) {
        self.stack = stack
    }

    // MARK: - Read

    /// 미션의 전체 Attendance를 planDate 오름차순으로 반환
    func fetchAttendances(for missionID: UUID) -> Single<[Attendance]> {
        let context = stack.viewContext
        return Single.create { observer in
            let request = Attendance.fetchRequest()
            request.predicate = NSPredicate(format: "mission.id == %@", missionID as CVarArg)
            request.sortDescriptors = [NSSortDescriptor(key: "planDate", ascending: true)]
            do {
                observer(.success(try context.fetch(request)))
            } catch {
                observer(.failure(error))
            }
            return Disposables.create()
        }
    }

    /// 특정 월에 속하는 Attendance만 반환 (달력 뷰용)
    func fetchAttendances(for missionID: UUID, in month: Date) -> Single<[Attendance]> {
        let context = stack.viewContext
        let (monthStart, monthEnd) = GTTDateService.shared.monthBounds(for: month)
        return Single.create { observer in
            let request = Attendance.fetchRequest()
            request.predicate = NSPredicate(
                format: "mission.id == %@ AND planDate >= %@ AND planDate < %@",
                missionID as CVarArg,
                monthStart as CVarArg,
                monthEnd as CVarArg
            )
            request.sortDescriptors = [NSSortDescriptor(key: "planDate", ascending: true)]
            do {
                observer(.success(try context.fetch(request)))
            } catch {
                observer(.failure(error))
            }
            return Disposables.create()
        }
    }

    /// 오늘 날짜의 Attendance 반환. 오늘 출석 예정이 없으면 nil.
    func fetchTodayAttendance(for missionID: UUID) -> Single<Attendance?> {
        let context = stack.viewContext
        let (todayStart, todayEnd) = GTTDateService.shared.todayBounds()
        return Single.create { observer in
            let request = Attendance.fetchRequest()
            request.predicate = NSPredicate(
                format: "mission.id == %@ AND planDate >= %@ AND planDate < %@",
                missionID as CVarArg,
                todayStart as CVarArg,
                todayEnd as CVarArg
            )
            request.fetchLimit = 1
            do {
                observer(.success(try context.fetch(request).first))
            } catch {
                observer(.failure(error))
            }
            return Disposables.create()
        }
    }

    // MARK: - Write

    /// 출석 기록. recordDate를 저장하고 DATABASE.md 정책에 따라 status를 계산한다.
    func recordAttendance(attendanceID: UUID, recordDate: Date) -> Single<Void> {
        return stack.performBackgroundTask { ctx in
            #if DEBUG
            print("[DB][Attendance] recordAttendance 시작 - attendanceID: \(attendanceID), recordDate: \(recordDate)")
            #endif

            let request = Attendance.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", attendanceID as CVarArg)
            request.fetchLimit = 1
            guard let attendance = try ctx.fetch(request).first else {
                #if DEBUG
                print("[DB][Attendance] ❌ recordAttendance 실패 - attendanceID \(attendanceID) 찾을 수 없음")
                #endif
                throw RepositoryError.notFound
            }

            attendance.recordDate = recordDate

            // DATABASE.md status 계산 정책
            if recordDate < attendance.planDate! {
                attendance.attendanceStatus = .success
            } else if recordDate < attendance.planDate!.addingTimeInterval(3 * 3600) {
                attendance.attendanceStatus = .late
            } else {
                // UI에서 3h 이후 버튼 비활성화이므로 정상 도달 불가. 방어적 처리.
                attendance.attendanceStatus = .fail
            }

            #if DEBUG
            print("[DB][Attendance] ✅ recordAttendance 완료 - planDate: \(attendance.planDate!), recordDate: \(recordDate), status: \(attendance.attendanceStatus)")
            #endif
        }
    }

    /// 다짐하기. status를 failCommitted(4)로 저장한다.
    func commitAttendance(attendanceID: UUID) -> Single<Void> {
        return stack.performBackgroundTask { ctx in
            #if DEBUG
            print("[DB][Attendance] commitAttendance 시작 - attendanceID: \(attendanceID)")
            #endif

            let request = Attendance.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", attendanceID as CVarArg)
            request.fetchLimit = 1
            guard let attendance = try ctx.fetch(request).first else {
                #if DEBUG
                print("[DB][Attendance] ❌ commitAttendance 실패 - attendanceID \(attendanceID) 찾을 수 없음")
                #endif
                throw RepositoryError.notFound
            }

            attendance.attendanceStatus = .failCommitted

            #if DEBUG
            print("[DB][Attendance] ✅ commitAttendance 완료 - attendanceID: \(attendanceID)")
            #endif
        }
    }

    /// Attendance 개별 삭제.
    func deleteAttendance(attendanceID: UUID) -> Single<Void> {
        return stack.performBackgroundTask { ctx in
            #if DEBUG
            print("[DB][Attendance] deleteAttendance 시작 - attendanceID: \(attendanceID)")
            #endif

            let request = Attendance.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", attendanceID as CVarArg)
            request.fetchLimit = 1
            guard let attendance = try ctx.fetch(request).first else {
                #if DEBUG
                print("[DB][Attendance] ❌ deleteAttendance 실패 - attendanceID \(attendanceID) 찾을 수 없음")
                #endif
                throw RepositoryError.notFound
            }

            ctx.delete(attendance)

            #if DEBUG
            print("[DB][Attendance] ✅ deleteAttendance 완료 - attendanceID: \(attendanceID)")
            #endif
        }
    }

    /// 앱 실행/포그라운드 복귀 시 호출.
    /// status 0(pending)이면서 planDate + 3h가 경과한 Attendance를 status 3(fail)으로 일괄 업데이트.
    /// NSBatchUpdateRequest로 SQLite 직접 업데이트 → O(1) 메모리.
    /// ⚠️ NSBatchUpdateRequest는 CloudKit 동기화 미대상 — 각 기기 실행 시 자체 재계산.
    func batchMarkFailed() -> Single<Void> {
        let viewContext = stack.viewContext
        return stack.performBackgroundTask { ctx in
            #if DEBUG
            print("[DB][Attendance] batchMarkFailed 시작")
            #endif

            // planDate + 3h < now  ⟺  planDate < now - 3h
            let threeHoursAgo = Date().addingTimeInterval(-3 * 3600)

            let batchUpdate = NSBatchUpdateRequest(entityName: "Attendance")
            batchUpdate.predicate = NSPredicate(
                format: "status == 0 AND planDate < %@",
                threeHoursAgo as CVarArg
            )
            batchUpdate.propertiesToUpdate = ["status": AttendanceStatus.fail.rawValue]
            batchUpdate.resultType = .updatedObjectIDsResultType

            let result = try ctx.execute(batchUpdate) as! NSBatchUpdateResult
            let updatedIDs = result.result as! [NSManagedObjectID]

            #if DEBUG
            print("[DB][Attendance] ✅ batchMarkFailed 완료 - \(updatedIDs.count)개 → fail(3) 처리")
            #endif

            // NSBatchUpdateRequest는 컨텍스트 object graph를 우회하므로
            // viewContext에 변경사항을 명시적으로 반영해야 한다.
            viewContext.perform {
                NSManagedObjectContext.mergeChanges(
                    fromRemoteContextSave: [NSUpdatedObjectsKey: updatedIDs],
                    into: [viewContext]
                )
            }
        }
    }
}
