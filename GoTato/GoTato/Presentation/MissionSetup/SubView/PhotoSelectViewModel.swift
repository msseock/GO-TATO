//
//  PhotoSelectViewModel.swift
//  GoTato
//

import Foundation
import UIKit
import Vision
import RxSwift
import RxCocoa

final class PhotoSelectViewModel: BaseViewModel {

    enum CaptureState: Equatable {
        case idle
        case captured(UIImage)
        case failed

        static func == (lhs: CaptureState, rhs: CaptureState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.failed, .failed): return true
            case (.captured(let a), .captured(let b)): return a === b
            default: return false
            }
        }
    }

    struct Input {
        let retakeTapped: Observable<Void>
        let ctaTapped: Observable<Void>
        let photoCaptured: Observable<(UIImage, VNFeaturePrintObservation)>
    }

    struct Output {
        let captureState: Driver<CaptureState>
        let isCtaEnabled: Driver<Bool>
        let confirmed: Signal<(UIImage, VNFeaturePrintObservation)>
    }

    private let disposeBag = DisposeBag()

    func transform(input: Input) -> Output {
        let captureState = BehaviorRelay<CaptureState>(value: .idle)
        let latestCapture = BehaviorRelay<(UIImage, VNFeaturePrintObservation)?>(value: nil)

        input.photoCaptured
            .subscribe(onNext: { image, observation in
                captureState.accept(.captured(image))
                latestCapture.accept((image, observation))
            })
            .disposed(by: disposeBag)

        input.retakeTapped
            .subscribe(onNext: {
                captureState.accept(.idle)
                latestCapture.accept(nil)
            })
            .disposed(by: disposeBag)

        let isCtaEnabled = captureState.asObservable()
            .map { if case .captured = $0 { return true }; return false }

        let confirmed = input.ctaTapped
            .withLatestFrom(latestCapture.asObservable())
            .compactMap { $0 }
            .asSignal(onErrorSignalWith: .empty())

        return Output(
            captureState: captureState.asDriver(),
            isCtaEnabled: isCtaEnabled.asDriver(onErrorJustReturn: false),
            confirmed: confirmed
        )
    }
}
