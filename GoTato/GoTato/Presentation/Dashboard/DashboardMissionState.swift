//
//  DashboardMissionState.swift
//  GoTato
//

import Foundation

struct DashboardMissionState {
    let title: String
    let deadline: String
    let messageCardState: DashBoardMessageCardState
    let mainActionState: MainActionState
    let bottomButtonState: BottomButtonState
    let attendanceID: UUID?
    let missionID: UUID?
    let wifiSSID: String?
    let wifiWarning: String?
}

enum MainActionState {
    case noMission
    case ongoing(OngoingMissionCardState)
    case locationPermissionDenied
    case success(recordDate: Date, locationName: String)
    case failed
    case failedCommitted
}

enum BottomButtonState {
    case hidden
    case checkIn(isEnabled: Bool)
    case commit
}
