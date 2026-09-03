//
//  EventManager.swift
//  MeMo
//
//  期間限定イベントの開催判定を一元管理するローカル実装。
//  将来Supabaseへ移行する場合は、この定義取得元だけを置き換えられる構成。
//

import Foundation

enum EventID: String, Codable, CaseIterable, Hashable, Identifiable {
    case halloween2026 = "halloween2026"

    var id: String { rawValue }
}

struct EventDefinition: Hashable {
    let id: EventID
    let title: String
    let startDate: Date
    let endDate: Date

    func isActive(at date: Date = Date()) -> Bool {
        date >= startDate && date < endDate
    }

    func hasEnded(at date: Date = Date()) -> Bool {
        date >= endDate
    }
}

enum EventManager {
    private static let tokyoTimeZone = TimeZone(identifier: "Asia/Tokyo")!

    private static func tokyoDate(
        year: Int,
        month: Int,
        day: Int,
        hour: Int = 0,
        minute: Int = 0,
        second: Int = 0
    ) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = tokyoTimeZone

        return calendar.date(
            from: DateComponents(
                timeZone: tokyoTimeZone,
                year: year,
                month: month,
                day: day,
                hour: hour,
                minute: minute,
                second: second
            )
        )!
    }

    /// このイベントを含むアップデートが配信される時点では開始済みになるよう、
    /// ローカル開始日時を2026/09/03 00:00 JSTに固定。
    /// 実際にはイベント機能を含むバージョンをインストールしたユーザーだけが入口を持つ。
    static let halloween2026 = EventDefinition(
        id: .halloween2026,
        title: "ハロウィンイベント",
        startDate: tokyoDate(year: 2026, month: 9, day: 3),
        // 2026/10/31 23:59:59まで有効。11/1 00:00 JSTから完全終了。
        endDate: tokyoDate(year: 2026, month: 11, day: 1)
    )

    static func definition(for eventID: EventID) -> EventDefinition {
        switch eventID {
        case .halloween2026:
            return halloween2026
        }
    }

    static func isActive(_ eventID: EventID, at date: Date = Date()) -> Bool {
        definition(for: eventID).isActive(at: date)
    }

    static func hasEnded(_ eventID: EventID, at date: Date = Date()) -> Bool {
        definition(for: eventID).hasEnded(at: date)
    }

    static func remainingTime(_ eventID: EventID, at date: Date = Date()) -> TimeInterval {
        max(0, definition(for: eventID).endDate.timeIntervalSince(date))
    }
}
