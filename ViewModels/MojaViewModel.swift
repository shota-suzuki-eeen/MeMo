//
//  MojaViewModel.swift
//  MeMo
//
//  Created by shota suzuki on 2026/03/20.
//

import Foundation
import SwiftUI
import Combine

/// ✅ MojaView 用 ViewModel（MVVM）
@MainActor
final class MojaViewModel: ObservableObject {

    // MARK: - Published (UI)

    @Published private(set) var mojaCount: Int = 0

    @Published private(set) var fusionIsRunning: Bool = false
    @Published private(set) var fusionEndAt: Date? = nil

    /// ✅ 完了後（カウント0）に「受け取り待ち」へ
    @Published private(set) var fusionIsReadyToClaim: Bool = false

    /// fusion中：0〜(count-1) を回す
    @Published private(set) var fusionFrameIndex: Int = 0

    /// 画面中央トースト用（View側で表示してOK）
    @Published var centerToastMessage: String? = nil
    @Published var showCenterToast: Bool = false

    /// ✅ 獲得ポップアップ用
    @Published var showRewardPopup: Bool = false
    @Published var rewardedPetID: String? = nil

    // MARK: - Constants

    /// もじゃ合わせに必要な消費数
    let fusionCost: Int = 0

    /// 6時間
    private let fusionDuration: TimeInterval = 6 * 60 * 60

    /// 画像切り替え（仕様：moja → A → B → C → moja...）
    let fusionFrameAssetNames: [String] = [
        "moja",
        "moja_fusionA",
        "moja_fusionB",
        "moja_fusionC"
    ]

    /// ✅ 1秒Ticker（安定化：TimerではなくTaskで回す）
    private var tickerTask: Task<Void, Never>?

    // MARK: - Storage Keys

    private enum Keys {
        static let mojaCount = "mojaCount"
        static let fusionIsRunning = "mojaFusionIsRunning"
        static let fusionEndAt = "mojaFusionEndAt" // Double (timeIntervalSince1970)
        static let fusionReadyToClaim = "mojaFusionReadyToClaim"
    }

    private let defaults: UserDefaults

    // MARK: - Init

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        loadFromStorage()

        // ✅ 起動時に進行中ならTickerを再開
        if fusionIsRunning {
            startTickerIfNeeded()
        }
    }

    deinit {
        tickerTask?.cancel()
    }

    // MARK: - Public API

    /// View の onAppear で呼ぶ想定
    /// - AppState 側で獲得した mojaCount を MojaView に反映する
    func onAppearPrepareDemoIfNeeded(state: AppState) {
        syncMojaCount(from: state)

        if fusionIsRunning {
            startTickerIfNeeded()
        }
    }

    /// ✅ AppState を正本として mojaCount を同期
    func syncMojaCount(from state: AppState) {
        let safeCount = max(0, state.mojaCount)
        if mojaCount != safeCount {
            mojaCount = safeCount
        }

        // 既存の保存方式を壊さないため、UserDefaults にも反映
        persistMojaCount()
    }

    /// ✅ 開始可能判定
    /// - 全キャラ所持でも「ボタンは押せる」ため、
    ///   ここでは未所持キャラの有無は見ない
    func canStartFusion(state: AppState) -> Bool {
        syncMojaCount(from: state)

        if fusionIsRunning { return false }
        if fusionIsReadyToClaim { return false }
        if mojaCount < fusionCost { return false }
        return true
    }

    /// ✅ 「もじゃをまとめる」押下
    /// - 全キャラ所持時は融合開始せず、中央トーストだけ表示
    func startFusion(now: Date, state: AppState) {
        syncMojaCount(from: state)

        guard fusionIsRunning == false else { return }
        guard fusionIsReadyToClaim == false else { return }

        guard mojaCount >= fusionCost else {
            toastCenter("もじゃが足りない…")
            return
        }

        state.ensureInitialPetsIfNeeded()

        let owned = Set(state.ownedPetIDs())
        let candidates = AppState.initialZukanPetIDs.filter { !owned.contains($0) }

        guard candidates.isEmpty == false else {
            toastCenter("コンプリートおめでとう！\n 新しいカルペットが遊びにくるのをお楽しみに！")
            return
        }

        guard state.consumeMoja(fusionCost) else {
            syncMojaCount(from: state)
            toastCenter("もじゃが足りない…")
            return
        }

        // ✅ 消費後は AppState を正本として ViewModel 側へ反映
        syncMojaCount(from: state)

        fusionIsRunning = true
        fusionIsReadyToClaim = false
        fusionFrameIndex = 0

        let end = now.addingTimeInterval(fusionDuration)
        fusionEndAt = end

        persistFusionProgress()

        toastCenter("もじゃがまとまり始めた！")

        // ✅ ここでTicker開始
        startTickerIfNeeded()
    }

    /// ✅ 「新しいカルペットをGET」押下：ランダム獲得 → 状態リセット → ポップアップ
    func claimNewPet(state: AppState) {
        guard fusionIsReadyToClaim else { return }

        state.ensureInitialPetsIfNeeded()

        let owned = Set(state.ownedPetIDs())
        let candidates = AppState.initialZukanPetIDs.filter { !owned.contains($0) }

        guard let newId = candidates.randomElement() else {
            toastCenter("全部のキャラを持っている！")
            return
        }

        var ids = state.ownedPetIDs()
        ids.append(newId)
        state.setOwnedPetIDs(ids)

        // ✅ ポップアップに表示するID
        rewardedPetID = newId
        withAnimation(.easeOut(duration: 0.15)) {
            showRewardPopup = true
        }

        // ✅ アセット画像・ボタンを最初の状態に戻す（= 進行も受け取り待ちも解除）
        resetFusionToIdle()

        // ✅ 表示用カウントも再同期
        syncMojaCount(from: state)
    }

    /// 「広告視聴で時間を短縮」押下（指定秒数だけ短縮）
    /// - 広告の表示は View 側で行い、視聴完了時にこのメソッドを呼ぶ
    func applyAdReduction(seconds: TimeInterval, now: Date, state: AppState) {
        guard fusionIsRunning else { return }
        guard fusionIsReadyToClaim == false else { return }
        guard let end = fusionEndAt else { return }

        let reduce = max(0, seconds)
        if reduce <= 0 { return }

        let newEnd = end.addingTimeInterval(-reduce)
        fusionEndAt = newEnd
        persistFusionProgress()

        toastCenter("広告で3時間短縮！")

        // 直後に0判定
        syncFusionIfNeeded(now: now)

        // ✅ 念のためカウント同期
        syncMojaCount(from: state)
    }

    // MARK: - View helpers

    /// ✅ 現在表示するアセット名
    /// - 仕様：カウント0になったら CalPet_secret で固定
    func currentFusionAssetName() -> String {
        if fusionIsReadyToClaim {
            return "CalPet_secret"
        }

        if fusionIsRunning {
            let idx = max(0, min(fusionFrameIndex, fusionFrameAssetNames.count - 1))
            return fusionFrameAssetNames[idx]
        }

        return "moja"
    }

    /// 表示用の残り時間（非実行時の表示も含む）
    func formattedDisplayTime(now: Date) -> String {
        if fusionIsReadyToClaim {
            return "00:00:00"
        }

        if fusionIsRunning {
            return formattedRemaining(now: now)
        }

        return "06:00:00"
    }

    /// 残り秒数（fusion中のみ）
    func remainingSeconds(now: Date) -> TimeInterval {
        guard fusionIsRunning, let end = fusionEndAt else { return fusionDuration }
        return max(0, end.timeIntervalSince(now))
    }

    func formattedRemaining(now: Date) -> String {
        let sec = Int(remainingSeconds(now: now))
        let h = sec / 3600
        let m = (sec % 3600) / 60
        let s = sec % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }

    // MARK: - Private (Ticker)

    private func startTickerIfNeeded() {
        guard tickerTask == nil else { return }

        tickerTask = Task { [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                if self.fusionIsRunning == false { break }

                try? await Task.sleep(nanoseconds: 1_000_000_000)

                if Task.isCancelled { break }
                if self.fusionIsRunning == false { break }

                // ✅ 完了判定
                self.syncFusionIfNeeded(now: Date())

                // ✅ まだ走っているならフレーム更新（見た目用）
                if self.fusionIsRunning {
                    self.fusionFrameIndex = (self.fusionFrameIndex + 1) % self.fusionFrameAssetNames.count
                }
            }

            await MainActor.run {
                self.tickerTask = nil
            }
        }
    }

    private func stopTicker() {
        tickerTask?.cancel()
        tickerTask = nil
    }

    // MARK: - Private (Fusion)

    private func syncFusionIfNeeded(now: Date) {
        guard fusionIsRunning, let end = fusionEndAt else { return }

        if now >= end {
            fusionIsRunning = false
            fusionEndAt = nil
            fusionFrameIndex = 0
            fusionIsReadyToClaim = true
            persistFusionProgress()

            stopTicker()
        }
    }

    private func resetFusionToIdle() {
        fusionIsRunning = false
        fusionEndAt = nil
        fusionFrameIndex = 0
        fusionIsReadyToClaim = false
        persistFusionProgress()
    }

    private func toastCenter(_ message: String) {
        centerToastMessage = message
        withAnimation(.easeOut(duration: 0.15)) {
            showCenterToast = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { [weak self] in
            guard let self else { return }
            withAnimation(.easeOut(duration: 0.2)) {
                self.showCenterToast = false
            }
        }
    }

    // MARK: - Storage

    private func loadFromStorage() {
        mojaCount = defaults.integer(forKey: Keys.mojaCount)

        fusionIsRunning = defaults.bool(forKey: Keys.fusionIsRunning)

        let endRaw = defaults.double(forKey: Keys.fusionEndAt)
        if endRaw > 0 {
            fusionEndAt = Date(timeIntervalSince1970: endRaw)
        } else {
            fusionEndAt = nil
        }

        fusionIsReadyToClaim = defaults.bool(forKey: Keys.fusionReadyToClaim)

        if fusionIsRunning == false {
            fusionFrameIndex = 0
        } else {
            fusionFrameIndex = fusionFrameIndex % max(1, fusionFrameAssetNames.count)
        }
    }

    private func persistMojaCount() {
        defaults.set(mojaCount, forKey: Keys.mojaCount)
    }

    private func persistFusionProgress() {
        defaults.set(fusionIsRunning, forKey: Keys.fusionIsRunning)
        defaults.set(fusionIsReadyToClaim, forKey: Keys.fusionReadyToClaim)

        if let end = fusionEndAt {
            defaults.set(end.timeIntervalSince1970, forKey: Keys.fusionEndAt)
        } else {
            defaults.set(0, forKey: Keys.fusionEndAt)
        }
    }
}
