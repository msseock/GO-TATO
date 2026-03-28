//
//  NaverLocalSearchService.swift
//  GoTato
//

import Foundation
import Alamofire
import RxSwift

final class NaverLocalSearchService {
    static let shared = NaverLocalSearchService()
    private init() {}

    func search(_ request: NaverLocalSearchRequest) -> Observable<NaverLocalSearchResponse> {
        Observable.create { observer in
            let task = AF.request(
                NaverLocalSearchRequest.baseURL,
                method: .get,
                parameters: request.parameters,
                encoding: URLEncoding.queryString,
                headers: NaverLocalSearchRequest.headers
            )
            .validate(statusCode: 200..<300)
            .responseDecodable(of: NaverLocalSearchResponse.self) { response in
                switch response.result {
                case .success(let decoded):
                    observer.onNext(decoded)
                    observer.onCompleted()
                case .failure(let afError):
                    if let statusCode = response.response?.statusCode {
                        observer.onError(NaverSearchError.invalidResponse(statusCode: statusCode))
                    } else {
                        observer.onError(NaverSearchError.networkFailure(afError))
                    }
                }
            }
            return Disposables.create { task.cancel() }
        }
    }
}
