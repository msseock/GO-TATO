//
//  LocationSelectViewModel.swift
//  GoTato
//

import Foundation
import RxSwift
import RxCocoa
import NMapsMap

final class LocationSelectViewModel: BaseViewModel {

    // MARK: - Input / Output

    struct Input {
        let searchText: Observable<String>
        let clearTap: Observable<Void>
        let itemTapped: Observable<Int>
        let ctaTapped: Observable<Void>
    }

    struct Output {
        let items: Driver<[NaverLocalItem]>
        let hasSearched: Driver<Bool>
        let isEmptyResult: Driver<Bool>
        let selectedIndex: Driver<Int?>
        let mapCoord: Driver<NMGLatLng?>
        let ctaEnabled: Driver<Bool>
        let ctaStyle: Driver<GTTButtonStyle>
        let locationConfirmed: Signal<SelectedLocation>
    }

    // MARK: - State

    private let allItems       = BehaviorRelay<[NaverLocalItem]>(value: [])
    private let hasSearched    = BehaviorRelay<Bool>(value: false)
    private let isEmptyResult  = BehaviorRelay<Bool>(value: false)
    private let selectedIndex  = BehaviorRelay<Int?>(value: nil)
    private let isLoading      = BehaviorRelay<Bool>(value: false)
    private let currentQuery   = BehaviorRelay<String>(value: "")
    private let disposeBag     = DisposeBag()

    // MARK: - Transform

    func transform(input: Input) -> Output {
        let locationConfirmed = PublishRelay<SelectedLocation>()

        // ── 검색 ────────────────────────────────────────────────────────────
        input.searchText
            .debounce(.milliseconds(500), scheduler: MainScheduler.instance)
            .distinctUntilChanged()
            .do(onNext: { [weak self] query in
                guard let self else { return }
                if query.isEmpty {
                    self.resetSearch()
                } else {
                    self.currentQuery.accept(query)
                    self.allItems.accept([])
                    self.selectedIndex.accept(nil)
                    self.hasSearched.accept(true)
                    self.isEmptyResult.accept(false)
                }
            })
            .filter { !$0.isEmpty }
            .flatMapLatest { [weak self] query -> Observable<NaverLocalSearchResponse> in
                guard let self else { return .empty() }
                self.isLoading.accept(true)
                return NaverLocalSearchService.shared.search(
                    NaverLocalSearchRequest(query: query, display: 5, start: 1)
                ).catch { [weak self] _ in
                    self?.isLoading.accept(false)
                    return .empty()
                }
            }
            .subscribe(onNext: { [weak self] response in
                guard let self else { return }
                self.isLoading.accept(false)
                self.allItems.accept(response.items)
                self.isEmptyResult.accept(response.items.isEmpty)
            })
            .disposed(by: disposeBag)

        // ✕ 버튼
        input.clearTap
            .subscribe(onNext: { [weak self] in self?.resetSearch() })
            .disposed(by: disposeBag)

        // ── 선택 (토글) ──────────────────────────────────────────────────────
        input.itemTapped
            .withLatestFrom(selectedIndex.asObservable()) { ($0, $1) }
            .subscribe(onNext: { [weak self] tapped, current in
                self?.selectedIndex.accept(current == tapped ? nil : tapped)
            })
            .disposed(by: disposeBag)

        // ── 지도 좌표 ────────────────────────────────────────────────────────
        let mapCoord = Observable
            .combineLatest(selectedIndex.asObservable(), allItems.asObservable())
            .map { idx, items -> NMGLatLng? in
                guard let idx, idx < items.count else { return nil }
                return Self.resolveCoord(for: items[idx])
            }
            .asDriver(onErrorJustReturn: nil)

        // ── CTA ─────────────────────────────────────────────────────────────
        let ctaEnabled = selectedIndex.map { $0 != nil }.asDriver(onErrorJustReturn: false)
        let ctaStyle = ctaEnabled.map { $0 ? GTTButtonStyle.primary : .secondary }

        input.ctaTapped
            .withLatestFrom(Observable.combineLatest(selectedIndex.asObservable(), allItems.asObservable()))
            .compactMap { idx, items -> SelectedLocation? in
                guard let idx, idx < items.count else { return nil }
                return Self.makeSelectedLocation(from: items[idx])
            }
            .bind(to: locationConfirmed)
            .disposed(by: disposeBag)

        return Output(
            items: allItems.asDriver(),
            hasSearched: hasSearched.asDriver(),
            isEmptyResult: isEmptyResult.asDriver(),
            selectedIndex: selectedIndex.asDriver(),
            mapCoord: mapCoord,
            ctaEnabled: ctaEnabled,
            ctaStyle: ctaStyle,
            locationConfirmed: locationConfirmed.asSignal()
        )
    }

    // MARK: - Private Helpers

    private func resetSearch() {
        currentQuery.accept("")
        allItems.accept([])
        selectedIndex.accept(nil)
        hasSearched.accept(false)
        isEmptyResult.accept(false)
        isLoading.accept(false)
    }

    // MARK: - 좌표 변환

    /// Naver 검색 API의 mapx/mapy를 NMGLatLng으로 변환.
    private static func resolveCoord(for item: NaverLocalItem) -> NMGLatLng? {
        guard let x = Double(item.mapx), let y = Double(item.mapy) else { return nil }

        let coord: NMGLatLng
        if x > 100_000_000 {
            coord = NMGLatLng(lat: y / 10_000_000.0, lng: x / 10_000_000.0)
        } else {
            coord = NMGTm128(x: x, y: y).toLatLng()
        }

        guard isInsideKorea(coord) else {
            print("[LocationVM] ⚠️ Coordinate outside Korea range: \(coord.lat), \(coord.lng)")
            return nil
        }
        return coord
    }

    private static func isInsideKorea(_ coord: NMGLatLng) -> Bool {
        (32.0...39.0).contains(coord.lat) && (124.0...132.0).contains(coord.lng)
    }

    private static func makeSelectedLocation(from item: NaverLocalItem) -> SelectedLocation? {
        guard let coord = resolveCoord(for: item) else { return nil }
        let address = item.roadAddress.isEmpty ? item.address : item.roadAddress
        return SelectedLocation(
            name: item.cleanTitle,
            address: address,
            lati: coord.lat,
            longi: coord.lng,
            mapx: Int(item.mapx) ?? 0,
            mapy: Int(item.mapy) ?? 0
        )
    }
}
