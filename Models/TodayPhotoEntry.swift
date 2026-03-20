//
//  TodayPhotoEntry.swift
//  MeMo
//
//  Created by shota suzuki on 2026/03/20.
//

import Foundation
import SwiftData
import UIKit

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
