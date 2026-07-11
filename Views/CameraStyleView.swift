//
//  CameraStyleView.swift
//  MeMo
//
//  Dynamic Island-connected camera printer animation.
//  PHOTO_PRINT_DYNAMIC_ISLAND_CLOSE_SINK_V18_CHARACTER_LABEL_SAFE_AREA_APPLIED.
//

import AVFoundation
import Combine
import CoreImage
import CoreImage.CIFilterBuiltins
import Metal
import PencilKit
import SwiftData
import SwiftUI
import UIKit

struct CameraStyleView: View {
  typealias Snapshotter = (@escaping (UIImage?) -> Void) -> Void
  typealias MetricValueProvider = () -> (steps: Int, activeKcal: Int, totalKcal: Int)

  enum Mode: String, Identifiable, CaseIterable, Equatable {
    case plain
    case ar
    var id: String { rawValue }
    var title: String { self == .plain ? "通常" : "AR" }
    var shortTitle: String { self == .plain ? "NORMAL" : "AR" }
  }

  private enum CameraPosition: Equatable { case front, back }

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
  @Environment(\.modelContext) private var modelContext

  @State private var mode: Mode
  @State private var cameraPosition: CameraPosition = .back
  @State private var isFlashOn = false
  @State private var takeBackgroundSnapshot: Snapshotter?
  @State private var lastPreviewSize: CGSize = .zero
  @State private var safeAreaInsets: UIEdgeInsets = .zero
  @State private var isClosing = false
  @State private var cameraRevealProgress: CGFloat = 0
  @State private var chromeRevealProgress: CGFloat = 0
  @State private var closingIslandSinkProgress: CGFloat = 0
  @State private var isPreviewFadingAfterCapture = false
  @State private var previewFadeOpacity: CGFloat = 1
  @State private var capturedPreviewSize: CGSize = .zero
  @State private var recentPhotos: [PicoPrintedPhoto] = []
  @State private var selectedPhoto: PicoPrintedPhoto?
  @State private var presentationTask: Task<Void, Never>?
  @State private var printPresentationTask: Task<Void, Never>?
  @State private var isPrintPresentationActive = false
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
    _mode = State(initialValue: .plain)
  }

  private var currentMetricValues: (steps: Int, activeKcal: Int, totalKcal: Int) {
    if let metricValueProvider {
      let values = metricValueProvider()
      let resolvedSteps = max(0, max(values.steps, values.totalKcal))
      return (resolvedSteps, 0, resolvedSteps)
    }
    let resolvedSteps = max(0, max(todaySteps, todayTotalKcal))
    return (resolvedSteps, 0, resolvedSteps)
  }

  private var cameraRotateEnabled: Bool { !printController.isBusy && !isClosing }

  private var backgroundRevealOpacity: CGFloat {
    (isPrintPresentationActive || printController.isBusy) ? 1 : max(0, min(1, chromeRevealProgress))
  }

  private var photoTrayRevealOpacity: CGFloat {
    (isPrintPresentationActive || printController.isBusy) ? 1 : max(0, min(1, chromeRevealProgress))
  }

  private var shaderAllowed: Bool {
    guard !accessibilityReduceMotion, !isLowPowerModeEnabled, !Self.isRunningForPreview else {
      return false
    }
    return PhotoPrintShaderSupport.isFunctionAvailable
  }

  var body: some View {
    GeometryReader { geometry in
      let panelLayout = cameraPanelLayout(in: geometry.size, safeTop: geometry.safeAreaInsets.top)
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
          Color.clear.frame(height: panelLayout.topMargin)

          cameraPanel(
            layout: panelLayout,
            printerLayout: printerLayout,
            screenSize: geometry.size
          )

          closeButtonRow
            .padding(.top, 12)
            .padding(.horizontal, 26)
            .opacity(chromeRevealProgress)
            .allowsHitTesting(chromeRevealProgress > 0.98 && !isClosing && !printController.isBusy)

          controlsArea
            .padding(.top, 20)
            .opacity(chromeRevealProgress)
            .allowsHitTesting(chromeRevealProgress > 0.98 && !isClosing && !printController.isBusy)

          Spacer(minLength: 22)

          photoTray
            .frame(height: max(230, geometry.size.height * 0.30))
            .padding(.horizontal, 18)
            .padding(.bottom, 18 + geometry.safeAreaInsets.bottom)
            .opacity(photoTrayRevealOpacity)
            .allowsHitTesting(chromeRevealProgress > 0.98 && !isClosing && !printController.isBusy)
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
            characterAssetName: characterAssetName,
            miniCharacterAssetName: "mini_person",
            onDismiss: { self.selectedPhoto = nil },
            onSave: { editedImage in updatePhoto(selectedPhoto, with: editedImage) },
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
      .onAppear(perform: prepareForPresentation)
      .onDisappear {
        presentationTask?.cancel()
        printPresentationTask?.cancel()
        printController.finishImmediately(completePendingPhoto: true)
      }
      .onChange(of: geometry.size) { _, _ in safeAreaInsets = Self.currentWindowSafeAreaInsets() }
      .onChange(of: mode) { _, _ in
        mode = .plain
        takeBackgroundSnapshot = nil
      }
      .onChange(of: cameraPosition) { _, _ in takeBackgroundSnapshot = nil }
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
          for: Notification.Name.NSProcessInfoPowerStateDidChange)
      ) { _ in
        isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
      }
      .onReceive(
        NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)
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
      withAnimation(.spring(response: 0.46, dampingFraction: 0.86)) { cameraRevealProgress = 1 }
      do { try await Task<Never, Never>.sleep(nanoseconds: 60_000_000) } catch { return }
      guard !Task.isCancelled, !isClosing else { return }
      withAnimation(.easeOut(duration: 0.14)) { chromeRevealProgress = 1 }
    }
  }

  private var backgroundBody: some View {
    LinearGradient(
      colors: [
        Color(red: 0.38, green: 0.39, blue: 0.41),
        Color(red: 0.27, green: 0.28, blue: 0.30),
        Color(red: 0.43, green: 0.44, blue: 0.46),
      ],
      startPoint: .top,
      endPoint: .bottom
    )
    .overlay(alignment: .top) {
      LinearGradient(colors: [.white.opacity(0.24), .clear], startPoint: .top, endPoint: .bottom)
        .frame(height: 44)
    }
    .overlay(alignment: .bottom) {
      LinearGradient(colors: [.clear, .black.opacity(0.24)], startPoint: .top, endPoint: .bottom)
        .frame(height: 64)
    }
    .ignoresSafeArea()
  }

  private func cameraPanelLayout(in screenSize: CGSize, safeTop: CGFloat) -> CameraPanelLayout {
    let isWideLayout = screenSize.width >= 700
    let horizontalMargin: CGFloat = isWideLayout ? 40 : 26
    let proposedWidth = screenSize.width - horizontalMargin * 2
    let expandedWidth =
      isWideLayout
      ? min(max(420, screenSize.width * 0.64), 570)
      : max(300, proposedWidth)
    let dynamicIslandHeight = max(38, min(54, safeTop + 2))
    let previewWidth = max(180, expandedWidth - dynamicIslandHeight * 2)
    let expandedHeight = previewWidth + dynamicIslandHeight * 2
    let compactWidth: CGFloat = 132
    let compactHeight: CGFloat = max(36, dynamicIslandHeight * 0.82)
    let progress = max(0, min(1, cameraRevealProgress))
    return CameraPanelLayout(
      width: compactWidth.interpolated(to: expandedWidth, progress: progress),
      height: compactHeight.interpolated(to: expandedHeight, progress: progress),
      corner: CGFloat(22).interpolated(to: 56, progress: progress),
      frameInset: dynamicIslandHeight,
      previewCorner: CGFloat(18).interpolated(to: 34, progress: progress),
      topMargin: max(4, safeTop * 0.10) + 6
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
    let targetWidth = min(
      max(isWideLayout ? 360 : 286, screenSize.width * (isWideLayout ? 0.52 : 0.76)),
      isWideLayout ? 470 : 360
    )
    let targetHeight = min(isWideLayout ? 92 : 78, max(70, screenSize.height * 0.105))
    let width = base.width.interpolated(to: targetWidth, progress: clamped)
    let height = base.height.interpolated(to: targetHeight, progress: clamped)
    return CameraPrinterLayout(
      width: width,
      height: height,
      corner: base.corner.interpolated(to: targetHeight * 0.48, progress: normalized),
      slotWidth: max(84, width - (isWideLayout ? 44 : 34)),
      slotGlobalY: base.topMargin + max(28, height - 4)
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
    let previewWidth = max(1, layout.width - effectiveFrameInset * 2)
    let previewHeight = max(1, layout.height - effectiveFrameInset * 2)
    let hasCapturedPreviewSize = capturedPreviewSize.width > 1 && capturedPreviewSize.height > 1
    let shouldFreezePreviewGeometry = isPreviewFadingAfterCapture && hasCapturedPreviewSize
    let renderedPreviewWidth =
      shouldFreezePreviewGeometry ? capturedPreviewSize.width : previewWidth
    let renderedPreviewHeight =
      shouldFreezePreviewGeometry ? capturedPreviewSize.height : previewHeight
    let renderedPreviewCorner = shouldFreezePreviewGeometry ? CGFloat(34) : layout.previewCorner
    let renderedPreviewInset = shouldFreezePreviewGeometry ? layout.frameInset : effectiveFrameInset
    let printerStrength = max(0, min(1, printController.printerProgress))
    let sinkProgress = max(0, min(1, closingIslandSinkProgress))
    let sinkScaleProgress = max(0, min(1, sinkProgress / 0.62))
    let sinkFadeProgress = max(0, min(1, (sinkProgress - 0.24) / 0.76))
    let exteriorFadeProgress = max(0, min(1, sinkProgress / 0.24))
    let exteriorVisibility = Double(1 - exteriorFadeProgress)
    let panelVisibility = Double(1 - sinkFadeProgress)
    let panelScale =
      (0.92 + max(cameraRevealProgress, printerStrength) * 0.08) * (1 - sinkScaleProgress * 0.28)

    return ZStack(alignment: .top) {
      PicoRaisedRoundedPanel(
        cornerRadius: printerLayout.corner,
        fill: .black,
        outerStrokeOpacity: 0.92 * exteriorVisibility,
        highlightOpacity: (0.16 + Double(printerStrength) * 0.05) * exteriorVisibility,
        shadowOpacity: (0.36 + Double(printerStrength) * 0.15) * exteriorVisibility,
        shadowRadius: (10 + printerStrength * 5) * (1 - sinkScaleProgress),
        shadowY: (7 + printerStrength * 4) * (1 - sinkScaleProgress)
      )
      .scaleEffect(panelScale, anchor: .center)

      if (cameraRevealProgress > 0.001 || isPreviewFadingAfterCapture) && !isClosing {
        cameraPreviewWindow(previewCorner: renderedPreviewCorner)
          .frame(width: renderedPreviewWidth, height: renderedPreviewHeight)
          .position(
            x: printerLayout.width * 0.5,
            y: renderedPreviewInset + renderedPreviewHeight * 0.5
          )
          .opacity(isPreviewFadingAfterCapture ? Double(previewFadeOpacity) : 1)
          .scaleEffect(isPreviewFadingAfterCapture ? 1 : panelScale, anchor: .center)
          .overlay {
            Color.black
              .opacity(Double(printerStrength) * 0.035)
              .clipShape(RoundedRectangle(cornerRadius: renderedPreviewCorner, style: .continuous))
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
      .onAppear { lastPreviewSize = proxy.size }
      .onChange(of: proxy.size) { _, newSize in lastPreviewSize = newSize }
    }
  }

  @ViewBuilder
  private var captureSurface: some View {
    PicoCameraPreviewView(
      position: cameraPosition == .front ? .front : .back,
      isFlashEnabled: isFlashOn
    ) { snapshotter in
      DispatchQueue.main.async { takeBackgroundSnapshot = snapshotter }
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
          foreground: isFlashOn ? .white.opacity(0.94) : .black.opacity(0.46),
          lineWidth: 0
        )
      }
      .buttonStyle(.plain)
      .disabled(printController.isBusy || isClosing)
      .opacity((printController.isBusy || isClosing) ? 0.42 : 1)
      .accessibilityLabel(isFlashOn ? "フラッシュON" : "フラッシュOFF")

      Button(action: captureAndPrint) {
        ZStack {
          Circle()
            .fill(Color.black.opacity(0.16))
            .frame(width: 104, height: 104)
            .shadow(color: .black.opacity(0.28), radius: 8, x: 0, y: 7)
          Circle()
            .fill(Color(red: 1, green: 0.60, blue: 0))
            .frame(width: 84, height: 84)
            .overlay(Circle().stroke(Color.black.opacity(0.78), lineWidth: 3))
            .shadow(color: .white.opacity(0.30), radius: 3, x: 0, y: -2)
        }
      }
      .buttonStyle(.plain)
      .disabled(printController.isBusy || takeBackgroundSnapshot == nil || isClosing)
      .opacity((printController.isBusy || takeBackgroundSnapshot == nil || isClosing) ? 0.58 : 1)
      .accessibilityLabel("撮影")
      .accessibilityHint(printController.isBusy ? "写真を処理中です" : "")

      Button {
        guard cameraRotateEnabled else { return }
        let next: CameraPosition = cameraPosition == .back ? .front : .back
        cameraPosition = next
        if next == .front { isFlashOn = false }
        takeBackgroundSnapshot = nil
      } label: {
        PicoRoundControlButton(
          systemImage: "arrow.triangle.2.circlepath.camera",
          size: 58,
          fill: Color(red: 0.30, green: 0.45, blue: 0.72).opacity(0.96),
          foreground: .white.opacity(0.94),
          lineWidth: 0
        )
      }
      .disabled(!cameraRotateEnabled)
      .opacity(cameraRotateEnabled ? 1 : 0.36)
      .accessibilityLabel("カメラ切り替え")
    }
  }

  private var topCloseButton: some View {
    Button(action: requestClose) {
      PicoRoundControlButton(
        systemImage: "xmark",
        size: 50,
        fill: Color(red: 0.16, green: 0.16, blue: 0.18).opacity(0.96),
        foreground: .white.opacity(0.94),
        lineWidth: 0
      )
    }
    .buttonStyle(.plain)
    .opacity((printController.isBusy || isClosing) ? 0.35 : 1)
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
                withAnimation(.easeOut(duration: 0.18)) { selectedPhoto = photo }
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
                  .shadow(color: .black.opacity(0.22), radius: 5, x: 0, y: 4)
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
    let validSize = CGSize(width: max(1, screenSize.width), height: max(1, screenSize.height))
    let photoWidth = min(
      validSize.width * (validSize.width >= 700 ? 0.46 : 0.64),
      validSize.width >= 700 ? 340 : 315
    )
    let useShader = shaderAllowed && printController.phase.allowsPaperShader
    let shouldMaskAtSlot = printController.phase.requiresSlotMask
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
          Color.clear.frame(height: max(0, slotY - frontOverlap))
          Rectangle().fill(.white)
        }
      } else {
        Rectangle().fill(.white)
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
      withAnimation(.easeInOut(duration: 0.12)) { chromeRevealProgress = 0 }
      do { try await Task<Never, Never>.sleep(nanoseconds: 60_000_000) } catch { return }
      guard !Task.isCancelled else { return }
      withAnimation(.easeInOut(duration: 0.30)) { cameraRevealProgress = 0 }
      do { try await Task<Never, Never>.sleep(nanoseconds: 300_000_000) } catch { return }
      guard !Task.isCancelled else { return }
      withAnimation(.easeInOut(duration: 0.20)) { closingIslandSinkProgress = 1 }
      do { try await Task<Never, Never>.sleep(nanoseconds: 220_000_000) } catch { return }
      guard !Task.isCancelled else { return }
      onCancel()
    }
  }

  private func captureAndPrint() {
    guard !isClosing,
      let takeBackgroundSnapshot,
      lastPreviewSize.width > 1,
      lastPreviewSize.height > 1,
      printController.beginCapture()
    else { return }

    let fixedPreviewSize = lastPreviewSize
    capturedPreviewSize = fixedPreviewSize
    let fixedMetrics = currentMetricValues

    takeBackgroundSnapshot { background in
      guard let background else {
        Task { @MainActor in printController.failCapture() }
        return
      }

      let normalizedBackground =
        background
        .picoFixedOrientation()
        .picoCroppedToAspectFill(of: fixedPreviewSize)
        ?? background.picoFixedOrientation()
      let composed = PicoCameraImageComposer.composeScene(
        background: normalizedBackground,
        previewSize: fixedPreviewSize,
        steps: fixedMetrics.steps
      )
      let finalPolaroid = PicoCameraImageComposer.makePolaroid(from: composed)
      let displayScene =
        finalPolaroid.picoPolaroidSceneImage()
        ?? composed.picoDownsampled(maxPixelDimension: 900)
      let photo = PicoPrintedPhoto(
        image: finalPolaroid,
        displaySceneImage: displayScene,
        date: Date()
      )
      let payload = PhotoPrintPayload(
        photo: photo,
        freezeImage: normalizedBackground.picoDownsampled(maxPixelDimension: 1_200),
        placeName: nil,
        latitude: nil,
        longitude: nil
      )
      Task { @MainActor in startPrintAnimation(payload: payload) }
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
      onInsertIntoTray: { insertPhotoIfNeeded($0) },
      onComplete: restoreCameraAfterPrint
    )
    guard didStage else { return }

    presentationTask?.cancel()
    printPresentationTask?.cancel()
    isPrintPresentationActive = true
    isPreviewFadingAfterCapture = true
    previewFadeOpacity = 1
    let collapseDuration = accessibilityReduceMotion ? 0.18 : 0.48
    let chromeDuration = accessibilityReduceMotion ? 0.08 : 0.16
    let settleNanoseconds: UInt64 = accessibilityReduceMotion ? 210_000_000 : 610_000_000

    printPresentationTask = Task { @MainActor in
      withAnimation(.easeInOut(duration: chromeDuration)) { chromeRevealProgress = 0 }
      do { try await Task<Never, Never>.sleep(nanoseconds: 70_000_000) } catch { return }
      guard !Task.isCancelled else { return }
      withAnimation(.easeOut(duration: collapseDuration * 0.82)) { previewFadeOpacity = 0 }
      withAnimation(
        .spring(response: collapseDuration, dampingFraction: accessibilityReduceMotion ? 1 : 0.90)
      ) {
        cameraRevealProgress = 0
      }
      do { try await Task<Never, Never>.sleep(nanoseconds: settleNanoseconds) } catch { return }
      guard !Task.isCancelled else { return }
      isPreviewFadingAfterCapture = false
      printController.startStagedAnimation(reduceMotion: accessibilityReduceMotion)
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
          dampingFraction: accessibilityReduceMotion ? 1 : 0.86
        )
      ) { cameraRevealProgress = 1 }
      do {
        try await Task<Never, Never>.sleep(
          nanoseconds: accessibilityReduceMotion ? 40_000_000 : 90_000_000
        )
      } catch { return }
      guard !Task.isCancelled else { return }
      withAnimation(.easeOut(duration: accessibilityReduceMotion ? 0.08 : 0.16)) {
        chromeRevealProgress = 1
      }
      do { try await Task<Never, Never>.sleep(nanoseconds: 180_000_000) } catch { return }
      guard !Task.isCancelled else { return }
      isPrintPresentationActive = false
      UIAccessibility.post(notification: .announcement, argument: "写真を撮影しました")
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
      if recentPhotos.count > 20 { recentPhotos = Array(recentPhotos.prefix(20)) }
    }
  }

  @MainActor
  private func updatePhoto(_ photo: PicoPrintedPhoto, with image: UIImage) {
    let normalized = image.picoFixedOrientation()
    let updated = PicoPrintedPhoto(
      id: photo.id,
      image: normalized,
      displaySceneImage: normalized.picoPolaroidSceneImage()
        ?? normalized.picoDownsampled(maxPixelDimension: 900),
      date: photo.date
    )
    if let index = recentPhotos.firstIndex(where: { $0.id == photo.id }) {
      recentPhotos[index] = updated
    }
    selectedPhoto = updated

    guard let entry = persistedEntry(nearestTo: photo.date) else { return }
    do {
      try TodayPhotoStorage.saveJPEG(normalized, fileName: entry.fileName, quality: 0.9)
      try modelContext.save()
    } catch {
      print("❌ update captured photo failed:", error)
    }
  }

  @MainActor
  private func deletePhoto(_ photo: PicoPrintedPhoto) {
    if let entry = persistedEntry(nearestTo: photo.date) {
      do {
        let url = try TodayPhotoStorage.fileURL(fileName: entry.fileName)
        if FileManager.default.fileExists(atPath: url.path) {
          try FileManager.default.removeItem(at: url)
        }
        modelContext.delete(entry)
        try modelContext.save()
      } catch {
        print("❌ delete captured photo failed:", error)
      }
    }

    withAnimation(.easeInOut(duration: 0.18)) {
      recentPhotos.removeAll { $0.id == photo.id }
      selectedPhoto = nil
    }
  }

  @MainActor
  private func persistedEntry(nearestTo date: Date) -> TodayPhotoEntry? {
    var descriptor = FetchDescriptor<TodayPhotoEntry>(
      sortBy: [SortDescriptor(\TodayPhotoEntry.date, order: .reverse)]
    )
    descriptor.fetchLimit = 60
    guard let entries = try? modelContext.fetch(descriptor) else { return nil }
    return
      entries
      .map { ($0, abs($0.date.timeIntervalSince(date))) }
      .filter { $0.1 <= 60 }
      .min { $0.1 < $1.1 }?
      .0
  }

  private static var isRunningForPreview: Bool {
    ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
  }

  private static func currentWindowSafeAreaInsets() -> UIEdgeInsets {
    let windowScene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
    let window = windowScene?.windows.first(where: { $0.isKeyWindow }) ?? windowScene?.windows.first
    return window?.safeAreaInsets ?? .zero
  }
}

private enum PhotoPrintPhase: Equatable {
  case idle, capturing, shutter, expandingPrinter, feeding, ejecting, releasing
  case settling, movingToTray, completed, retracting, cancelled, failed

  var isBusy: Bool {
    switch self {
    case .idle, .cancelled, .failed: return false
    default: return true
    }
  }

  var allowsPaperShader: Bool {
    switch self {
    case .feeding, .ejecting, .releasing, .settling: return true
    default: return false
    }
  }

  var requiresSlotMask: Bool {
    switch self {
    case .shutter, .expandingPrinter, .feeding, .ejecting, .releasing, .settling: return true
    default: return false
    }
  }

  var hasStartedEjection: Bool {
    switch self {
    case .feeding, .ejecting, .releasing, .settling, .movingToTray, .completed: return true
    default: return false
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
  @Published private(set) var shutterHapticTrigger = 0
  @Published private(set) var printerHapticTrigger = 0
  @Published private(set) var settleHapticTrigger = 0
  @Published private(set) var trayHapticTrigger = 0

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

  var isBusy: Bool { phase.isBusy }

  @MainActor
  func beginCapture() -> Bool {
    guard !phase.isBusy else { return false }
    cancelTasks()
    clearCompletionState()
    phase = .capturing
    flashOpacity = 0.94
    emitHaptic(.shutter)
    PhotoPrintMotorSoundDriver.shared.prepare()
    PhotoPrintUIKitHaptics.prepareFeedRattle()
    flashTask = Task { @MainActor [weak self] in
      await Task.yield()
      guard let self, !Task.isCancelled else { return }
      withAnimation(.easeOut(duration: 0.12)) { self.flashOpacity = 0 }
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
      do { try await Task<Never, Never>.sleep(nanoseconds: 180_000_000) } catch { return }
      self?.resetToIdle()
    }
  }

  @MainActor
  func finishImmediately(completePendingPhoto: Bool) {
    if completePendingPhoto { insertIntoTrayOnce() }
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
      ) { printerProgress = reduceMotion ? 1 : 1.03 }
      try await sleep(seconds: configuration.printerExpansionDuration * 0.72)
      try Task.checkCancellation()
      withAnimation(.easeOut(duration: configuration.printerExpansionDuration * 0.28)) {
        printerProgress = 1
      }

      phase = .feeding
      animationID = UUID()
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

      if !reduceMotion { try await playDeterministicPrinterVibration() }
      let vibrationBudget = reduceMotion ? 0 : 0.25
      phase = .ejecting
      try await sleep(seconds: max(0, configuration.feedingDuration - vibrationBudget))
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
      withAnimation(.spring(response: configuration.retractionDuration, dampingFraction: 0.88)) {
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
      stopAndClear(cancelled: true)
    } catch {
      stopAndClear(cancelled: false)
    }
  }

  @MainActor
  private func stopAndClear(cancelled: Bool) {
    stopFeedEffects()
    payload = nil
    stagedPayload = nil
    freezeImage = nil
    flashOpacity = 0
    printerShakeX = 0
    printerProgress = 0
    phase = cancelled ? .cancelled : .failed
    clearCompletionState()
    phase = .idle
  }

  @MainActor
  private func playDeterministicPrinterVibration() async throws {
    let values: [CGFloat] = [-0.9, 0.75, -0.62, 0.48, -0.34, 0.22, 0]
    for value in values {
      try Task.checkCancellation()
      withAnimation(.linear(duration: 0.035)) { printerShakeX = value }
      try await sleep(seconds: 0.035)
    }
  }

  @MainActor
  private func playFeedHapticRattle(duration: Double, reduceMotion: Bool) async throws {
    let totalDuration = max(0, duration)
    guard totalDuration > 0 else { return }
    let baseInterval = reduceMotion ? 0.072 : 0.038
    let intervalOffsets: [Double] = [0, -0.004, 0.003, -0.002, 0.005, -0.003, 0.002, -0.001]
    let intensityPattern: [CGFloat] =
      reduceMotion
      ? [0.36, 0.42, 0.38, 0.44]
      : [0.62, 0.76, 0.68, 0.82, 0.72, 0.88, 0.74, 0.80]
    var elapsed: Double = 0
    var index = 0
    while elapsed < totalDuration {
      try Task.checkCancellation()
      let progress = min(1, elapsed / max(0.001, totalDuration))
      let edgeEnvelope = min(1, min(progress / 0.08, (1 - progress) / 0.10))
      let baseIntensity = intensityPattern[index % intensityPattern.count]
      let intensity = min(1, max(0.30, baseIntensity * CGFloat(0.86 + 0.22 * edgeEnvelope)))
      PhotoPrintUIKitHaptics.playFeedRattlePulse(index: index, intensity: intensity)
      let interval = max(0.032, baseInterval + intervalOffsets[index % intervalOffsets.count])
      let actual = min(interval, totalDuration - elapsed)
      guard actual > 0 else { break }
      try await sleep(seconds: actual)
      elapsed += actual
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
    guard !didInsertIntoTray, let photo = payload?.photo ?? stagedPayload?.photo else { return }
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
    case .shutter: shutterHapticTrigger &+= 1
    case .printer: printerHapticTrigger &+= 1
    case .settle: settleHapticTrigger &+= 1
    case .tray: trayHapticTrigger &+= 1
    case .failure: break
    }
    if #available(iOS 17.0, *) { return }
    emitUIKitFallbackHaptic(event)
  }

  @MainActor
  private func emitUIKitFallbackHaptic(_ event: PhotoPrintHapticEvent) {
    PhotoPrintUIKitHaptics.play(event)
  }

  @MainActor
  private func sleep(seconds: Double) async throws {
    try await Task<Never, Never>.sleep(nanoseconds: UInt64(max(0, seconds) * 1_000_000_000))
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

private enum PhotoPrintHapticEvent { case shutter, printer, settle, tray, failure }

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
    let value = intensity.clamped(to: 0...1)
    if index.isMultiple(of: 4) {
      mediumGenerator.impactOccurred(intensity: min(1, value * 0.96))
      mediumGenerator.prepare()
    } else if index.isMultiple(of: 2) {
      lightGenerator.impactOccurred(intensity: min(1, value * 0.92))
      lightGenerator.prepare()
    } else {
      softGenerator.impactOccurred(intensity: min(1, value * 0.88))
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
    _ = audioData(duration: 1.55, reduceMotion: false)
    _ = audioData(duration: 0.44, reduceMotion: true)
  }

  func play(duration: Double, reduceMotion: Bool) {
    let resolvedDuration = max(0.08, duration)
    stopPlayerOnly()
    do { try activateAmbientAudioSession() } catch {
      log("audio session activation failed: \(error.localizedDescription)")
    }
    let data = audioData(duration: resolvedDuration, reduceMotion: reduceMotion)
    retainedAudioData = data
    do {
      let audioPlayer = try AVAudioPlayer(data: data)
      audioPlayer.numberOfLoops = 0
      audioPlayer.volume = reduceMotion ? 0.72 : 0.92
      audioPlayer.enableRate = false
      let prepared = audioPlayer.prepareToPlay()
      player = audioPlayer
      guard prepared, audioPlayer.play() else {
        log("AVAudioPlayer could not start")
        return
      }
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
    if player?.isPlaying == true { player?.stop() }
    player = nil
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
    try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
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
    } catch { log("audio session restoration failed: \(error.localizedDescription)") }
  }

  private func audioData(duration: Double, reduceMotion: Bool) -> Data {
    let durationMilliseconds = Int((duration * 1_000).rounded())
    let key = durationMilliseconds * 10 + (reduceMotion ? 1 : 0)
    if let cached = cachedAudioData[key] { return cached }
    let generated = makeMotorWAVData(duration: duration, reduceMotion: reduceMotion)
    cachedAudioData[key] = generated
    return generated
  }

  private func makeMotorWAVData(duration: Double, reduceMotion: Bool) -> Data {
    let sampleRate: UInt32 = 44_100
    let channelCount: UInt16 = 1
    let bitsPerSample: UInt16 = 16
    let frameCount = max(1, Int(Double(sampleRate) * duration))
    var pcmData = Data()
    pcmData.reserveCapacity(frameCount * 2)
    var motorPhase: Double = 0
    var whinePhase: Double = 0
    var upperWhinePhase: Double = 0
    var noiseState: UInt32 = 0x73A9_51C3
    let twoPi = Double.pi * 2
    let amplitude = reduceMotion ? 0.34 : 0.48

    for frame in 0..<frameCount {
      let time = Double(frame) / Double(sampleRate)
      let remaining = max(0, duration - time)
      let envelope = max(0, min(min(1, time / 0.045), min(1, remaining / 0.085)))
      let spinUp = 1 - exp(-time * 9.5)
      let flutter = sin(twoPi * 5.8 * time) * 3.2
      motorPhase += twoPi * (126 + 48 * spinUp + flutter) / Double(sampleRate)
      whinePhase += twoPi * (590 + 118 * spinUp + 14 * sin(twoPi * 1.9 * time)) / Double(sampleRate)
      upperWhinePhase +=
        twoPi * (1_120 + 90 * spinUp + 22 * sin(twoPi * 2.4 * time)) / Double(sampleRate)
      noiseState = noiseState &* 1_664_525 &+ 1_013_904_223
      let noise = Double(noiseState) / Double(UInt32.max) * 2 - 1
      let roller = 0.79 + 0.21 * sin(twoPi * 28 * time)
      let motor =
        0.50 * sin(motorPhase) + 0.20 * sin(motorPhase * 2.01) + 0.07 * sin(motorPhase * 3.98)
      let raw =
        (motor * roller + 0.22 * sin(whinePhase) + 0.075 * sin(upperWhinePhase) + noise * 0.052
          * roller) * amplitude * envelope
      let clipped = tanh(raw * 1.18) * 0.94
      appendLittleEndian(Int16(max(-1, min(1, clipped)) * Double(Int16.max)), to: &pcmData)
    }

    let dataSize = UInt32(pcmData.count)
    let byteRate = sampleRate * UInt32(channelCount) * UInt32(bitsPerSample / 8)
    let blockAlign = channelCount * (bitsPerSample / 8)
    var wavData = Data()
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

  private func appendLittleEndian<T: FixedWidthInteger>(_ value: T, to data: inout Data) {
    var value = value.littleEndian
    Swift.withUnsafeBytes(of: &value) { data.append(contentsOf: $0) }
  }

  private func log(_ message: String) {
    #if DEBUG
      print("[PhotoPrintMotorSound] \(message)")
    #endif
  }
}

private enum PhotoPrintUIKitHaptics {
  @MainActor static func prepareFeedRattle() { PhotoPrintFeedHapticDriver.shared.prepare() }
  @MainActor static func playFeedRattlePulse(index: Int, intensity: CGFloat) {
    PhotoPrintFeedHapticDriver.shared.pulse(index: index, intensity: intensity)
  }
  @MainActor static func play(_ event: PhotoPrintHapticEvent) {
    switch event {
    case .shutter: UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: 0.75)
    case .printer: UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.55)
    case .settle: UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.48)
    case .tray: UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.52)
    case .failure: UINotificationFeedbackGenerator().notificationOccurred(.error)
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
        .sensoryFeedback(.impact(weight: .medium, intensity: 0.75), trigger: shutterTrigger)
        .sensoryFeedback(.impact(weight: .light, intensity: 0.48), trigger: printerTrigger)
        .sensoryFeedback(.impact(weight: .light, intensity: 0.42), trigger: settleTrigger)
        .sensoryFeedback(.impact(weight: .medium, intensity: 0.48), trigger: trayTrigger)
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

  private var photoHeight: CGFloat { photoWidth / PolaroidPaperView.aspectRatio }

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

  private var photoHeight: CGFloat { photoWidth / PolaroidPaperView.aspectRatio }

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
          LinearKeyframe(0, duration: configuration.feedingDuration)
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

  private var photoHeight: CGFloat { photoWidth / PolaroidPaperView.aspectRatio }

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
      .shadow(color: .black.opacity(shadowOpacity), radius: shadowRadius, x: 0, y: shadowY)
      .position(
        x: screenSize.width * 0.5 + vibrationX,
        y: PhotoPrintGeometry.centerY(
          slotY: slotY,
          photoHeight: photoHeight,
          screenHeight: screenSize.height,
          progress: verticalProgress
        )
      )
      .task(id: trigger) { await runFallbackAnimation() }
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
      .timingCurve(0.16, 0.78, 0.20, 1.0, duration: configuration.feedingDuration)
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
      withAnimation(.linear(duration: vibrationDuration)) { vibrationX = value }
      try? await Task<Never, Never>.sleep(
        nanoseconds: UInt64(vibrationDuration * 1_000_000_000)
      )
    }

    let used = vibrationDuration * Double(vibrationValues.count)
    let remaining = max(0, configuration.feedingDuration - used)
    try? await Task<Never, Never>.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
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

  private var photoHeight: CGFloat { photoWidth / PolaroidPaperView.aspectRatio }

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
      .scaleEffect(0.62 + progress * 0.38, anchor: .top)
      .rotation3DEffect(
        .degrees(Double(8 * (1 - progress))),
        axis: (x: 1, y: 0, z: 0),
        anchor: .top,
        perspective: 0.08
      )
      .opacity(opacity)
      .shadow(
        color: .black.opacity(0.18 + Double(progress) * 0.08),
        radius: 6 + progress * 6,
        x: 0,
        y: 4 + progress * 5
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
    let startCenter = slotY - safeHeight * 0.56
    let additionalTravel = min(max(28, screenHeight * 0.065), 58)
    let travel = safeHeight * 1.06 + additionalTravel
    return startCenter + travel * progress
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
          colors: [.white.opacity(0.20), .clear, .black.opacity(0.05)],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
        .opacity(min(0.22, 0.04 + Double(abs(values.paperBend)) * 0.14))
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
      let sideInset =
        width * (PicoPolaroidLayout.photoRect.minX / PicoPolaroidLayout.canvasSize.width)
      let topInset =
        height * (PicoPolaroidLayout.photoRect.minY / PicoPolaroidLayout.canvasSize.height)
      let photoSide =
        width * (PicoPolaroidLayout.photoRect.width / PicoPolaroidLayout.canvasSize.width)
      let paperCorner = max(3, width * 0.022)
      let photoCorner = max(2, width * 0.014)
      let edgeWidth = max(0.65, width * 0.0024)
      let paperShape = RoundedRectangle(cornerRadius: paperCorner, style: .continuous)
      let photoShape = RoundedRectangle(cornerRadius: photoCorner, style: .continuous)

      ZStack(alignment: .topLeading) {
        paperShape
          .fill(
            LinearGradient(
              stops: [
                .init(color: Color(red: 0.995, green: 0.991, blue: 0.965), location: 0),
                .init(color: Color(red: 0.974, green: 0.968, blue: 0.938), location: 0.48),
                .init(color: Color(red: 0.935, green: 0.930, blue: 0.900), location: 1),
              ],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )

        RadialGradient(
          colors: [.white.opacity(0.34), .white.opacity(0.06), .clear],
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

        photoShape
          .fill(Color.black.opacity(0.16))
          .frame(width: photoSide, height: photoSide)
          .offset(x: sideInset, y: topInset + max(0.5, width * 0.002))
          .blur(radius: max(0.25, width * 0.0012))

        Image(uiImage: sceneImage)
          .resizable()
          .scaledToFill()
          .frame(width: photoSide, height: photoSide)
          .clipShape(photoShape)
          .overlay {
            LinearGradient(
              colors: [.white.opacity(0.095), .clear, .black.opacity(0.055)],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
            .blendMode(.softLight)
            .clipShape(photoShape)
          }
          .overlay {
            photoShape.strokeBorder(
              Color.black.opacity(0.16),
              lineWidth: max(0.5, width * 0.0014)
            )
          }
          .offset(x: sideInset, y: topInset)

        LinearGradient(
          stops: [
            .init(color: .clear, location: 0),
            .init(color: .black.opacity(0.018), location: 0.62),
            .init(color: .white.opacity(0.14), location: 1),
          ],
          startPoint: .top,
          endPoint: .bottom
        )
        .frame(height: height * 0.19)
        .frame(maxHeight: .infinity, alignment: .bottom)
        .clipShape(paperShape)
        .blendMode(.softLight)

        LinearGradient(
          colors: [.white.opacity(0.18), .clear, .black.opacity(0.035)],
          startPoint: .top,
          endPoint: .bottom
        )
        .clipShape(paperShape)
        .blendMode(.softLight)

        paperShape.strokeBorder(
          LinearGradient(
            colors: [.white.opacity(0.86), .white.opacity(0.24), .black.opacity(0.17)],
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

      for index in 0..<320 {
        let x = CGFloat((index * 47 + 19) % 997) / 997 * width
        let y = CGFloat((index * 83 + 31) % 991) / 991 * height
        let diameter = max(0.35, min(width, height) * CGFloat(0.0011 + Double(index % 3) * 0.00035))
        let opacity = 0.022 + Double(index % 6) * 0.0045
        context.fill(
          Path(ellipseIn: CGRect(x: x, y: y, width: diameter, height: diameter)),
          with: .color(.black.opacity(opacity))
        )
      }

      for index in 0..<96 {
        let x = CGFloat((index * 61 + 7) % 983) / 983 * width
        let y = CGFloat((index * 97 + 13) % 977) / 977 * height
        let length = width * CGFloat(0.018 + Double(index % 4) * 0.007)
        let rise = height * CGFloat(Double((index % 3) - 1) * 0.0012)
        var path = Path()
        path.move(to: CGPoint(x: x, y: y))
        path.addLine(to: CGPoint(x: min(width, x + length), y: max(0, min(height, y + rise))))
        context.stroke(
          path, with: .color(.white.opacity(0.075)), lineWidth: max(0.25, width * 0.00072))
      }

      for index in 0..<88 {
        let x = CGFloat((index * 109 + 23) % 971) / 971 * width
        let y = CGFloat((index * 71 + 41) % 967) / 967 * height
        let length = width * CGFloat(0.006 + Double(index % 5) * 0.0035)
        let fall = height * CGFloat(Double((index % 5) - 2) * 0.00055)
        var path = Path()
        path.move(to: CGPoint(x: x, y: y))
        path.addLine(to: CGPoint(x: min(width, x + length), y: max(0, min(height, y + fall))))
        context.stroke(
          path, with: .color(.black.opacity(0.032)), lineWidth: max(0.2, width * 0.00050))
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
    DispatchQueue.main.async { clearPresentationBackground(from: view) }
    return view
  }

  func updateUIView(_ uiView: UIView, context: Context) {
    DispatchQueue.main.async { clearPresentationBackground(from: uiView) }
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

  static func == (lhs: PicoPrintedPhoto, rhs: PicoPrintedPhoto) -> Bool { lhs.id == rhs.id }
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
            .stroke(.black.opacity(outerStrokeOpacity), lineWidth: 5)
            .padding(-3)
          RoundedRectangle(cornerRadius: cornerRadius + 5, style: .continuous)
            .stroke(.white.opacity(highlightOpacity), lineWidth: 1.2)
            .padding(-5)
            .offset(y: -1)
        }
        .allowsHitTesting(false)
      }
      .shadow(color: .black.opacity(shadowOpacity), radius: shadowRadius, x: 0, y: shadowY)
      .shadow(color: .white.opacity(highlightOpacity * 0.52), radius: 3, x: 0, y: -1)
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
        .fill(.black.opacity(0.16))
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.28), radius: 8, x: 0, y: 7)
      Circle()
        .fill(fill)
        .frame(width: size * 0.82, height: size * 0.82)
        .overlay(Circle().stroke(.black.opacity(0.72), lineWidth: max(2, lineWidth)))
        .overlay(Circle().stroke(.white.opacity(0.18), lineWidth: 1.2).padding(3))
        .shadow(color: .white.opacity(0.22), radius: 3, x: 0, y: -2)
      Image(systemName: systemImage)
        .font(.system(size: size * 0.31, weight: .heavy))
        .foregroundStyle(foreground)
    }
    .frame(width: size, height: size)
  }
}

private enum PicoCameraOverlaySafeArea {
  @MainActor
  static func topHeaderOffset(from reportedInset: CGFloat) -> CGFloat {
    let currentPadding = max(18, max(0, reportedInset) + 8)
    let resolvedPadding = max(18, currentWindowTopInset + 8)
    return max(0, resolvedPadding - currentPadding)
  }

  @MainActor
  private static var currentWindowTopInset: CGFloat {
    let scenes = UIApplication.shared.connectedScenes
    let windowScene = scenes.compactMap { $0 as? UIWindowScene }.first
    let window = windowScene?.windows.first(where: { $0.isKeyWindow })
      ?? windowScene?.windows.first
    return max(0, window?.safeAreaInsets.top ?? 0)
  }
}

private struct PicoPrintedPhotoDetailOverlay: View {
  let photo: PicoPrintedPhoto
  let characterAssetName: String
  let miniCharacterAssetName: String
  let onDismiss: () -> Void
  let onSave: (UIImage) -> Void
  let onDelete: () -> Void

  @State private var displayedImage: UIImage
  @State private var isEditing = false
  @State private var isShareDestinationPresented = false
  @State private var isActivityPresented = false
  @State private var activeAlert: DetailAlert?

  init(
    photo: PicoPrintedPhoto,
    characterAssetName: String,
    miniCharacterAssetName: String,
    onDismiss: @escaping () -> Void,
    onSave: @escaping (UIImage) -> Void,
    onDelete: @escaping () -> Void
  ) {
    self.photo = photo
    self.characterAssetName = characterAssetName
    self.miniCharacterAssetName = miniCharacterAssetName
    self.onDismiss = onDismiss
    self.onSave = onSave
    self.onDelete = onDelete
    _displayedImage = State(initialValue: photo.image)
  }

  private enum DetailAlert: String, Identifiable {
    case delete
    case instagramUnavailable
    var id: String { rawValue }
  }

  private var timeText: String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ja_JP")
    formatter.dateFormat = "HH:mm"
    return formatter.string(from: photo.date)
  }

  private var instagramSourceApplicationID: String {
    let infoDictionary = Bundle.main.infoDictionary ?? [:]

    for key in ["InstagramSourceApplicationID", "FacebookAppID"] {
      if let value = infoDictionary[key] as? String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
          return trimmed
        }
      }

      if let value = infoDictionary[key] as? NSNumber {
        return value.stringValue
      }
    }

    // 明示設定がない開発ビルドでも Stories 作成画面を要求できるよう、
    // 最後の手段としてアプリの Bundle ID を source_application に使用する。
    return Bundle.main.bundleIdentifier ?? "MeMo"
  }

  var body: some View {
    GeometryReader { geometry in
      ZStack {
        Color(red: 0.085, green: 0.078, blue: 0.088)
          .ignoresSafeArea()

        VStack(spacing: 0) {
          detailHeader(safeTop: geometry.safeAreaInsets.top)
            .offset(
              y: PicoCameraOverlaySafeArea.topHeaderOffset(
                from: geometry.safeAreaInsets.top
              )
            )

          Spacer(minLength: 20)

          Image(uiImage: displayedImage)
            .resizable()
            .scaledToFit()
            .frame(
              maxWidth: min(geometry.size.width - 32, 560),
              maxHeight: max(280, geometry.size.height * 0.65)
            )
            .shadow(color: .black.opacity(0.46), radius: 24, x: 0, y: 14)
            .accessibilityLabel("撮影したポラロイド写真")

          Spacer(minLength: 24)

          detailActionBar(bottomInset: geometry.safeAreaInsets.bottom)
        }
        .frame(width: geometry.size.width, height: geometry.size.height)

        if isEditing {
          PicoPhotoEditorOverlay(
            baseImage: displayedImage,
            characterAssetName: characterAssetName,
            miniCharacterAssetName: miniCharacterAssetName,
            onCancel: {
              withAnimation(.easeInOut(duration: 0.18)) {
                isEditing = false
              }
            },
            onSave: { editedImage in
              displayedImage = editedImage
              onSave(editedImage)
              withAnimation(.easeInOut(duration: 0.18)) {
                isEditing = false
              }
            }
          )
          .transition(.opacity.combined(with: .scale(scale: 0.985)))
          .zIndex(10)
        }
      }
      .ignoresSafeArea()
    }
    .confirmationDialog(
      "共有先を選択",
      isPresented: $isShareDestinationPresented,
      titleVisibility: .visible
    ) {
      Button("インスタグラム") { shareToInstagramStories() }
      Button("その他共有") { isActivityPresented = true }
      Button("キャンセル", role: .cancel) {}
    }
    .sheet(isPresented: $isActivityPresented) {
      PicoActivityView(activityItems: [displayedImage])
        .presentationDetents([.medium, .large])
    }
    .alert(item: $activeAlert) { alert in
      switch alert {
      case .delete:
        return Alert(
          title: Text("写真を削除しますか？"),
          message: Text("この操作は取り消せません。"),
          primaryButton: .destructive(Text("削除"), action: onDelete),
          secondaryButton: .cancel(Text("キャンセル"))
        )
      case .instagramUnavailable:
        return Alert(
          title: Text("Instagramを開けませんでした"),
          message: Text("Instagramがインストールされているか確認してください。"),
          dismissButton: .default(Text("OK"))
        )
      }
    }
    .accessibilityElement(children: .contain)
    .accessibilityLabel("写真詳細画面")
  }

  private func detailHeader(safeTop: CGFloat) -> some View {
    HStack(spacing: 12) {
      Button(action: onDismiss) {
        PicoDetailRoundButton(systemImage: "chevron.left")
      }
      .buttonStyle(.plain)
      .accessibilityLabel("戻る")

      Spacer(minLength: 8)

      VStack(spacing: 1) {
        Text("今日")
          .font(.system(size: 22, weight: .heavy, design: .rounded))
        Text(timeText)
          .font(.system(size: 18, weight: .bold, design: .rounded))
      }
      .foregroundStyle(.white)
      .frame(minWidth: 144)
      .padding(.horizontal, 22)
      .padding(.vertical, 8)
      .background(.white.opacity(0.055), in: Capsule())
      .overlay(Capsule().stroke(.white.opacity(0.20), lineWidth: 2))

      Spacer(minLength: 8)

      Color.clear.frame(width: 58, height: 58)
    }
    .padding(.horizontal, 22)
    .padding(.top, max(18, safeTop + 8))
  }

  private func detailActionBar(bottomInset: CGFloat) -> some View {
    HStack {
      Button {
        isShareDestinationPresented = true
      } label: {
        PicoDetailRoundButton(systemImage: "square.and.arrow.up")
      }
      .buttonStyle(.plain)
      .accessibilityLabel("共有")

      Spacer()

      Button {
        withAnimation(.easeInOut(duration: 0.18)) {
          isEditing = true
        }
      } label: {
        PicoDetailRoundButton(systemImage: "pencil.tip")
      }
      .buttonStyle(.plain)
      .accessibilityLabel("編集")

      Spacer()

      Button {
        activeAlert = .delete
      } label: {
        PicoDetailRoundButton(systemImage: "trash")
      }
      .buttonStyle(.plain)
      .accessibilityLabel("削除")
    }
    .padding(.horizontal, 32)
    .padding(.bottom, max(22, bottomInset + 14))
  }

  @MainActor
  private func shareToInstagramStories() {
    guard let stickerData = displayedImage.pngData() else {
      activeAlert = .instagramUnavailable
      return
    }

    var storiesURLComponents = URLComponents()
    storiesURLComponents.scheme = "instagram-stories"
    storiesURLComponents.host = "share"
    storiesURLComponents.queryItems = [
      URLQueryItem(
        name: "source_application",
        value: instagramSourceApplicationID
      )
    ]

    guard let storiesURL = storiesURLComponents.url else {
      activeAlert = .instagramUnavailable
      return
    }

    let pasteboardItem: [String: Any] = [
      "com.instagram.sharedSticker.stickerImage": stickerData,
      "com.instagram.sharedSticker.backgroundTopColor": "#181419",
      "com.instagram.sharedSticker.backgroundBottomColor": "#181419",
    ]

    UIPasteboard.general.setItems(
      [pasteboardItem],
      options: [.expirationDate: Date().addingTimeInterval(300)]
    )

    // Pasteboard の反映直後に遷移すると Instagram 側が素材を取得できず
    // ホームへフォールバックする場合があるため、短い猶予を置いて作成画面を開く。
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
      UIApplication.shared.open(storiesURL, options: [:]) { success in
        guard !success else { return }
        DispatchQueue.main.async {
          activeAlert = .instagramUnavailable
        }
      }
    }
  }
}

private struct PicoDetailRoundButton: View {
  let systemImage: String

  var body: some View {
    Image(systemName: systemImage)
      .font(.system(size: 23, weight: .semibold))
      .foregroundStyle(.white)
      .frame(width: 58, height: 58)
      .background(.white.opacity(0.052), in: Circle())
      .overlay(Circle().stroke(.white.opacity(0.20), lineWidth: 2))
      .contentShape(Circle())
  }
}

private struct PicoActivityView: UIViewControllerRepresentable {
  let activityItems: [Any]

  func makeUIViewController(context: Context) -> UIActivityViewController {
    UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
  }

  func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private enum PicoEditorInteractionMode {
  case draw
  case sticker
}

private enum PicoEditorStickerMode: Int, CaseIterable {
  case none
  case caredCharacter
  case miniCharacter

  var next: PicoEditorStickerMode {
    switch self {
    case .none: return .caredCharacter
    case .caredCharacter: return .miniCharacter
    case .miniCharacter: return .none
    }
  }

  var accessibilityLabel: String {
    switch self {
    case .none: return "お世話中のキャラクターを追加"
    case .caredCharacter: return "ミニキャラクターに変更"
    case .miniCharacter: return "イラストを消す"
    }
  }
}

private final class PicoPhotoEditorStore: NSObject, ObservableObject, PKCanvasViewDelegate {
  let canvasView = PKCanvasView()
  @Published private(set) var canUndo = false
  @Published private(set) var canRedo = false

  // PencilKit はダークモード時にインク色を外観へ適応させる場合があるため、
  // どの UITraitCollection でも常に同じ黒を返す固定色として定義する。
  private static let fineBlackColor = UIColor { _ in
    UIColor(
      red: 0,
      green: 0,
      blue: 0,
      alpha: 1
    )
  }

  override init() {
    super.init()
    canvasView.delegate = self
    canvasView.overrideUserInterfaceStyle = .light
    canvasView.tintColor = Self.fineBlackColor
    canvasView.backgroundColor = .clear
    canvasView.isOpaque = false
    canvasView.isScrollEnabled = false
    canvasView.drawingPolicy = .anyInput
    canvasView.tool = Self.makeFineBlackPen()
    canvasView.alwaysBounceVertical = false
    canvasView.alwaysBounceHorizontal = false
    refreshUndoState()
  }

  func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
    refreshUndoState()
  }

  func selectFineBlackPen() {
    enforceFixedBlackAppearance()
    canvasView.tool = Self.makeFineBlackPen()
    canvasView.becomeFirstResponder()
  }

  func enforceFixedBlackAppearance() {
    canvasView.overrideUserInterfaceStyle = .light
    canvasView.tintColor = Self.fineBlackColor
  }

  func undo() {
    canvasView.undoManager?.undo()
    refreshUndoState()
  }

  func redo() {
    canvasView.undoManager?.redo()
    refreshUndoState()
  }

  func clear() {
    canvasView.drawing = PKDrawing()
    refreshUndoState()
  }

  private static func makeFineBlackPen() -> PKInkingTool {
    PKInkingTool(
      .pen,
      color: fineBlackColor,
      width: 4.5
    )
  }

  private func refreshUndoState() {
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      canUndo = canvasView.undoManager?.canUndo ?? false
      canRedo = canvasView.undoManager?.canRedo ?? false
    }
  }
}

private struct PicoCanvasRepresentable: UIViewRepresentable {
  @ObservedObject var store: PicoPhotoEditorStore
  let onTap: (CGPoint) -> Void

  func makeCoordinator() -> Coordinator {
    Coordinator(onTap: onTap)
  }

  func makeUIView(context: Context) -> PKCanvasView {
    let canvasView = store.canvasView
    store.enforceFixedBlackAppearance()
    let tapRecognizer = UITapGestureRecognizer(
      target: context.coordinator,
      action: #selector(Coordinator.handleTap(_:))
    )
    tapRecognizer.cancelsTouchesInView = true
    tapRecognizer.delegate = context.coordinator
    canvasView.addGestureRecognizer(tapRecognizer)
    return canvasView
  }

  func updateUIView(_ uiView: PKCanvasView, context: Context) {
    store.enforceFixedBlackAppearance()
    uiView.backgroundColor = .clear
    uiView.isOpaque = false
    context.coordinator.onTap = onTap
  }

  final class Coordinator: NSObject, UIGestureRecognizerDelegate {
    var onTap: (CGPoint) -> Void

    init(onTap: @escaping (CGPoint) -> Void) {
      self.onTap = onTap
    }

    @objc
    func handleTap(_ recognizer: UITapGestureRecognizer) {
      guard let view = recognizer.view else { return }
      onTap(recognizer.location(in: view))
    }

    func gestureRecognizer(
      _ gestureRecognizer: UIGestureRecognizer,
      shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
      true
    }
  }
}

private struct PicoStickerControlHandle: View {
  let systemImage: String
  let counterRotation: Angle
  let isHorizontallyFlipped: Bool
  let accessibilityLabel: String
  let accessibilityHint: String

  var body: some View {
    ZStack {
      Circle()
        .fill(Color.black.opacity(0.88))
        .overlay(Circle().stroke(Color.white.opacity(0.95), lineWidth: 2))
        .shadow(color: .black.opacity(0.34), radius: 5, x: 0, y: 3)

      Image(systemName: systemImage)
        .font(.system(size: 17, weight: .bold))
        .foregroundStyle(.white)
        .scaleEffect(x: isHorizontallyFlipped ? -1 : 1, y: 1)
        .rotationEffect(counterRotation)
    }
    .frame(width: 44, height: 44)
    .contentShape(Circle())
    .accessibilityLabel(accessibilityLabel)
    .accessibilityHint(accessibilityHint)
  }
}

private struct PicoPhotoEditorOverlay: View {
  private static let editorSurfaceCoordinateSpace = "PicoPhotoEditorSurface"

  let baseImage: UIImage
  let characterAssetName: String
  let miniCharacterAssetName: String
  let onCancel: () -> Void
  let onSave: (UIImage) -> Void

  @StateObject private var editorStore = PicoPhotoEditorStore()
  @State private var stickerMode: PicoEditorStickerMode = .none
  @State private var interactionMode: PicoEditorInteractionMode = .draw
  @State private var stickerOffset: CGSize = .zero
  @State private var stickerScale: CGFloat = 1
  @State private var stickerRotation: Angle = .zero
  @State private var editorSurfaceSize: CGSize = .zero
  @State private var isStickerSelectionVisible = false
  @State private var resizeGestureStartScale: CGFloat?
  @State private var resizeGestureStartDistance: CGFloat?
  @State private var rotationHandleStartPointerAngle: Double?
  @State private var rotationHandleStartRotation: Angle?
  @State private var stickerDragStartOffset: CGSize?

  var body: some View {
    GeometryReader { geometry in
      let availableWidth = max(220, geometry.size.width - 28)
      let availableHeight = max(
        300,
        geometry.size.height - geometry.safeAreaInsets.top - geometry.safeAreaInsets.bottom - 210)
      let photoWidth = min(availableWidth, availableHeight * PicoPolaroidLayout.aspectRatio)
      let photoHeight = photoWidth / PicoPolaroidLayout.aspectRatio
      let surfaceSize = CGSize(width: photoWidth, height: photoHeight)

      ZStack {
        Color(red: 0.085, green: 0.078, blue: 0.088)
          .ignoresSafeArea()

        VStack(spacing: 0) {
          editorHeader(safeTop: geometry.safeAreaInsets.top, surfaceSize: surfaceSize)
            .offset(
              y: PicoCameraOverlaySafeArea.topHeaderOffset(
                from: geometry.safeAreaInsets.top
              )
            )

          Spacer(minLength: 18)

          editorSurface(size: surfaceSize)
            .shadow(color: .black.opacity(0.45), radius: 22, x: 0, y: 13)

          Spacer(minLength: 18)

          editorToolBar(bottomInset: geometry.safeAreaInsets.bottom)
        }
        .frame(width: geometry.size.width, height: geometry.size.height)
      }
      .onAppear {
        editorSurfaceSize = surfaceSize
        activateFineBlackPen()
      }
      .onChange(of: surfaceSize) { _, newSize in
        editorSurfaceSize = newSize
      }
    }
    .ignoresSafeArea()
    .accessibilityElement(children: .contain)
    .accessibilityLabel("写真編集画面")
  }

  private func editorHeader(safeTop: CGFloat, surfaceSize: CGSize) -> some View {
    HStack(spacing: 20) {
      Button(action: onCancel) {
        Image(systemName: "xmark")
          .font(.system(size: 25, weight: .medium))
          .foregroundStyle(.white)
          .frame(width: 58, height: 58)
          .background(.white.opacity(0.04), in: Circle())
          .overlay(Circle().stroke(.white.opacity(0.18), lineWidth: 2))
      }
      .buttonStyle(.plain)
      .accessibilityLabel("編集をキャンセル")

      HStack(spacing: 12) {
        Button {
          editorStore.undo()
        } label: {
          Image(systemName: "arrow.uturn.backward")
            .frame(width: 58, height: 50)
        }
        .disabled(!editorStore.canUndo)
        .accessibilityLabel("元に戻す")

        Button {
          editorStore.redo()
        } label: {
          Image(systemName: "arrow.uturn.forward")
            .frame(width: 58, height: 50)
        }
        .disabled(!editorStore.canRedo)
        .accessibilityLabel("やり直す")
      }
      .font(.system(size: 24, weight: .semibold))
      .foregroundStyle(.white)
      .buttonStyle(.plain)
      .background(.white.opacity(0.045), in: Capsule())
      .overlay(Capsule().stroke(.white.opacity(0.16), lineWidth: 2))

      Spacer()

      Button {
        guard let rendered = renderEditedImage(surfaceSize: surfaceSize) else { return }
        onSave(rendered)
      } label: {
        Image(systemName: "checkmark")
          .font(.system(size: 29, weight: .bold))
          .foregroundStyle(.white)
          .frame(width: 58, height: 58)
          .background(Color(red: 0.82, green: 0.35, blue: 0.10), in: Circle())
          .overlay(Circle().stroke(.white.opacity(0.20), lineWidth: 1.5))
      }
      .buttonStyle(.plain)
      .accessibilityLabel("編集を保存")
    }
    .padding(.horizontal, 22)
    .padding(.top, max(18, safeTop + 8))
  }

  private func editorSurface(size: CGSize) -> some View {
    ZStack {
      Image(uiImage: baseImage)
        .resizable()
        .scaledToFill()
        .frame(width: size.width, height: size.height)
        .clipped()
        .allowsHitTesting(false)

      if let stickerImage = currentStickerImage {
        let baseSize = stickerBaseSize(for: stickerImage, surfaceSize: size)
        let effectiveScale = stickerScale.clamped(to: 0.35...3.0)
        let effectiveRotation = stickerRotation
        let renderedSize = CGSize(
          width: baseSize.width * effectiveScale,
          height: baseSize.height * effectiveScale
        )

        ZStack {
          Image(uiImage: stickerImage)
            .resizable()
            .scaledToFit()
            .frame(width: renderedSize.width, height: renderedSize.height)
            .contentShape(Rectangle())
            .shadow(color: .black.opacity(0.18), radius: 5, x: 0, y: 3)
            .gesture(stickerDragGesture)
            .onTapGesture(perform: activateStickerSelection)

          if isStickerSelectionVisible {
            stickerSelectionChrome(
              renderedSize: renderedSize,
              effectiveRotation: effectiveRotation,
              surfaceSize: size
            )
          }
        }
        .frame(width: renderedSize.width, height: renderedSize.height)
        .rotationEffect(effectiveRotation)
        .position(stickerCenter(in: size))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("追加したキャラクターイラスト")
        .accessibilityHint(
          "ドラッグで位置を調整し、左右上部のボタンで角度とサイズを変更できます"
        )
      }

      PicoCanvasRepresentable(store: editorStore) { point in
        handleCanvasTap(at: point, surfaceSize: size)
      }
      .frame(width: size.width, height: size.height)
      .allowsHitTesting(interactionMode == .draw)
    }
    .frame(width: size.width, height: size.height)
    .coordinateSpace(name: Self.editorSurfaceCoordinateSpace)
    .clipShape(RoundedRectangle(cornerRadius: max(5, size.width * 0.022), style: .continuous))
    .contentShape(Rectangle())
  }

  private func stickerSelectionChrome(
    renderedSize: CGSize,
    effectiveRotation: Angle,
    surfaceSize: CGSize
  ) -> some View {
    let counterRotation = Angle(radians: -effectiveRotation.radians)
    let selectionShape = RoundedRectangle(cornerRadius: 7, style: .continuous)

    return ZStack {
      selectionShape
        .stroke(
          Color(red: 0.38, green: 0.76, blue: 1.0).opacity(0.95),
          style: StrokeStyle(
            lineWidth: 3.4,
            lineCap: .round,
            lineJoin: .round,
            dash: [7, 5]
          )
        )

      selectionShape
        .stroke(
          Color(red: 0.82, green: 0.94, blue: 1.0).opacity(0.88),
          style: StrokeStyle(
            lineWidth: 1.2,
            lineCap: .round,
            lineJoin: .round,
            dash: [7, 5]
          )
        )
    }
    .frame(width: renderedSize.width, height: renderedSize.height)
    .allowsHitTesting(false)
    .overlay(alignment: .topLeading) {
      PicoStickerControlHandle(
        systemImage: "arrow.clockwise",
        counterRotation: counterRotation,
        isHorizontallyFlipped: false,
        accessibilityLabel: "キャラクターの角度を調整",
        accessibilityHint: "押したまま指を動かすと角度を変更できます"
      )
      .offset(x: -22, y: -22)
      .highPriorityGesture(rotationHandleGesture(surfaceSize: surfaceSize))
      .allowsHitTesting(true)
    }
    .overlay(alignment: .topTrailing) {
      PicoStickerControlHandle(
        systemImage: "arrow.up.left.and.arrow.down.right",
        counterRotation: counterRotation,
        isHorizontallyFlipped: true,
        accessibilityLabel: "キャラクターのサイズを調整",
        accessibilityHint: "押したまま指を動かすとサイズを変更できます"
      )
      .offset(x: 22, y: -22)
      .highPriorityGesture(resizeHandleGesture(surfaceSize: surfaceSize))
      .allowsHitTesting(true)
    }
  }

  private func editorToolBar(bottomInset: CGFloat) -> some View {
    HStack(spacing: 42) {
      Button(action: activateFineBlackPen) {
        VStack(spacing: 5) {
          ZStack(alignment: .bottomTrailing) {
            Image(systemName: "pencil.tip")
              .font(.system(size: 26, weight: .semibold))

            Circle()
              .fill(Color.black)
              .frame(width: 11, height: 11)
              .overlay(Circle().stroke(Color.white.opacity(0.92), lineWidth: 1.2))
              .offset(x: 5, y: 4)
          }

          Text("細ペン")
            .font(.system(size: 11, weight: .bold))
        }
        .foregroundStyle(.white)
        .frame(width: 72, height: 72)
        .background(
          interactionMode == .draw
            ? Color(red: 0.82, green: 0.35, blue: 0.10).opacity(0.86)
            : .white.opacity(0.055),
          in: Circle()
        )
        .overlay(Circle().stroke(.white.opacity(0.18), lineWidth: 2))
      }
      .buttonStyle(.plain)
      .accessibilityLabel("細い黒ペン")

      Button {
        cycleSticker()
      } label: {
        VStack(spacing: 5) {
          Image(systemName: stickerMode == .miniCharacter ? "xmark.circle" : "photo.badge.plus")
            .font(.system(size: 26, weight: .semibold))
          Text(stickerButtonText)
            .font(.system(size: 11, weight: .bold))
        }
        .foregroundStyle(.white)
        .frame(width: 72, height: 72)
        .background(.white.opacity(0.055), in: Circle())
        .overlay(Circle().stroke(.white.opacity(0.18), lineWidth: 2))
      }
      .buttonStyle(.plain)
      .accessibilityLabel(stickerMode.accessibilityLabel)
    }
    .padding(.bottom, max(12, bottomInset + 8))
  }

  private var stickerButtonText: String {
    switch stickerMode {
    case .none: return "キャラ"
    case .caredCharacter: return "ミニキャラ"
    case .miniCharacter: return "消す"
    }
  }

  private var currentStickerImage: UIImage? {
    switch stickerMode {
    case .none:
      return nil
    case .caredCharacter:
      return UIImage(named: characterAssetName)
    case .miniCharacter:
      return UIImage(named: miniCharacterAssetName) ?? UIImage(named: characterAssetName)
    }
  }

  private var stickerDragGesture: some Gesture {
    DragGesture(
      minimumDistance: 0,
      coordinateSpace: .named(Self.editorSurfaceCoordinateSpace)
    )
    .onChanged { value in
      activateStickerSelection()

      // 移動対象自身の座標系で translation を計算すると、View が動くたびに
      // ジェスチャーの基準位置まで動いて小刻みに揺れる。固定された編集面の
      // 座標系とドラッグ開始時の offset を使い、指の移動量を一度だけ加算する。
      if stickerDragStartOffset == nil {
        stickerDragStartOffset = stickerOffset
      }

      let initialOffset = stickerDragStartOffset ?? stickerOffset
      stickerOffset = CGSize(
        width: initialOffset.width + value.translation.width,
        height: initialOffset.height + value.translation.height
      )
    }
    .onEnded { value in
      let initialOffset = stickerDragStartOffset ?? stickerOffset
      stickerOffset = CGSize(
        width: initialOffset.width + value.translation.width,
        height: initialOffset.height + value.translation.height
      )
      stickerDragStartOffset = nil
    }
  }

  private func resizeHandleGesture(surfaceSize: CGSize) -> some Gesture {
    DragGesture(
      minimumDistance: 0,
      coordinateSpace: .named(Self.editorSurfaceCoordinateSpace)
    )
    .onChanged { value in
      activateStickerSelection()

      let center = stickerCenter(in: surfaceSize)
      let startDistance = max(1, distance(from: center, to: value.startLocation))

      if resizeGestureStartScale == nil {
        resizeGestureStartScale = stickerScale
        resizeGestureStartDistance = startDistance
      }

      let initialScale = resizeGestureStartScale ?? stickerScale
      let initialDistance = max(1, resizeGestureStartDistance ?? startDistance)
      let currentDistance = max(1, distance(from: center, to: value.location))
      stickerScale = (initialScale * currentDistance / initialDistance).clamped(to: 0.35...3.0)
    }
    .onEnded { _ in
      resizeGestureStartScale = nil
      resizeGestureStartDistance = nil
    }
  }

  private func rotationHandleGesture(surfaceSize: CGSize) -> some Gesture {
    DragGesture(
      minimumDistance: 0,
      coordinateSpace: .named(Self.editorSurfaceCoordinateSpace)
    )
    .onChanged { value in
      activateStickerSelection()

      let center = stickerCenter(in: surfaceSize)
      let startPointerAngle = pointerAngle(from: center, to: value.startLocation)

      if rotationHandleStartPointerAngle == nil {
        rotationHandleStartPointerAngle = startPointerAngle
        rotationHandleStartRotation = stickerRotation
      }

      let initialPointerAngle = rotationHandleStartPointerAngle ?? startPointerAngle
      let initialRotation = rotationHandleStartRotation ?? stickerRotation
      let currentPointerAngle = pointerAngle(from: center, to: value.location)
      let delta = normalizedAngleDelta(currentPointerAngle - initialPointerAngle)
      stickerRotation = Angle(radians: initialRotation.radians + delta)
    }
    .onEnded { _ in
      rotationHandleStartPointerAngle = nil
      rotationHandleStartRotation = nil
    }
  }

  private func activateFineBlackPen() {
    interactionMode = .draw
    isStickerSelectionVisible = false
    editorStore.selectFineBlackPen()
  }

  private func activateStickerSelection() {
    guard stickerMode != .none else { return }
    interactionMode = .sticker
    isStickerSelectionVisible = true
  }

  private func handleCanvasTap(at point: CGPoint, surfaceSize: CGSize) {
    guard isPointInsideSticker(point, surfaceSize: surfaceSize) else { return }
    activateStickerSelection()
  }

  private func cycleSticker() {
    let previousMode = stickerMode
    let nextMode = previousMode.next
    stickerMode = nextMode

    switch nextMode {
    case .none:
      activateFineBlackPen()

    case .caredCharacter:
      if previousMode == .none {
        stickerOffset = .zero
        stickerScale = 1
        stickerRotation = .zero
      }
      activateStickerSelection()

    case .miniCharacter:
      activateStickerSelection()
    }
  }

  private func stickerBaseWidth(for surfaceSize: CGSize) -> CGFloat {
    min(170, max(96, surfaceSize.width * 0.34))
  }

  private func stickerBaseSize(for image: UIImage, surfaceSize: CGSize) -> CGSize {
    let width = stickerBaseWidth(for: surfaceSize)
    let aspect = max(0.15, image.size.height / max(1, image.size.width))
    return CGSize(width: width, height: width * aspect)
  }

  private func stickerCenter(in surfaceSize: CGSize) -> CGPoint {
    CGPoint(
      x: surfaceSize.width * 0.5 + stickerOffset.width,
      y: surfaceSize.height * 0.5 + stickerOffset.height
    )
  }

  private func isPointInsideSticker(_ point: CGPoint, surfaceSize: CGSize) -> Bool {
    guard let stickerImage = currentStickerImage else { return false }

    let baseSize = stickerBaseSize(for: stickerImage, surfaceSize: surfaceSize)
    let renderedWidth = baseSize.width * stickerScale
    let renderedHeight = baseSize.height * stickerScale
    let center = stickerCenter(in: surfaceSize)
    let radians = -stickerRotation.radians
    let deltaX = Double(point.x - center.x)
    let deltaY = Double(point.y - center.y)
    let localX = deltaX * cos(radians) - deltaY * sin(radians)
    let localY = deltaX * sin(radians) + deltaY * cos(radians)
    let hitPadding: CGFloat = 14

    return abs(localX) <= Double(renderedWidth * 0.5 + hitPadding)
      && abs(localY) <= Double(renderedHeight * 0.5 + hitPadding)
  }

  private func distance(from first: CGPoint, to second: CGPoint) -> CGFloat {
    hypot(second.x - first.x, second.y - first.y)
  }

  private func pointerAngle(from center: CGPoint, to point: CGPoint) -> Double {
    atan2(
      Double(point.y - center.y),
      Double(point.x - center.x)
    )
  }

  private func normalizedAngleDelta(_ radians: Double) -> Double {
    let fullTurn = Double.pi * 2
    var normalized = radians.truncatingRemainder(dividingBy: fullTurn)
    if normalized > Double.pi {
      normalized -= fullTurn
    } else if normalized < -Double.pi {
      normalized += fullTurn
    }
    return normalized
  }

  private func renderEditedImage(surfaceSize: CGSize) -> UIImage? {
    guard surfaceSize.width > 1, surfaceSize.height > 1 else { return nil }

    let source = baseImage.picoFixedOrientation()
    let outputSize = source.size
    guard outputSize.width > 1, outputSize.height > 1 else { return nil }

    let format = UIGraphicsImageRendererFormat.default()
    format.scale = 1
    format.opaque = false
    let renderer = UIGraphicsImageRenderer(size: outputSize, format: format)

    return renderer.image { rendererContext in
      source.draw(in: CGRect(origin: .zero, size: outputSize))

      if let stickerImage = currentStickerImage {
        let widthRatio = outputSize.width / surfaceSize.width
        let heightRatio = outputSize.height / surfaceSize.height
        let baseWidth = stickerBaseWidth(for: surfaceSize)
        let aspect = max(0.15, stickerImage.size.height / max(1, stickerImage.size.width))
        let baseHeight = baseWidth * aspect
        let renderedWidth = baseWidth * stickerScale * widthRatio
        let renderedHeight = baseHeight * stickerScale * heightRatio
        let center = CGPoint(
          x: (surfaceSize.width * 0.5 + stickerOffset.width) * widthRatio,
          y: (surfaceSize.height * 0.5 + stickerOffset.height) * heightRatio
        )

        let cg = rendererContext.cgContext
        cg.saveGState()
        cg.translateBy(x: center.x, y: center.y)
        cg.rotate(by: CGFloat(stickerRotation.radians))
        cg.interpolationQuality = .high
        stickerImage.draw(
          in: CGRect(
            x: -renderedWidth * 0.5,
            y: -renderedHeight * 0.5,
            width: renderedWidth,
            height: renderedHeight
          )
        )
        cg.restoreGState()
      }

      let drawingRect = CGRect(origin: .zero, size: surfaceSize)
      let drawingScale = max(
        outputSize.width / surfaceSize.width,
        outputSize.height / surfaceSize.height
      )
      // 保存時もライト外観を明示し、アプリのダークモード設定に関係なく
      // PencilKit の黒インクを黒のままラスタライズする。
      var drawingImage: UIImage?
      UITraitCollection(userInterfaceStyle: .light).performAsCurrent {
        drawingImage = editorStore.canvasView.drawing.image(
          from: drawingRect,
          scale: drawingScale
        )
      }
      drawingImage?.draw(in: CGRect(origin: .zero, size: outputSize))
    }
  }
}


private enum PicoCameraImageComposer {
  private static let disposableCameraContext = CIContext(
    options: [.cacheIntermediates: false]
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

      UIColor(red: 0.974, green: 0.968, blue: 0.936, alpha: 1).setFill()
      cg.fill(paperRect)

      if let paperGradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [
          UIColor(red: 1.0, green: 0.995, blue: 0.974, alpha: 1).cgColor,
          UIColor(red: 0.948, green: 0.942, blue: 0.910, alpha: 1).cgColor,
        ] as CFArray,
        locations: [0, 1]
      ) {
        cg.drawLinearGradient(
          paperGradient,
          start: .zero,
          end: CGPoint(x: outputSize.width, y: outputSize.height),
          options: []
        )
      }

      if let highlightGradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [
          UIColor.white.withAlphaComponent(0.26).cgColor,
          UIColor.white.withAlphaComponent(0).cgColor,
        ] as CFArray,
        locations: [0, 1]
      ) {
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

      if let lowerDensityGradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [
          UIColor.clear.cgColor,
          UIColor.black.withAlphaComponent(0.018).cgColor,
          UIColor.white.withAlphaComponent(0.12).cgColor,
        ] as CFArray,
        locations: [0, 0.65, 1]
      ) {
        let lowerStartY = outputSize.height * 0.80
        cg.drawLinearGradient(
          lowerDensityGradient,
          start: CGPoint(x: outputSize.width * 0.5, y: lowerStartY),
          end: CGPoint(x: outputSize.width * 0.5, y: outputSize.height),
          options: []
        )
      }

      let fixed = image.picoFixedOrientation()
      let cropped = fixed.picoCroppedToAspectFill(of: photoRect.size) ?? fixed
      cg.saveGState()
      cg.addPath(photoPath.cgPath)
      cg.clip()
      cropped.draw(in: photoRect)
      UIColor(red: 1.0, green: 0.94, blue: 0.76, alpha: 0.025).setFill()
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
    guard let inputImage = CIImage(image: fixed) else { return fixed }
    var outputImage = inputImage

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
    vignette.radius = Float(min(inputImage.extent.width, inputImage.extent.height) * 1.05)
    outputImage = vignette.outputImage ?? outputImage

    guard
      let rendered = disposableCameraContext.createCGImage(
        outputImage.cropped(to: inputImage.extent),
        from: inputImage.extent
      )
    else {
      return fixed
    }

    let adjusted = UIImage(cgImage: rendered, scale: fixed.scale, orientation: .up)
    return addSubtleDisposableCameraSurface(to: adjusted)
  }

  private static func addSubtleDisposableCameraSurface(to image: UIImage) -> UIImage {
    let size = image.size
    guard size.width > 1, size.height > 1 else { return image }
    let format = UIGraphicsImageRendererFormat.default()
    format.scale = image.scale
    format.opaque = true
    let renderer = UIGraphicsImageRenderer(size: size, format: format)

    return renderer.image { context in
      let cg = context.cgContext
      image.draw(in: CGRect(origin: .zero, size: size))

      if let flashGradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [
          UIColor(red: 1.0, green: 0.89, blue: 0.68, alpha: 0.018).cgColor,
          UIColor.clear.cgColor,
        ] as CFArray,
        locations: [0, 1]
      ) {
        let center = CGPoint(x: size.width * 0.22, y: size.height * 0.16)
        cg.drawRadialGradient(
          flashGradient,
          startCenter: center,
          startRadius: 0,
          endCenter: center,
          endRadius: max(size.width, size.height) * 0.72,
          options: []
        )
      }

      cg.saveGState()
      cg.setBlendMode(.softLight)
      let dotCount = 900
      let baseDiameter = max(0.45, min(size.width, size.height) * 0.00024)
      for index in 0..<dotCount {
        let x = CGFloat((index * 149 + 37) % 4093) / 4093 * size.width
        let y = CGFloat((index * 233 + 71) % 4091) / 4091 * size.height
        let diameter = baseDiameter * CGFloat(0.75 + Double(index % 4) * 0.20)
        let alpha = CGFloat(0.004 + Double(index % 6) * 0.0012)
        (index.isMultiple(of: 3)
          ? UIColor.white.withAlphaComponent(alpha)
          : UIColor.black.withAlphaComponent(alpha)).setFill()
        cg.fillEllipse(in: CGRect(x: x, y: y, width: diameter, height: diameter))
      }
      cg.restoreGState()
    }
  }

  private static func drawTinyStepStamp(steps: Int, canvasSize: CGSize) {
    guard steps > 0 else { return }
    let text = "\(steps) steps"
    let attributes: [NSAttributedString.Key: Any] = [
      .font: UIFont.systemFont(ofSize: max(20, canvasSize.width * 0.035), weight: .heavy),
      .foregroundColor: UIColor.white.withAlphaComponent(0.82),
      .strokeColor: UIColor.black.withAlphaComponent(0.30),
      .strokeWidth: -2,
    ]
    let textSize = text.size(withAttributes: attributes)
    text.draw(
      in: CGRect(
        x: canvasSize.width - textSize.width - 34,
        y: canvasSize.height - textSize.height - 30,
        width: textSize.width,
        height: textSize.height
      ),
      withAttributes: attributes
    )
  }

  private static func addPaperTexture(
    context: UIGraphicsImageRendererContext,
    size: CGSize
  ) {
    let cg = context.cgContext
    cg.saveGState()

    for index in 0..<3_400 {
      let x = CGFloat((index * 37 + 11) % max(1, Int(size.width)))
      let y = CGFloat((index * 71 + 23) % max(1, Int(size.height)))
      let diameter = CGFloat(0.7 + Double(index % 3) * 0.35)
      let alpha = CGFloat(0.010 + Double(index % 8) * 0.0023)
      (index.isMultiple(of: 4)
        ? UIColor.white.withAlphaComponent(alpha * 1.25)
        : UIColor.black.withAlphaComponent(alpha)).setFill()
      cg.fillEllipse(in: CGRect(x: x, y: y, width: diameter, height: diameter))
    }

    cg.setLineCap(.round)
    for index in 0..<360 {
      let x = CGFloat((index * 89 + 17) % max(1, Int(size.width)))
      let y = CGFloat((index * 53 + 29) % max(1, Int(size.height)))
      let length = CGFloat(8 + (index % 5) * 5)
      let rise = CGFloat((index % 3) - 1) * 0.7
      UIColor.white.withAlphaComponent(0.038).setStroke()
      cg.setLineWidth(0.62)
      cg.move(to: CGPoint(x: x, y: y))
      cg.addLine(to: CGPoint(x: min(size.width, x + length), y: max(0, min(size.height, y + rise))))
      cg.strokePath()
    }

    for index in 0..<260 {
      let x = CGFloat((index * 127 + 31) % max(1, Int(size.width)))
      let y = CGFloat((index * 101 + 47) % max(1, Int(size.height)))
      let length = CGFloat(5 + (index % 7) * 3)
      let fall = CGFloat((index % 5) - 2) * 0.48
      UIColor.black.withAlphaComponent(0.024).setStroke()
      cg.setLineWidth(0.42)
      cg.move(to: CGPoint(x: x, y: y))
      cg.addLine(to: CGPoint(x: min(size.width, x + length), y: max(0, min(size.height, y + fall))))
      cg.strokePath()
    }
    cg.restoreGState()
  }
}

private struct PicoCameraPreviewView: UIViewRepresentable {
  typealias Snapshotter = CameraStyleView.Snapshotter

  enum Position { case front, back }

  let position: Position
  let isFlashEnabled: Bool
  let onSnapshotReady: (@escaping Snapshotter) -> Void

  func makeUIView(context: Context) -> PreviewUIView {
    let view = PreviewUIView(position: position, isFlashEnabled: isFlashEnabled)
    view.isUserInteractionEnabled = false
    view.startRunning()
    DispatchQueue.main.async {
      onSnapshotReady { completion in view.capturePhoto(completion: completion) }
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
    private let sessionQueue = DispatchQueue(label: "com.memo.camera.session", qos: .userInitiated)
    private var photoCompletion: ((UIImage?) -> Void)?
    private let position: Position
    private var isFlashEnabled: Bool
    private var deviceHasFlash = false

    init(position: Position, isFlashEnabled: Bool) {
      self.position = position
      self.isFlashEnabled = isFlashEnabled
      super.init(frame: .zero)
      setupSession()
    }

    override init(frame: CGRect) {
      position = .back
      isFlashEnabled = false
      super.init(frame: frame)
      setupSession()
    }

    required init?(coder: NSCoder) {
      position = .back
      isFlashEnabled = false
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
      if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }
      session.commitConfiguration()
      updatePreviewMirroring()
    }

    func setFlashEnabled(_ isEnabled: Bool) {
      isFlashEnabled = isEnabled
    }

    func updatePreviewMirroring() {
      guard let connection = previewLayer.connection, connection.isVideoMirroringSupported else {
        return
      }
      connection.automaticallyAdjustsVideoMirroring = false
      connection.isVideoMirrored = position == .front
    }

    func startRunning() {
      sessionQueue.async { [weak self] in
        guard let self, AVCaptureDevice.authorizationStatus(for: .video) != .denied else { return }
        if !session.isRunning { session.startRunning() }
      }
    }

    func stopRunning() {
      sessionQueue.async { [weak self] in
        guard let self else { return }
        if session.isRunning { session.stopRunning() }
      }
    }

    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
      photoCompletion = completion
      let settings = AVCapturePhotoSettings()
      settings.flashMode = isFlashEnabled && deviceHasFlash ? .on : .off
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
      if let data = photo.fileDataRepresentation(), let captured = UIImage(data: data) {
        image = position == .front ? (captured.picoMirroredHorizontally() ?? captured) : captured
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

extension UIImage {
  fileprivate func picoFixedOrientation() -> UIImage {
    guard imageOrientation != .up else { return self }
    let format = UIGraphicsImageRendererFormat.default()
    format.scale = scale
    format.opaque = false
    return UIGraphicsImageRenderer(size: size, format: format).image { _ in
      draw(in: CGRect(origin: .zero, size: size))
    }
  }

  fileprivate func picoMirroredHorizontally() -> UIImage? {
    let source = picoFixedOrientation()
    let format = UIGraphicsImageRendererFormat.default()
    format.scale = source.scale
    format.opaque = true
    return UIGraphicsImageRenderer(size: source.size, format: format).image { context in
      context.cgContext.translateBy(x: source.size.width, y: 0)
      context.cgContext.scaleBy(x: -1, y: 1)
      source.draw(in: CGRect(origin: .zero, size: source.size))
    }
  }

  fileprivate func picoCroppedToAspectFill(of targetSize: CGSize) -> UIImage? {
    guard let cgImage, targetSize.width > 0, targetSize.height > 0 else { return nil }
    let imageWidth = CGFloat(cgImage.width)
    let imageHeight = CGFloat(cgImage.height)
    let targetAspect = targetSize.width / targetSize.height
    let imageAspect = imageWidth / imageHeight
    let cropRect: CGRect

    if imageAspect > targetAspect {
      let newWidth = imageHeight * targetAspect
      cropRect = CGRect(
        x: (imageWidth - newWidth) * 0.5, y: 0, width: newWidth, height: imageHeight)
    } else {
      let newHeight = imageWidth / targetAspect
      cropRect = CGRect(
        x: 0, y: (imageHeight - newHeight) * 0.5, width: imageWidth, height: newHeight)
    }

    guard let cropped = cgImage.cropping(to: cropRect.integral) else { return nil }
    return UIImage(cgImage: cropped, scale: scale, orientation: .up)
  }

  fileprivate func picoPolaroidSceneImage() -> UIImage? {
    let source = picoFixedOrientation()
    guard let cgImage = source.cgImage else { return nil }
    let pixelWidth = CGFloat(cgImage.width)
    let pixelHeight = CGFloat(cgImage.height)
    guard pixelWidth > 0, pixelHeight > 0 else { return nil }

    let cropRect = CGRect(
      x: pixelWidth * (PicoPolaroidLayout.photoRect.minX / PicoPolaroidLayout.canvasSize.width),
      y: pixelHeight * (PicoPolaroidLayout.photoRect.minY / PicoPolaroidLayout.canvasSize.height),
      width: pixelWidth
        * (PicoPolaroidLayout.photoRect.width / PicoPolaroidLayout.canvasSize.width),
      height: pixelHeight
        * (PicoPolaroidLayout.photoRect.height / PicoPolaroidLayout.canvasSize.height)
    )
    .integral
    .intersection(CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))

    guard cropRect.width > 1, cropRect.height > 1, let cropped = cgImage.cropping(to: cropRect)
    else { return nil }
    return UIImage(cgImage: cropped, scale: source.scale, orientation: .up)
  }

  fileprivate func picoDownsampled(maxPixelDimension: CGFloat) -> UIImage {
    let fixed = picoFixedOrientation()
    guard maxPixelDimension > 1, let cgImage = fixed.cgImage else { return fixed }
    let pixelWidth = CGFloat(cgImage.width)
    let pixelHeight = CGFloat(cgImage.height)
    let longest = max(pixelWidth, pixelHeight)
    guard longest > maxPixelDimension else { return fixed }
    let ratio = maxPixelDimension / longest
    let outputSize = CGSize(
      width: max(1, floor(pixelWidth * ratio)),
      height: max(1, floor(pixelHeight * ratio))
    )
    let format = UIGraphicsImageRendererFormat.default()
    format.scale = 1
    format.opaque = true
    return UIGraphicsImageRenderer(size: outputSize, format: format).image { _ in
      fixed.draw(in: CGRect(origin: .zero, size: outputSize))
    }
  }
}

extension CGFloat {
  fileprivate func interpolated(to target: CGFloat, progress: CGFloat) -> CGFloat {
    self + (target - self) * progress
  }

  fileprivate func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
    Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
  }
}

#if DEBUG
  private struct PhotoPrintComponentPreview: View {
    private let image: UIImage = {
      let size = CGSize(width: 800, height: 800)
      return UIGraphicsImageRenderer(size: size).image { context in
        UIColor(red: 0.20, green: 0.48, blue: 0.72, alpha: 1).setFill()
        context.cgContext.fill(CGRect(origin: .zero, size: size))
        let text = "MeMo"
        let attributes: [NSAttributedString.Key: Any] = [
          .font: UIFont.systemFont(ofSize: 120, weight: .heavy),
          .foregroundColor: UIColor.white,
        ]
        let textSize = text.size(withAttributes: attributes)
        text.draw(
          at: CGPoint(
            x: (size.width - textSize.width) * 0.5, y: (size.height - textSize.height) * 0.5),
          withAttributes: attributes
        )
      }
    }()

    var body: some View {
      ZStack {
        Color.gray.opacity(0.35).ignoresSafeArea()
        PolaroidPaperView(sceneImage: image)
          .frame(width: 260)
          .shadow(color: .black.opacity(0.28), radius: 16, x: 0, y: 12)
      }
    }
  }

  #Preview("Polaroid Paper") {
    PhotoPrintComponentPreview()
  }
#endif
