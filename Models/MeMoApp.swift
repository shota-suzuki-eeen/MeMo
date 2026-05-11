//
//  MeMoApp.swift
//  MeMo
//
//  Created by shota suzuki on 2026/03/20.
//

import SwiftUI
import SwiftData
import UIKit

#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

@main
struct MeMoApp: App {

    // ✅ アプリ全体でBGMを1つだけ管理
    @StateObject private var bgmManager = BGMManager()

    init() {
        // ✅ AdMob 初期化（アプリ起動時に1回だけ）
        AdMobManager.shared.start()

        // iPad の SwiftUI fullScreenCover は RootView の phone canvas 外に出るため、
        // presented hosting controller 自体を HomeView と同じ固定サイズへ寄せる。
        // installIfNeeded() は一度だけ適用される。
        MemoIPadPresentedPhoneCanvas.installIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            MemoAppRootContainer(bgmManager: bgmManager)
        }
        // MARK: - SwiftData Schema
        // ⚠️ リリース後の運用ルール
        // ここに登録している @Model は、ユーザーのローカル保存データと直結している。
        // リリース後は以下を原則禁止する。
        // - 既存 @Model の削除
        // - 既存 @Model 名の変更
        // - .modelContainer から既存モデルを外す
        //
        // 新しい保存モデルが必要な場合は、既存モデルを残したまま配列に追加する。
        // 既存データを移行する場合は、旧モデル/旧プロパティを残した状態で段階的に行う。
        .modelContainer(for: [
            AppState.self,
            TodayPhotoEntry.self,
            WorkoutSessionRecord.self
        ])
    }
}

// MARK: - App Root Appearance Container

private struct MemoAppRootContainer: View {
    @ObservedObject var bgmManager: BGMManager

    // ✅ 表示モード（デフォルトはライトモード）
    @AppStorage(MemoAppearanceMode.storageKey) private var memoAppearanceModeRawValue: String = MemoAppearanceMode.light.rawValue

    private var appearanceMode: MemoAppearanceMode {
        MemoAppearanceMode.resolve(memoAppearanceModeRawValue)
    }

    var body: some View {
        RootView()
            .environmentObject(bgmManager)
            // iPadではiPhone相当のキャンバスに収め、既存のiPhone UIを崩さず中央表示する
            .memoIPadPhoneCanvas()
            // SwiftUI側の色環境を切り替える
            .preferredColorScheme(appearanceMode.colorScheme)
            // UIKit / Window側にも反映して、設定変更直後に確実に切り替える
            .background(
                MemoInterfaceStyleApplier(style: appearanceMode.userInterfaceStyle)
                    .frame(width: 0, height: 0)
                    .allowsHitTesting(false)
            )
            .onAppear {
                MemoInterfaceStyleApplier.apply(style: appearanceMode.userInterfaceStyle)
                bgmManager.startIfNeeded()
            }
            .onChange(of: memoAppearanceModeRawValue) { _, newValue in
                MemoInterfaceStyleApplier.apply(
                    style: MemoAppearanceMode.resolve(newValue).userInterfaceStyle
                )
            }
    }
}

// MARK: - Appearance Mode

enum MemoAppearanceMode: String, CaseIterable, Identifiable {
    static let storageKey = "memoAppearanceMode"

    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .light:
            return "ライト"
        case .dark:
            return "ダーク"
        }
    }

    var colorScheme: ColorScheme {
        switch self {
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }

    var userInterfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }

    static func resolve(_ rawValue: String) -> MemoAppearanceMode {
        MemoAppearanceMode(rawValue: rawValue) ?? .light
    }
}

// MARK: - UIKit Interface Style Applier

struct MemoInterfaceStyleApplier: UIViewControllerRepresentable {
    let style: UIUserInterfaceStyle

    func makeUIViewController(context: Context) -> Controller {
        let controller = Controller()
        controller.style = style
        controller.applyStyle()
        return controller
    }

    func updateUIViewController(_ uiViewController: Controller, context: Context) {
        uiViewController.style = style
        uiViewController.applyStyle()
    }

    static func apply(style: UIUserInterfaceStyle) {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }

        for scene in scenes {
            for window in scene.windows {
                window.overrideUserInterfaceStyle = style
            }
        }
    }

    final class Controller: UIViewController {
        var style: UIUserInterfaceStyle = .light

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            applyStyle()
        }

        override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
            super.viewWillTransition(to: size, with: coordinator)
            coordinator.animate(alongsideTransition: nil) { [weak self] _ in
                self?.applyStyle()
            }
        }

        func applyStyle() {
            view.window?.overrideUserInterfaceStyle = style
            Self.applyToActiveWindows(style: style)
        }

        private static func applyToActiveWindows(style: UIUserInterfaceStyle) {
            let scenes = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }

            for scene in scenes {
                for window in scene.windows {
                    window.overrideUserInterfaceStyle = style
                }
            }
        }
    }
}

// MARK: - Device Layout Support

enum MemoDevice {
    static var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
}

private struct MemoIPadPhoneCanvasModifier: ViewModifier {
    private enum Layout {
        // HomeView の iPad 基準サイズ。既存 iPhone UI の固定座標を崩さない。
        static let phoneSize = CGSize(width: 393, height: 852)
        static let cornerRadius: CGFloat = 42
    }

    @ViewBuilder
    func body(content: Content) -> some View {
        if MemoDevice.isIPad {
            ZStack {
                Color.clear
                    .ignoresSafeArea()

                content
                    .frame(width: Layout.phoneSize.width, height: Layout.phoneSize.height)
                    .background(Color(uiColor: .systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.18), radius: 28, x: 0, y: 14)
                    .accessibilityLabel("MeMo iPhone layout on iPad")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                MemoTransparentWindowBackgroundApplier()
                    .frame(width: 0, height: 0)
                    .allowsHitTesting(false)
            )
            .ignoresSafeArea(.keyboard, edges: .bottom)
        } else {
            content
        }
    }
}

extension View {
    func memoIPadPhoneCanvas() -> some View {
        modifier(MemoIPadPhoneCanvasModifier())
    }
}

// MARK: - Transparent Window Background

private struct MemoTransparentWindowBackgroundApplier: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .clear
        DispatchQueue.main.async {
            makeWindowTransparent(from: view)
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            makeWindowTransparent(from: uiView)
        }
    }

    private func makeWindowTransparent(from view: UIView) {
        guard MemoDevice.isIPad else { return }

        var current: UIView? = view
        var depth = 0

        while let targetView = current, depth < 8 {
            targetView.backgroundColor = .clear
            current = targetView.superview
            depth += 1
        }

        view.window?.backgroundColor = .clear
        view.window?.rootViewController?.view.backgroundColor = .clear
    }
}
