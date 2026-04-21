//
//  MissionPhotoRepository.swift
//  GoTato
//

import Foundation
import CoreData
import UIKit
import Vision
import RxSwift

final class MissionPhotoRepository {
    static let shared = MissionPhotoRepository()

    private let stack: CoreDataStack

    init(stack: CoreDataStack = .shared) {
        self.stack = stack
    }

    // MARK: - Save

    func saveMissionPhoto(
        _ image: UIImage,
        observation: VNFeaturePrintObservation,
        missionID: UUID
    ) -> Single<Void> {
        return stack.performBackgroundTask { ctx in
            let filename = "\(UUID().uuidString).jpg"
            let imageURL = Self.photosDirectory().appendingPathComponent(filename)

            guard let data = MissionPhotoService.prepareImageData(image) else {
                throw MissionPhotoError.imageProcessingFailed
            }
            try data.write(to: imageURL)

            let observationData = try NSKeyedArchiver.archivedData(
                withRootObject: observation,
                requiringSecureCoding: true
            )

            let missionRequest = Mission.fetchRequest()
            missionRequest.predicate = NSPredicate(format: "id == %@", missionID as CVarArg)
            missionRequest.fetchLimit = 1
            guard let mission = try ctx.fetch(missionRequest).first else {
                throw RepositoryError.notFound
            }

            // 기존 사진이 있으면 파일 삭제 후 덮어쓰기
            if let existing = mission.missionPhoto {
                Self.deleteImageFile(filename: existing.imagePath)
                ctx.delete(existing)
            }

            let photo = MissionPhoto(context: ctx)
            photo.imagePath = filename
            photo.observationData = observationData
            photo.mission = mission

            #if DEBUG
            print("[DB][MissionPhoto] ✅ saveMissionPhoto - missionID: \(missionID), file: \(filename)")
            #endif
        }
    }

    // MARK: - Load

    func loadReferenceImage(for missionID: UUID) -> UIImage? {
        let context = stack.viewContext
        let request = MissionPhoto.fetchRequest()
        request.predicate = NSPredicate(
            format: "mission.id == %@", missionID as CVarArg
        )
        request.fetchLimit = 1

        guard let photo = try? context.fetch(request).first,
              let filename = photo.imagePath else { return nil }

        let url = Self.photosDirectory().appendingPathComponent(filename)
        return UIImage(contentsOfFile: url.path)
    }

    func loadObservationData(for missionID: UUID) -> Data? {
        let context = stack.viewContext
        let request = MissionPhoto.fetchRequest()
        request.predicate = NSPredicate(
            format: "mission.id == %@", missionID as CVarArg
        )
        request.fetchLimit = 1

        return try? context.fetch(request).first?.observationData
    }

    // MARK: - Delete

    func deleteMissionPhoto(for missionID: UUID) -> Single<Void> {
        return stack.performBackgroundTask { ctx in
            let request = MissionPhoto.fetchRequest()
            request.predicate = NSPredicate(
                format: "mission.id == %@", missionID as CVarArg
            )
            request.fetchLimit = 1

            guard let photo = try ctx.fetch(request).first else { return }

            Self.deleteImageFile(filename: photo.imagePath)
            ctx.delete(photo)

            #if DEBUG
            print("[DB][MissionPhoto] deleteMissionPhoto - missionID: \(missionID)")
            #endif
        }
    }

    // MARK: - Private Helpers

    static func photosDirectory() -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("missionPhotos", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static func deleteImageFile(filename: String?) {
        guard let filename else { return }
        let url = photosDirectory().appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: url)
    }
}
