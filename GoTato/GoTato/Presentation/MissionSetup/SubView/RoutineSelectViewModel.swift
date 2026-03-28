//
//  RoutineSelectViewModel.swift
//  GoTato
//

import Foundation
import RxSwift
import RxCocoa

enum SegmentMode { case daily, once }

final class RoutineSelectViewModel: BaseViewModel {

    struct Input {
        let segmentSelected: Observable<Int>
        let startDateSelected: Observable<Date>
        let endDateSelected: Observable<Date>
        let singleDateSelected: Observable<Date>
        let timeSelected: Observable<Date>
        let ctaTapped: Observable<Void>
    }

    struct Output {
        let mode: Driver<SegmentMode>
        let startDate: Driver<Date>
        let endDate: Driver<Date>
        let singleDate: Driver<Date>
        let selectedTime: Driver<Date>
        let routineConfirmed: Signal<MissionRoutine>
    }

    private let disposeBag = DisposeBag()

    func transform(input: Input) -> Output {
        let initialStartDate = Calendar.current.startOfDay(for: Date())
        let initialEndDate = Calendar.current.date(byAdding: .day, value: 31, to: initialStartDate) ?? Date()
        let initialSingleDate = initialStartDate
        
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = 9
        components.minute = 0
        components.second = 0
        let initialTime = Calendar.current.date(from: components) ?? Date()

        let mode = BehaviorRelay<SegmentMode>(value: .daily)
        let startDate = BehaviorRelay<Date>(value: initialStartDate)
        let endDate = BehaviorRelay<Date>(value: initialEndDate)
        let singleDate = BehaviorRelay<Date>(value: initialSingleDate)
        let selectedTime = BehaviorRelay<Date>(value: initialTime)

        input.segmentSelected
            .map { $0 == 0 ? SegmentMode.daily : .once }
            .do(onNext: { newMode in
                if newMode == .once {
                    singleDate.accept(startDate.value)
                } else {
                    startDate.accept(singleDate.value)
                    let newEnd = Calendar.current.date(byAdding: .day, value: 31, to: startDate.value) ?? startDate.value
                    endDate.accept(newEnd)
                }
            })
            .bind(to: mode)
            .disposed(by: disposeBag)

        input.startDateSelected
            .do(onNext: { newStart in
                let cal = Calendar.current
                let minEnd = cal.date(byAdding: .day, value: 1, to: newStart) ?? newStart
                let maxEnd = cal.date(byAdding: .month, value: 1, to: newStart) ?? newStart
                
                if endDate.value < minEnd || endDate.value > maxEnd {
                    let adjustedEnd = cal.date(byAdding: .day, value: 7, to: newStart) ?? newStart
                    endDate.accept(adjustedEnd)
                }
            })
            .bind(to: startDate)
            .disposed(by: disposeBag)

        input.endDateSelected
            .bind(to: endDate)
            .disposed(by: disposeBag)

        input.singleDateSelected
            .bind(to: singleDate)
            .disposed(by: disposeBag)

        input.timeSelected
            .bind(to: selectedTime)
            .disposed(by: disposeBag)

        let routineConfirmed = input.ctaTapped
            .withLatestFrom(Observable.combineLatest(
                mode.asObservable(),
                startDate.asObservable(),
                endDate.asObservable(),
                singleDate.asObservable(),
                selectedTime.asObservable()
            ))
            .map { currentMode, start, end, single, time -> MissionRoutine in
                switch currentMode {
                case .daily:
                    return MissionRoutine(mode: .daily, startDate: start, endDate: end, deadline: time)
                case .once:
                    return MissionRoutine(mode: .once, startDate: single, endDate: nil, deadline: time)
                }
            }
            .asSignal(onErrorSignalWith: .empty())

        return Output(
            mode: mode.asDriver(),
            startDate: startDate.asDriver(),
            endDate: endDate.asDriver(),
            singleDate: singleDate.asDriver(),
            selectedTime: selectedTime.asDriver(),
            routineConfirmed: routineConfirmed
        )
    }
}
