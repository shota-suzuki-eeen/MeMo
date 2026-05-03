//
//  MemoTutorialZukanSwitchView.swift
//  MeMo
//
//  Mandatory onboarding character switch bridge.
//  The tutorial now follows the real Home menu flow and then uses the real ZukanView.
//  iOS 18.6+
//

import SwiftUI

struct MemoTutorialZukanSwitchView: View {
    let state: AppState
    let onFinish: () -> Void

    @EnvironmentObject private var bgmManager: BGMManager
    @AppStorage(WallpaperCatalog.selectedHomeWallpaperAssetNameKey)
    private var selectedHomeWallpaperAssetName: String = WallpaperCatalog.defaultWallpaper.assetName

    @State private var phase: Phase = .menuButton
    @State private var showMenuPopup: Bool = false
    @State private var isPulsing: Bool = false

    private enum Phase: Equatable {
        case menuButton
        case pictureButton
        case zukan
    }

    private enum Layout {
        static let bottomButtonSize: CGFloat = 68
        static let bottomButtonsSpacing: CGFloat = 16
        static let bottomPadding: CGFloat = 72
        static let bottomHorizontalPadding: CGFloat = 18
        static let bottomButtonBackgroundAssetName: String = "clay_block"
        static let bottomButtonBackgroundSize: CGFloat = 76
        static let bottomButtonIconSize: CGFloat = 68
        static let bottomButtonCornerRadius: CGFloat = 22
        static let bottomBarHorizontalPadding: CGFloat = 14
        static let bottomBarVerticalPadding: CGFloat = 12

        static let menuPopupMaxWidth: CGFloat = 360
        static let menuPopupHorizontalPadding: CGFloat = 18
        static let menuPopupBackgroundAssetName: String = "blue_block"
        static let menuPopupButtonBackgroundAssetName: String = "clay_block"
        static let menuPopupCloseButtonAssetName: String = "close_button"
        static let menuPopupCloseButtonSize: CGFloat = 54
        static let menuPopupCloseButtonTopPadding: CGFloat = 18
        static let menuPopupCloseButtonTrailingPadding: CGFloat = 18
        static let menuPopupContentTopPadding: CGFloat = 34
        static let menuPopupContentBottomPadding: CGFloat = 20
        static let menuPopupGridOffsetX: CGFloat = -12
        static let menuPopupGridOffsetY: CGFloat = 8
        static let menuPopupGridWidth: CGFloat = 296
        static let menuButtonSize: CGFloat = 116
        static let menuButtonSpacing: CGFloat = 28
    }

    private var petID: String {
        state.memoTutorialGachaCharacterPetID
    }

    private var homeBackgroundAssetName: String {
        WallpaperCatalog.item(for: selectedHomeWallpaperAssetName)?.assetName
        ?? WallpaperCatalog.defaultWallpaper.assetName
    }

    private var currentCharacterAssetName: String {
        PetMaster.assetName(for: state.normalizedCurrentPetID)
    }

    var body: some View {
        Group {
            switch phase {
            case .menuButton, .pictureButton:
                homeMenuTutorialView
            case .zukan:
                NavigationStack {
                    ZukanView(
                        isTutorialMode: true,
                        tutorialTargetPetID: petID,
                        onTutorialSwitchFinished: onFinish
                    )
                }
                .environmentObject(bgmManager)
            }
        }
        .interactiveDismissDisabled(true)
        .onAppear {
            _ = state.memoAwardTutorialGachaCharacterIfNeeded()
            withAnimation(.easeInOut(duration: 0.95).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }

    private var homeMenuTutorialView: some View {
        GeometryReader { proxy in
            ZStack {
                Image(homeBackgroundAssetName)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()

                Color.black.opacity(0.08)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer(minLength: max(proxy.safeAreaInsets.top + 24, 56))
                    instructionCard
                        .padding(.horizontal, 18)
                    Spacer(minLength: 0)
                }
                .zIndex(10)

                Image(currentCharacterAssetName)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: min(proxy.size.width * 0.78, 300), maxHeight: min(proxy.size.height * 0.42, 360))
                    .offset(y: -16)
                    .shadow(color: .black.opacity(0.22), radius: 14, y: 8)
                    .allowsHitTesting(false)

                tutorialBottomButtons
                    .padding(.bottom, Layout.bottomPadding)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .zIndex(20)

                if showMenuPopup {
                    Color.black.opacity(0.28)
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .zIndex(30)

                    TutorialCenterMenuPopup(
                        isPictureButtonPulsing: phase == .pictureButton && isPulsing,
                        onPicture: openZukan,
                        onDismiss: closeMenuPopup
                    )
                    .frame(maxWidth: Layout.menuPopupMaxWidth)
                    .padding(.horizontal, Layout.menuPopupHorizontalPadding)
                    .zIndex(31)
                    .transition(.scale(scale: 0.92).combined(with: .opacity))
                }
            }
            .ignoresSafeArea()
        }
    }

    private var instructionCard: some View {
        let title: String = phase == .menuButton ? "メニューを開こう" : "図鑑を開こう"
        let message: String = phase == .menuButton
        ? "画面下の menu_button を押して、メニューを開いてみよう。"
        : "メニューの picture_button を押して、図鑑へ進もう。"

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text("👩‍🏫")
                    .font(.system(size: 26))

                Text(title)
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(.primary)

                Spacer(minLength: 0)
            }

            Text(message)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)
                .lineSpacing(3)
        }
        .padding(16)
        .frame(maxWidth: 360, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.45), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.18), radius: 16, x: 0, y: 8)
    }

    private var tutorialBottomButtons: some View {
        HStack(spacing: Layout.bottomButtonsSpacing) {
            TutorialBottomActionButton(
                imageName: "menu_button",
                isHighlighted: phase == .menuButton,
                isPulsing: isPulsing,
                action: openMenuPopup
            )

            TutorialBottomActionButton(
                imageName: "gatya_button",
                isHighlighted: false,
                isPulsing: false,
                action: {}
            )
            .opacity(0.55)

            TutorialBottomActionButton(
                imageName: "work_button",
                isHighlighted: false,
                isPulsing: false,
                action: {}
            )
            .opacity(0.55)

            TutorialBottomActionButton(
                imageName: "step_button",
                isHighlighted: false,
                isPulsing: false,
                action: {}
            )
            .opacity(0.55)
        }
        .padding(.horizontal, Layout.bottomBarHorizontalPadding)
        .padding(.vertical, Layout.bottomBarVerticalPadding)
        .padding(.horizontal, Layout.bottomHorizontalPadding)
    }

    private func openMenuPopup() {
        guard phase == .menuButton else { return }
        bgmManager.playSE(.push)
        phase = .pictureButton
        withAnimation(.easeInOut(duration: 0.18)) {
            showMenuPopup = true
        }
    }

    private func closeMenuPopup() {
        bgmManager.playSE(.push)
        withAnimation(.easeInOut(duration: 0.18)) {
            showMenuPopup = false
        }
        phase = .menuButton
    }

    private func openZukan() {
        guard phase == .pictureButton else { return }
        bgmManager.playSE(.push)
        withAnimation(.easeInOut(duration: 0.18)) {
            showMenuPopup = false
        }
        phase = .zukan
    }
}

private struct TutorialCenterMenuPopup: View {
    let isPictureButtonPulsing: Bool
    let onPicture: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image("blue_block")
                .resizable()
                .scaledToFit()

            VStack(alignment: .leading, spacing: 28) {
                HStack(spacing: 28) {
                    TutorialMenuPopupActionIcon(imageName: "camera_button", isHighlighted: false, isPulsing: false) {}
                        .opacity(0.55)

                    TutorialMenuPopupActionIcon(imageName: "omoide_button", isHighlighted: false, isPulsing: false) {}
                        .opacity(0.55)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 28) {
                    TutorialMenuPopupActionIcon(
                        imageName: "picture_button",
                        isHighlighted: true,
                        isPulsing: isPictureButtonPulsing,
                        action: onPicture
                    )

                    TutorialMenuPopupActionIcon(imageName: "option_button", isHighlighted: false, isPulsing: false) {}
                        .opacity(0.55)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(width: 296, alignment: .leading)
            .padding(.top, 34)
            .padding(.bottom, 20)
            .offset(x: -12, y: 8)

            Button(action: onDismiss) {
                Image("close_button")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 54, height: 54)
            }
            .buttonStyle(.plain)
            .padding(.top, 18)
            .padding(.trailing, 18)
        }
        .frame(maxWidth: 360)
        .shadow(color: .black.opacity(0.22), radius: 18, x: 0, y: 10)
    }
}

private struct TutorialMenuPopupActionIcon: View {
    let imageName: String
    let isHighlighted: Bool
    let isPulsing: Bool
    let action: () -> Void

    private let buttonSize: CGFloat = 116
    private var iconSize: CGFloat { buttonSize * 0.74 }

    var body: some View {
        Button(action: action) {
            ZStack {
                Image("clay_block")
                    .resizable()
                    .scaledToFit()
                    .frame(width: buttonSize, height: buttonSize)

                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: iconSize, height: iconSize)

                if isHighlighted {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white, lineWidth: 4)
                        .scaleEffect(isPulsing ? 1.12 : 0.94)
                        .shadow(color: .white.opacity(0.9), radius: 14)
                }
            }
            .frame(width: buttonSize, height: buttonSize)
            .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(.plain)
        .shadow(color: .black.opacity(0.16), radius: 8, x: 0, y: 4)
    }
}

private struct TutorialBottomActionButton: View {
    let imageName: String
    let isHighlighted: Bool
    let isPulsing: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Image("clay_block")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 76, height: 76)

                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 68, height: 68)

                if isHighlighted {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white, lineWidth: 4)
                        .scaleEffect(isPulsing ? 1.12 : 0.94)
                        .shadow(color: .white.opacity(0.9), radius: 14)
                }
            }
            .frame(width: 76, height: 76)
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
        .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 4)
    }
}

#if DEBUG
#Preview("Tutorial Zukan Placeholder") {
    Text("Preview requires AppState from the app runtime")
        .padding()
}
#endif
