//
//  MemoriesViewModel.swift
//  MeMo
//
//  Created by shota suzuki on 2026/03/20.
//

import Foundation
import Combine
import UIKit
import Photos

@MainActor
final class MemoriesViewModel: ObservableObject {
    // ✅ “タップした日” を保持（同日複数閲覧の起点）
    @Published var selectedDayKey: String?

    /// ✅ トースト通知（View側が購読して表示する）
    /// - 例：保存成功時に "保存しました！" を流す
    @Published var toastMessage: String?

    /// グリッド/リスト用キャッシュ
    /// - dayKey のサムネ用途は "day:\(dayKey)"
    /// - fileName の個別用途は "file:\(fileName)"
    @Published private(set) var imageCache: [String: UIImage] = [:]

    /// 読み込み中の二重起動防止
    private var loadingKeys: Set<String> = []

    /// メモリキャッシュ（自動で破棄されやすい）
    private let nsCache = NSCache<NSString, UIImage>()

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.timeZone = .current
        f.dateFormat = "yyyy/MM/dd"
        return f
    }()

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.timeZone = .current
        f.dateFormat = "HH:mm"
        return f
    }()

    // MARK: - Public

    func labelText(for date: Date) -> String {
        dateFormatter.string(from: date)
    }

    func timeText(for date: Date) -> String {
        timeFormatter.string(from: date)
    }

    // ✅ dayKeyサムネ（最新1枚）用
    func thumbnailImage(for dayKey: String) -> UIImage? {
        cachedImage(for: "day:\(dayKey)")
    }

    func loadThumbnailIfNeeded(dayKey: String, fileName: String) {
        loadImageIfNeeded(cacheKey: "day:\(dayKey)", fileName: fileName)
    }

    // ✅ fileName 個別用（同日複数ビューで使う）
    func image(forFileName fileName: String) -> UIImage? {
        cachedImage(for: "file:\(fileName)")
    }

    func loadImageIfNeeded(fileName: String) {
        loadImageIfNeeded(cacheKey: "file:\(fileName)", fileName: fileName)
    }

    /// メモリを節約したい時に呼べる（例：表示切替時など）
    func clearInMemoryCache(keepSelectedDay: Bool = true) {
        let keepDay = keepSelectedDay ? selectedDayKey : nil

        imageCache.removeAll(keepingCapacity: false)
        nsCache.removeAllObjects()
        loadingKeys.removeAll()

        // keepDay のサムネを残す（残っていれば）
        if let keepDay, let img = nsCache.object(forKey: ("day:\(keepDay)" as NSString)) {
            imageCache["day:\(keepDay)"] = img
        }
    }

    // ✅ 写真アプリへ保存（右下ボタン）
    // ✅ 成功したら toastMessage に "保存しました！" を流す
    func saveToPhotos(_ image: UIImage) async throws {
        let status = await requestAddOnlyAuthorizationIfNeeded()

        guard status == .authorized || status == .limited else {
            let err = NSError(
                domain: "MemoriesViewModel",
                code: 10,
                userInfo: [NSLocalizedDescriptionKey: "写真への追加が許可されていません。設定から許可してください。"]
            )
            toastMessage = err.localizedDescription
            throw err
        }

        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }
            // ✅ 要件：保存後に表示
            toastMessage = "保存しました！"
        } catch {
            toastMessage = "保存に失敗しました"
            throw error
        }
    }

    /// ✅ View側で表示し終わったら呼ぶ（同じメッセージが再発火しないように）
    func consumeToast() {
        toastMessage = nil
    }

    // MARK: - Private (cache)

    private func cachedImage(for cacheKey: String) -> UIImage? {
        if let img = imageCache[cacheKey] { return img }
        if let img = nsCache.object(forKey: cacheKey as NSString) {
            imageCache[cacheKey] = img
            return img
        }
        return nil
    }

    private func loadImageIfNeeded(cacheKey: String, fileName: String) {
        if cachedImage(for: cacheKey) != nil { return }

        if loadingKeys.contains(cacheKey) { return }
        loadingKeys.insert(cacheKey)

        Task(priority: .utility) { [weak self] in
            guard let self else { return }

            // ✅ TodayPhotoStorage.loadImage(fileName:) が MainActor 隔離でも警告が出ないようにする
            let img = await MainActor.run {
                TodayPhotoStorage.loadImage(fileName: fileName)
            }

            await MainActor.run {
                self.loadingKeys.remove(cacheKey)

                guard let img else { return }

                self.imageCache[cacheKey] = img
                self.nsCache.setObject(img, forKey: cacheKey as NSString)
            }
        }
    }

    // MARK: - Private (Photos auth)

    private func requestAddOnlyAuthorizationIfNeeded() async -> PHAuthorizationStatus {
        // iOS 14+ は addOnly が使える（追加だけ許可）
        let current = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        if current == .authorized || current == .limited || current == .denied || current == .restricted {
            return current
        }

        return await withCheckedContinuation { cont in
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                cont.resume(returning: status)
            }
        }
    }
}
