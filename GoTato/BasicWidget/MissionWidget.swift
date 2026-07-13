//
//  MissionWidget.swift
//  BasicWidget
//

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Configuration Intent

struct SelectMissionIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "미션 선택"
    static var description = IntentDescription("위젯에 표시할 미션을 선택하세요.")

    @Parameter(title: "미션")
    var mission: MissionEntity?
}

struct MissionEntity: AppEntity {
    let id: UUID
    let title: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "미션"
    static var defaultQuery = MissionEntityQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)")
    }
}

struct MissionEntityQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [MissionEntity] {
        WidgetSnapshotStore.load()
            .filter { identifiers.contains($0.id) }
            .map { MissionEntity(id: $0.id, title: $0.title) }
    }

    func suggestedEntities() async throws -> [MissionEntity] {
        let snapshots = WidgetSnapshotStore.load()
        let now = Date()
        return snapshots
            .sorted { abs($0.planDate.timeIntervalSince(now)) < abs($1.planDate.timeIntervalSince(now)) }
            .map { MissionEntity(id: $0.id, title: $0.title) }
    }
}

// MARK: - Timeline Provider

struct MissionProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> MissionEntry {
        MissionEntry(date: Date(), snapshot: nil)
    }

    func snapshot(for configuration: SelectMissionIntent, in context: Context) async -> MissionEntry {
        entry(for: configuration)
    }

    func timeline(for configuration: SelectMissionIntent, in context: Context) async -> Timeline<MissionEntry> {
        // 자체 주기 갱신 없음 — 메인 앱/지오펜스 콜백이 WidgetCenter.reloadTimelines로 갱신을 트리거한다.
        Timeline(entries: [entry(for: configuration)], policy: .never)
    }

    private func entry(for configuration: SelectMissionIntent) -> MissionEntry {
        let snapshots = WidgetSnapshotStore.load()
        let selected = configuration.mission.flatMap { selection in
            snapshots.first { $0.id == selection.id }
        }
        // 아직 미션을 선택하지 않았으면 현재 시각과 가장 가까운 미션을 기본값으로 보여준다.
        let snapshot = selected ?? WidgetSnapshotStore.nearestMission(from: snapshots)
        return MissionEntry(date: Date(), snapshot: snapshot)
    }
}

struct MissionEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetMissionSnapshot?
}

// MARK: - View

struct MissionWidgetEntryView: View {
    var entry: MissionEntry

    var body: some View {
        Group {
            if let snapshot = entry.snapshot {
                content(for: snapshot)
                    .widgetURL(URL(string: "gotato://mission/\(snapshot.id.uuidString)"))
            } else {
                Text("표시할 미션이 없어요")
                    .font(.caption)
                    .foregroundStyle(Color(uiColor: GTTColor.textQuiet))
            }
        }
        .containerBackground(for: .widget) { Color(uiColor: backgroundColor(for: entry.snapshot?.displayState)) }
    }

    private func content(for snapshot: WidgetMissionSnapshot) -> some View {
        VStack(spacing: 0) {
            Text(snapshot.title)
                .font(.subheadline).bold()
                .foregroundStyle(Color(uiColor: GTTColor.textPrimary))
                .lineLimit(1)

            Text(snapshot.deadline)
                .font(.caption2)
                .foregroundStyle(Color(uiColor: GTTColor.textSecondary))
                .padding(.vertical, 4)
            
            statusView(for: snapshot.displayState)
                .frame(
                    maxWidth: .infinity,
                    minHeight: 32
                )

            Image(potatoImageName(for: snapshot.displayState))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 120, height: 120)
//                .offset(y: 16)
        }
        .padding(.top, 30)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .offset(y: 16)
    }

    private func potatoImageName(for state: WidgetDisplayState) -> String {
        switch state {
        case .ongoing: return "PotatoFighting"
        case .success: return "PotatoNametag"
        case .failed, .locationPermissionDenied: return "PotatoSad"
        }
    }

    /// isNear일 땐 눌러야 할 것처럼 보이는 CTA 캡슐 버튼, 그 외엔 일반 상태 텍스트.
    @ViewBuilder
    private func statusView(for state: WidgetDisplayState) -> some View {
        switch state {
        case .ongoing(let isNear) where isNear:
            Text("인증하기")
                .font(.caption).bold()
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color(uiColor: GTTColor.brand)))
        case .ongoing:
            Text("출근 이동 중")
                .font(.caption).bold()
                .foregroundStyle(Color(uiColor: GTTColor.infoText))
        case .success:
            Text("출근 완료")
                .font(.caption).bold()
                .foregroundStyle(Color(uiColor: GTTColor.success))
        case .failed:
            Text("미인증")
                .font(.caption).bold()
                .foregroundStyle(Color(uiColor: GTTColor.errorSolid))
        case .locationPermissionDenied:
            Text("위치 권한 필요")
                .font(.caption).bold()
                .foregroundStyle(Color(uiColor: GTTColor.textQuiet))
        }
    }

    private func backgroundColor(for state: WidgetDisplayState?) -> UIColor {
        switch state {
        case .none: return GTTColor.surface
        case .ongoing(let isNear): return isNear ? GTTColor.bgCard : GTTColor.infoLight
        case .success: return GTTColor.successLight
        case .failed: return GTTColor.errorLight
        case .locationPermissionDenied: return GTTColor.surface
        }
    }
}

// MARK: - Widget

struct MissionWidget: Widget {
    let kind: String = "MissionWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SelectMissionIntent.self, provider: MissionProvider()) { entry in
            MissionWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("출근 미션")
        .description("선택한 미션의 출근 상태를 확인해요.")
        .supportedFamilies([.systemSmall])
    }
}

private func previewSnapshot(title: String, state: WidgetDisplayState) -> WidgetMissionSnapshot {
    WidgetMissionSnapshot(id: UUID(), title: title, deadline: "오전 9시까지", planDate: .now, displayState: state)
}

#Preview("출근 이동 중", as: .systemSmall) {
    MissionWidget()
} timeline: {
    MissionEntry(date: .now, snapshot: previewSnapshot(title: "출근 미션", state: .ongoing(isNear: false)))
}

#Preview("도착 (인증 가능)", as: .systemSmall) {
    MissionWidget()
} timeline: {
    MissionEntry(date: .now, snapshot: previewSnapshot(title: "출근 미션", state: .ongoing(isNear: true)))
}

#Preview("출근 완료", as: .systemSmall) {
    MissionWidget()
} timeline: {
    MissionEntry(date: .now, snapshot: previewSnapshot(title: "출근 미션", state: .success))
}

#Preview("미인증", as: .systemSmall) {
    MissionWidget()
} timeline: {
    MissionEntry(date: .now, snapshot: previewSnapshot(title: "출근 미션", state: .failed))
}

#Preview("위치 권한 필요", as: .systemSmall) {
    MissionWidget()
} timeline: {
    MissionEntry(date: .now, snapshot: previewSnapshot(title: "출근 미션", state: .locationPermissionDenied))
}

#Preview("미선택 상태", as: .systemSmall) {
    MissionWidget()
} timeline: {
    MissionEntry(date: .now, snapshot: nil)
}
