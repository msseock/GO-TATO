//
//  WifiSelectViewModel.swift
//  GoTato
//

import Foundation
import RxSwift
import RxCocoa

final class WifiSelectViewModel: BaseViewModel {

    struct Input {
        /// 토글 상태 변경 (true: WiFi 인증 사용)
        let toggleChanged: Observable<Bool>
        /// "다시 시도" 또는 "다시 캡처" 버튼
        let captureTapped: Observable<Void>
        /// CTA(미션 만들기) 버튼
        let ctaTapped: Observable<Void>
    }

    enum CaptureState: Equatable {
        case idle              // 토글 OFF
        case captured(String)  // SSID 캡처 성공
        case failed            // 캡처 실패 (미연결/권한 등)
    }

    struct Output {
        let captureState: Driver<CaptureState>
        let isCtaEnabled: Driver<Bool>
        /// CTA 탭 시 최종 결과 SSID. 토글 OFF면 nil.
        let confirmed: Signal<String?>
    }

    private let disposeBag = DisposeBag()

    func transform(input: Input) -> Output {
        let captureState = BehaviorRelay<CaptureState>(value: .idle)

        // 토글 ON → 즉시 자동 캡처 시도. OFF → idle.
        input.toggleChanged
            .subscribe(onNext: { isOn in
                guard isOn else {
                    captureState.accept(.idle)
                    return
                }
                WifiService.fetchCurrentSSID { ssid in
                    if let ssid = ssid {
                        captureState.accept(.captured(ssid))
                    } else {
                        captureState.accept(.failed)
                    }
                }
            })
            .disposed(by: disposeBag)

        // 다시 시도
        input.captureTapped
            .subscribe(onNext: {
                WifiService.fetchCurrentSSID { ssid in
                    if let ssid = ssid {
                        captureState.accept(.captured(ssid))
                    } else {
                        captureState.accept(.failed)
                    }
                }
            })
            .disposed(by: disposeBag)

        // CTA: idle(토글 OFF) 또는 captured 상태에서만 활성
        let isCtaEnabled = captureState.asObservable()
            .map { state -> Bool in
                switch state {
                case .idle, .captured: return true
                case .failed: return false
                }
            }

        let confirmed = input.ctaTapped
            .withLatestFrom(captureState.asObservable())
            .map { state -> String? in
                if case .captured(let ssid) = state { return ssid }
                return nil
            }
            .asSignal(onErrorSignalWith: .empty())

        return Output(
            captureState: captureState.asDriver(),
            isCtaEnabled: isCtaEnabled.asDriver(onErrorJustReturn: true),
            confirmed: confirmed
        )
    }
}
