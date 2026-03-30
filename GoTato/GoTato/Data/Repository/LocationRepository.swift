//
//  LocationRepository.swift
//  GoTato
//

import Foundation
import CoreData
import RxSwift

protocol LocationRepositoryProtocol {
    func fetchAllLocations() -> Single<[Location]>
    func createLocation(name: String, lati: Double, longi: Double) -> Single<Location>
    func findOrCreateLocation(name: String, lati: Double, longi: Double) -> Single<Location>
    func updateLocationName(locationID: UUID, newName: String) -> Single<Void>
}

final class LocationRepository: LocationRepositoryProtocol {
    static let shared = LocationRepository()

    private let stack: CoreDataStack

    init(stack: CoreDataStack = .shared) {
        self.stack = stack
    }

    func fetchAllLocations() -> Single<[Location]> {
        let context = stack.viewContext
        return Single.create { observer in
            do {
                observer(.success(try context.fetch(Location.fetchRequest())))
            } catch {
                observer(.failure(error))
            }
            return Disposables.create()
        }
    }

    func createLocation(name: String, lati: Double, longi: Double) -> Single<Location> {
        let viewContext = stack.viewContext
        return stack.performBackgroundTask { ctx in
            #if DEBUG
            print("[DB][Location] createLocation 시작 - name: \"\(name)\", lati: \(lati), longi: \(longi)")
            #endif

            let location = Location(context: ctx)
            location.name = name
            location.lati = lati
            location.longi = longi
            // save()를 먼저 호출해야 임시 ID → 영구 ID로 전환됨
            // performBackgroundTask의 save()는 이후 no-op
            try ctx.save()

            #if DEBUG
            print("[DB][Location] ✅ createLocation 완료 - name: \"\(name)\"")
            #endif

            return location.objectID
        }
        .observe(on: MainScheduler.instance)
        .map { objectID in
            viewContext.object(with: objectID) as! Location
        }
    }

    /// Location 이름 수정. 동일 Location을 참조하는 모든 미션에 반영됨.
    func updateLocationName(locationID: UUID, newName: String) -> Single<Void> {
        return stack.performBackgroundTask { ctx in
            let request = Location.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", locationID as CVarArg)
            request.fetchLimit = 1
            guard let location = try ctx.fetch(request).first else {
                throw RepositoryError.notFound
            }
            #if DEBUG
            print("[DB][Location] updateLocationName: \"\(location.name ?? "")\" → \"\(newName)\"")
            #endif
            location.name = newName
        }
    }

    /// 동일 좌표(lati, longi)의 Location이 있으면 반환, 없으면 생성 후 반환.
    /// Naver API 좌표는 fixed-precision이므로 exact 비교 안전.
    func findOrCreateLocation(name: String, lati: Double, longi: Double) -> Single<Location> {
        let request = Location.fetchRequest()
        request.predicate = NSPredicate(format: "lati == %lf AND longi == %lf", lati, longi)
        request.fetchLimit = 1

        do {
            if let existing = try stack.viewContext.fetch(request).first {
                #if DEBUG
                print("[DB][Location] findOrCreateLocation - 기존 Location 재사용: \"\(existing.name ?? "")\" (lati: \(lati), longi: \(longi))")
                #endif
                return .just(existing)
            }
        } catch {
            #if DEBUG
            print("[DB][Location] findOrCreateLocation fetch 실패: \(error)")
            #endif
            return .error(error)
        }

        #if DEBUG
        print("[DB][Location] findOrCreateLocation - 동일 좌표 없음, 신규 생성")
        #endif
        return createLocation(name: name, lati: lati, longi: longi)
    }
}
