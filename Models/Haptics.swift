//
//  Haptics.swift
//  MeMo
//
//  Created by shota suzuki on 2026/03/20.
//

import UIKit

/// 「ダララララ」系の連続振動（疑似）
/// - CoreHapticsは使わず、Impactを細かく連打して再現
/// - 開始 / 停止を明示的に制御できる + 旧API(rattle)互換あり
enum Haptics {

    // MARK: - Internal state

    @MainActor
    private static var rattleTask: Task<Void, Never>?

    @MainActor
    private static var isRattling: Bool = false

    // MARK: - Rattle control (new)

    /// 連続振動を開始する（すでに鳴っている場合は何もしない）
    @MainActor
    static func startRattle(
        style: UIImpactFeedbackGenerator.FeedbackStyle = .light,
        interval: TimeInterval = 0.03,
        intensity: CGFloat = 0.8
    ) {
        guard !isRattling else { return }
        isRattling = true

        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()

        rattleTask = Task { @MainActor in
            while isRattling {
                if #available(iOS 13.0, *) {
                    generator.impactOccurred(intensity: intensity)
                } else {
                    generator.impactOccurred()
                }

                try? await Task.sleep(
                    nanoseconds: UInt64(interval * 1_000_000_000)
                )
            }
        }
    }

    /// 連続振動を停止する
    @MainActor
    static func stopRattle() {
        isRattling = false
        rattleTask?.cancel()
        rattleTask = nil
    }

    // MARK: - Backward compatible API (old)

    /// 旧: 連続的にブルブルさせる（ダララララ）
    /// - 既存コード互換のため残す
    /// - 内部は start/stop に委譲
    @MainActor
    static func rattle(
        duration: TimeInterval = 0.30,
        style: UIImpactFeedbackGenerator.FeedbackStyle = .light
    ) {
        // 旧実装互換：duration だけ鳴らして止める
        startRattle(style: style)

        let stopWork = DispatchWorkItem {
            Task { @MainActor in
                stopRattle()
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: stopWork)
    }

    // MARK: - Simple haptics

    /// 単発の軽い反応
    @MainActor
    static func tap(
        style: UIImpactFeedbackGenerator.FeedbackStyle = .light
    ) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }

    /// 成功 / 警告 / エラーなど（将来用）
    @MainActor
    static func notify(
        _ type: UINotificationFeedbackGenerator.FeedbackType
    ) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }
}
