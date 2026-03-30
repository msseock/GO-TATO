//
//  CoreDataStack.swift
//  GoTato
//

import Foundation
import CoreData
import RxSwift

final class CoreDataStack {
    static let shared = CoreDataStack()

    let container: NSPersistentCloudKitContainer

    var viewContext: NSManagedObjectContext {
        container.viewContext
    }

    private init() {
        container = NSPersistentCloudKitContainer(name: "GoTato")
        container.loadPersistentStores { _, error in
            if let error {
                fatalError("CoreData 로드 실패: \(error)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    /// 모든 쓰기 작업의 공통 진입점.
    /// 블록은 새 백그라운드 컨텍스트에서 실행되며 성공 시 자동 저장된다.
    /// 결과는 항상 main thread에서 deliver된다.
    func performBackgroundTask<T>(_ block: @escaping (NSManagedObjectContext) throws -> T) -> Single<T> {
        return Single.create { [container] observer in
            container.performBackgroundTask { context in
                context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
                do {
                    let result = try block(context)
                    try context.save()
                    observer(.success(result))
                } catch {
                    observer(.failure(error))
                }
            }
            return Disposables.create()
        }
        .observe(on: MainScheduler.instance)
    }

    func saveViewContext() {
        guard viewContext.hasChanges else { return }
        do {
            try viewContext.save()
        } catch {
            let nserror = error as NSError
            fatalError("viewContext 저장 실패: \(nserror), \(nserror.userInfo)")
        }
    }
}
