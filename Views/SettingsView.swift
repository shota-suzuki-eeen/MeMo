//
//  SettingsView.swift
//  MeMo
//
//  Created by shota suzuki on 2026/03/20.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var bgmManager: BGMManager

    @State private var toastMessage: String?
    @State private var showToast: Bool = false

    // ✅ 開発者モード
    @AppStorage("isDeveloperMode") private var isDeveloperMode: Bool = false

    // ✅ 表示モード（デフォルトはライトモード）
    @AppStorage(MemoAppearanceMode.storageKey) private var memoAppearanceModeRawValue: String = MemoAppearanceMode.light.rawValue

    // ✅ 開発者モード解除/有効化用
    @State private var hiddenTapCount: Int = 0
    @State private var lastHiddenTapAt: Date?
    @State private var showDeveloperPinPopup: Bool = false
    @State private var developerPinText: String = ""
    @FocusState private var isDeveloperPinFocused: Bool

    private let developerPinCode = "eeen"
    private let hiddenTapRequiredCount = 15

    private let appVersion = "1.0.0"
    private let termsURL: URL? = nil
    private let privacyPolicyURL: URL? = nil
    private let contactURL = URL(
        string: "https://docs.google.com/forms/d/e/1FAIpQLScpk7wVSUGvr8AA2RDpVa3gak2lA_wk0GbLeQTlI62Wc0X58g/viewform?usp=header"
    )!

    private var selectedAppearanceMode: MemoAppearanceMode {
        MemoAppearanceMode.resolve(memoAppearanceModeRawValue)
    }

    var body: some View {
        ZStack {
            Color.clear.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    titleView

                    settingsSection(title: "テーマ") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("表示モード")
                                .font(.headline)

                            HStack(spacing: 10) {
                                ForEach(MemoAppearanceMode.allCases) { mode in
                                    appearanceModeButton(mode)
                                }
                            }

                            Text("アプリの表示をライトモード / ダークモードに切り替えます。")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    settingsSection(title: "システム") {
                        VStack(alignment: .leading, spacing: 14) {
                            Toggle(isOn: $bgmManager.isBGMEnabled) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("BGM")
                                        .font(.headline)

                                    Text(bgmManager.isBGMEnabled ? "ON" : "OFF")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .onChange(of: bgmManager.isBGMEnabled) { _, _ in
                                bgmManager.playSE(.push)
                            }

                            if bgmManager.isBGMEnabled {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("BGM音量")
                                            .font(.subheadline.weight(.semibold))

                                        Spacer()

                                        Text("\(bgmManager.bgmVolumeStep) / 10")
                                            .font(.subheadline.monospacedDigit())
                                            .foregroundStyle(.secondary)
                                    }

                                    Slider(
                                        value: Binding(
                                            get: { Double(bgmManager.bgmVolumeStep) },
                                            set: { newValue in
                                                bgmManager.bgmVolumeStep = Int(newValue.rounded())
                                            }
                                        ),
                                        in: 1...10,
                                        step: 1
                                    )
                                }
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }

                            Divider()

                            Toggle(isOn: $bgmManager.isSoundEffectEnabled) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("効果音")
                                        .font(.headline)

                                    Text(bgmManager.isSoundEffectEnabled ? "ON" : "OFF")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .onChange(of: bgmManager.isSoundEffectEnabled) { _, newValue in
                                if newValue {
                                    bgmManager.playSE(.push)
                                }
                            }
                        }
                    }

                    settingsSection(title: "アプリ") {
                        VStack(spacing: 0) {
                            SettingsValueRow(title: "バージョン", value: appVersion)

                            Divider()
                                .padding(.leading, 2)

                            SettingsLinkRow(title: "利用規約", value: "準備中") {
                                openOptionalURL(termsURL, fallbackMessage: "利用規約は準備中です")
                            }

                            Divider()
                                .padding(.leading, 2)

                            SettingsLinkRow(title: "プライバシーポリシー", value: "準備中") {
                                openOptionalURL(privacyPolicyURL, fallbackMessage: "プライバシーポリシーは準備中です")
                            }

                            Divider()
                                .padding(.leading, 2)

                            SettingsLinkRow(title: "お問い合わせ", value: nil) {
                                bgmManager.playSE(.push)
                                openURL(contactURL)
                            }
                        }
                    }

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
        .background(settingBackground)
        .navigationBarTitleDisplayMode(.inline)
        .animation(.easeInOut(duration: 0.2), value: showDeveloperPinPopup)
        .animation(.easeInOut(duration: 0.18), value: bgmManager.isBGMEnabled)
        .animation(.easeInOut(duration: 0.18), value: memoAppearanceModeRawValue)
        .onAppear {
            normalizeAppearanceModeIfNeeded()
            MemoInterfaceStyleApplier.apply(style: selectedAppearanceMode.userInterfaceStyle)
        }
        .onChange(of: memoAppearanceModeRawValue) { _, newValue in
            MemoInterfaceStyleApplier.apply(style: MemoAppearanceMode.resolve(newValue).userInterfaceStyle)
        }
    }

    private var titleView: some View {
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
    }

    private var settingBackground: some View {
        ZStack {
            Image("setting_background")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            Color.black
                .opacity(selectedAppearanceMode == .dark ? 0.55 : 0.25)
                .ignoresSafeArea()
        }
    }

    @ViewBuilder
    private func settingsSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 2)

            content()
                .padding(14)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(radius: 8)
        }
    }

    private func appearanceModeButton(_ mode: MemoAppearanceMode) -> some View {
        let isSelected = selectedAppearanceMode == mode

        return Button {
            selectAppearanceMode(mode)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.subheadline.weight(.semibold))

                Text(mode.title)
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(isSelected ? .white : .primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.accentColor : Color.primary.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.accentColor : Color.primary.opacity(0.12), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func selectAppearanceMode(_ mode: MemoAppearanceMode) {
        bgmManager.playSE(.push)

        guard memoAppearanceModeRawValue != mode.rawValue else {
            MemoInterfaceStyleApplier.apply(style: mode.userInterfaceStyle)
            return
        }

        memoAppearanceModeRawValue = mode.rawValue
        MemoInterfaceStyleApplier.apply(style: mode.userInterfaceStyle)
    }

    private func normalizeAppearanceModeIfNeeded() {
        let resolved = MemoAppearanceMode.resolve(memoAppearanceModeRawValue)
        if resolved.rawValue != memoAppearanceModeRawValue {
            memoAppearanceModeRawValue = resolved.rawValue
        }
    }

    private func openOptionalURL(_ url: URL?, fallbackMessage: String) {
        bgmManager.playSE(.push)

        guard let url else {
            toast(fallbackMessage)
            return
        }

        openURL(url)
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

    // MARK: - Toast

    private func toast(_ message: String) {
        toastMessage = message
        withAnimation(.easeInOut(duration: 0.2)) { showToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation(.easeInOut(duration: 0.2)) { showToast = false }
        }
    }
}

private struct SettingsValueRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.body)

            Spacer()

            Text(value)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 12)
    }
}

private struct SettingsLinkRow: View {
    let title: String
    let value: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(.primary)

                Spacer()

                if let value {
                    Text(value)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
