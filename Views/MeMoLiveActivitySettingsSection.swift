//
//  MeMoLiveActivitySettingsSection.swift
//  MeMo
//
//  Settings screen section for toggling the care-status Live Activity.
//  Add this file to the MeMo app target only.
//

import SwiftData
import SwiftUI

struct MeMoLiveActivitySettingsSection: View {
    @EnvironmentObject private var bgmManager: BGMManager
    @Query private var states: [AppState]

    @AppStorage(MeMoLiveActivityManager.enabledStorageKey)
    private var isEnabled: Bool = false

    @State private var isChanging: Bool = false

    private var state: AppState? { states.first }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle(isOn: Binding(get: { isEnabled }, set: { setEnabled($0) })) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ライブアクティビティ")
                        .font(.headline)

                    Text(statusText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .disabled(isChanging || !MeMoLiveActivityManager.shared.isSupported)

            Text(descriptionText)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var statusText: String {
        guard MeMoLiveActivityManager.shared.isSupported else {
            return "このiOSバージョンまたは端末設定では利用できません"
        }
        return isEnabled ? "ON" : "OFF"
    }

    private var descriptionText: String {
        if isEnabled {
            return "ロック画面とダイナミックアイランドに、お世話中のミーモ、歩数、満腹度、次の10回ガチャまでの残り歩数を表示します。"
        }
        return "ONにすると、ロック画面とダイナミックアイランドでミーモの現在の状態を確認できます。"
    }

    private func setEnabled(_ enabled: Bool) {
        guard isChanging == false else { return }
        bgmManager.playSE(.push)
        isChanging = true

        Task { @MainActor in
            await MeMoLiveActivityManager.shared.setEnabled(enabled, state: state)
            isChanging = false
        }
    }
}
