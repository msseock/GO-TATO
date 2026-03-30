//
//  OnboardViewModel.swift
//  GoTato
//
//  Created by 석민솔 on 3/24/26.
//

import Foundation
import RxSwift
import RxCocoa

final class OnboardViewModel: BaseViewModel {

    struct Input {
        let missionTap: Observable<Void>
        let browseTap: Observable<Void>
    }

    struct Output {
        let navigateToMission: Signal<Void>
        let navigateToDashboard: Signal<Void>
    }

    private let disposeBag = DisposeBag()

    func transform(input: Input) -> Output {
        let navigateToMission = input.missionTap
            .asSignal(onErrorSignalWith: .empty())

        let navigateToDashboard = input.browseTap
            .do(onNext: {
                UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
            })
            .asSignal(onErrorSignalWith: .empty())

        return Output(
            navigateToMission: navigateToMission,
            navigateToDashboard: navigateToDashboard
        )
    }
}
