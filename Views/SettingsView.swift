//
//  SettingsView.swift
//  MeMo
//
//  Created by shota suzuki on 2026/03/20.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var bgmManager: BGMManager
    @Query private var appStates: [AppState]

    @State private var toastMessage: String?
    @State private var showToast: Bool = false

    // ✅ 開発者モード
    @AppStorage("isDeveloperMode") private var isDeveloperMode: Bool = false

    // ✅ 開発者モード解除/有効化用
    @State private var hiddenTapCount: Int = 0
    @State private var lastHiddenTapAt: Date?
    @State private var showDeveloperPinPopup: Bool = false
    @State private var developerPinText: String = ""
    @FocusState private var isDeveloperPinFocused: Bool

    private let developerPinCode = "eeen"
    private let hiddenTapRequiredCount = 15

    private var fixedDailyGoalSteps: Int {
        AppState.fixedDailyStepGoal
    }

    var body: some View {
        let state = ensureAppState()

        ZStack {
            Color.clear.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 8) {
                        Spacer()

                        Text("設定")
                            .font(.title2)
                            .bold()

                        if isDeveloperMode {
                            Text("DEV")
                                .font(.caption2.bold())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.orange)
                                .clipShape(Capsule())
                        }

                        Spacer()
                    }
                    .padding(.top, 8)

                    // ✅ 目標表示カード（編集不可）
                    VStack(alignment: .leading, spacing: 10) {
                        Text("1日の目標歩数")
                            .font(.headline)

                        Text("目標設定の変更機能は廃止されました。Home画面のメーターは毎日 10,000 歩を基準に表示されます。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("現在の目標")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)

                                Text("\(fixedDailyGoalSteps.formatted()) 歩")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(.primary)
                            }

                            Spacer()

                            Text("固定")
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.blue)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(14)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(radius: 8)

                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
                .contentShape(Rectangle())
            }

            VStack {
                Spacer()
                if showToast, let toastMessage {
                    Text(toastMessage)
                        .font(.footnote)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(.thinMaterial)
                        .clipShape(Capsule())
                        .shadow(radius: 8)
                        .padding(.bottom, 18)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }

            if showDeveloperPinPopup {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture {
                        closeDeveloperPinPopup()
                    }

                VStack(spacing: 14) {
                    Text(isDeveloperMode ? "開発者モードを解除" : "開発者モードを有効化")
                        .font(.headline)

                    Text("PINコードを入力してください")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    SecureField("PIN", text: $developerPinText)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($isDeveloperPinFocused)
                        .submitLabel(.done)
                        .onSubmit {
                            confirmDeveloperMode()
                        }

                    HStack(spacing: 10) {
                        Button("キャンセル") {
                            bgmManager.playSE(.push)
                            closeDeveloperPinPopup()
                        }
                        .buttonStyle(.bordered)

                        Button("決定") {
                            bgmManager.playSE(.push)
                            confirmDeveloperMode()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(20)
                .frame(maxWidth: 320)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .shadow(radius: 16)
                .padding(.horizontal, 24)
                .transition(.scale(scale: 0.95).combined(with: .opacity))
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        isDeveloperPinFocused = true
                    }
                }
            }
        }
        .contentShape(Rectangle())
        .simultaneousGesture(
            TapGesture().onEnded {
                registerHiddenTap()
            }
        )
        .background(
            ZStack {
                Image("setting_background")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()

                Color.black.opacity(0.25)
                    .ignoresSafeArea()
            }
        )
        .navigationBarTitleDisplayMode(.inline)
        .animation(.easeInOut(duration: 0.2), value: showDeveloperPinPopup)
        .onAppear {
            if state.normalizeFixedDailyStepGoal() {
                do {
                    try modelContext.save()
                } catch {
                    toast("目標歩数の更新に失敗しました")
                }
            }
        }
    }

    // MARK: - Developer Mode

    private func registerHiddenTap() {
        guard showDeveloperPinPopup == false else { return }

        let now = Date()
        if let lastHiddenTapAt, now.timeIntervalSince(lastHiddenTapAt) > 1.2 {
            hiddenTapCount = 0
        }

        hiddenTapCount += 1
        lastHiddenTapAt = now

        if hiddenTapCount >= hiddenTapRequiredCount {
            hiddenTapCount = 0
            developerPinText = ""
            withAnimation(.easeInOut(duration: 0.2)) {
                showDeveloperPinPopup = true
            }
            Haptics.rattle(duration: 0.12, style: .light)
        }
    }

    private func confirmDeveloperMode() {
        guard developerPinText == developerPinCode else {
            Haptics.rattle(duration: 0.14, style: .light)
            toast("PINコードが違います")
            developerPinText = ""
            isDeveloperPinFocused = true
            return
        }

        isDeveloperMode.toggle()
        Haptics.rattle(duration: 0.18, style: .light)

        if isDeveloperMode {
            toast("開発者モードを有効化しました")
        } else {
            toast("開発者モードを解除しました")
        }

        closeDeveloperPinPopup()
    }

    private func closeDeveloperPinPopup() {
        developerPinText = ""
        isDeveloperPinFocused = false
        withAnimation(.easeInOut(duration: 0.2)) {
            showDeveloperPinPopup = false
        }
    }

    // MARK: - AppState

    private func ensureAppState() -> AppState {
        if let first = appStates.first {
            return first
        }

        let created = AppState(
            walletKcal: 0,
            pendingKcal: 0,
            lastSyncedAt: nil,
            dailyGoalKcal: AppState.fixedDailyStepGoal,
            lastDayKey: AppState.makeDayKey(Date())
        )
        modelContext.insert(created)

        do {
            try modelContext.save()
        } catch { }

        return created
    }

    // MARK: - Toast

    private func toast(_ message: String) {
        toastMessage = message
        withAnimation(.easeInOut(duration: 0.2)) { showToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation(.easeInOut(duration: 0.2)) { showToast = false }
        }
    }
}
