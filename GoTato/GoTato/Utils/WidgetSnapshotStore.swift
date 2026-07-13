import Foundation

/// 위젯에 표시할 미션 1건의 상태 스냅샷. CoreData 모델을 직접 넘기지 않고
/// 위젯 UI에 필요한 최소 필드만 담아 App Group UserDefaults에 JSON으로 저장한다.
struct WidgetMissionSnapshot: Codable, Identifiable, Equatable {
    let id: UUID
    let title: String
    let deadline: String
    let planDate: Date
    let displayState: WidgetDisplayState
}

enum WidgetDisplayState: Codable, Equatable {
    case ongoing(isNear: Bool)
    case success
    case failed
    case locationPermissionDenied
}

enum WidgetSnapshotStore {
    static let suiteName = "group.msseock.widgetpractice"
    private static let missionsKey = "widget.missionSnapshots"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }

    /// 메인 앱에서 호출 — 오늘의 전체 미션 스냅샷을 통째로 덮어쓴다.
    static func save(_ snapshots: [WidgetMissionSnapshot]) {
        guard let data = try? JSONEncoder().encode(snapshots) else { return }
        defaults?.set(data, forKey: missionsKey)
    }

    /// 지오펜스 콜백 등에서 호출 — 특정 미션 하나만 교체(없으면 추가)한다.
    static func upsert(_ snapshot: WidgetMissionSnapshot) {
        var snapshots = load()
        if let index = snapshots.firstIndex(where: { $0.id == snapshot.id }) {
            snapshots[index] = snapshot
        } else {
            snapshots.append(snapshot)
        }
        save(snapshots)
    }

    /// 위젯에서 호출 — 저장된 스냅샷 목록을 읽는다.
    static func load() -> [WidgetMissionSnapshot] {
        guard let data = defaults?.data(forKey: missionsKey),
              let snapshots = try? JSONDecoder().decode([WidgetMissionSnapshot].self, from: data)
        else { return [] }
        return snapshots
    }

    /// planDate가 현재 시각에 가장 가까운 미션. 위젯 미선택 상태의 기본값으로 쓰인다.
    static func nearestMission(from snapshots: [WidgetMissionSnapshot], now: Date = Date()) -> WidgetMissionSnapshot? {
        snapshots.min { abs($0.planDate.timeIntervalSince(now)) < abs($1.planDate.timeIntervalSince(now)) }
    }

    /// DashboardViewModel.formatDeadline과 동일한 포맷("오후 9시 30분까지"). 위젯 스냅샷 부분 갱신 시 재사용.
    static func formatDeadline(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "a h시"
        let hourStr = formatter.string(from: date)

        let minutes = Calendar.current.component(.minute, from: date)
        return minutes == 0 ? "\(hourStr)까지" : "\(hourStr) \(minutes)분까지"
    }
}
