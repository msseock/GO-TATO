//
//  NaverLocalSearchAPI.swift
//  GoTato
//

import Foundation
import Alamofire

struct NaverLocalSearchRequest {
    let query: String
    let display: Int
    let start: Int
    let sort: SortType

    enum SortType: String {
        case random
        case comment
    }

    init(query: String, display: Int = 5, start: Int = 1, sort: SortType = .random) {
        self.query = query
        self.display = display
        self.start = start
        self.sort = sort
    }
}

extension NaverLocalSearchRequest {
    static let baseURL = "https://openapi.naver.com/v1/search/local.json"

    var parameters: Parameters {
        ["query": query, "display": display, "start": start, "sort": sort.rawValue]
    }

    static var headers: HTTPHeaders {
        [
            "X-Naver-Client-Id": SecretConstants.naverSearchAPICLientID,
            "X-Naver-Client-Secret": SecretConstants.naverSearchAPICLientSecret
        ]
    }
}

enum NaverSearchError: Error, LocalizedError {
    case networkFailure(Error)
    case invalidResponse(statusCode: Int)
    case decodingFailure(Error)

    var errorDescription: String? {
        switch self {
        case .networkFailure(let e): return "네트워크 오류: \(e.localizedDescription)"
        case .invalidResponse(let code): return "서버 응답 오류 (status: \(code))"
        case .decodingFailure(let e): return "응답 파싱 실패: \(e.localizedDescription)"
        }
    }
}
