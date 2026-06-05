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

    @AppStorage("memo.liveActivity.careStatus.enabled") private var isEnabled: Bool = false
    @State private var isChanging: Bool = false

    private var state: AppState? { states.first }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle(isOn: Binding(get: { isEnabled }, set: { setEnabled($0) })) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ロック画面に表示")
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
        "お世話中のペット名、歩数、満腹度、ごきげん、次の10連ガチャまでの進捗をロック画面とDynamic Islandに表示します。"
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
