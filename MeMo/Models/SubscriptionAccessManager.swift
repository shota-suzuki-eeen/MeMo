//
//  SubscriptionAccessManager.swift
//  MeMo
//
//  Created as a preparation layer for future subscription support.
//

import Foundation
import Combine

// MARK: - Subscription Access State

/// 将来 StoreKit 2 を導入したときに、アプリ内の各機能が直接 StoreKit に依存しないようにするための入口。
///
/// 現時点ではサブスクリプション購入処理は実装しない。
/// そのため、デフォルトは常に `.free` とし、既存ユーザーの挙動を変えない。
///
/// 今後の実装方針:
/// - StoreKit 2 の `Transaction.currentEntitlements` で現在の権利状態を確認する
/// - `Transaction.updates` を監視して、別端末購入・更新・期限切れを反映する
/// - `AppState` などの SwiftData 保存モデルには、サブスク状態を正として保存しない
final class SubscriptionAccessManager: ObservableObject {
    static let shared = SubscriptionAccessManager()

    @Published private(set) var accessLevel: SubscriptionAccessLevel = .free

    private init() {}

    var hasPremiumAccess: Bool {
        accessLevel == .premium
    }

    /// 将来 StoreKit 2 の権利確認を実装するための予約メソッド。
    /// 現時点では機能実装を行わないため、既存挙動を維持する。
    func refreshEntitlements() async {
        accessLevel = .free
    }

    /// 将来 `Transaction.updates` の監視を開始するための予約メソッド。
    /// 現時点では何もしない。
    func startTransactionObservationIfNeeded() {
        // StoreKit 2 導入時に実装する。
    }

    #if DEBUG
    /// Preview やローカル確認でプレミアム状態のUI分岐を確認するための補助メソッド。
    /// 本番ビルドには含めない。
    func setPremiumAccessForDebug(_ isEnabled: Bool) {
        accessLevel = isEnabled ? .premium : .free
    }
    #endif
}

enum SubscriptionAccessLevel: String, Codable, Equatable {
    case free
    case premium
}
