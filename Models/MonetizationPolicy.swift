//
//  MonetizationPolicy.swift
//  MeMo
//
//  Centralized feature policy for future subscription support.
//  2026/06 update: 広告配信を一時停止。既存の広告方針はコメントとして残す。
//  2026/06 update: AdMob規約リスク低減のため、開発者モード時の広告SDK停止、広告リクエスト間隔、
//  インタースティシャル広告の表示頻度を一元管理する。
//

import Foundation

// MARK: - Premium Features

/// 将来サブスクリプション特典を追加するときに、View や Manager 側へ条件分岐を散らさないための定義。
///
/// 現時点では購入処理を実装せず、`SubscriptionAccessManager` の状態だけを参照する。
enum PremiumFeature: String, CaseIterable, Identifiable {
    case hidePassiveAds
    case premiumMemories
    case premiumCharacterItems

    var id: String { rawValue }
}

// MARK: - Monetization Policy

enum MonetizationPolicy {
    /// 全広告を停止するための一元スイッチ。
    ///
    /// 2026/06時点では AdMob 停止中のため `true` のまま維持する。
    /// 再開時は `false` に戻すが、開発者モード・Premium・頻度制御の条件は維持する。
    static let isAdvertisingPaused: Bool = true

    /// 同一広告枠への新規広告リクエスト最小間隔。
    ///
    /// 画面を短時間で行き来した場合でも、onAppear ごとに新しい広告リクエストを送らない。
    /// 60秒未満の場合は既存のロード済み広告を再利用し、未ロードの場合も追加リクエストしない。
    static let minimumAdRequestInterval: TimeInterval = 60

    /// インタースティシャル広告は、ユーザー操作2回につき最大1回までに制限する。
    ///
    /// 安全側に倒し、初回操作では表示せず、2回目以降の対象操作でのみ表示候補にする。
    static let minimumInterstitialUserActions: Int = 2

    /// 連続表示を避けるためのインタースティシャル広告の最小表示間隔。
    static let minimumInterstitialPresentationInterval: TimeInterval = 60

    /// 広告SDKへ触れてよい状態か。
    ///
    /// 開発者モードでは広告SDKを起動せず、広告リクエスト・広告表示も行わない。
    static func canTouchAdvertisingSDK(isDeveloperMode: Bool) -> Bool {
        !isAdvertisingPaused && !isDeveloperMode
    }

    /// バナー広告・インタースティシャル広告など、ユーザーが能動的に報酬獲得を選ばない広告を表示するか。
    ///
    /// - Developer Mode: 広告SDK自体を使用しない
    /// - Premium: 将来の広告非表示特典として広告は表示しない
    /// - Free: 広告停止解除後は広告を表示する
    static func shouldShowPassiveAdvertising(
        isDeveloperMode: Bool,
        hasPremiumAccess: Bool
    ) -> Bool {
        guard canTouchAdvertisingSDK(isDeveloperMode: isDeveloperMode) else { return false }
        guard !hasPremiumAccess else { return false }
        return true
    }

    /// リワード広告は、無料10回ガチャなどユーザーが報酬獲得のために明示的に選ぶ広告。
    /// 将来プレミアム特典としてスキップさせる場合は、このポリシーに分岐を集約する。
    static func shouldUseRewardedAdvertising(
        isDeveloperMode: Bool,
        hasPremiumAccess: Bool
    ) -> Bool {
        guard canTouchAdvertisingSDK(isDeveloperMode: isDeveloperMode) else { return false }

        // 広告再開時の既存方針:
        // Premium でも、報酬獲得型の広告はユーザーが明示的に選択するため利用対象にする。
        // 将来「広告スキップ券」等を導入する場合は、ここへ条件を追加する。
        return true
    }

    static func isPremiumFeatureEnabled(
        _ feature: PremiumFeature,
        hasPremiumAccess: Bool
    ) -> Bool {
        hasPremiumAccess
    }
}
