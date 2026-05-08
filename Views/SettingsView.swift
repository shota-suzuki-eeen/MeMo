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

                            SettingsNavigationRow(title: "利用規約", value: nil) {
                                TermsOfServiceView()
                            }
                            .simultaneousGesture(
                                TapGesture().onEnded {
                                    bgmManager.playSE(.push)
                                }
                            )

                            Divider()
                                .padding(.leading, 2)

                            SettingsNavigationRow(title: "プライバシーポリシー", value: nil) {
                                PrivacyPolicyView()
                            }
                            .simultaneousGesture(
                                TapGesture().onEnded {
                                    bgmManager.playSE(.push)
                                }
                            )

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

private struct SettingsNavigationRow<Destination: View>: View {
    let title: String
    let value: String?
    let destination: () -> Destination

    var body: some View {
        NavigationLink(destination: destination()) {
            SettingsRowContent(title: title, value: value)
        }
        .buttonStyle(.plain)
    }
}

private struct SettingsLinkRow: View {
    let title: String
    let value: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            SettingsRowContent(title: title, value: value)
        }
        .buttonStyle(.plain)
    }
}

private struct SettingsRowContent: View {
    let title: String
    let value: String?

    var body: some View {
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
}

private struct TermsOfServiceView: View {
    var body: some View {
        LegalDocumentView(
            title: "利用規約",
            updatedAt: LegalDocumentContent.termsLastUpdated,
            sections: LegalDocumentContent.termsSections
        )
    }
}

private struct PrivacyPolicyView: View {
    var body: some View {
        LegalDocumentView(
            title: "プライバシーポリシー",
            updatedAt: LegalDocumentContent.privacyPolicyLastUpdated,
            sections: LegalDocumentContent.privacyPolicySections
        )
    }
}

private struct LegalDocumentView: View {
    let title: String
    let updatedAt: String
    let sections: [LegalDocumentSection]

    var body: some View {
        ZStack {
            legalDocumentBackground

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(title)
                            .font(.title2.bold())

                        Text(updatedAt)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 18) {
                        ForEach(sections) { section in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(section.title)
                                    .font(.headline)

                                Text(section.body)
                                    .font(.body)
                                    .lineSpacing(4)
                                    .foregroundStyle(.primary)
                                    .textSelection(.enabled)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(16)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(radius: 8)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var legalDocumentBackground: some View {
        ZStack {
            Image("setting_background")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            Color.black
                .opacity(0.25)
                .ignoresSafeArea()
        }
    }
}

private struct LegalDocumentSection: Identifiable {
    let id = UUID()
    let title: String
    let body: String
}

private enum LegalDocumentContent {
    static let termsLastUpdated = "最終更新日：2026年5月8日"

    static let termsSections: [LegalDocumentSection] = [
        LegalDocumentSection(
            title: "1. はじめに",
            body: """
            本利用規約は、ミーモ - 歩数でペット育成（以下、「本アプリ」）の利用条件を定めるものです。
            本アプリを利用するユーザーは、本規約に同意したうえで本アプリを利用するものとします。
            """
        ),
        LegalDocumentSection(
            title: "2. 本アプリの内容",
            body: """
            本アプリは、歩数、日々の行動、集中時間、思い出写真などをもとに、キャラクター育成や記録を楽しむためのアプリです。
            本アプリの機能、表示内容、仕様は、改善や運用上の理由により、事前の通知なく変更、追加、停止、または終了される場合があります。
            """
        ),
        LegalDocumentSection(
            title: "3. 利用環境と権限",
            body: """
            本アプリでは、機能提供のためにHealthKit / ヘルスケア、位置情報、カメラ、写真へのアクセスなど、端末上の権限を使用する場合があります。
            これらの権限は、ユーザーの許可がある場合のみ利用されます。
            権限を許可しない場合、一部の機能が利用できない、または正常に動作しない場合があります。
            """
        ),
        LegalDocumentSection(
            title: "4. 禁止事項",
            body: """
            ユーザーは、本アプリの利用にあたり、以下の行為を行ってはなりません。

            ・法令または公序良俗に反する行為
            ・本アプリの運営、提供、または他のユーザーの利用を妨げる行為
            ・本アプリの不正利用、解析、改変、リバースエンジニアリングに該当する行為
            ・虚偽、不正確、または不適切な情報を入力する行為
            ・その他、開発者が不適切と判断する行為
            """
        ),
        LegalDocumentSection(
            title: "5. 広告表示",
            body: """
            本アプリでは、一部機能で広告を表示する場合があります。
            広告配信にはGoogle AdMobを利用しています。
            広告の表示内容、遷移先、広告提供者のサービスについて、開発者は管理または保証を行うものではありません。
            """
        ),
        LegalDocumentSection(
            title: "6. データの保存と管理",
            body: """
            本アプリでは、キャラクターの育成状態、所持情報、歩数に応じた報酬情報、ワーク・集中時間の記録、思い出写真の保存情報、アプリ設定情報などを端末内に保存する場合があります。
            端末の故障、紛失、アプリの削除、OSやアプリの不具合等により、保存データが失われる場合があります。
            """
        ),
        LegalDocumentSection(
            title: "7. 免責事項",
            body: """
            開発者は、本アプリの動作、正確性、完全性、継続性、特定目的への適合性について、明示または黙示を問わず保証しません。
            本アプリの利用によりユーザーに生じた損害について、開発者の故意または重過失がある場合を除き、開発者は責任を負いません。
            歩数、距離、ルート、集中時間などの表示は、端末やOS、各種権限、外部フレームワークの状態により、実際の値と異なる場合があります。
            """
        ),
        LegalDocumentSection(
            title: "8. 知的財産権",
            body: """
            本アプリに含まれる文章、画像、キャラクター、デザイン、プログラム、その他一切のコンテンツに関する権利は、開発者または正当な権利者に帰属します。
            ユーザーは、権利者の許可なく、これらを複製、転載、配布、改変、販売、または二次利用してはなりません。
            """
        ),
        LegalDocumentSection(
            title: "9. 規約の変更",
            body: """
            開発者は、必要に応じて本規約を変更できるものとします。
            変更後の規約は、本アプリ内または関連ページで表示された時点から効力を生じるものとします。
            """
        ),
        LegalDocumentSection(
            title: "10. お問い合わせ",
            body: """
            本規約に関するお問い合わせは、以下までお願いいたします。

            メール：pop.eeen.iin@gmail.com
            """
        )
    ]

    static let privacyPolicyLastUpdated = "最終更新日：2026年5月8日"

    static let privacyPolicySections: [LegalDocumentSection] = [
        LegalDocumentSection(
            title: "1. 取得する情報",
            body: """
            本アプリでは、以下の情報を取得する場合があります。

            ■ 健康データ（HealthKit）
            ・歩数

            これらの情報は、アプリ内機能の提供、キャラクター育成、報酬獲得、歩数記録の表示などのために使用されます。
            HealthKitデータは、ユーザーの許可がある場合のみ取得されます。
            HealthKitデータを広告配信、第三者への販売、または広告目的の分析に使用することはありません。

            ■ 位置情報
            ・ワークアウト・移動記録時の位置情報
            ・距離やルート計測に必要な位置情報
            ・写真撮影時の位置情報（任意）

            これらの情報は、ステップ記録、距離・ルートの表示、撮影した思い出写真への場所情報の付与などのために使用されます。
            位置情報は、ユーザーの許可がある場合のみ取得されます。
            バックグラウンドでの位置情報取得は、計測中のルート記録など、アプリ機能の提供に必要な場合に限り使用されます。
            位置情報を第三者へ販売することはありません。

            ■ カメラ・写真データ
            ・アプリ内で撮影した画像
            ・保存された思い出写真
            ・写真アプリへ保存するための画像データ

            これらは、キャラクターとの思い出撮影、思い出一覧での表示、端末への保存機能のために使用されます。
            撮影した画像は、原則として端末内に保存され、外部サーバーへ送信されることはありません。

            ■ アプリ内データ
            ・キャラクターの育成状態
            ・所持キャラクター・図鑑情報
            ・所持アイテム・ごはん情報
            ・歩数に応じた報酬情報
            ・ワーク・集中時間の記録
            ・思い出写真の保存情報
            ・アプリ設定情報

            これらの情報は、アプリ機能の継続利用、表示内容の復元、ユーザー体験の向上のために使用されます。

            ■ 広告関連情報
            本アプリでは、Google AdMobを利用して広告を配信しています。
            広告配信のために、Google AdMobにより広告識別子（IDFA等）、デバイス情報、広告の表示・利用状況、アプリの利用状況に関する情報などが自動的に収集される場合があります。

            Googleのプライバシーポリシー：
            https://policies.google.com/privacy
            """
        ),
        LegalDocumentSection(
            title: "2. 情報の利用目的",
            body: """
            取得した情報は、以下の目的で使用されます。

            ・アプリ機能の提供
            ・歩数記録・ルート記録・集中時間記録の表示
            ・キャラクター育成、図鑑、報酬機能の提供
            ・思い出写真の撮影・保存・表示
            ・アプリの品質向上および不具合対応
            ・広告の配信
            """
        ),
        LegalDocumentSection(
            title: "3. 第三者提供",
            body: """
            本アプリは、以下の場合を除き、ユーザー情報を第三者に提供することはありません。

            ・法令に基づく場合
            ・ユーザーの同意がある場合
            ・広告配信のためにGoogle AdMobが必要な情報を取得する場合

            なお、HealthKitデータを広告目的で第三者に提供することはありません。
            """
        ),
        LegalDocumentSection(
            title: "4. 情報の管理",
            body: """
            本アプリは、取得した情報を適切に管理し、不正アクセス、紛失、漏洩、改ざん等の防止に努めます。
            アプリ内で保存される写真、育成データ、記録データ等は、主にユーザーの端末内に保存されます。
            """
        ),
        LegalDocumentSection(
            title: "5. ユーザーの選択",
            body: """
            ユーザーは、端末の設定により以下を選択できます。

            ・HealthKit / ヘルスケア連携の許可・拒否
            ・位置情報の許可・拒否
            ・カメラの許可・拒否
            ・写真への追加・保存の許可・拒否
            ・広告トラッキングの許可・制限

            一部の権限を拒否した場合、該当機能が利用できない、または正常に動作しない場合があります。
            """
        ),
        LegalDocumentSection(
            title: "6. 未成年の利用",
            body: """
            未成年の方は、保護者の同意を得たうえで本アプリをご利用ください。
            """
        ),
        LegalDocumentSection(
            title: "7. 変更について",
            body: """
            本ポリシーは、法令、サービス内容、アプリ機能の変更等に応じて、必要に応じて変更される場合があります。
            変更後のプライバシーポリシーは、本ページまたはアプリ内で告知された時点から効力を生じるものとします。
            """
        ),
        LegalDocumentSection(
            title: "8. お問い合わせ",
            body: """
            プライバシーに関するお問い合わせは、以下までお願いいたします。

            メール：pop.eeen.iin@gmail.com
            """
        ),
        LegalDocumentSection(
            title: "9. 事業者情報",
            body: """
            開発者：Shota Suzuki
            """
        )
    ]
}
