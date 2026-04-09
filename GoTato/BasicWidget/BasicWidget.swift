//
//  BasicWidget.swift
//  BasicWidget
//
//  Created by 석민솔 on 4/9/26.
//

import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        completion(SimpleEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let timeline = Timeline(entries: [SimpleEntry(date: Date())], policy: .never)
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
}

struct BasicWidgetEntryView: View {
    var entry: Provider.Entry

    var body: some View {
        Image("PotatoSparkle")
            .resizable()
            .interpolation(.high)
            .antialiased(true)
            .aspectRatio(contentMode: .fit)
    }
}

struct BasicWidget: Widget {
    let kind: String = "BasicWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(iOS 17.0, *) {
                BasicWidgetEntryView(entry: entry)
                    .containerBackground(for: .widget) {
                        Color("BrandColor")
                    }
            } else {
                BasicWidgetEntryView(entry: entry)
                    .padding()
                    .background(Color("BrandColor"))
            }
        }
        .configurationDisplayName("일단감자")
        .description("앱 바로가기")
        .supportedFamilies([.systemSmall])
    }
}

#Preview(as: .systemSmall) {
    BasicWidget()
} timeline: {
    SimpleEntry(date: .now)
}
