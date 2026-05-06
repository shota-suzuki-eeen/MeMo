//
//  MonetizationPolicy.swift
//  MeMo
//
//  Centralized feature policy for future subscription support.
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
    /// バナー広告・インタースティシャル広告など、ユーザーが能動的に報酬獲得を選ばない広告を表示するか。
    ///
    /// - Developer Mode: 既存挙動通り広告は表示しない
    /// - Premium: 将来の広告非表示特典として広告は表示しない
    /// - Free: 既存挙動通り広告を表示する
    static func shouldShowPassiveAdvertising(
        isDeveloperMode: Bool,
        hasPremiumAccess: Bool
    ) -> Bool {
        !isDeveloperMode && !hasPremiumAccess
    }

    /// リワード広告は、無料10回ガチャなどユーザーが報酬獲得のために明示的に選ぶ広告。
    /// 将来プレミアム特典としてスキップさせる場合は、このポリシーに分岐を集約する。
    static func shouldUseRewardedAdvertising(
        isDeveloperMode: Bool,
        hasPremiumAccess: Bool
    ) -> Bool {
        !isDeveloperMode
    }

    static func isPremiumFeatureEnabled(
        _ feature: PremiumFeature,
        hasPremiumAccess: Bool
    ) -> Bool {
        hasPremiumAccess
    }
}
