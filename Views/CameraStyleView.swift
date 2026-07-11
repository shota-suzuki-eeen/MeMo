//
//  CameraStyleView.swift
//  MeMo
//
//  Dynamic Island-connected camera printer animation.
//  PHOTO_PRINT_DYNAMIC_ISLAND_CLOSE_SINK_V11_HAPTIC_BOOST_APPLIED.
//

import SwiftUI
import UIKit
import AVFoundation
import Combine
import Metal
import CoreImage
import CoreImage.CIFilterBuiltins

struct CameraStyleView: View {
    typealias Snapshotter = (@escaping (UIImage?) -> Void) -> Void
    typealias MetricValueProvider = () -> (steps: Int, activeKcal: Int, totalKcal: Int)

    enum Mode: String, Identifiable, CaseIterable, Equatable {
        case plain
        case ar

        var id: String { rawValue }

        var title: String {
            switch self {
            case .plain:
                return "通常"
            case .ar:
                return "AR"
            }
        }

        var shortTitle: String {
            switch self {
            case .plain:
                return "NORMAL"
            case .ar:
                return "AR"
            }
        }
    }

    private enum CameraPosition: Equatable {
        case front
        case back
    }

    private struct CameraPanelLayout {
        let width: CGFloat
        let height: CGFloat
        let corner: CGFloat
        let frameInset: CGFloat
        let previewCorner: CGFloat
        let topMargin: CGFloat
    }

    private struct CameraPrinterLayout {
        let width: CGFloat
        let height: CGFloat
        let corner: CGFloat
        let slotWidth: CGFloat
        let slotGlobalY: CGFloat
    }

    let initialMode: Mode
    let todaySteps: Int
    let todayActiveKcal: Int
    let todayTotalKcal: Int
    let plainBackgroundAssetName: String
    let characterAssetName: String
    let metricValueProvider: MetricValueProvider?
    let onCancel: () -> Void
    let onCapture: (UIImage) -> Void
    let onCaptureWithPlace: ((UIImage, String?, Double?, Double?) -> Void)?

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    @State private var mode: Mode
    @State private var cameraPosition: CameraPosition = .back
    @State private var isFlashOn: Bool = false

    @State private var takeBackgroundSnapshot: Snapshotter?
    @State private var lastPreviewSize: CGSize = .zero
    @State private var safeAreaInsets: UIEdgeInsets = .zero

    @State private var isClosing: Bool = false
    @State private var cameraRevealProgress: CGFloat = 0
    @State private var chromeRevealProgress: CGFloat = 0
    @State private var closingIslandSinkProgress: CGFloat = 0
    @State private var isPreviewFadingAfterCapture: Bool = false
    @State private var previewFadeOpacity: CGFloat = 1
    @State private var capturedPreviewSize: CGSize = .zero
    @State private var recentPhotos: [PicoPrintedPhoto] = []
    @State private var selectedPhoto: PicoPrintedPhoto?
    @State private var presentationTask: Task<Void, Never>?
    @State private var printPresentationTask: Task<Void, Never>?
    @State private var isPrintPresentationActive: Bool = false
    @State private var isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled

    @StateObject private var printController = PhotoPrintAnimationController()
    @Namespace private var photoTransitionNamespace

    init(
        initialMode: Mode = .plain,
        todaySteps: Int,
        todayActiveKcal: Int,
        todayTotalKcal: Int,
        plainBackgroundAssetName: String,
        characterAssetName: String = "purpor",
        metricValueProvider: MetricValueProvider? = nil,
        onCancel: @escaping () -> Void,
        onCapture: @escaping (UIImage) -> Void,
        onCaptureWithPlace: ((UIImage, String?, Double?, Double?) -> Void)? = nil
    ) {
        self.initialMode = initialMode
        self.todaySteps = todaySteps
        self.todayActiveKcal = todayActiveKcal
        self.todayTotalKcal = todayTotalKcal
        self.plainBackgroundAssetName = plainBackgroundAssetName
        self.characterAssetName = characterAssetName
        self.metricValueProvider = metricValueProvider
        self.onCancel = onCancel
        self.onCapture = onCapture
        self.onCaptureWithPlace = onCaptureWithPlace

        // AR機能は廃止し、既存呼び出し元との互換性を維持しながら通常カメラ固定にする。
        _mode = State(initialValue: .plain)
    }

    private var currentMetricValues: (steps: Int, activeKcal: Int, totalKcal: Int) {
        if let metricValueProvider {
            let values = metricValueProvider()
            let resolvedSteps = max(0, max(values.steps, values.totalKcal))
            return (steps: resolvedSteps, activeKcal: 0, totalKcal: resolvedSteps)
        }

        let resolvedSteps = max(0, max(todaySteps, todayTotalKcal))
        return (steps: resolvedSteps, activeKcal: 0, totalKcal: resolvedSteps)
    }

    private var cameraRotateEnabled: Bool {
        !printController.isBusy && !isClosing
    }

    private var backgroundRevealOpacity: CGFloat {
        if isPrintPresentationActive || printController.isBusy {
            return 1
        }
        return max(0, min(1, chromeRevealProgress))
    }

    private var photoTrayRevealOpacity: CGFloat {
        if isPrintPresentationActive || printController.isBusy {
            return 1
        }
        return max(0, min(1, chromeRevealProgress))
    }

    private var shaderAllowed: Bool {
        guard !accessibilityReduceMotion else { return false }
        guard !isLowPowerModeEnabled else { return false }
        guard !Self.isRunningForPreview else { return false }
        guard PhotoPrintShaderSupport.isFunctionAvailable else { return false }
        return true
    }

    var body: some View {
        GeometryReader { geometry in
            let panelLayout = cameraPanelLayout(
                in: geometry.size,
                safeTop: geometry.safeAreaInsets.top
            )
            let printerLayout = cameraPrinterLayout(
                base: panelLayout,
                screenSize: geometry.size,
                progress: printController.printerProgress
            )

            ZStack {
                backgroundBody
                    .opacity(backgroundRevealOpacity)
                    .allowsHitTesting(false)

                VStack(spacing: 0) {
                    Color.clear
                        .frame(height: panelLayout.topMargin)

                    cameraPanel(
                        layout: panelLayout,
                        printerLayout: printerLayout,
                        screenSize: geometry.size
                    )

                    closeButtonRow
                        .padding(.top, 12)
                        .padding(.horizontal, 26)
                        .opacity(chromeRevealProgress)
                        .allowsHitTesting(
                            chromeRevealProgress > 0.98
                            && !isClosing
                            && !printController.isBusy
                        )

                    controlsArea
                        .padding(.top, 20)
                        .opacity(chromeRevealProgress)
                        .allowsHitTesting(
                            chromeRevealProgress > 0.98
                            && !isClosing
                            && !printController.isBusy
                        )

                    Spacer(minLength: 22)

                    photoTray
                        .frame(height: max(230, geometry.size.height * 0.30))
                        .padding(.horizontal, 18)
                        .padding(.bottom, 18 + geometry.safeAreaInsets.bottom)
                        .opacity(photoTrayRevealOpacity)
                        .allowsHitTesting(
                            chromeRevealProgress > 0.98
                            && !isClosing
                            && !printController.isBusy
                        )
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .zIndex(200)

                if let payload = printController.payload {
                    printingPhotoLayer(
                        payload: payload,
                        screenSize: geometry.size,
                        slotY: printerLayout.slotGlobalY,
                        slotWidth: printerLayout.slotWidth
                    )
                    .zIndex(printController.phase == .movingToTray ? 500 : 260)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }

                Color.white
                    .opacity(printController.flashOpacity)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                    .zIndex(700)

                if let selectedPhoto {
                    PicoPrintedPhotoDetailOverlay(
                        photo: selectedPhoto,
                        onDismiss: { self.selectedPhoto = nil },
                        onDelete: { deletePhoto(selectedPhoto) }
                    )
                    .zIndex(800)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                }
            }
            .background(FullScreenCoverClearBackground())
            .ignoresSafeArea()
            .modifier(
                PhotoPrintSensoryFeedbackModifier(
                    shutterTrigger: printController.shutterHapticTrigger,
                    printerTrigger: printController.printerHapticTrigger,
                    settleTrigger: printController.settleHapticTrigger,
                    trayTrigger: printController.trayHapticTrigger
                )
            )
            .onAppear {
                prepareForPresentation()
            }
            .onDisappear {
                presentationTask?.cancel()
                printPresentationTask?.cancel()
                printController.finishImmediately(completePendingPhoto: true)
            }
            .onChange(of: geometry.size) { _, _ in
                safeAreaInsets = Self.currentWindowSafeAreaInsets()
            }
            .onChange(of: mode) { _, _ in
                mode = .plain
                takeBackgroundSnapshot = nil
            }
            .onChange(of: cameraPosition) { _, _ in
                takeBackgroundSnapshot = nil
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase != .active else { return }
                finishPrintPresentationImmediately()
            }
            .onChange(of: accessibilityReduceMotion) { _, reduceMotion in
                guard reduceMotion, printController.isBusy else { return }
                finishPrintPresentationImmediately()
            }
            .onReceive(
                NotificationCenter.default.publisher(
                    for: Notification.Name.NSProcessInfoPowerStateDidChange
                )
            ) { _ in
                isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
            }
            .onReceive(
                NotificationCenter.default.publisher(
                    for: UIApplication.didReceiveMemoryWarningNotification
                )
            ) { _ in
                finishPrintPresentationImmediately()
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("カメラ画面")
        }
        .statusBarHidden(true)
        .ignoresSafeArea()
    }

    private func prepareForPresentation() {
        presentationTask?.cancel()
        printPresentationTask?.cancel()
        printController.resetToIdle()
        safeAreaInsets = Self.currentWindowSafeAreaInsets()
        mode = .plain
        cameraPosition = .back
        isFlashOn = false
        isClosing = false
        isPrintPresentationActive = false
        cameraRevealProgress = 0
        chromeRevealProgress = 0
        closingIslandSinkProgress = 0
        isPreviewFadingAfterCapture = false
        previewFadeOpacity = 1
        capturedPreviewSize = .zero
        isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled

        presentationTask = Task { @MainActor in
            withAnimation(.spring(response: 0.46, dampingFraction: 0.86)) {
                cameraRevealProgress = 1
            }

            do {
                try await Task<Never, Never>.sleep(nanoseconds: 60_000_000)
            } catch {
                return
            }

            guard !Task.isCancelled, !isClosing else { return }
            withAnimation(.easeOut(duration: 0.14)) {
                chromeRevealProgress = 1
            }
        }
    }

    private var backgroundBody: some View {
        LinearGradient(
            colors: [
                Color(red: 0.38, green: 0.39, blue: 0.41),
                Color(red: 0.27, green: 0.28, blue: 0.30),
                Color(red: 0.43, green: 0.44, blue: 0.46)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .overlay(alignment: .top) {
            LinearGradient(
                colors: [.white.opacity(0.24), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 44)
        }
        .overlay(alignment: .bottom) {
            LinearGradient(
                colors: [.clear, .black.opacity(0.24)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 64)
        }
        .ignoresSafeArea()
    }

    private func cameraPanelLayout(
        in screenSize: CGSize,
        safeTop: CGFloat
    ) -> CameraPanelLayout {
        let isWideLayout = screenSize.width >= 700
        let horizontalMargin: CGFloat = isWideLayout ? 40 : 26
        let proposedWidth = screenSize.width - (horizontalMargin * 2)
        let expandedWidth: CGFloat

        if isWideLayout {
            expandedWidth = min(max(420, screenSize.width * 0.64), 570)
        } else {
            expandedWidth = max(300, proposedWidth)
        }

        // Dynamic Island搭載有無を端末名で分岐せず、safe areaを黒枠厚の基準にする。
        let dynamicIslandHeight = max(38, min(54, safeTop + 2))
        let previewWidth = max(180, expandedWidth - (dynamicIslandHeight * 2))
        let previewHeight = previewWidth
        let expandedHeight = previewHeight + (dynamicIslandHeight * 2)

        let compactWidth: CGFloat = 132
        let compactHeight: CGFloat = max(36, dynamicIslandHeight * 0.82)
        let progress = max(0, min(1, cameraRevealProgress))

        let width = compactWidth.interpolated(to: expandedWidth, progress: progress)
        let height = compactHeight.interpolated(to: expandedHeight, progress: progress)
        let corner = CGFloat(22).interpolated(to: 56, progress: progress)
        let previewCorner = CGFloat(18).interpolated(to: 34, progress: progress)
        let topMargin = max(4, safeTop * 0.10) + 6

        return CameraPanelLayout(
            width: width,
            height: height,
            corner: corner,
            frameInset: dynamicIslandHeight,
            previewCorner: previewCorner,
            topMargin: topMargin
        )
    }

    private func cameraPrinterLayout(
        base: CameraPanelLayout,
        screenSize: CGSize,
        progress: CGFloat
    ) -> CameraPrinterLayout {
        let clamped = max(0, min(1.04, progress))
        let normalized = max(0, min(1, clamped))
        let isWideLayout = screenSize.width >= 700

        // カメラ表示中は base の大きさをそのまま使用する。
        // 撮影後に cameraRevealProgress が 0 まで戻ると base は Dynamic Island 相当の
        // コンパクト形状になるため、そこから横長プリンターへ変形させる。
        let targetWidth = min(
            max(isWideLayout ? 360 : 286, screenSize.width * (isWideLayout ? 0.52 : 0.76)),
            isWideLayout ? 470 : 360
        )
        let targetHeight = min(
            isWideLayout ? 92 : 78,
            max(70, screenSize.height * 0.105)
        )

        let width = base.width.interpolated(to: targetWidth, progress: clamped)
        let height = base.height.interpolated(to: targetHeight, progress: clamped)
        let corner = base.corner.interpolated(
            to: targetHeight * 0.48,
            progress: normalized
        )
        // 排出口そのものは描画しない。黒いDynamic Island形状の下端を
        // ポラロイドが現れ始める境界としてのみ使用する。
        let slotWidth = max(84, width - (isWideLayout ? 44 : 34))
        let slotGlobalY = base.topMargin + max(28, height - 4)

        return CameraPrinterLayout(
            width: width,
            height: height,
            corner: corner,
            slotWidth: slotWidth,
            slotGlobalY: slotGlobalY
        )
    }

    private func cameraPanel(
        layout: CameraPanelLayout,
        printerLayout: CameraPrinterLayout,
        screenSize: CGSize
    ) -> some View {
        let effectiveFrameInset = min(
            layout.frameInset,
            max(8, (layout.width - 26) * 0.5),
            max(8, (layout.height - 26) * 0.5)
        )
        let previewWidth = max(1, layout.width - (effectiveFrameInset * 2))
        let previewHeight = max(1, layout.height - (effectiveFrameInset * 2))
        let hasCapturedPreviewSize = capturedPreviewSize.width > 1 && capturedPreviewSize.height > 1
        let shouldFreezePreviewGeometry = isPreviewFadingAfterCapture && hasCapturedPreviewSize
        let renderedPreviewWidth = shouldFreezePreviewGeometry
            ? capturedPreviewSize.width
            : previewWidth
        let renderedPreviewHeight = shouldFreezePreviewGeometry
            ? capturedPreviewSize.height
            : previewHeight
        let renderedPreviewCorner = shouldFreezePreviewGeometry
            ? CGFloat(34)
            : layout.previewCorner
        let renderedPreviewInset = shouldFreezePreviewGeometry
            ? layout.frameInset
            : effectiveFrameInset
        let printerStrength = max(0, min(1, printController.printerProgress))
        let sinkProgress = max(0, min(1, closingIslandSinkProgress))
        let sinkScaleProgress = max(0, min(1, sinkProgress / 0.62))
        let sinkFadeProgress = max(0, min(1, (sinkProgress - 0.24) / 0.76))
        let exteriorFadeProgress = max(0, min(1, sinkProgress / 0.24))
        let exteriorVisibility = Double(1 - exteriorFadeProgress)
        let panelVisibility = Double(1 - sinkFadeProgress)
        let panelScale = (
            0.92 + (max(cameraRevealProgress, printerStrength) * 0.08)
        ) * (1 - (sinkScaleProgress * 0.28))

        return ZStack(alignment: .top) {
            PicoRaisedRoundedPanel(
                cornerRadius: printerLayout.corner,
                fill: Color.black,
                outerStrokeOpacity: 0.92 * exteriorVisibility,
                highlightOpacity: (0.16 + (Double(printerStrength) * 0.05)) * exteriorVisibility,
                shadowOpacity: (0.36 + (Double(printerStrength) * 0.15)) * exteriorVisibility,
                shadowRadius: (10 + (printerStrength * 5)) * (1 - sinkScaleProgress),
                shadowY: (7 + (printerStrength * 4)) * (1 - sinkScaleProgress)
            )
            .scaleEffect(panelScale, anchor: .center)

            if (cameraRevealProgress > 0.001 || isPreviewFadingAfterCapture) && !isClosing {
                cameraPreviewWindow(previewCorner: renderedPreviewCorner)
                    // 撮影直後だけは撮影時のフレームを固定する。
                    // 黒い外枠がDynamic Island形状へ変形しても、映像自体は縮小・横移動せず
                    // 元の位置で透明になるため、画面内容が右へ流れて見えない。
                    .frame(width: renderedPreviewWidth, height: renderedPreviewHeight)
                    .position(
                        x: printerLayout.width * 0.5,
                        y: renderedPreviewInset + (renderedPreviewHeight * 0.5)
                    )
                    .opacity(
                        isPreviewFadingAfterCapture
                            ? Double(previewFadeOpacity)
                            : 1
                    )
                    .scaleEffect(
                        isPreviewFadingAfterCapture ? 1 : panelScale,
                        anchor: .center
                    )
                    .overlay {
                        Color.black
                            .opacity(Double(printerStrength) * 0.035)
                            .clipShape(
                                RoundedRectangle(
                                    cornerRadius: renderedPreviewCorner,
                                    style: .continuous
                                )
                            )
                    }
            }

        }
        .frame(width: printerLayout.width, height: printerLayout.height, alignment: .top)
        .offset(x: printController.printerShakeX)
        .opacity(panelVisibility)
    }

    private func cameraPreviewWindow(previewCorner: CGFloat) -> some View {
        GeometryReader { proxy in
            ZStack {
                captureSurface

                if let freezeImage = printController.freezeImage {
                    Image(uiImage: freezeImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipShape(RoundedRectangle(cornerRadius: previewCorner, style: .continuous))
            .onAppear {
                lastPreviewSize = proxy.size
            }
            .onChange(of: proxy.size) { _, newSize in
                lastPreviewSize = newSize
            }
        }
    }

    @ViewBuilder
    private var captureSurface: some View {
        PicoCameraPreviewView(
            position: cameraPosition == .front ? .front : .back,
            isFlashEnabled: isFlashOn
        ) { snapshotter in
            DispatchQueue.main.async {
                takeBackgroundSnapshot = snapshotter
            }
        }
        .id("pico_plain_camera_\(cameraPosition == .front ? "front" : "back")")
    }

    private var closeButtonRow: some View {
        HStack {
            topCloseButton
            Spacer()
        }
    }

    private var controlsArea: some View {
        HStack(alignment: .center, spacing: 58) {
            Button {
                guard !printController.isBusy, !isClosing else { return }
                isFlashOn.toggle()
            } label: {
                PicoRoundControlButton(
                    systemImage: isFlashOn ? "bolt.fill" : "bolt.slash.fill",
                    size: 58,
                    fill: isFlashOn
                        ? Color(red: 0.34, green: 0.58, blue: 0.36).opacity(0.96)
                        : Color.black.opacity(0.08),
                    foreground: isFlashOn
                        ? Color.white.opacity(0.94)
                        : Color.black.opacity(0.46),
                    lineWidth: 0
                )
            }
            .buttonStyle(.plain)
            .disabled(printController.isBusy || isClosing)
            .opacity((printController.isBusy || isClosing) ? 0.42 : 1.0)
            .accessibilityLabel(isFlashOn ? "フラッシュON" : "フラッシュOFF")

            Button {
                captureAndPrint()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.16))
                        .frame(width: 104, height: 104)
                        .shadow(color: .black.opacity(0.28), radius: 8, x: 0, y: 7)

                    Circle()
                        .fill(Color(red: 1.0, green: 0.60, blue: 0.0))
                        .frame(width: 84, height: 84)
                        .overlay(Circle().stroke(Color.black.opacity(0.78), lineWidth: 3))
                        .shadow(color: .white.opacity(0.30), radius: 3, x: 0, y: -2)
                }
            }
            .buttonStyle(.plain)
            .disabled(
                printController.isBusy
                || takeBackgroundSnapshot == nil
                || isClosing
            )
            .opacity(
                (printController.isBusy || takeBackgroundSnapshot == nil || isClosing)
                ? 0.58
                : 1.0
            )
            .accessibilityLabel("撮影")
            .accessibilityHint(printController.isBusy ? "写真を処理中です" : "")

            Button {
                guard cameraRotateEnabled else { return }
                let nextPosition: CameraPosition = cameraPosition == .back ? .front : .back
                cameraPosition = nextPosition
                if nextPosition == .front {
                    isFlashOn = false
                }
                takeBackgroundSnapshot = nil
            } label: {
                PicoRoundControlButton(
                    systemImage: "arrow.triangle.2.circlepath.camera",
                    size: 58,
                    fill: Color(red: 0.30, green: 0.45, blue: 0.72).opacity(0.96),
                    foreground: Color.white.opacity(0.94),
                    lineWidth: 0
                )
            }
            .disabled(!cameraRotateEnabled)
            .opacity(!cameraRotateEnabled ? 0.36 : 1.0)
            .accessibilityLabel("カメラ切り替え")
        }
    }

    private var topCloseButton: some View {
        Button(action: requestClose) {
            PicoRoundControlButton(
                systemImage: "xmark",
                size: 50,
                fill: Color(red: 0.16, green: 0.16, blue: 0.18).opacity(0.96),
                foreground: Color.white.opacity(0.94),
                lineWidth: 0
            )
        }
        .buttonStyle(.plain)
        .opacity((printController.isBusy || isClosing) ? 0.35 : 1.0)
        .disabled(printController.isBusy || isClosing)
        .accessibilityLabel("閉じる")
    }

    private var photoTray: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 14) {
                    if recentPhotos.isEmpty {
                        Text("撮影した写真がここに並びます")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white.opacity(0.48))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 12)
                            .padding(.top, 14)
                    } else {
                        ForEach(recentPhotos) { photo in
                            Button {
                                withAnimation(.easeOut(duration: 0.18)) {
                                    selectedPhoto = photo
                                }
                            } label: {
                                PolaroidPaperView(sceneImage: photo.displaySceneImage)
                                    .frame(width: 112)
                                    .matchedGeometryEffect(
                                        id: photo.id,
                                        in: photoTransitionNamespace,
                                        properties: .frame,
                                        anchor: .center,
                                        isSource: false
                                    )
                                    .shadow(
                                        color: .black.opacity(0.22),
                                        radius: 5,
                                        x: 0,
                                        y: 4
                                    )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("撮影した写真")
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 18)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            PicoRaisedRoundedPanel(
                cornerRadius: 18,
                fill: Color(red: 0.13, green: 0.13, blue: 0.15).opacity(0.96),
                outerStrokeOpacity: 0.82,
                highlightOpacity: 0.12,
                shadowOpacity: 0.42,
                shadowRadius: 10,
                shadowY: 7
            )
        )
    }

    @ViewBuilder
    private func printingPhotoLayer(
        payload: PhotoPrintPayload,
        screenSize: CGSize,
        slotY: CGFloat,
        slotWidth: CGFloat
    ) -> some View {
        let validSize = CGSize(
            width: max(1, screenSize.width),
            height: max(1, screenSize.height)
        )
        let photoWidth = min(
            validSize.width * (validSize.width >= 700 ? 0.46 : 0.64),
            validSize.width >= 700 ? 340 : 315
        )
        let useShader = shaderAllowed && printController.phase.allowsPaperShader
        let shouldMaskAtSlot = printController.phase.requiresSlotMask

        // 左右方向は常に写真全幅を描画する。排出途中にスロット幅で横方向を
        // 切り取ると、マスク解除時に写真幅が突然広がって見えるため、
        // Dynamic Island下端だけを縦方向の排出境界として使用する。
        let frontOverlap = max(20, min(34, slotWidth * 0.10))

        ZStack {
            if accessibilityReduceMotion {
                if printController.phase.hasStartedEjection {
                    ReducedMotionEjectingPolaroidView(
                        image: payload.photo.displaySceneImage,
                        photoID: payload.photo.id,
                        namespace: photoTransitionNamespace,
                        trigger: printController.animationID,
                        photoWidth: photoWidth,
                        screenSize: validSize,
                        slotY: slotY
                    )
                } else {
                    InitialEjectingPolaroidView(
                        image: payload.photo.displaySceneImage,
                        photoID: payload.photo.id,
                        namespace: photoTransitionNamespace,
                        photoWidth: photoWidth,
                        screenSize: validSize,
                        slotY: slotY,
                        reduceMotion: true
                    )
                }
            } else if #available(iOS 17.0, *) {
                KeyframedEjectingPolaroidView(
                    image: payload.photo.displaySceneImage,
                    photoID: payload.photo.id,
                    namespace: photoTransitionNamespace,
                    trigger: printController.animationID,
                    photoWidth: photoWidth,
                    screenSize: validSize,
                    slotY: slotY,
                    configuration: printController.configuration,
                    shaderEnabled: useShader
                )
            } else if printController.phase.hasStartedEjection {
                LegacyEjectingPolaroidView(
                    image: payload.photo.displaySceneImage,
                    photoID: payload.photo.id,
                    namespace: photoTransitionNamespace,
                    trigger: printController.animationID,
                    photoWidth: photoWidth,
                    screenSize: validSize,
                    slotY: slotY,
                    configuration: printController.configuration
                )
            } else {
                InitialEjectingPolaroidView(
                    image: payload.photo.displaySceneImage,
                    photoID: payload.photo.id,
                    namespace: photoTransitionNamespace,
                    photoWidth: photoWidth,
                    screenSize: validSize,
                    slotY: slotY,
                    reduceMotion: false
                )
            }
        }
        .frame(width: validSize.width, height: validSize.height)
        .mask {
            if shouldMaskAtSlot {
                VStack(spacing: 0) {
                    Color.clear
                        .frame(height: max(0, slotY - frontOverlap))

                    Rectangle()
                        .fill(Color.white)
                }
            } else {
                Rectangle().fill(Color.white)
            }
        }
    }

    private func requestClose() {
        guard !printController.isBusy, !isClosing else { return }
        presentationTask?.cancel()
        printPresentationTask?.cancel()
        isClosing = true
        selectedPhoto = nil
        closingIslandSinkProgress = 0

        presentationTask = Task { @MainActor in
            withAnimation(.easeInOut(duration: 0.12)) {
                chromeRevealProgress = 0
            }

            do {
                try await Task<Never, Never>.sleep(nanoseconds: 60_000_000)
            } catch {
                return
            }

            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.30)) {
                cameraRevealProgress = 0
            }

            do {
                try await Task<Never, Never>.sleep(nanoseconds: 300_000_000)
            } catch {
                return
            }

            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.20)) {
                closingIslandSinkProgress = 1
            }

            do {
                try await Task<Never, Never>.sleep(nanoseconds: 220_000_000)
            } catch {
                return
            }

            guard !Task.isCancelled else { return }
            onCancel()
        }
    }

    private func captureAndPrint() {
        guard !isClosing else { return }
        guard let takeBackgroundSnapshot else { return }
        guard lastPreviewSize.width > 1, lastPreviewSize.height > 1 else { return }
        guard printController.beginCapture() else { return }

        let fixedPreviewSize = lastPreviewSize
        capturedPreviewSize = fixedPreviewSize
        let fixedMetrics = currentMetricValues

        takeBackgroundSnapshot { background in
            guard let background else {
                Task { @MainActor in
                    printController.failCapture()
                }
                return
            }

            let normalizedBackground = background
                .picoFixedOrientation()
                .picoCroppedToAspectFill(of: fixedPreviewSize)
                ?? background.picoFixedOrientation()

            let composed = PicoCameraImageComposer.composeScene(
                background: normalizedBackground,
                previewSize: fixedPreviewSize,
                steps: fixedMetrics.steps
            )
            let finalPolaroid = PicoCameraImageComposer.makePolaroid(from: composed)
            let displayScene = finalPolaroid.picoPolaroidSceneImage()
                ?? composed.picoDownsampled(maxPixelDimension: 900)
            let displayFreeze = normalizedBackground.picoDownsampled(maxPixelDimension: 1_200)
            let photo = PicoPrintedPhoto(
                image: finalPolaroid,
                displaySceneImage: displayScene,
                date: Date()
            )
            let payload = PhotoPrintPayload(
                photo: photo,
                freezeImage: displayFreeze,
                placeName: nil,
                latitude: nil,
                longitude: nil
            )

            Task { @MainActor in
                startPrintAnimation(payload: payload)
            }
        }
    }

    @MainActor
    private func startPrintAnimation(payload: PhotoPrintPayload) {
        let didStage = printController.stageCapture(
            payload: payload,
            reduceMotion: accessibilityReduceMotion,
            onPersist: { persistedPayload in
                if let onCaptureWithPlace {
                    onCaptureWithPlace(
                        persistedPayload.photo.image,
                        persistedPayload.placeName,
                        persistedPayload.latitude,
                        persistedPayload.longitude
                    )
                } else {
                    onCapture(persistedPayload.photo.image)
                }
            },
            onInsertIntoTray: { printedPhoto in
                insertPhotoIfNeeded(printedPhoto)
            },
            onComplete: {
                restoreCameraAfterPrint()
            }
        )

        guard didStage else { return }

        presentationTask?.cancel()
        printPresentationTask?.cancel()
        isPrintPresentationActive = true
        isPreviewFadingAfterCapture = true
        previewFadeOpacity = 1

        let collapseDuration = accessibilityReduceMotion ? 0.18 : 0.48
        let chromeDuration = accessibilityReduceMotion ? 0.08 : 0.16
        let settleNanoseconds: UInt64 = accessibilityReduceMotion
            ? 210_000_000
            : 610_000_000

        printPresentationTask = Task { @MainActor in
            withAnimation(.easeInOut(duration: chromeDuration)) {
                chromeRevealProgress = 0
            }

            do {
                try await Task<Never, Never>.sleep(nanoseconds: 70_000_000)
            } catch {
                return
            }

            guard !Task.isCancelled else { return }

            // 映像は独立した不透明度アニメーションだけでその場から消す。
            // 黒い外枠のスプリング変形には追従させない。
            withAnimation(.easeOut(duration: collapseDuration * 0.82)) {
                previewFadeOpacity = 0
            }
            withAnimation(
                .spring(
                    response: collapseDuration,
                    dampingFraction: accessibilityReduceMotion ? 1.0 : 0.90
                )
            ) {
                cameraRevealProgress = 0
            }

            do {
                try await Task<Never, Never>.sleep(nanoseconds: settleNanoseconds)
            } catch {
                return
            }

            guard !Task.isCancelled else { return }
            isPreviewFadingAfterCapture = false
            printController.startStagedAnimation(
                reduceMotion: accessibilityReduceMotion
            )
        }
    }

    @MainActor
    private func restoreCameraAfterPrint() {
        printPresentationTask?.cancel()
        isPreviewFadingAfterCapture = false
        previewFadeOpacity = 1

        printPresentationTask = Task { @MainActor in
            withAnimation(
                .spring(
                    response: accessibilityReduceMotion ? 0.22 : 0.48,
                    dampingFraction: accessibilityReduceMotion ? 1.0 : 0.86
                )
            ) {
                cameraRevealProgress = 1
            }

            do {
                try await Task<Never, Never>.sleep(
                    nanoseconds: accessibilityReduceMotion
                        ? 40_000_000
                        : 90_000_000
                )
            } catch {
                return
            }

            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: accessibilityReduceMotion ? 0.08 : 0.16)) {
                chromeRevealProgress = 1
            }

            do {
                try await Task<Never, Never>.sleep(nanoseconds: 180_000_000)
            } catch {
                return
            }

            guard !Task.isCancelled else { return }
            isPrintPresentationActive = false
            UIAccessibility.post(
                notification: .announcement,
                argument: "写真を撮影しました"
            )
        }
    }

    @MainActor
    private func finishPrintPresentationImmediately() {
        printPresentationTask?.cancel()
        printPresentationTask = nil
        printController.finishImmediately(completePendingPhoto: true)
        cameraRevealProgress = 1
        chromeRevealProgress = 1
        isPreviewFadingAfterCapture = false
        previewFadeOpacity = 1
        capturedPreviewSize = .zero
        isPrintPresentationActive = false
    }

    @MainActor
    private func insertPhotoIfNeeded(_ photo: PicoPrintedPhoto) {
        guard !recentPhotos.contains(where: { $0.id == photo.id }) else { return }

        withAnimation(
            .spring(
                response: printController.configuration.trayMovementDuration,
                dampingFraction: 0.86
            )
        ) {
            recentPhotos.insert(photo, at: 0)
            if recentPhotos.count > 20 {
                recentPhotos = Array(recentPhotos.prefix(20))
            }
        }
    }

    private func deletePhoto(_ photo: PicoPrintedPhoto) {
        withAnimation(.easeInOut(duration: 0.18)) {
            recentPhotos.removeAll { $0.id == photo.id }
            selectedPhoto = nil
        }
    }

    private static var isRunningForPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    private static func currentWindowSafeAreaInsets() -> UIEdgeInsets {
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.compactMap { $0 as? UIWindowScene }.first
        let window = windowScene?.windows.first(where: { $0.isKeyWindow })
            ?? windowScene?.windows.first
        return window?.safeAreaInsets ?? .zero
    }
}


private enum PhotoPrintPhase: Equatable {
    case idle
    case capturing
    case shutter
    case expandingPrinter
    case feeding
    case ejecting
    case releasing
    case settling
    case movingToTray
    case completed
    case retracting
    case cancelled
    case failed

    var isBusy: Bool {
        switch self {
        case .idle, .cancelled, .failed:
            return false
        default:
            return true
        }
    }

    var allowsPaperShader: Bool {
        switch self {
        case .feeding, .ejecting, .releasing, .settling:
            return true
        default:
            return false
        }
    }

    var requiresSlotMask: Bool {
        switch self {
        case .shutter, .expandingPrinter, .feeding, .ejecting, .releasing, .settling:
            return true
        default:
            return false
        }
    }

    var hasStartedEjection: Bool {
        switch self {
        case .feeding, .ejecting, .releasing, .settling, .movingToTray, .completed:
            return true
        default:
            return false
        }
    }
}

private struct PhotoPrintAnimationConfiguration {
    let shutterDuration: Double
    let printerExpansionDuration: Double
    let feedingDuration: Double
    let releaseDuration: Double
    let settleDuration: Double
    let trayMovementDuration: Double
    let retractionDuration: Double

    // 既存の現像・排出速度を維持するため、各値は変更しない。
    static let standard = PhotoPrintAnimationConfiguration(
        shutterDuration: 0.12,
        printerExpansionDuration: 0.34,
        feedingDuration: 1.55,
        releaseDuration: 0.22,
        settleDuration: 0.20,
        trayMovementDuration: 0.60,
        retractionDuration: 0.30
    )

    static let reducedMotion = PhotoPrintAnimationConfiguration(
        shutterDuration: 0.08,
        printerExpansionDuration: 0.18,
        feedingDuration: 0.44,
        releaseDuration: 0.06,
        settleDuration: 0.08,
        trayMovementDuration: 0.32,
        retractionDuration: 0.18
    )

    var ejectTimelineDuration: Double {
        feedingDuration + releaseDuration + settleDuration
    }
}

private struct PhotoPrintAnimationValues {
    var verticalProgress: CGFloat = 0
    var scale: CGFloat = 0.46
    var rotationX: Double = 65
    var rotationY: Double = 0.8
    var rotationZ: Double = -0.35
    var perspective: CGFloat = 0.24
    var shadowRadius: CGFloat = 2
    var shadowY: CGFloat = 1
    var shadowOpacity: Double = 0.08
    var paperBend: CGFloat = 0.04
    var paperRelease: CGFloat = 0
    var lateralVibration: CGFloat = 0
}

private struct PhotoPrintPayload {
    let photo: PicoPrintedPhoto
    let freezeImage: UIImage
    let placeName: String?
    let latitude: Double?
    let longitude: Double?
}

private final class PhotoPrintAnimationController: ObservableObject {
    @Published private(set) var phase: PhotoPrintPhase = .idle
    @Published private(set) var payload: PhotoPrintPayload?
    @Published private(set) var freezeImage: UIImage?
    @Published private(set) var animationID = UUID()
    @Published private(set) var printerProgress: CGFloat = 0
    @Published private(set) var printerShakeX: CGFloat = 0
    @Published private(set) var flashOpacity: Double = 0

    @Published private(set) var shutterHapticTrigger: Int = 0
    @Published private(set) var printerHapticTrigger: Int = 0
    @Published private(set) var settleHapticTrigger: Int = 0
    @Published private(set) var trayHapticTrigger: Int = 0

    private(set) var configuration = PhotoPrintAnimationConfiguration.standard

    private var animationTask: Task<Void, Never>?
    private var flashTask: Task<Void, Never>?
    private var feedEffectsTask: Task<Void, Never>?
    private var stagedPayload: PhotoPrintPayload?
    private var onInsertIntoTray: ((PicoPrintedPhoto) -> Void)?
    private var onComplete: (() -> Void)?
    private var didPersist = false
    private var didInsertIntoTray = false
    private var didComplete = false

    var isBusy: Bool {
        phase.isBusy
    }

    @MainActor
    func beginCapture() -> Bool {
        guard !phase.isBusy else { return false }

        cancelTasks()
        clearCompletionState()
        phase = .capturing
        flashOpacity = 0.94
        emitHaptic(.shutter)

        // 撮影から紙送り開始までの間にエンジンとジェネレーターを準備し、
        // 実際の排出開始時に音や触覚が遅れて立ち上がらないようにする。
        PhotoPrintMotorSoundDriver.shared.prepare()
        PhotoPrintUIKitHaptics.prepareFeedRattle()

        flashTask = Task { @MainActor [weak self] in
            await Task.yield()
            guard let self, !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.12)) {
                self.flashOpacity = 0
            }
        }

        return true
    }

    @MainActor
    func stageCapture(
        payload: PhotoPrintPayload,
        reduceMotion: Bool,
        onPersist: (PhotoPrintPayload) -> Void,
        onInsertIntoTray: @escaping (PicoPrintedPhoto) -> Void,
        onComplete: @escaping () -> Void
    ) -> Bool {
        guard phase == .capturing else { return false }

        configuration = reduceMotion ? .reducedMotion : .standard
        stagedPayload = payload
        freezeImage = payload.freezeImage
        self.onInsertIntoTray = onInsertIntoTray
        self.onComplete = onComplete

        if !didPersist {
            didPersist = true
            onPersist(payload)
        }

        return true
    }

    @MainActor
    func startStagedAnimation(reduceMotion: Bool) {
        guard phase == .capturing, let stagedPayload else { return }

        payload = stagedPayload
        self.stagedPayload = nil
        phase = .shutter

        animationTask?.cancel()
        animationTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.runAnimation(reduceMotion: reduceMotion)
        }
    }

    @MainActor
    func failCapture() {
        guard phase == .capturing else { return }
        phase = .failed
        flashOpacity = 0
        emitUIKitFallbackHaptic(.failure)

        animationTask?.cancel()
        animationTask = Task { @MainActor [weak self] in
            do {
                try await Task<Never, Never>.sleep(nanoseconds: 180_000_000)
            } catch {
                return
            }
            self?.resetToIdle()
        }
    }

    @MainActor
    func finishImmediately(completePendingPhoto: Bool) {
        if completePendingPhoto {
            insertIntoTrayOnce()
        }

        cancelTasks()
        payload = nil
        stagedPayload = nil
        freezeImage = nil
        flashOpacity = 0
        printerShakeX = 0
        printerProgress = 0
        phase = .cancelled
        clearCompletionState()
        phase = .idle
    }

    @MainActor
    func resetToIdle() {
        cancelTasks()
        payload = nil
        stagedPayload = nil
        freezeImage = nil
        flashOpacity = 0
        printerShakeX = 0
        printerProgress = 0
        phase = .idle
        clearCompletionState()
    }

    @MainActor
    private func runAnimation(reduceMotion: Bool) async {
        do {
            try await sleep(seconds: configuration.shutterDuration)
            try Task.checkCancellation()

            phase = .expandingPrinter
            emitHaptic(.printer)

            withAnimation(
                .spring(
                    response: configuration.printerExpansionDuration * 0.78,
                    dampingFraction: reduceMotion ? 0.95 : 0.74
                )
            ) {
                printerProgress = reduceMotion ? 1.0 : 1.03
            }

            try await sleep(seconds: configuration.printerExpansionDuration * 0.72)
            try Task.checkCancellation()

            withAnimation(.easeOut(duration: configuration.printerExpansionDuration * 0.28)) {
                printerProgress = 1.0
            }

            phase = .feeding
            animationID = UUID()

            // 紙送り開始と同時に、細かな「ダラララ」触覚と
            // 小型プリンターのモーターを模した「ウィーーーン」音を開始する。
            // どちらもfeedingDuration内で並行再生するため、既存の現像時間は変化しない。
            PhotoPrintUIKitHaptics.prepareFeedRattle()
            PhotoPrintMotorSoundDriver.shared.play(
                duration: configuration.feedingDuration,
                reduceMotion: reduceMotion
            )
            feedEffectsTask?.cancel()
            feedEffectsTask = Task { @MainActor [weak self] in
                guard let self else { return }
                try? await self.playFeedHapticRattle(
                    duration: self.configuration.feedingDuration,
                    reduceMotion: reduceMotion
                )
            }

            if !reduceMotion {
                try await playDeterministicPrinterVibration()
            }

            let vibrationBudget = reduceMotion ? 0 : 0.25
            let remainingFeed = max(0, configuration.feedingDuration - vibrationBudget)
            phase = .ejecting
            try await sleep(seconds: remainingFeed)
            try Task.checkCancellation()

            stopFeedEffects()
            phase = .releasing
            try await sleep(seconds: configuration.releaseDuration)
            try Task.checkCancellation()

            phase = .settling
            emitHaptic(.settle)
            try await sleep(seconds: configuration.settleDuration)
            try Task.checkCancellation()

            phase = .movingToTray
            insertIntoTrayOnce()
            try await sleep(seconds: configuration.trayMovementDuration)
            try Task.checkCancellation()

            phase = .completed
            payload = nil
            emitHaptic(.tray)

            try await sleep(seconds: 0.10)
            try Task.checkCancellation()

            phase = .retracting
            withAnimation(
                .spring(
                    response: configuration.retractionDuration,
                    dampingFraction: 0.88
                )
            ) {
                printerProgress = 0
            }

            try await sleep(seconds: configuration.retractionDuration)
            try Task.checkCancellation()

            freezeImage = nil
            printerShakeX = 0
            flashOpacity = 0
            phase = .idle
            completeOnce()
            clearCompletionState()
        } catch is CancellationError {
            stopFeedEffects()
            payload = nil
            stagedPayload = nil
            freezeImage = nil
            flashOpacity = 0
            printerShakeX = 0
            printerProgress = 0
            phase = .cancelled
            clearCompletionState()
            phase = .idle
        } catch {
            stopFeedEffects()
            payload = nil
            stagedPayload = nil
            freezeImage = nil
            flashOpacity = 0
            printerShakeX = 0
            printerProgress = 0
            phase = .failed
            clearCompletionState()
            phase = .idle
        }
    }

    @MainActor
    private func playDeterministicPrinterVibration() async throws {
        let values: [CGFloat] = [-0.9, 0.75, -0.62, 0.48, -0.34, 0.22, 0]
        let stepDuration = 0.035

        for value in values {
            try Task.checkCancellation()
            withAnimation(.linear(duration: stepDuration)) {
                printerShakeX = value
            }
            try await sleep(seconds: stepDuration)
        }
    }

    @MainActor
    private func playFeedHapticRattle(
        duration: Double,
        reduceMotion: Bool
    ) async throws {
        let totalDuration = max(0, duration)
        guard totalDuration > 0 else { return }

        // 約40ms前後の細かな間隔で連続パルスを鳴らし、
        // 送りローラーが高速で回る「ダラララ」感をより強くする。
        // 触覚タスクは紙送りの待機処理と並行するため、現像時間には加算されない。
        let baseInterval = reduceMotion ? 0.072 : 0.038
        let intervalOffsets: [Double] = [0.000, -0.004, 0.003, -0.002, 0.005, -0.003, 0.002, -0.001]
        let intensityPattern: [CGFloat] = reduceMotion
            ? [0.36, 0.42, 0.38, 0.44]
            : [0.62, 0.76, 0.68, 0.82, 0.72, 0.88, 0.74, 0.80]

        var elapsed: Double = 0
        var index = 0

        while elapsed < totalDuration {
            try Task.checkCancellation()

            let progress = min(1, elapsed / max(0.001, totalDuration))
            let edgeEnvelope = min(1, min(progress / 0.08, (1 - progress) / 0.10))
            let baseIntensity = intensityPattern[index % intensityPattern.count]
            let intensity = min(1.0, max(0.30, baseIntensity * CGFloat(0.86 + (0.22 * edgeEnvelope))))

            PhotoPrintUIKitHaptics.playFeedRattlePulse(
                index: index,
                intensity: intensity
            )

            let requestedInterval = max(0.032, baseInterval + intervalOffsets[index % intervalOffsets.count])
            let remaining = totalDuration - elapsed
            let actualInterval = min(requestedInterval, remaining)
            guard actualInterval > 0 else { break }

            try await sleep(seconds: actualInterval)
            elapsed += actualInterval
            index += 1
        }
    }

    @MainActor
    private func stopFeedEffects() {
        feedEffectsTask?.cancel()
        feedEffectsTask = nil
        PhotoPrintMotorSoundDriver.shared.stop()
    }

    @MainActor
    private func insertIntoTrayOnce() {
        guard !didInsertIntoTray else { return }
        guard let photo = payload?.photo ?? stagedPayload?.photo else { return }
        didInsertIntoTray = true
        onInsertIntoTray?(photo)
    }

    @MainActor
    private func completeOnce() {
        guard !didComplete else { return }
        didComplete = true
        onComplete?()
    }

    @MainActor
    private func emitHaptic(_ event: PhotoPrintHapticEvent) {
        switch event {
        case .shutter:
            shutterHapticTrigger &+= 1
        case .printer:
            printerHapticTrigger &+= 1
        case .settle:
            settleHapticTrigger &+= 1
        case .tray:
            trayHapticTrigger &+= 1
        case .failure:
            break
        }

        if #available(iOS 17.0, *) {
            return
        }
        emitUIKitFallbackHaptic(event)
    }

    @MainActor
    private func emitUIKitFallbackHaptic(_ event: PhotoPrintHapticEvent) {
        PhotoPrintUIKitHaptics.play(event)
    }

    @MainActor
    private func sleep(seconds: Double) async throws {
        let clamped = max(0, seconds)
        let nanoseconds = UInt64(clamped * 1_000_000_000)
        try await Task<Never, Never>.sleep(nanoseconds: nanoseconds)
    }

    @MainActor
    private func cancelTasks() {
        animationTask?.cancel()
        animationTask = nil
        flashTask?.cancel()
        flashTask = nil
        stopFeedEffects()
    }

    @MainActor
    private func clearCompletionState() {
        stagedPayload = nil
        onInsertIntoTray = nil
        onComplete = nil
        didPersist = false
        didInsertIntoTray = false
        didComplete = false
    }

    deinit {
        animationTask?.cancel()
        flashTask?.cancel()
        feedEffectsTask?.cancel()
    }
}

private enum PhotoPrintHapticEvent {
    case shutter
    case printer
    case settle
    case tray
    case failure
}

@MainActor
private final class PhotoPrintFeedHapticDriver {
    static let shared = PhotoPrintFeedHapticDriver()

    private let softGenerator = UIImpactFeedbackGenerator(style: .soft)
    private let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)

    private init() {}

    func prepare() {
        softGenerator.prepare()
        lightGenerator.prepare()
        mediumGenerator.prepare()
    }

    func pulse(index: Int, intensity: CGFloat) {
        let clampedIntensity = intensity.clamped(to: 0...1)

        // 柔らかいベースにlight/mediumを交互に混ぜ、
        // 送りローラーが細かく強く噛む感触を作る。
        if index.isMultiple(of: 4) {
            mediumGenerator.impactOccurred(intensity: min(1.0, clampedIntensity * 0.96))
            mediumGenerator.prepare()
        } else if index.isMultiple(of: 2) {
            lightGenerator.impactOccurred(intensity: min(1.0, clampedIntensity * 0.92))
            lightGenerator.prepare()
        } else {
            softGenerator.impactOccurred(intensity: min(1.0, clampedIntensity * 0.88))
            softGenerator.prepare()
        }
    }
}

@MainActor
private final class PhotoPrintMotorSoundDriver {
    static let shared = PhotoPrintMotorSoundDriver()

    private struct AudioSessionState {
        let category: AVAudioSession.Category
        let mode: AVAudioSession.Mode
        let options: AVAudioSession.CategoryOptions
    }

    private var player: AVAudioPlayer?
    private var retainedAudioData: Data?
    private var cachedAudioData: [Int: Data] = [:]
    private var previousAudioSessionState: AudioSessionState?

    private init() {}

    func prepare() {
        // AVAudioEngineのグラフ起動は行わず、再生に使うWAVデータだけを先に生成する。
        // これにより撮影後の紙送り開始時にデコード待ちが発生しにくくなる。
        _ = audioData(duration: 1.55, reduceMotion: false)
        _ = audioData(duration: 0.44, reduceMotion: true)
    }

    func play(duration: Double, reduceMotion: Bool) {
        let resolvedDuration = max(0.08, duration)
        stopPlayerOnly()

        // .ambientは端末の消音スイッチを尊重するカテゴリー。
        // セッション設定に失敗しても、現在のアプリ側セッションで再生できる可能性があるため、
        // エラーを記録したうえでAVAudioPlayerの生成・再生は続行する。
        do {
            try activateAmbientAudioSession()
        } catch {
            log("audio session activation failed: \(error.localizedDescription)")
        }

        let data = audioData(
            duration: resolvedDuration,
            reduceMotion: reduceMotion
        )
        retainedAudioData = data

        do {
            let audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer.numberOfLoops = 0
            audioPlayer.volume = reduceMotion ? 0.72 : 0.92
            audioPlayer.enableRate = false

            let prepared = audioPlayer.prepareToPlay()
            player = audioPlayer

            guard prepared else {
                log("AVAudioPlayer.prepareToPlay returned false")
                return
            }

            guard audioPlayer.play() else {
                log("AVAudioPlayer.play returned false")
                return
            }

            log(
                "playback started: duration=\(resolvedDuration), "
                + "volume=\(audioPlayer.volume), "
                + "session=\(AVAudioSession.sharedInstance().category.rawValue)"
            )
        } catch {
            player = nil
            retainedAudioData = nil
            log("AVAudioPlayer creation failed: \(error.localizedDescription)")
        }
    }

    func stop() {
        stopPlayerOnly()
        retainedAudioData = nil
        restorePreviousAudioSession()
    }

    private func stopPlayerOnly() {
        guard let player else { return }
        if player.isPlaying {
            player.stop()
        }
        self.player = nil
    }

    private func activateAmbientAudioSession() throws {
        let session = AVAudioSession.sharedInstance()

        if previousAudioSessionState == nil {
            previousAudioSessionState = AudioSessionState(
                category: session.category,
                mode: session.mode,
                options: session.categoryOptions
            )
        }

        try session.setCategory(
            .ambient,
            mode: .default,
            options: [.mixWithOthers]
        )
        try session.setActive(true)
    }

    private func restorePreviousAudioSession() {
        guard let previousAudioSessionState else { return }
        self.previousAudioSessionState = nil

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(
                previousAudioSessionState.category,
                mode: previousAudioSessionState.mode,
                options: previousAudioSessionState.options
            )
            try session.setActive(true)
        } catch {
            log("audio session restoration failed: \(error.localizedDescription)")
        }
    }

    private func audioData(
        duration: Double,
        reduceMotion: Bool
    ) -> Data {
        let durationMilliseconds = Int((duration * 1_000).rounded())
        let cacheKey = (durationMilliseconds * 10) + (reduceMotion ? 1 : 0)

        if let cached = cachedAudioData[cacheKey] {
            return cached
        }

        let generated = makeMotorWAVData(
            duration: duration,
            reduceMotion: reduceMotion
        )
        cachedAudioData[cacheKey] = generated
        return generated
    }

    private func makeMotorWAVData(
        duration: Double,
        reduceMotion: Bool
    ) -> Data {
        let sampleRate: UInt32 = 44_100
        let channelCount: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let bytesPerSample = Int(bitsPerSample / 8)
        let frameCount = max(1, Int(Double(sampleRate) * duration))

        var pcmData = Data()
        pcmData.reserveCapacity(frameCount * bytesPerSample)

        var motorPhase: Double = 0
        var whinePhase: Double = 0
        var upperWhinePhase: Double = 0
        var noiseState: UInt32 = 0x73A9_51C3
        let twoPi = Double.pi * 2
        let amplitude = reduceMotion ? 0.34 : 0.48

        for frame in 0..<frameCount {
            let time = Double(frame) / Double(sampleRate)
            let remaining = max(0, duration - time)

            let fadeIn = min(1, time / 0.045)
            let fadeOut = min(1, remaining / 0.085)
            let envelope = max(0, min(fadeIn, fadeOut))

            let spinUp = 1 - exp(-time * 9.5)
            let flutter = sin(twoPi * 5.8 * time) * 3.2
            let motorFrequency = 126 + (48 * spinUp) + flutter
            motorPhase += twoPi * motorFrequency / Double(sampleRate)

            let whineFrequency = 590
                + (118 * spinUp)
                + (14 * sin(twoPi * 1.9 * time))
            whinePhase += twoPi * whineFrequency / Double(sampleRate)

            let upperWhineFrequency = 1_120
                + (90 * spinUp)
                + (22 * sin(twoPi * 2.4 * time))
            upperWhinePhase += twoPi * upperWhineFrequency / Double(sampleRate)

            noiseState = noiseState &* 1_664_525 &+ 1_013_904_223
            let noise = (Double(noiseState) / Double(UInt32.max) * 2) - 1

            let rollerModulation = 0.79 + (0.21 * sin(twoPi * 28 * time))
            let motor = (
                0.50 * sin(motorPhase)
                + 0.20 * sin(motorPhase * 2.01)
                + 0.07 * sin(motorPhase * 3.98)
            )
            let whine = 0.22 * sin(whinePhase)
            let upperWhine = 0.075 * sin(upperWhinePhase)
            let mechanicalNoise = noise * 0.052 * rollerModulation

            let rawSample = (
                motor * rollerModulation
                + whine
                + upperWhine
                + mechanicalNoise
            ) * amplitude * envelope

            // 軽いソフトクリップで音量を確保しながら、整数PCM変換時の歪みを防ぐ。
            let clipped = tanh(rawSample * 1.18) * 0.94
            let integerSample = Int16(
                max(-1, min(1, clipped)) * Double(Int16.max)
            )
            appendLittleEndian(integerSample, to: &pcmData)
        }

        let dataSize = UInt32(pcmData.count)
        let byteRate = sampleRate
            * UInt32(channelCount)
            * UInt32(bitsPerSample / 8)
        let blockAlign = channelCount * (bitsPerSample / 8)

        var wavData = Data()
        wavData.reserveCapacity(44 + pcmData.count)
        appendASCII("RIFF", to: &wavData)
        appendLittleEndian(UInt32(36) + dataSize, to: &wavData)
        appendASCII("WAVE", to: &wavData)
        appendASCII("fmt ", to: &wavData)
        appendLittleEndian(UInt32(16), to: &wavData)
        appendLittleEndian(UInt16(1), to: &wavData)
        appendLittleEndian(channelCount, to: &wavData)
        appendLittleEndian(sampleRate, to: &wavData)
        appendLittleEndian(byteRate, to: &wavData)
        appendLittleEndian(blockAlign, to: &wavData)
        appendLittleEndian(bitsPerSample, to: &wavData)
        appendASCII("data", to: &wavData)
        appendLittleEndian(dataSize, to: &wavData)
        wavData.append(pcmData)
        return wavData
    }

    private func appendASCII(_ string: String, to data: inout Data) {
        data.append(contentsOf: string.utf8)
    }

    private func appendLittleEndian<T: FixedWidthInteger>(
        _ value: T,
        to data: inout Data
    ) {
        var littleEndianValue = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndianValue) { bytes in
            data.append(contentsOf: bytes)
        }
    }

    private func log(_ message: String) {
        #if DEBUG
        print("[PhotoPrintMotorSound] \(message)")
        #endif
    }
}

private enum PhotoPrintUIKitHaptics {
    @MainActor
    static func prepareFeedRattle() {
        PhotoPrintFeedHapticDriver.shared.prepare()
    }

    @MainActor
    static func playFeedRattlePulse(index: Int, intensity: CGFloat) {
        PhotoPrintFeedHapticDriver.shared.pulse(
            index: index,
            intensity: intensity
        )
    }

    @MainActor
    static func play(_ event: PhotoPrintHapticEvent) {
        switch event {
        case .shutter:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: 0.75)
        case .printer:
            UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.55)
        case .settle:
            UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.48)
        case .tray:
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.52)
        case .failure:
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
}

private struct PhotoPrintSensoryFeedbackModifier: ViewModifier {
    let shutterTrigger: Int
    let printerTrigger: Int
    let settleTrigger: Int
    let trayTrigger: Int

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content
                .sensoryFeedback(
                    .impact(weight: .medium, intensity: 0.75),
                    trigger: shutterTrigger
                )
                .sensoryFeedback(
                    .impact(weight: .light, intensity: 0.48),
                    trigger: printerTrigger
                )
                .sensoryFeedback(
                    .impact(weight: .light, intensity: 0.42),
                    trigger: settleTrigger
                )
                .sensoryFeedback(
                    .impact(weight: .medium, intensity: 0.48),
                    trigger: trayTrigger
                )
        } else {
            content
        }
    }
}

private struct InitialEjectingPolaroidView: View {
    let image: UIImage
    let photoID: UUID
    let namespace: Namespace.ID
    let photoWidth: CGFloat
    let screenSize: CGSize
    let slotY: CGFloat
    let reduceMotion: Bool

    private var photoHeight: CGFloat {
        photoWidth / PolaroidPaperView.aspectRatio
    }

    var body: some View {
        let values = PhotoPrintAnimationValues(
            verticalProgress: 0,
            scale: reduceMotion ? 0.62 : 0.46,
            rotationX: reduceMotion ? 8 : 65,
            rotationY: reduceMotion ? 0 : 0.8,
            rotationZ: reduceMotion ? 0 : -0.35,
            perspective: reduceMotion ? 0.08 : 0.24,
            shadowRadius: 2,
            shadowY: 1,
            shadowOpacity: 0.08,
            paperBend: 0.04,
            paperRelease: 0,
            lateralVibration: 0
        )

        PolaroidPaperView(sceneImage: image)
            .frame(width: photoWidth)
            .matchedGeometryEffect(
                id: photoID,
                in: namespace,
                properties: .frame,
                anchor: .center,
                isSource: true
            )
            .modifier(
                PhotoPrintTransformModifier(
                    values: values,
                    photoSize: CGSize(width: photoWidth, height: photoHeight),
                    screenSize: screenSize,
                    slotY: slotY
                )
            )
    }
}

@available(iOS 17.0, *)
private struct KeyframedEjectingPolaroidView: View {
    let image: UIImage
    let photoID: UUID
    let namespace: Namespace.ID
    let trigger: UUID
    let photoWidth: CGFloat
    let screenSize: CGSize
    let slotY: CGFloat
    let configuration: PhotoPrintAnimationConfiguration
    let shaderEnabled: Bool

    private var photoHeight: CGFloat {
        photoWidth / PolaroidPaperView.aspectRatio
    }

    var body: some View {
        PolaroidPaperView(sceneImage: image)
            .frame(width: photoWidth)
            .matchedGeometryEffect(
                id: photoID,
                in: namespace,
                properties: .frame,
                anchor: .center,
                isSource: true
            )
            .keyframeAnimator(
                initialValue: PhotoPrintAnimationValues(),
                trigger: trigger
            ) { content, values in
                content
                    .modifier(
                        PhotoPrintShaderModifier(
                            size: CGSize(width: photoWidth, height: photoHeight),
                            progress: values.verticalProgress,
                            bendAmount: values.paperBend,
                            releaseAmount: values.paperRelease,
                            isEnabled: shaderEnabled
                        )
                    )
                    .modifier(
                        PhotoPrintTransformModifier(
                            values: values,
                            photoSize: CGSize(width: photoWidth, height: photoHeight),
                            screenSize: screenSize,
                            slotY: slotY
                        )
                    )
            } keyframes: { _ in
                KeyframeTrack(\.verticalProgress) {
                    CubicKeyframe(0.10, duration: 0.18)
                    LinearKeyframe(0.78, duration: 1.10)
                    CubicKeyframe(1.00, duration: 0.27)
                    CubicKeyframe(1.04, duration: 0.10)
                    CubicKeyframe(0.985, duration: 0.12)
                    CubicKeyframe(1.00, duration: 0.20)
                }

                KeyframeTrack(\.scale) {
                    CubicKeyframe(0.58, duration: 0.35)
                    CubicKeyframe(1.02, duration: 1.20)
                    CubicKeyframe(1.035, duration: 0.10)
                    CubicKeyframe(0.995, duration: 0.12)
                    CubicKeyframe(1.00, duration: 0.20)
                }

                KeyframeTrack(\.rotationX) {
                    CubicKeyframe(50, duration: 0.30)
                    CubicKeyframe(29, duration: 0.72)
                    CubicKeyframe(4.5, duration: 0.53)
                    CubicKeyframe(0.8, duration: 0.10)
                    CubicKeyframe(3.2, duration: 0.12)
                    CubicKeyframe(1.2, duration: 0.20)
                }

                KeyframeTrack(\.rotationY) {
                    LinearKeyframe(-0.7, duration: 0.42)
                    LinearKeyframe(0.55, duration: 0.44)
                    LinearKeyframe(-0.25, duration: 0.43)
                    LinearKeyframe(0.12, duration: 0.26)
                    LinearKeyframe(0, duration: 0.42)
                }

                KeyframeTrack(\.rotationZ) {
                    LinearKeyframe(0.48, duration: 0.155)
                    LinearKeyframe(-0.55, duration: 0.155)
                    LinearKeyframe(0.42, duration: 0.155)
                    LinearKeyframe(-0.36, duration: 0.155)
                    LinearKeyframe(0.30, duration: 0.155)
                    LinearKeyframe(-0.24, duration: 0.155)
                    LinearKeyframe(0.18, duration: 0.155)
                    LinearKeyframe(-0.12, duration: 0.155)
                    LinearKeyframe(0.08, duration: 0.155)
                    LinearKeyframe(0, duration: 0.155)
                    CubicKeyframe(0.12, duration: 0.10)
                    CubicKeyframe(-0.08, duration: 0.12)
                    CubicKeyframe(0, duration: 0.20)
                }

                KeyframeTrack(\.perspective) {
                    CubicKeyframe(0.30, duration: 0.55)
                    CubicKeyframe(0.34, duration: 0.70)
                    CubicKeyframe(0.18, duration: 0.30)
                    CubicKeyframe(0.12, duration: 0.42)
                }

                KeyframeTrack(\.shadowRadius) {
                    CubicKeyframe(5, duration: 0.35)
                    CubicKeyframe(13, duration: 0.75)
                    CubicKeyframe(20, duration: 0.45)
                    CubicKeyframe(17, duration: 0.42)
                }

                KeyframeTrack(\.shadowY) {
                    CubicKeyframe(3, duration: 0.35)
                    CubicKeyframe(10, duration: 0.75)
                    CubicKeyframe(17, duration: 0.45)
                    CubicKeyframe(12, duration: 0.42)
                }

                KeyframeTrack(\.shadowOpacity) {
                    CubicKeyframe(0.14, duration: 0.35)
                    CubicKeyframe(0.27, duration: 0.75)
                    CubicKeyframe(0.34, duration: 0.45)
                    CubicKeyframe(0.24, duration: 0.42)
                }

                KeyframeTrack(\.paperBend) {
                    CubicKeyframe(0.22, duration: 0.25)
                    CubicKeyframe(1.00, duration: 0.80)
                    CubicKeyframe(0.38, duration: 0.50)
                    CubicKeyframe(-0.16, duration: 0.10)
                    CubicKeyframe(0.08, duration: 0.12)
                    CubicKeyframe(0, duration: 0.20)
                }

                KeyframeTrack(\.paperRelease) {
                    LinearKeyframe(0, duration: 1.55)
                    CubicKeyframe(1.00, duration: 0.10)
                    CubicKeyframe(0.10, duration: 0.12)
                    CubicKeyframe(0, duration: 0.20)
                }

                KeyframeTrack(\.lateralVibration) {
                    LinearKeyframe(0.9, duration: 0.155)
                    LinearKeyframe(-1.1, duration: 0.155)
                    LinearKeyframe(0.8, duration: 0.155)
                    LinearKeyframe(-0.75, duration: 0.155)
                    LinearKeyframe(0.65, duration: 0.155)
                    LinearKeyframe(-0.55, duration: 0.155)
                    LinearKeyframe(0.45, duration: 0.155)
                    LinearKeyframe(-0.35, duration: 0.155)
                    LinearKeyframe(0.22, duration: 0.155)
                    LinearKeyframe(0, duration: 0.155)
                    LinearKeyframe(0, duration: 0.42)
                }
            }
    }
}

private struct LegacyEjectingPolaroidView: View {
    let image: UIImage
    let photoID: UUID
    let namespace: Namespace.ID
    let trigger: UUID
    let photoWidth: CGFloat
    let screenSize: CGSize
    let slotY: CGFloat
    let configuration: PhotoPrintAnimationConfiguration

    @State private var verticalProgress: CGFloat = 0
    @State private var scale: CGFloat = 0.46
    @State private var rotationX: Double = 65
    @State private var rotationY: Double = 0.8
    @State private var rotationZ: Double = -0.35
    @State private var shadowRadius: CGFloat = 2
    @State private var shadowY: CGFloat = 1
    @State private var shadowOpacity: Double = 0.08
    @State private var vibrationX: CGFloat = 0

    private var photoHeight: CGFloat {
        photoWidth / PolaroidPaperView.aspectRatio
    }

    var body: some View {
        PolaroidPaperView(sceneImage: image)
            .frame(width: photoWidth)
            .matchedGeometryEffect(
                id: photoID,
                in: namespace,
                properties: .frame,
                anchor: .center,
                isSource: true
            )
            .rotation3DEffect(
                .degrees(rotationX),
                axis: (x: 1, y: 0, z: 0),
                anchor: .top,
                perspective: 0.48
            )
            .rotation3DEffect(
                .degrees(rotationY),
                axis: (x: 0, y: 1, z: 0),
                anchor: .center,
                perspective: 0.20
            )
            .rotationEffect(.degrees(rotationZ))
            .scaleEffect(scale, anchor: .top)
            .shadow(
                color: .black.opacity(shadowOpacity),
                radius: shadowRadius,
                x: 0,
                y: shadowY
            )
            .position(
                x: screenSize.width * 0.5 + vibrationX,
                y: PhotoPrintGeometry.centerY(
                    slotY: slotY,
                    photoHeight: photoHeight,
                    screenHeight: screenSize.height,
                    progress: verticalProgress
                )
            )
            .task(id: trigger) {
                await runFallbackAnimation()
            }
    }

    @MainActor
    private func runFallbackAnimation() async {
        verticalProgress = 0
        scale = 0.46
        rotationX = 65
        rotationY = 0.8
        rotationZ = -0.35
        shadowRadius = 2
        shadowY = 1
        shadowOpacity = 0.08
        vibrationX = 0

        withAnimation(
            .timingCurve(
                0.16,
                0.78,
                0.20,
                1.0,
                duration: configuration.feedingDuration
            )
        ) {
            verticalProgress = 1
            scale = 1.02
            rotationX = 4
            rotationY = 0
            rotationZ = 0.12
            shadowRadius = 20
            shadowY = 17
            shadowOpacity = 0.32
        }

        let vibrationValues: [CGFloat] = [0.9, -1.1, 0.8, -0.7, 0.55, -0.4, 0.25, 0]
        let vibrationDuration = min(0.10, configuration.feedingDuration / 10)

        for value in vibrationValues {
            guard !Task.isCancelled else { return }
            withAnimation(.linear(duration: vibrationDuration)) {
                vibrationX = value
            }
            try? await Task<Never, Never>.sleep(
                nanoseconds: UInt64(vibrationDuration * 1_000_000_000)
            )
        }

        let used = vibrationDuration * Double(vibrationValues.count)
        let remaining = max(0, configuration.feedingDuration - used)
        try? await Task<Never, Never>.sleep(
            nanoseconds: UInt64(remaining * 1_000_000_000)
        )
        guard !Task.isCancelled else { return }

        withAnimation(.spring(response: configuration.releaseDuration, dampingFraction: 0.68)) {
            verticalProgress = 1.04
            scale = 1.035
            rotationX = 0.8
            rotationZ = -0.08
        }

        try? await Task<Never, Never>.sleep(
            nanoseconds: UInt64(configuration.releaseDuration * 1_000_000_000)
        )
        guard !Task.isCancelled else { return }

        withAnimation(.spring(response: configuration.settleDuration, dampingFraction: 0.78)) {
            verticalProgress = 1
            scale = 1
            rotationX = 1.2
            rotationZ = 0
            shadowRadius = 17
            shadowY = 12
            shadowOpacity = 0.24
        }
    }
}

private struct ReducedMotionEjectingPolaroidView: View {
    let image: UIImage
    let photoID: UUID
    let namespace: Namespace.ID
    let trigger: UUID
    let photoWidth: CGFloat
    let screenSize: CGSize
    let slotY: CGFloat

    @State private var progress: CGFloat = 0
    @State private var opacity: Double = 0.88

    private var photoHeight: CGFloat {
        photoWidth / PolaroidPaperView.aspectRatio
    }

    var body: some View {
        PolaroidPaperView(sceneImage: image)
            .frame(width: photoWidth)
            .matchedGeometryEffect(
                id: photoID,
                in: namespace,
                properties: .frame,
                anchor: .center,
                isSource: true
            )
            .scaleEffect(0.62 + (progress * 0.38), anchor: .top)
            .rotation3DEffect(
                .degrees(Double(8 * (1 - progress))),
                axis: (x: 1, y: 0, z: 0),
                anchor: .top,
                perspective: 0.08
            )
            .opacity(opacity)
            .shadow(
                color: .black.opacity(0.18 + (Double(progress) * 0.08)),
                radius: 6 + (progress * 6),
                x: 0,
                y: 4 + (progress * 5)
            )
            .position(
                x: screenSize.width * 0.5,
                y: PhotoPrintGeometry.centerY(
                    slotY: slotY,
                    photoHeight: photoHeight,
                    screenHeight: screenSize.height,
                    progress: progress
                )
            )
            .task(id: trigger) {
                progress = 0
                opacity = 0.88
                withAnimation(.easeOut(duration: 0.44)) {
                    progress = 1
                    opacity = 1
                }
            }
    }
}

private enum PhotoPrintGeometry {
    static func centerY(
        slotY: CGFloat,
        photoHeight: CGFloat,
        screenHeight: CGFloat,
        progress: CGFloat
    ) -> CGFloat {
        let safeHeight = max(1, photoHeight)
        // 初期状態では写真全体をDynamic Island／排出口の背面へ完全に隠す。
        // 最終位置は従来とほぼ同じになるよう、開始位置を上げた分だけ移動量を増やす。
        let startCenter = slotY - (safeHeight * 0.56)
        let additionalTravel = min(max(28, screenHeight * 0.065), 58)
        let travel = (safeHeight * 1.06) + additionalTravel
        return startCenter + (travel * progress)
    }
}

private struct PhotoPrintTransformModifier: ViewModifier {
    let values: PhotoPrintAnimationValues
    let photoSize: CGSize
    let screenSize: CGSize
    let slotY: CGFloat

    func body(content: Content) -> some View {
        content
            .overlay {
                LinearGradient(
                    colors: [
                        .white.opacity(0.20),
                        .clear,
                        .black.opacity(0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .opacity(
                    min(
                        0.22,
                        0.04 + (Double(abs(values.paperBend)) * 0.14)
                    )
                )
                .blendMode(.screen)
                .allowsHitTesting(false)
            }
            .rotation3DEffect(
                .degrees(values.rotationX),
                axis: (x: 1, y: 0, z: 0),
                anchor: .top,
                perspective: values.perspective
            )
            .rotation3DEffect(
                .degrees(values.rotationY),
                axis: (x: 0, y: 1, z: 0),
                anchor: .center,
                perspective: max(0.08, values.perspective * 0.38)
            )
            .rotationEffect(.degrees(values.rotationZ))
            .scaleEffect(values.scale, anchor: .top)
            .shadow(
                color: .black.opacity(values.shadowOpacity),
                radius: values.shadowRadius,
                x: 0,
                y: values.shadowY
            )
            .position(
                x: screenSize.width * 0.5 + values.lateralVibration,
                y: PhotoPrintGeometry.centerY(
                    slotY: slotY,
                    photoHeight: photoSize.height,
                    screenHeight: screenSize.height,
                    progress: values.verticalProgress
                )
            )
    }
}

private enum PhotoPrintShaderSupport {
    static let isFunctionAvailable: Bool = {
        guard let device = MTLCreateSystemDefaultDevice() else { return false }
        guard let library = device.makeDefaultLibrary() else { return false }
        return library.makeFunction(name: "polaroidPaperBend") != nil
    }()
}

private struct PhotoPrintShaderModifier: ViewModifier {
    let size: CGSize
    let progress: CGFloat
    let bendAmount: CGFloat
    let releaseAmount: CGFloat
    let isEnabled: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *), isEnabled, size.width > 1, size.height > 1 {
            let maxOffset = CGSize(
                width: min(8, max(2, size.width * 0.024)),
                height: min(20, max(4, size.height * 0.052))
            )

            content.distortionEffect(
                ShaderLibrary.default.polaroidPaperBend(
                    .float2(Float(size.width), Float(size.height)),
                    .float(Float(progress)),
                    .float(Float(bendAmount)),
                    .float(Float(releaseAmount))
                ),
                maxSampleOffset: maxOffset,
                isEnabled: true
            )
        } else {
            content
        }
    }
}


private enum PicoPolaroidLayout {
    static let canvasSize = CGSize(width: 1200, height: 1500)
    static let photoRect = CGRect(x: 92, y: 108, width: 1016, height: 1016)
    static let paperCornerRadius: CGFloat = 29
    static let photoCornerRadius: CGFloat = 14
    static let aspectRatio: CGFloat = canvasSize.width / canvasSize.height
}

private struct PolaroidPaperView: View {
    static let aspectRatio: CGFloat = PicoPolaroidLayout.aspectRatio

    let sceneImage: UIImage

    var body: some View {
        GeometryReader { proxy in
            let width = max(1, proxy.size.width)
            let height = max(1, proxy.size.height)
            let sideInset = width * (
                PicoPolaroidLayout.photoRect.minX / PicoPolaroidLayout.canvasSize.width
            )
            let topInset = height * (
                PicoPolaroidLayout.photoRect.minY / PicoPolaroidLayout.canvasSize.height
            )
            let photoSide = width * (
                PicoPolaroidLayout.photoRect.width / PicoPolaroidLayout.canvasSize.width
            )
            let paperCorner = max(3, width * 0.022)
            let photoCorner = max(2, width * 0.014)
            let edgeWidth = max(0.65, width * 0.0024)
            let paperShape = RoundedRectangle(
                cornerRadius: paperCorner,
                style: .continuous
            )
            let photoShape = RoundedRectangle(
                cornerRadius: photoCorner,
                style: .continuous
            )

            ZStack(alignment: .topLeading) {
                paperShape
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(
                                    color: Color(
                                        red: 0.995,
                                        green: 0.991,
                                        blue: 0.965
                                    ),
                                    location: 0
                                ),
                                .init(
                                    color: Color(
                                        red: 0.974,
                                        green: 0.968,
                                        blue: 0.938
                                    ),
                                    location: 0.48
                                ),
                                .init(
                                    color: Color(
                                        red: 0.935,
                                        green: 0.930,
                                        blue: 0.900
                                    ),
                                    location: 1
                                )
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                RadialGradient(
                    colors: [
                        Color.white.opacity(0.34),
                        Color.white.opacity(0.06),
                        Color.clear
                    ],
                    center: UnitPoint(x: 0.16, y: 0.08),
                    startRadius: 0,
                    endRadius: max(width, height) * 0.78
                )
                .clipShape(paperShape)
                .blendMode(.screen)

                PolaroidPaperTextureView()
                    .clipShape(paperShape)
                    .blendMode(.multiply)
                    .opacity(0.92)

                // 写真面を紙よりわずかに沈ませ、乳剤層が台紙に載っている厚みを表現する。
                photoShape
                    .fill(Color.black.opacity(0.16))
                    .frame(width: photoSide, height: photoSide)
                    .offset(
                        x: sideInset,
                        y: topInset + max(0.5, width * 0.002)
                    )
                    .blur(radius: max(0.25, width * 0.0012))

                Image(uiImage: sceneImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: photoSide, height: photoSide)
                    .clipShape(photoShape)
                    .overlay {
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.095),
                                Color.clear,
                                Color.black.opacity(0.055)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .blendMode(.softLight)
                        .clipShape(photoShape)
                    }
                    .overlay {
                        photoShape
                            .strokeBorder(
                                Color.black.opacity(0.16),
                                lineWidth: max(0.5, width * 0.0014)
                            )
                    }
                    .offset(x: sideInset, y: topInset)

                // 実物のインスタント写真にある下部の薬剤ポッド／厚みを、
                // 帯ではなくごく弱い濃度差として表現する。
                LinearGradient(
                    stops: [
                        .init(color: Color.clear, location: 0),
                        .init(color: Color.black.opacity(0.018), location: 0.62),
                        .init(color: Color.white.opacity(0.14), location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: height * 0.19)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .clipShape(paperShape)
                .blendMode(.softLight)

                LinearGradient(
                    colors: [
                        Color.white.opacity(0.18),
                        Color.clear,
                        Color.black.opacity(0.035)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(paperShape)
                .blendMode(.softLight)

                paperShape
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.86),
                                Color.white.opacity(0.24),
                                Color.black.opacity(0.17)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: edgeWidth
                    )

                paperShape
                    .inset(by: max(0.8, width * 0.004))
                    .strokeBorder(
                        Color.black.opacity(0.035),
                        lineWidth: max(0.45, width * 0.0012)
                    )
            }
            .clipShape(paperShape)
            .compositingGroup()
        }
        .aspectRatio(Self.aspectRatio, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

private struct PolaroidPaperTextureView: View {
    var body: some View {
        Canvas { context, size in
            let width = max(1, size.width)
            let height = max(1, size.height)

            // 決定的な座標を使い、アニメーション中にテクスチャがちらつかないようにする。
            for index in 0..<320 {
                let x = CGFloat((index * 47 + 19) % 997) / 997 * width
                let y = CGFloat((index * 83 + 31) % 991) / 991 * height
                let diameter = max(
                    0.35,
                    min(width, height) * CGFloat(0.0011 + Double(index % 3) * 0.00035)
                )
                let opacity = 0.022 + (Double(index % 6) * 0.0045)

                var dot = Path()
                dot.addEllipse(
                    in: CGRect(
                        x: x,
                        y: y,
                        width: diameter,
                        height: diameter
                    )
                )
                context.fill(
                    dot,
                    with: .color(Color.black.opacity(opacity))
                )
            }

            for index in 0..<96 {
                let x = CGFloat((index * 61 + 7) % 983) / 983 * width
                let y = CGFloat((index * 97 + 13) % 977) / 977 * height
                let length = width * CGFloat(0.018 + Double(index % 4) * 0.007)
                let rise = height * CGFloat(Double((index % 3) - 1) * 0.0012)

                var fiber = Path()
                fiber.move(to: CGPoint(x: x, y: y))
                fiber.addLine(
                    to: CGPoint(
                        x: min(width, x + length),
                        y: max(0, min(height, y + rise))
                    )
                )
                context.stroke(
                    fiber,
                    with: .color(Color.white.opacity(0.075)),
                    lineWidth: max(0.25, width * 0.00072)
                )
            }

            // 紙の浅い凹凸を短い暗線として重ね、均一なデジタルノイズではなく
            // 実際の台紙表面に近いざらつきを作る。
            for index in 0..<88 {
                let x = CGFloat((index * 109 + 23) % 971) / 971 * width
                let y = CGFloat((index * 71 + 41) % 967) / 967 * height
                let length = width * CGFloat(0.006 + Double(index % 5) * 0.0035)
                let fall = height * CGFloat(Double((index % 5) - 2) * 0.00055)

                var relief = Path()
                relief.move(to: CGPoint(x: x, y: y))
                relief.addLine(
                    to: CGPoint(
                        x: min(width, x + length),
                        y: max(0, min(height, y + fall))
                    )
                )
                context.stroke(
                    relief,
                    with: .color(Color.black.opacity(0.032)),
                    lineWidth: max(0.2, width * 0.00050)
                )
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct FullScreenCoverClearBackground: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear

        DispatchQueue.main.async {
            clearPresentationBackground(from: view)
        }

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            clearPresentationBackground(from: uiView)
        }
    }

    private func clearPresentationBackground(from view: UIView) {
        view.backgroundColor = .clear
        view.superview?.backgroundColor = .clear
        view.superview?.superview?.backgroundColor = .clear
        view.superview?.superview?.superview?.backgroundColor = .clear
    }
}

private struct PicoPrintedPhoto: Identifiable, Equatable {
    let id: UUID
    let image: UIImage
    let displaySceneImage: UIImage
    let date: Date

    init(
        id: UUID = UUID(),
        image: UIImage,
        displaySceneImage: UIImage,
        date: Date
    ) {
        self.id = id
        self.image = image
        self.displaySceneImage = displaySceneImage
        self.date = date
    }

    static func == (lhs: PicoPrintedPhoto, rhs: PicoPrintedPhoto) -> Bool {
        lhs.id == rhs.id
    }
}

private struct PicoRaisedRoundedPanel: View {
    let cornerRadius: CGFloat
    let fill: Color
    let outerStrokeOpacity: Double
    let highlightOpacity: Double
    let shadowOpacity: Double
    let shadowRadius: CGFloat
    let shadowY: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(fill)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius + 4, style: .continuous)
                        .stroke(Color.black.opacity(outerStrokeOpacity), lineWidth: 5)
                        .padding(-3)

                    RoundedRectangle(cornerRadius: cornerRadius + 5, style: .continuous)
                        .stroke(Color.white.opacity(highlightOpacity), lineWidth: 1.2)
                        .padding(-5)
                        .offset(y: -1)
                }
                .allowsHitTesting(false)
            }
            .shadow(
                color: .black.opacity(shadowOpacity),
                radius: shadowRadius,
                x: 0,
                y: shadowY
            )
            .shadow(
                color: .white.opacity(highlightOpacity * 0.52),
                radius: 3,
                x: 0,
                y: -1
            )
    }
}

private struct PicoRoundControlButton: View {
    let systemImage: String
    let size: CGFloat
    let fill: Color
    let foreground: Color
    let lineWidth: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.16))
                .frame(width: size, height: size)
                .shadow(color: .black.opacity(0.28), radius: 8, x: 0, y: 7)

            Circle()
                .fill(fill)
                .frame(width: size * 0.82, height: size * 0.82)
                .overlay(
                    Circle()
                        .stroke(Color.black.opacity(0.72), lineWidth: max(2, lineWidth))
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.18), lineWidth: 1.2)
                        .padding(3)
                )
                .shadow(color: .white.opacity(0.22), radius: 3, x: 0, y: -2)

            Image(systemName: systemImage)
                .font(.system(size: size * 0.31, weight: .heavy))
                .foregroundStyle(foreground)
        }
        .frame(width: size, height: size)
    }
}

private struct PicoPrintedPhotoDetailOverlay: View {
    let photo: PicoPrintedPhoto
    let onDismiss: () -> Void
    let onDelete: () -> Void

    private var timeText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: photo.date)
    }

    var body: some View {
        ZStack {
            Color(red: 0.09, green: 0.09, blue: 0.10)
                .opacity(0.98)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            VStack(spacing: 0) {
                HStack {
                    Button(action: onDismiss) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 56, height: 56)
                            .background(Color.white.opacity(0.06), in: Circle())
                            .overlay(Circle().stroke(Color.white.opacity(0.22), lineWidth: 2))
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    VStack(spacing: 2) {
                        Text("今日")
                            .font(.system(size: 22, weight: .heavy, design: .rounded))
                        Text(timeText)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.06), in: Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.22), lineWidth: 2))

                    Spacer()

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 23, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 56, height: 56)
                            .background(Color.white.opacity(0.06), in: Circle())
                            .overlay(Circle().stroke(Color.white.opacity(0.22), lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 22)
                .padding(.top, 54)

                Spacer(minLength: 42)

                Image(uiImage: photo.image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 360)
                    .rotationEffect(.degrees(-1.8))
                    .shadow(color: .black.opacity(0.42), radius: 18, x: 0, y: 10)
                    .padding(.horizontal, 32)

                Spacer(minLength: 90)
            }
        }
    }
}

private enum PicoCameraImageComposer {
    private static let disposableCameraContext = CIContext(
        options: [
            .cacheIntermediates: false
        ]
    )

    static func composeScene(
        background: UIImage,
        previewSize: CGSize,
        steps: Int
    ) -> UIImage {
        let filteredBackground = applyDisposableCameraLook(to: background)
        let backgroundSize = filteredBackground.size

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = filteredBackground.scale
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: backgroundSize, format: format)
        return renderer.image { _ in
            filteredBackground.draw(in: CGRect(origin: .zero, size: backgroundSize))
            drawTinyStepStamp(steps: steps, canvasSize: backgroundSize)
        }
    }

    static func makePolaroid(from image: UIImage) -> UIImage {
        let outputSize = PicoPolaroidLayout.canvasSize
        let photoRect = PicoPolaroidLayout.photoRect
        let paperRect = CGRect(origin: .zero, size: outputSize)
        let paperPath = UIBezierPath(
            roundedRect: paperRect.insetBy(dx: 2, dy: 2),
            cornerRadius: PicoPolaroidLayout.paperCornerRadius
        )
        let photoPath = UIBezierPath(
            roundedRect: photoRect,
            cornerRadius: PicoPolaroidLayout.photoCornerRadius
        )

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(size: outputSize, format: format)
        return renderer.image { context in
            let cg = context.cgContext
            cg.clear(paperRect)

            cg.saveGState()
            cg.addPath(paperPath.cgPath)
            cg.clip()

            UIColor(
                red: 0.974,
                green: 0.968,
                blue: 0.936,
                alpha: 1
            ).setFill()
            cg.fill(paperRect)

            let paperGradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [
                    UIColor(
                        red: 1.0,
                        green: 0.995,
                        blue: 0.974,
                        alpha: 1
                    ).cgColor,
                    UIColor(
                        red: 0.948,
                        green: 0.942,
                        blue: 0.910,
                        alpha: 1
                    ).cgColor
                ] as CFArray,
                locations: [0, 1]
            )
            if let paperGradient {
                cg.drawLinearGradient(
                    paperGradient,
                    start: CGPoint(x: 0, y: 0),
                    end: CGPoint(x: outputSize.width, y: outputSize.height),
                    options: []
                )
            }

            let highlightGradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [
                    UIColor.white.withAlphaComponent(0.26).cgColor,
                    UIColor.white.withAlphaComponent(0.0).cgColor
                ] as CFArray,
                locations: [0, 1]
            )
            if let highlightGradient {
                cg.drawRadialGradient(
                    highlightGradient,
                    startCenter: CGPoint(x: 170, y: 110),
                    startRadius: 0,
                    endCenter: CGPoint(x: 170, y: 110),
                    endRadius: 940,
                    options: []
                )
            }

            addPaperTexture(context: context, size: outputSize)

            let lowerDensityRect = CGRect(
                x: 0,
                y: outputSize.height * 0.80,
                width: outputSize.width,
                height: outputSize.height * 0.20
            )
            let lowerDensityGradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [
                    UIColor.clear.cgColor,
                    UIColor.black.withAlphaComponent(0.018).cgColor,
                    UIColor.white.withAlphaComponent(0.12).cgColor
                ] as CFArray,
                locations: [0, 0.65, 1]
            )
            if let lowerDensityGradient {
                cg.drawLinearGradient(
                    lowerDensityGradient,
                    start: CGPoint(x: lowerDensityRect.midX, y: lowerDensityRect.minY),
                    end: CGPoint(x: lowerDensityRect.midX, y: lowerDensityRect.maxY),
                    options: []
                )
            }

            let fixed = image.picoFixedOrientation()
            let cropped = fixed.picoCroppedToAspectFill(of: photoRect.size) ?? fixed

            cg.saveGState()
            cg.addPath(photoPath.cgPath)
            cg.clip()
            cropped.draw(in: photoRect)

            UIColor(
                red: 1.0,
                green: 0.94,
                blue: 0.76,
                alpha: 0.025
            ).setFill()
            cg.fill(photoRect)
            cg.restoreGState()

            UIColor.black.withAlphaComponent(0.14).setStroke()
            cg.setLineWidth(2)
            cg.addPath(photoPath.cgPath)
            cg.strokePath()

            cg.restoreGState()

            UIColor.white.withAlphaComponent(0.72).setStroke()
            cg.setLineWidth(2.2)
            cg.addPath(paperPath.cgPath)
            cg.strokePath()

            let insetPaperPath = UIBezierPath(
                roundedRect: paperRect.insetBy(dx: 7, dy: 7),
                cornerRadius: 23
            )
            UIColor.black.withAlphaComponent(0.035).setStroke()
            cg.setLineWidth(1.1)
            cg.addPath(insetPaperPath.cgPath)
            cg.strokePath()
        }
    }

    private static func applyDisposableCameraLook(to image: UIImage) -> UIImage {
        let fixed = image.picoFixedOrientation()
        guard let inputImage = CIImage(image: fixed) else {
            return fixed
        }

        var outputImage = inputImage

        // V9では色調補正、暖色化、周辺減光、粒状感を全体的に弱め、
        // 元のカメラ映像を主体にしながら、ごく薄い使い捨てカメラ感だけを残す。
        let colorControls = CIFilter.colorControls()
        colorControls.inputImage = outputImage
        colorControls.saturation = 0.98
        colorControls.contrast = 1.025
        colorControls.brightness = 0.001
        outputImage = colorControls.outputImage ?? outputImage

        let temperature = CIFilter.temperatureAndTint()
        temperature.inputImage = outputImage
        temperature.neutral = CIVector(x: 6500, y: 0)
        temperature.targetNeutral = CIVector(x: 6425, y: 0.8)
        outputImage = temperature.outputImage ?? outputImage

        let highlightShadow = CIFilter.highlightShadowAdjust()
        highlightShadow.inputImage = outputImage
        highlightShadow.highlightAmount = 0.96
        highlightShadow.shadowAmount = 0.05
        outputImage = highlightShadow.outputImage ?? outputImage

        let vignette = CIFilter.vignette()
        vignette.inputImage = outputImage
        vignette.intensity = 0.07
        vignette.radius = Float(
            min(inputImage.extent.width, inputImage.extent.height) * 1.05
        )
        outputImage = vignette.outputImage ?? outputImage

        guard let rendered = disposableCameraContext.createCGImage(
            outputImage.cropped(to: inputImage.extent),
            from: inputImage.extent
        ) else {
            return fixed
        }

        let colorAdjusted = UIImage(
            cgImage: rendered,
            scale: fixed.scale,
            orientation: .up
        )
        return addSubtleDisposableCameraSurface(to: colorAdjusted)
    }

    private static func addSubtleDisposableCameraSurface(
        to image: UIImage
    ) -> UIImage {
        let size = image.size
        guard size.width > 1, size.height > 1 else { return image }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            let cg = context.cgContext
            image.draw(in: CGRect(origin: .zero, size: size))

            // 使い捨てカメラの直射フラッシュを連想させる、非常に弱い暖色の光だまり。
            let flashGradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [
                    UIColor(
                        red: 1.0,
                        green: 0.89,
                        blue: 0.68,
                        alpha: 0.018
                    ).cgColor,
                    UIColor.clear.cgColor
                ] as CFArray,
                locations: [0, 1]
            )
            if let flashGradient {
                cg.drawRadialGradient(
                    flashGradient,
                    startCenter: CGPoint(
                        x: size.width * 0.22,
                        y: size.height * 0.16
                    ),
                    startRadius: 0,
                    endCenter: CGPoint(
                        x: size.width * 0.22,
                        y: size.height * 0.16
                    ),
                    endRadius: max(size.width, size.height) * 0.72,
                    options: []
                )
            }

            cg.saveGState()
            cg.setBlendMode(.softLight)

            let dotCount = 900
            let baseDiameter = max(
                0.45,
                min(size.width, size.height) * 0.00024
            )

            for index in 0..<dotCount {
                let x = CGFloat((index * 149 + 37) % 4093) / 4093 * size.width
                let y = CGFloat((index * 233 + 71) % 4091) / 4091 * size.height
                let diameter = baseDiameter * CGFloat(0.75 + Double(index % 4) * 0.20)
                let alpha = CGFloat(0.004 + Double(index % 6) * 0.0012)

                if index.isMultiple(of: 3) {
                    UIColor.white.withAlphaComponent(alpha).setFill()
                } else {
                    UIColor.black.withAlphaComponent(alpha).setFill()
                }

                cg.fillEllipse(
                    in: CGRect(
                        x: x,
                        y: y,
                        width: diameter,
                        height: diameter
                    )
                )
            }

            cg.restoreGState()
        }
    }

    private static func drawTinyStepStamp(steps: Int, canvasSize: CGSize) {
        guard steps > 0 else { return }

        let text = "\(steps) steps"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(
                ofSize: max(20, canvasSize.width * 0.035),
                weight: .heavy
            ),
            .foregroundColor: UIColor.white.withAlphaComponent(0.82),
            .strokeColor: UIColor.black.withAlphaComponent(0.30),
            .strokeWidth: -2
        ]
        let size = text.size(withAttributes: attributes)
        let rect = CGRect(
            x: canvasSize.width - size.width - 34,
            y: canvasSize.height - size.height - 30,
            width: size.width,
            height: size.height
        )
        text.draw(in: rect, withAttributes: attributes)
    }

    private static func addPaperTexture(
        context: UIGraphicsImageRendererContext,
        size: CGSize
    ) {
        let cg = context.cgContext
        cg.saveGState()

        for index in 0..<3_400 {
            let x = CGFloat((index * 37 + 11) % Int(size.width))
            let y = CGFloat((index * 71 + 23) % Int(size.height))
            let diameter = CGFloat(0.7 + Double(index % 3) * 0.35)
            let alpha = CGFloat(0.010 + (Double(index % 8) * 0.0023))

            if index.isMultiple(of: 4) {
                UIColor.white.withAlphaComponent(alpha * 1.25).setFill()
            } else {
                UIColor.black.withAlphaComponent(alpha).setFill()
            }

            cg.fillEllipse(
                in: CGRect(
                    x: x,
                    y: y,
                    width: diameter,
                    height: diameter
                )
            )
        }

        cg.setLineCap(.round)
        for index in 0..<360 {
            let x = CGFloat((index * 89 + 17) % Int(size.width))
            let y = CGFloat((index * 53 + 29) % Int(size.height))
            let length = CGFloat(8 + (index % 5) * 5)
            let rise = CGFloat((index % 3) - 1) * 0.7

            UIColor.white.withAlphaComponent(0.038).setStroke()
            cg.setLineWidth(0.62)
            cg.move(to: CGPoint(x: x, y: y))
            cg.addLine(
                to: CGPoint(
                    x: min(size.width, x + length),
                    y: max(0, min(size.height, y + rise))
                )
            )
            cg.strokePath()
        }

        for index in 0..<260 {
            let x = CGFloat((index * 127 + 31) % Int(size.width))
            let y = CGFloat((index * 101 + 47) % Int(size.height))
            let length = CGFloat(5 + (index % 7) * 3)
            let fall = CGFloat((index % 5) - 2) * 0.48

            UIColor.black.withAlphaComponent(0.024).setStroke()
            cg.setLineWidth(0.42)
            cg.move(to: CGPoint(x: x, y: y))
            cg.addLine(
                to: CGPoint(
                    x: min(size.width, x + length),
                    y: max(0, min(size.height, y + fall))
                )
            )
            cg.strokePath()
        }

        cg.restoreGState()
    }
}

private struct PicoCameraPreviewView: UIViewRepresentable {
    typealias Snapshotter = CameraStyleView.Snapshotter

    enum Position {
        case front
        case back
    }

    let position: Position
    let isFlashEnabled: Bool
    let onSnapshotReady: (@escaping Snapshotter) -> Void

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView(position: position, isFlashEnabled: isFlashEnabled)
        view.isUserInteractionEnabled = false
        view.startRunning()

        DispatchQueue.main.async {
            onSnapshotReady { completion in
                view.capturePhoto(completion: completion)
            }
        }

        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {
        uiView.setFlashEnabled(isFlashEnabled)
        uiView.updatePreviewMirroring()
    }

    static func dismantleUIView(_ uiView: PreviewUIView, coordinator: ()) {
        uiView.stopRunning()
    }

    final class PreviewUIView: UIView, AVCapturePhotoCaptureDelegate {
        private let session = AVCaptureSession()
        private let previewLayer = AVCaptureVideoPreviewLayer()
        private let photoOutput = AVCapturePhotoOutput()
        private let sessionQueue = DispatchQueue(
            label: "com.memo.camera.session",
            qos: .userInitiated
        )
        private var photoCompletion: ((UIImage?) -> Void)?
        private let position: Position
        private var isFlashEnabled: Bool
        private var deviceHasFlash: Bool = false

        init(position: Position, isFlashEnabled: Bool) {
            self.position = position
            self.isFlashEnabled = isFlashEnabled
            super.init(frame: .zero)
            setupSession()
        }

        override init(frame: CGRect) {
            self.position = .back
            self.isFlashEnabled = false
            super.init(frame: frame)
            setupSession()
        }

        required init?(coder: NSCoder) {
            self.position = .back
            self.isFlashEnabled = false
            super.init(coder: coder)
            setupSession()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            previewLayer.frame = bounds
            updatePreviewMirroring()
        }

        private func setupSession() {
            previewLayer.session = session
            previewLayer.videoGravity = .resizeAspectFill
            layer.addSublayer(previewLayer)

            guard AVCaptureDevice.authorizationStatus(for: .video) != .denied else { return }

            guard
                let device = AVCaptureDevice.default(
                    .builtInWideAngleCamera,
                    for: .video,
                    position: position == .front ? .front : .back
                ),
                let input = try? AVCaptureDeviceInput(device: device),
                session.canAddInput(input)
            else {
                return
            }

            deviceHasFlash = device.hasFlash

            session.beginConfiguration()
            session.sessionPreset = .photo
            session.addInput(input)
            if session.canAddOutput(photoOutput) {
                session.addOutput(photoOutput)
            }
            session.commitConfiguration()

            updatePreviewMirroring()
        }

        func setFlashEnabled(_ isEnabled: Bool) {
            isFlashEnabled = isEnabled
        }

        func updatePreviewMirroring() {
            guard let connection = previewLayer.connection else { return }
            guard connection.isVideoMirroringSupported else { return }
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = position == .front
        }

        func startRunning() {
            sessionQueue.async { [weak self] in
                guard let self else { return }
                guard AVCaptureDevice.authorizationStatus(for: .video) != .denied else { return }
                if !session.isRunning {
                    session.startRunning()
                }
            }
        }

        func stopRunning() {
            sessionQueue.async { [weak self] in
                guard let self else { return }
                if session.isRunning {
                    session.stopRunning()
                }
            }
        }

        func capturePhoto(completion: @escaping (UIImage?) -> Void) {
            photoCompletion = completion
            let settings = AVCapturePhotoSettings()
            settings.flashMode = (isFlashEnabled && deviceHasFlash) ? .on : .off
            photoOutput.capturePhoto(with: settings, delegate: self)
        }

        func photoOutput(
            _ output: AVCapturePhotoOutput,
            didFinishProcessingPhoto photo: AVCapturePhoto,
            error: Error?
        ) {
            guard error == nil else {
                DispatchQueue.main.async {
                    self.photoCompletion?(nil)
                    self.photoCompletion = nil
                }
                return
            }

            let image: UIImage?
            if let data = photo.fileDataRepresentation(),
               let captured = UIImage(data: data) {
                if position == .front {
                    image = captured.picoMirroredHorizontally() ?? captured
                } else {
                    image = captured
                }
            } else {
                image = nil
            }

            DispatchQueue.main.async {
                self.photoCompletion?(image)
                self.photoCompletion = nil
            }
        }
    }
}

private extension UIImage {
    func picoFixedOrientation() -> UIImage {
        guard imageOrientation != .up else { return self }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }

    func picoMirroredHorizontally() -> UIImage? {
        let source = picoFixedOrientation()
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = source.scale
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: source.size, format: format)
        return renderer.image { context in
            context.cgContext.translateBy(x: source.size.width, y: 0)
            context.cgContext.scaleBy(x: -1, y: 1)
            source.draw(in: CGRect(origin: .zero, size: source.size))
        }
    }

    func picoCroppedToAspectFill(of targetSize: CGSize) -> UIImage? {
        guard let cgImage else { return nil }
        guard targetSize.width > 0, targetSize.height > 0 else { return nil }

        let imageWidth = CGFloat(cgImage.width)
        let imageHeight = CGFloat(cgImage.height)
        let targetAspect = targetSize.width / targetSize.height
        let imageAspect = imageWidth / imageHeight

        let cropRect: CGRect
        if imageAspect > targetAspect {
            let newWidth = imageHeight * targetAspect
            cropRect = CGRect(
                x: (imageWidth - newWidth) * 0.5,
                y: 0,
                width: newWidth,
                height: imageHeight
            )
        } else {
            let newHeight = imageWidth / targetAspect
            cropRect = CGRect(
                x: 0,
                y: (imageHeight - newHeight) * 0.5,
                width: imageWidth,
                height: newHeight
            )
        }

        guard let cropped = cgImage.cropping(to: cropRect.integral) else { return nil }
        return UIImage(cgImage: cropped, scale: scale, orientation: .up)
    }

    func picoPolaroidSceneImage() -> UIImage? {
        let source = picoFixedOrientation()
        guard let cgImage = source.cgImage else { return nil }

        let pixelWidth = CGFloat(cgImage.width)
        let pixelHeight = CGFloat(cgImage.height)
        guard pixelWidth > 0, pixelHeight > 0 else { return nil }

        let cropRect = CGRect(
            x: pixelWidth * (
                PicoPolaroidLayout.photoRect.minX / PicoPolaroidLayout.canvasSize.width
            ),
            y: pixelHeight * (
                PicoPolaroidLayout.photoRect.minY / PicoPolaroidLayout.canvasSize.height
            ),
            width: pixelWidth * (
                PicoPolaroidLayout.photoRect.width / PicoPolaroidLayout.canvasSize.width
            ),
            height: pixelHeight * (
                PicoPolaroidLayout.photoRect.height / PicoPolaroidLayout.canvasSize.height
            )
        ).integral.intersection(
            CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight)
        )

        guard cropRect.width > 1, cropRect.height > 1 else { return nil }
        guard let cropped = cgImage.cropping(to: cropRect) else { return nil }
        return UIImage(cgImage: cropped, scale: source.scale, orientation: .up)
    }

    func picoDownsampled(maxPixelDimension: CGFloat) -> UIImage {
        let fixed = picoFixedOrientation()
        guard maxPixelDimension > 1 else { return fixed }
        guard let cgImage = fixed.cgImage else { return fixed }

        let pixelWidth = CGFloat(cgImage.width)
        let pixelHeight = CGFloat(cgImage.height)
        let longest = max(pixelWidth, pixelHeight)
        guard longest > maxPixelDimension else { return fixed }

        let ratio = maxPixelDimension / longest
        let outputPixelSize = CGSize(
            width: max(1, floor(pixelWidth * ratio)),
            height: max(1, floor(pixelHeight * ratio))
        )
        let outputPointSize = CGSize(
            width: outputPixelSize.width,
            height: outputPixelSize.height
        )

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: outputPointSize, format: format)
        return renderer.image { _ in
            fixed.draw(in: CGRect(origin: .zero, size: outputPointSize))
        }
    }
}

private extension CGFloat {
    func interpolated(to target: CGFloat, progress: CGFloat) -> CGFloat {
        self + ((target - self) * progress)
    }

    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        if self < range.lowerBound {
            return range.lowerBound
        }
        if self > range.upperBound {
            return range.upperBound
        }
        return self
    }
}

#if DEBUG
private struct PhotoPrintComponentPreview: View {
    private let image: UIImage = {
        let size = CGSize(width: 800, height: 800)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor(red: 0.20, green: 0.48, blue: 0.72, alpha: 1).setFill()
            context.cgContext.fill(CGRect(origin: .zero, size: size))

            let text = "MeMo"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 120, weight: .heavy),
                .foregroundColor: UIColor.white
            ]
            let textSize = text.size(withAttributes: attributes)
            text.draw(
                at: CGPoint(
                    x: (size.width - textSize.width) * 0.5,
                    y: (size.height - textSize.height) * 0.5
                ),
                withAttributes: attributes
            )
        }
    }()

    var body: some View {
        ZStack {
            Color.gray.opacity(0.35).ignoresSafeArea()
            PolaroidPaperView(sceneImage: image)
                .frame(width: 260)
                .rotation3DEffect(
                    .degrees(22),
                    axis: (x: 1, y: 0, z: 0),
                    anchor: .top,
                    perspective: 0.35
                )
                .shadow(color: .black.opacity(0.28), radius: 16, x: 0, y: 12)
        }
    }
}

#Preview("Polaroid Paper") {
    PhotoPrintComponentPreview()
}
#endif
