//
//  MissionSetupViewModel.swift
//  GoTato
//
//  Created by 석민솔 on 3/24/26.
//

import Foundation
import UIKit
import Vision
import RxSwift
import RxCocoa

final class MissionSetupViewModel: BaseViewModel {

    struct PhotoCapture {
        let image: UIImage
        let observation: VNFeaturePrintObservation
    }

    struct CreateMissionInput {
        let location: SelectedLocation
        let routine: MissionRoutine
        var wifiSSID: String? = nil
        var photo: PhotoCapture? = nil
    }

    struct Input {
        let createMission: Observable<CreateMissionInput>
    }

    struct Output {
        let missionCreated: Signal<Void>
        let errorMessage: Signal<String>
    }

    private let disposeBag = DisposeBag()

    func transform(input: Input) -> Output {
        let missionResult = input.createMission
            .flatMapLatest { missionInput -> Observable<Event<Void>> in
                let location = missionInput.location
                let routine = missionInput.routine
                let wifiSSID = missionInput.wifiSSID
                let photoCapture = missionInput.photo

                let startDate = Calendar.current.startOfDay(for: routine.startDate)
                let endDate = Calendar.current.startOfDay(for: routine.endDate)

                return LocationRepository.shared.findOrCreateLocation(
                    name: location.name,
                    lati: location.lati,
                    longi: location.longi
                )
                .flatMap { loc in
                    MissionRepository.shared.createMission(
                        title: location.name,
                        deadline: routine.deadline,
                        startDate: startDate,
                        endDate: endDate,
                        selectedDays: routine.selectedDays,
                        location: loc,
                        wifiSSID: wifiSSID
                    )
                }
                .do(onSuccess: { missionID in
                    LocationService.shared.requestAlwaysAuthorization()

                    GeofenceManager.shared.registerRegion(
                        missionID: missionID,
                        latitude: location.lati,
                        longitude: location.longi
                    )

                    // 사진 인증이 설정된 경우 저장
                    if let capture = photoCapture {
                        MissionPhotoRepository.shared.saveMissionPhoto(
                            capture.image,
                            observation: capture.observation,
                            missionID: missionID
                        )
                        .subscribe()
                        .disposed(by: self.disposeBag)
                    }
                })
                .map { _ in }
                .asObservable()
                .materialize()
            }
            .share()

        let missionCreated: Signal<Void> = missionResult
            .compactMap { $0.element }
            .asSignal(onErrorJustReturn: ())

        let errorMessage: Signal<String> = missionResult
            .compactMap { $0.error }
            .map { error -> String in
                if let repoError = error as? RepositoryError {
                    switch repoError {
                    case .tooManyActiveMissions:
                        return "진행 중인 미션이 너무 많아요. 기존 미션을 완료한 후 다시 시도해주세요."
                    case .deadlineConflict:
                        return "다른 미션과 출근 시간이 겹쳐요. 시간을 조정해주세요."
                    case .missionPeriodTooLong:
                        return "미션 기간은 최대 1달까지 설정할 수 있어요."
                    default:
                        return "미션 생성에 실패했어요. 다시 시도해주세요."
                    }
                }
                return "미션 생성에 실패했어요. 다시 시도해주세요."
            }
            .asSignal(onErrorJustReturn: "미션 생성에 실패했어요. 다시 시도해주세요.")

        return Output(missionCreated: missionCreated, errorMessage: errorMessage)
    }
}
