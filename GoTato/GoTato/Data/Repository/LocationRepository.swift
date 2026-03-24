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
            let location = Location(context: ctx)
            location.name = name
            location.lati = lati
            location.longi = longi
            // save()를 먼저 호출해야 임시 ID → 영구 ID로 전환됨
            // performBackgroundTask의 save()는 이후 no-op
            try ctx.save()
            return location.objectID
        }
        .observe(on: MainScheduler.instance)
        .map { objectID in
            viewContext.object(with: objectID) as! Location
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
                return .just(existing)
            }
        } catch {
            return .error(error)
        }

        return createLocation(name: name, lati: lati, longi: longi)
    }
}
