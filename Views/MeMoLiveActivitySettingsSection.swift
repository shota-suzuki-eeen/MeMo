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

    @AppStorage(MeMoLiveActivityManager.lockScreenEnabledStorageKey)
    private var isLockScreenEnabled: Bool = true

    @AppStorage(MeMoLiveActivityManager.dynamicIslandEnabledStorageKey)
    private var isDynamicIslandEnabled: Bool = true

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

            if isEnabled {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle(isOn: Binding(get: { isLockScreenEnabled }, set: { setLockScreenEnabled($0) })) {
                        Text("ロック画面")
                            .font(.subheadline.weight(.semibold))
                    }

                    Toggle(isOn: Binding(get: { isDynamicIslandEnabled }, set: { setDynamicIslandEnabled($0) })) {
                        Text("ダイナミックアイランド")
                            .font(.subheadline.weight(.semibold))
                    }
                }
                .padding(.leading, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
                .disabled(isChanging || !MeMoLiveActivityManager.shared.isSupported)
            }

            Text(descriptionText)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .animation(.easeInOut(duration: 0.18), value: isEnabled)
    }

    private var statusText: String {
        guard MeMoLiveActivityManager.shared.isSupported else {
            return "このiOSバージョンまたは端末設定では利用できません"
        }
        return isEnabled ? "ON" : "OFF"
    }

    private var descriptionText: String {
        if isEnabled {
            return "お世話中のペット名、歩数、満腹度、次の10回ガチャまでの残り歩数を表示します。表示先はロック画面とダイナミックアイランドで個別に切り替えられます。"
        }
        return "ONにすると、ロック画面とダイナミックアイランドの表示先を個別に設定できます。"
    }

    private func setEnabled(_ enabled: Bool) {
        guard isChanging == false else { return }
        bgmManager.playSE(.push)
        isChanging = true

        Task { @MainActor in
            if enabled {
                if UserDefaults.standard.object(forKey: MeMoLiveActivityManager.lockScreenEnabledStorageKey) == nil {
                    isLockScreenEnabled = true
                }
                if UserDefaults.standard.object(forKey: MeMoLiveActivityManager.dynamicIslandEnabledStorageKey) == nil {
                    isDynamicIslandEnabled = true
                }
            }

            await MeMoLiveActivityManager.shared.setEnabled(enabled, state: state)
            isChanging = false
        }
    }

    private func setLockScreenEnabled(_ enabled: Bool) {
        guard isChanging == false else { return }
        bgmManager.playSE(.push)
        isChanging = true

        Task { @MainActor in
            await MeMoLiveActivityManager.shared.setDisplayPreferences(
                lockScreenEnabled: enabled,
                state: state
            )
            isChanging = false
        }
    }

    private func setDynamicIslandEnabled(_ enabled: Bool) {
        guard isChanging == false else { return }
        bgmManager.playSE(.push)
        isChanging = true

        Task { @MainActor in
            await MeMoLiveActivityManager.shared.setDisplayPreferences(
                dynamicIslandEnabled: enabled,
                state: state
            )
            isChanging = false
        }
    }
}
