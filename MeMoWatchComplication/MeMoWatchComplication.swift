//
//  MeMoWatchComplication.swift
//  MeMoWatchComplicationExtension
//
//  Apple Watch の文字盤上に MeMo へのショートカットを表示する
//  WidgetKit コンプリケーション。
//
//  切り分け用としてカスタム画像アセットを使用せず、
//  SF Symbols の pawprint.fill を表示します。
//

import SwiftUI
import WidgetKit

struct MeMoWatchComplicationEntry: TimelineEntry {
    let date: Date
}

struct MeMoWatchComplicationProvider: TimelineProvider {
    func placeholder(in context: Context) -> MeMoWatchComplicationEntry {
        MeMoWatchComplicationEntry(date: Date())
    }

    func getSnapshot(
        in context: Context,
        completion: @escaping (MeMoWatchComplicationEntry) -> Void
    ) {
        completion(
            MeMoWatchComplicationEntry(date: Date())
        )
    }

    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<MeMoWatchComplicationEntry>) -> Void
    ) {
        let entry = MeMoWatchComplicationEntry(date: Date())

        completion(
            Timeline(
                entries: [entry],
                policy: .never
            )
        )
    }
}

struct MeMoWatchComplication: Widget {
    static let kind = "MeMoWatchComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: Self.kind,
            provider: MeMoWatchComplicationProvider()
        ) { entry in
            MeMoWatchComplicationEntryView(entry: entry)
        }
        .configurationDisplayName("MeMo")
        .description("文字盤からMeMoをすぐに開きます。")
        .supportedFamilies([
            .accessoryCircular
        ])
    }
}

private struct MeMoWatchComplicationEntryView: View {
    let entry: MeMoWatchComplicationEntry

    var body: some View {
        Image(systemName: "pawprint.fill")
            .font(.system(size: 28, weight: .bold))
            .containerBackground(for: .widget) {
                Color.clear
            }
            .accessibilityLabel("MeMoを開く")
    }
}
