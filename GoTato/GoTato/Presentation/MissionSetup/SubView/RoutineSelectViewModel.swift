//
//  RoutineSelectViewModel.swift
//  GoTato
//

import Foundation
import RxSwift
import RxCocoa

final class RoutineSelectViewModel: BaseViewModel {

    struct Input {
        let startDateSelected: Observable<Date>
        let endDateSelected: Observable<Date>
        let dayToggled: Observable<Int>
        let allDaysToggled: Observable<Void>
        let timeSelected: Observable<Date>
        let ctaTapped: Observable<Void>
    }

    struct Output {
        let startDate: Driver<Date>
        let endDate: Driver<Date>
        let selectedTime: Driver<Date>
        let showDaySelector: Driver<Bool>
        let availableDays: Driver<Set<Int>>
        let selectedDays: Driver<Set<Int>>
        let isCtaEnabled: Driver<Bool>
        let routineConfirmed: Signal<MissionRoutine>
    }

    private let disposeBag = DisposeBag()

    func transform(input: Input) -> Output {
        let cal = Calendar.current
        let initialStartDate = cal.startOfDay(for: Date())
        let initialEndDate = cal.date(byAdding: .day, value: 7, to: initialStartDate) ?? Date()

        var components = cal.dateComponents([.year, .month, .day], from: Date())
        components.hour = 9
        components.minute = 0
        components.second = 0
        let initialTime = cal.date(from: components) ?? Date()

        let startDate = BehaviorRelay<Date>(value: initialStartDate)
        let endDate = BehaviorRelay<Date>(value: initialEndDate)
        let selectedTime = BehaviorRelay<Date>(value: initialTime)
        let selectedDays = BehaviorRelay<Set<Int>>(value: Set(1...7))

        // 시작일~종료일 범위에 존재하는 요일 계산
        let availableDays: Observable<Set<Int>> = Observable
            .combineLatest(startDate.asObservable(), endDate.asObservable())
            .map { start, end in
                Self.computeAvailableDays(from: start, to: end)
            }
            .share(replay: 1)

        // 시작일 = 종료일이면 요일 선택기 숨김
        let showDaySelector: Observable<Bool> = Observable
            .combineLatest(startDate.asObservable(), endDate.asObservable())
            .map { start, end in
                cal.startOfDay(for: start) != cal.startOfDay(for: end)
            }

        // 시작일 변경
        input.startDateSelected
            .do(onNext: { newStart in
                let minEnd = newStart
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

        input.timeSelected
            .bind(to: selectedTime)
            .disposed(by: disposeBag)

        // availableDays가 변경되면 disabled된 요일을 selectedDays에서 제거
        availableDays
            .subscribe(onNext: { available in
                let filtered = selectedDays.value.intersection(available)
                if filtered != selectedDays.value {
                    selectedDays.accept(filtered.isEmpty ? available : filtered)
                }
            })
            .disposed(by: disposeBag)

        // 개별 요일 토글
        input.dayToggled
            .subscribe(onNext: { day in
                var current = selectedDays.value
                if current.contains(day) {
                    current.remove(day)
                } else {
                    current.insert(day)
                }
                selectedDays.accept(current)
            })
            .disposed(by: disposeBag)

        // "매일" 버튼 토글
        input.allDaysToggled
            .withLatestFrom(availableDays)
            .subscribe(onNext: { available in
                let allSelected = available.isSubset(of: selectedDays.value)
                selectedDays.accept(allSelected ? [] : available)
            })
            .disposed(by: disposeBag)

        let isCtaEnabled = selectedDays.asObservable()
            .map { !$0.isEmpty }

        let routineConfirmed = input.ctaTapped
            .withLatestFrom(Observable.combineLatest(
                startDate.asObservable(),
                endDate.asObservable(),
                selectedDays.asObservable(),
                selectedTime.asObservable(),
                showDaySelector
            ))
            .map { start, end, days, time, showSelector -> MissionRoutine in
                if showSelector {
                    return MissionRoutine(startDate: start, endDate: end, selectedDays: days, deadline: time)
                } else {
                    // 시작일 = 종료일: 해당 날의 요일만 포함
                    let weekday = cal.component(.weekday, from: start)
                    return MissionRoutine(startDate: start, endDate: start, selectedDays: [weekday], deadline: time)
                }
            }
            .asSignal(onErrorSignalWith: .empty())

        return Output(
            startDate: startDate.asDriver(),
            endDate: endDate.asDriver(),
            selectedTime: selectedTime.asDriver(),
            showDaySelector: showDaySelector.asDriver(onErrorJustReturn: true),
            availableDays: availableDays.asDriver(onErrorJustReturn: Set(1...7)),
            selectedDays: selectedDays.asDriver(),
            isCtaEnabled: isCtaEnabled.asDriver(onErrorJustReturn: false),
            routineConfirmed: routineConfirmed
        )
    }

    /// 시작일~종료일 범위에 실제 존재하는 요일 집합 계산
    private static func computeAvailableDays(from start: Date, to end: Date) -> Set<Int> {
        let cal = Calendar.current
        let startDay = cal.startOfDay(for: start)
        let endDay = cal.startOfDay(for: end)

        let dayCount = cal.dateComponents([.day], from: startDay, to: endDay).day ?? 0

        // 7일 이상이면 모든 요일 존재
        if dayCount >= 7 {
            return Set(1...7)
        }

        var result = Set<Int>()
        var current = startDay
        while current <= endDay {
            result.insert(cal.component(.weekday, from: current))
            current = cal.date(byAdding: .day, value: 1, to: current)!
        }
        return result
    }
}
