//
//  RootView.swift
//  MeMo
//
//  Created by shota suzuki on 2026/03/20.
//

import SwiftUI
import SwiftData
import UIKit

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var appStates: [AppState]
    @StateObject private var hk = HealthKitManager()

    // 起動処理の多重実行防止は ViewModel 側で担保
    @StateObject private var viewModel = RootViewModel()

    // App 側で environmentObject 注入済み
    @EnvironmentObject private var bgmManager: BGMManager
    @State private var isHomeBannerHiddenByChildScreen: Bool = false
    @State private var isHomeNavigationDestinationVisible: Bool = false

    var body: some View {
        Group {
            switch hk.authState {
            case .unknown:
                AuthRequestView(
                    onAuthorize: { Task { await viewModel.startAuthorizationIfNeeded(hk: hk) } },
                    errorMessage: hk.errorMessage
                )

            case .denied:
                DeniedView()

            case .authorized:
                if let sharedState = viewModel.sharedState {
                    ZStack(alignment: .top) {
                        HomeView(state: sharedState, hk: hk)

                        HomeNavigationDepthReader { depth in
                            isHomeNavigationDestinationVisible = depth > 1
                        }
                        .frame(width: 0, height: 0)
                        .allowsHitTesting(false)

                        if !isHomeBannerHiddenByChildScreen && !isHomeNavigationDestinationVisible {
                            // ✅ Banner_HomeView
                            // Home画面上部（メーターの上）に表示。
                            // 思い出 / 設定 / 図鑑など、Home配下の遷移先では
                            // 各画面からの通知で非表示にする。
                            AdBannerView(
                                placement: .home,
                                height: 76,
                                maxBannerWidth: 320,
                                contentHeight: 50,
                                topOffset: 10
                            )
                            .allowsHitTesting(false)
                            .zIndex(10_000)
                            .transition(.opacity)
                        }
                    }
                    .onAppear {
                        isHomeBannerHiddenByChildScreen = false
                        AdMobManager.shared.prepareInterstitialGetIfNeeded(
                            isRewardClaimable: sharedState.nextClaimableHappinessRewardLevel() != nil
                        )
                    }
                    .onReceive(NotificationCenter.default.publisher(for: .memoHideHomeBannerAd)) { _ in
                        withAnimation(.easeInOut(duration: 0.18)) {
                            isHomeBannerHiddenByChildScreen = true
                        }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: .memoShowHomeBannerAd)) { _ in
                        withAnimation(.easeInOut(duration: 0.18)) {
                            isHomeBannerHiddenByChildScreen = false
                        }
                    }
                    .onChange(of: sharedState.happinessLevel) { _, _ in
                        AdMobManager.shared.prepareInterstitialGetIfNeeded(
                            isRewardClaimable: sharedState.nextClaimableHappinessRewardLevel() != nil
                        )
                    }
                } else {
                    ProgressView()
                }
            }
        }
        .task {
            await viewModel.bootIfNeeded(
                appStates: appStates,
                modelContext: modelContext,
                hk: hk,
                bgmManager: bgmManager
            )
        }
    }
}

// MARK: - Shared views

private struct AuthRequestView: View {
    let onAuthorize: () -> Void
    let errorMessage: String?

    var body: some View {
        VStack(spacing: 16) {
            Text("Health連動が必要です")
                .font(.title2)
                .bold()

            Text("歩数を取得します。\n許可しない場合は利用できません。")
                .multilineTextAlignment(.center)

            Button("許可してはじめる") {
                onAuthorize()
            }
            .buttonStyle(.borderedProminent)

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
    }
}

private struct DeniedView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 16) {
            Text("Healthの許可が必要です")
                .font(.title2)
                .bold()

            Text("設定アプリで歩数のHealthアクセスを許可してください。\n許可されない場合、このアプリは利用できません。")
                .multilineTextAlignment(.center)

            Button("設定を開く") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}


// MARK: - Home Banner Visibility Notifications

extension Notification.Name {
    /// HomeView上部のバナー広告を、Home配下の遷移先画面で一時的に非表示にするための通知。
    static let memoHideHomeBannerAd = Notification.Name("memo.hideHomeBannerAd")

    /// HomeViewへ戻ったタイミングで、HomeView上部のバナー広告を再表示するための通知。
    static let memoShowHomeBannerAd = Notification.Name("memo.showHomeBannerAd")
}


// MARK: - Navigation Depth Reader

private struct HomeNavigationDepthReader: UIViewControllerRepresentable {
    var onDepthChange: (Int) -> Void

    func makeUIViewController(context: Context) -> ObserverViewController {
        let controller = ObserverViewController()
        controller.onDepthChange = onDepthChange
        return controller
    }

    func updateUIViewController(_ uiViewController: ObserverViewController, context: Context) {
        uiViewController.onDepthChange = onDepthChange
        uiViewController.startMonitoringIfNeeded()
    }

    final class ObserverViewController: UIViewController {
        var onDepthChange: ((Int) -> Void)?
        private var timer: Timer?
        private var lastDepth: Int?

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            startMonitoringIfNeeded()
            publishDepthIfNeeded()
        }

        override func viewDidDisappear(_ animated: Bool) {
            super.viewDidDisappear(animated)
            stopMonitoring()
        }

        deinit {
            stopMonitoring()
        }

        func startMonitoringIfNeeded() {
            guard timer == nil else { return }
            let newTimer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
                self?.publishDepthIfNeeded()
            }
            timer = newTimer
            RunLoop.main.add(newTimer, forMode: .common)
            publishDepthIfNeeded()
        }

        private func stopMonitoring() {
            timer?.invalidate()
            timer = nil
        }

        private func publishDepthIfNeeded() {
            let depth = currentMaximumNavigationDepth()
            guard depth != lastDepth else { return }
            lastDepth = depth
            onDepthChange?(depth)
        }

        private func currentMaximumNavigationDepth() -> Int {
            var depths: [Int] = []

            if let navigationController {
                depths.append(navigationController.viewControllers.count)
            }

            if let nearestNavigationController = nearestNavigationController() {
                depths.append(nearestNavigationController.viewControllers.count)
            }

            if let root = activeRootViewController() {
                let globalDepths = collectNavigationControllers(from: root).map { $0.viewControllers.count }
                depths.append(contentsOf: globalDepths)
            }

            return max(depths.max() ?? 1, 1)
        }

        private func nearestNavigationController() -> UINavigationController? {
            if let navigationController {
                return navigationController
            }

            var current: UIViewController? = parent
            while let controller = current {
                if let navigationController = controller as? UINavigationController {
                    return navigationController
                }
                if let navigationController = controller.navigationController {
                    return navigationController
                }
                current = controller.parent
            }

            return nil
        }

        private func activeRootViewController() -> UIViewController? {
            let activeScenes = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .filter { $0.activationState == .foregroundActive }

            let keyWindow = activeScenes
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }

            return keyWindow?.rootViewController
        }

        private func collectNavigationControllers(from controller: UIViewController) -> [UINavigationController] {
            var result: [UINavigationController] = []

            if let navigationController = controller as? UINavigationController {
                result.append(navigationController)
            }

            if let navigationController = controller.navigationController {
                result.append(navigationController)
            }

            if let presentedViewController = controller.presentedViewController {
                result.append(contentsOf: collectNavigationControllers(from: presentedViewController))
            }

            for child in controller.children {
                result.append(contentsOf: collectNavigationControllers(from: child))
            }

            var seen = Set<ObjectIdentifier>()
            return result.filter { navigationController in
                let identifier = ObjectIdentifier(navigationController)
                guard !seen.contains(identifier) else { return false }
                seen.insert(identifier)
                return true
            }
        }
    }
}
