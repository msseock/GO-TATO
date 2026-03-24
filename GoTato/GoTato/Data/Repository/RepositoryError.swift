//
//  RepositoryError.swift
//  GoTato
//

import Foundation

enum RepositoryError: Error {
    case tooManyActiveMissions  // 진행 중 미션 10개 이상
    case deadlineConflict       // 기존 미션 deadline ±5분 이내
    case missionPeriodTooLong   // endDate > startDate + 1달
    case notFound               // ID로 조회 실패
}
