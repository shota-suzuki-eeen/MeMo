//
//  TodayPhotoEntry.swift
//  MeMo
//
//  Created by shota suzuki on 2026/03/20.
//

import Foundation
import SwiftData
import UIKit

// MARK: - Persistent Photo Metadata
// ⚠️ SwiftData運用メモ
// TodayPhotoEntry は、思い出画像そのものではなく画像ファイルへの参照情報を保持する。
// リリース後は、dayKey / fileName / 保存ディレクトリの扱いを変更すると既存の思い出表示に影響する。
@Model
final class TodayPhotoEntry {
    // yyyyMMdd
    var dayKey: String

    // 表示用（並び順・ラベル）
    var date: Date

    // documents/memories/ のファイル名（例: 20260203.jpg）
    var fileName: String

    // ✅ 保存済みの地名（キャッシュ用）
    // 表示側では nil のとき "おもいで" を出す
    var placeName: String?

    // ✅ 追加：緯度・経度（逆ジオコーディング用）
    // 取得できなかった場合は nil
    var latitude: Double?
    var longitude: Double?

    init(
        dayKey: String,
        date: Date,
        fileName: String,
        placeName: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) {
        self.dayKey = dayKey
        self.date = date
        self.fileName = fileName
        self.placeName = placeName
        self.latitude = latitude
        self.longitude = longitude
    }

    // MARK: - Display Helpers（表示統一）

    /// placeName が空/未設定なら nil を返す（表示側でフォールバックしやすくする）
    static func memoryTitlePlace(_ placeName: String?) -> String? {
        guard let placeName else { return nil }
        let trimmed = placeName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// 仕様の1行目：「◯◯ の おもいで」 / 取れなければ「おもいで」
    static func memoryTitleLine(_ placeName: String?) -> String {
        if let place = memoryTitlePlace(placeName) {
            return "\(place) の おもいで"
        }
        return "おもいで"
    }
}

// MARK: - Storage
// ⚠️ リリース後の画像保存ルール
// TodayPhotoEntry は SwiftData に fileName を保存し、実画像は Documents/memories/ 配下に保存する。
// そのため、リリース後に以下を移行なしで変更すると既存画像が表示できなくなる可能性がある。
// - memories ディレクトリ名
// - fileName の命名ルール
// - JPEG保存形式
//
// 保存先を変更する場合は、旧パスから新パスへの移行処理を必ず用意する。
enum TodayPhotoStorage {
    static func memoriesDirURL() throws -> URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("memories", isDirectory: true)

        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(
                at: dir,
                withIntermediateDirectories: true
            )
        }

        return dir
    }

    static func fileURL(fileName: String) throws -> URL {
        try memoriesDirURL().appendingPathComponent(fileName)
    }

    static func loadImage(fileName: String) -> UIImage? {
        do {
            let url = try fileURL(fileName: fileName)
            return UIImage(contentsOfFile: url.path)
        } catch {
            return nil
        }
    }

    static func saveJPEG(
        _ image: UIImage,
        fileName: String,
        quality: CGFloat = 0.9
    ) throws {
        guard let data = image.jpegData(compressionQuality: quality) else {
            throw NSError(
                domain: "TodayPhotoStorage",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "JPEG変換に失敗しました"]
            )
        }

        let url = try fileURL(fileName: fileName)
        try data.write(to: url, options: .atomic)
    }
}
