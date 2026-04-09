//
//  RouteCameraCaptureView.swift
//  MeMo
//
//  Created by shota suzuki on 2026/04/09.
//

import SwiftUI
import UIKit
import AVFoundation
import ARKit
import RealityKit

struct MemoRouteCameraCaptureView: View {
    typealias Snapshotter = (@escaping (UIImage?) -> Void) -> Void

    enum Mode: String, Identifiable, CaseIterable {
        case ar
        case plain

        var id: String { rawValue }

        var title: String {
            switch self {
            case .ar:
                return "AR"
            case .plain:
                return "通常"
            }
        }
    }

    enum RouteLineColorStyle: Equatable {
        case white
        case black

        var toggled: RouteLineColorStyle {
            self == .white ? .black : .white
        }

        var systemImage: String {
            "circle.lefthalf.filled"
        }

        var swiftUIColor: Color {
            self == .white ? .white : .black
        }
    }

    private enum CameraPosition {
        case front
        case back
    }

    let initialMode: Mode
    let plainBackgroundAssetName: String
    let characterAssetName: String
    let routePoints: [WorkoutRoutePoint]
    let onCancel: () -> Void
    let onCapture: (UIImage) -> Void

    @State private var mode: Mode
    @State private var characterOffset: CGSize = .zero
    @State private var characterScale: CGFloat = 1.0
    @State private var lastOffset: CGSize = .zero
    @State private var lastScale: CGFloat = 1.0
    @State private var sliderScale: Double = 1.0

    @State private var routeLineColorStyle: RouteLineColorStyle = .white
    @State private var routeOverlayPlacement: WorkoutRouteOverlayPlacement = .center
    @State private var isAlternatePoseEnabled: Bool = false
    @State private var cameraPosition: CameraPosition = .back

    @State private var lastViewSize: CGSize = .zero
    @State private var takeBackgroundSnapshot: Snapshotter?
    @State private var isCapturing: Bool = false

    @State private var windowSafeTop: CGFloat = 0
    @State private var windowSafeBottom: CGFloat = 0
    @State private var windowSafeTrailing: CGFloat = 0

    init(
        initialMode: Mode = .plain,
        plainBackgroundAssetName: String,
        characterAssetName: String,
        routePoints: [WorkoutRoutePoint],
        onCancel: @escaping () -> Void,
        onCapture: @escaping (UIImage) -> Void
    ) {
        self.initialMode = initialMode
        self.plainBackgroundAssetName = plainBackgroundAssetName
        self.characterAssetName = characterAssetName
        self.routePoints = routePoints
        self.onCancel = onCancel
        self.onCapture = onCapture
        _mode = State(initialValue: initialMode)
    }

    private var alternateCharacterAssetName: String {
        "\(characterAssetName)_tap_0002"
    }

    private var canUseAlternatePose: Bool {
        UIImage(named: alternateCharacterAssetName) != nil
    }

    private var displayedCharacterAssetName: String {
        if isAlternatePoseEnabled && canUseAlternatePose {
            return alternateCharacterAssetName
        }
        return characterAssetName
    }

    private var poseToggleSystemImage: String {
        isAlternatePoseEnabled ? "figure.wave" : "figure.stand"
    }

    var body: some View {
        GeometryReader { geometry in
            let characterWidth = min(geometry.size.width * 0.45, 220)

            ZStack {
                Color.black.ignoresSafeArea()

                backgroundContainer
                    .onAppear {
                        lastViewSize = geometry.size
                        updateWindowSafeArea()
                    }
                    .onChange(of: geometry.size) { _, newValue in
                        lastViewSize = newValue
                        updateWindowSafeArea()
                    }

                if !routePoints.isEmpty {
                    WorkoutRouteLineOverlayView(
                        points: routePoints,
                        strokeColor: routeLineColorStyle.swiftUIColor,
                        placement: routeOverlayPlacement
                    )
                    .allowsHitTesting(false)
                    .zIndex(8)
                }

                Image(displayedCharacterAssetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: characterWidth)
                    .scaleEffect(characterScale)
                    .offset(characterOffset)
                    .gesture(characterGesture)
                    .zIndex(10)
            }
            .ignoresSafeArea()
            .overlay(alignment: .top) {
                topBar
                    .padding(.top, windowSafeTop + 8)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }
            .overlay(alignment: .bottomTrailing) {
                controlButtons
                    .padding(.trailing, 14 + windowSafeTrailing)
                    .padding(.bottom, 60 + windowSafeBottom)
                    .zIndex(200)
            }
            .overlay(alignment: .bottom) {
                shutterButton
                    .padding(.bottom, 40 + windowSafeBottom)
                    .zIndex(300)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            sliderScale = Double(characterScale)
            updateWindowSafeArea()
            if !canUseAlternatePose {
                isAlternatePoseEnabled = false
            }
        }
        .onChange(of: sliderScale) { _, newValue in
            let clamped = max(0.4, min(2.8, newValue))
            characterScale = CGFloat(clamped)
            lastScale = characterScale
        }
        .onChange(of: mode) { _, _ in
            takeBackgroundSnapshot = nil
            if mode == .plain {
                cameraPosition = .back
            }
            updateWindowSafeArea()
        }
        .onChange(of: characterScale) { _, newValue in
            sliderScale = Double(newValue)
        }
    }

    private var backgroundContainer: some View {
        ZStack {
            captureSurface
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(.black.opacity(0.5), in: Circle())
                    .contentShape(Circle())
            }

            Spacer()

            Button {
                guard mode == .ar else { return }
                cameraPosition = cameraPosition == .back ? .front : .back
                takeBackgroundSnapshot = nil
            } label: {
                let iconName = cameraPosition == .back ? "camera.rotate" : "camera.rotate.fill"
                MemoRouteIconPillButton(systemImage: iconName, isEnabled: mode == .ar)
            }
            .disabled(mode == .plain)

            Picker("撮影", selection: $mode) {
                ForEach(Mode.allCases) { currentMode in
                    Text(currentMode.title).tag(currentMode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 170)
        }
    }

    private var controlButtons: some View {
        VStack(spacing: 10) {
            Button {
                routeLineColorStyle = routeLineColorStyle.toggled
            } label: {
                MemoRouteIconPillButton(
                    systemImage: routeLineColorStyle.systemImage,
                    isEnabled: true,
                    foregroundColor: routeLineColorStyle.swiftUIColor
                )
            }
            .accessibilityLabel(routeLineColorStyle == .white ? "ランルートを黒に" : "ランルートを白に")

            Button {
                routeOverlayPlacement.toggle()
            } label: {
                MemoRouteIconPillButton(systemImage: routeOverlayPlacement.systemImage, isEnabled: true)
            }
            .accessibilityLabel(routeOverlayPlacement.accessibilityLabel)

            Button {
                if canUseAlternatePose {
                    isAlternatePoseEnabled.toggle()
                } else {
                    isAlternatePoseEnabled = false
                }
            } label: {
                MemoRouteIconPillButton(
                    systemImage: poseToggleSystemImage,
                    isEnabled: canUseAlternatePose
                )
            }
            .disabled(!canUseAlternatePose)
            .accessibilityLabel(
                canUseAlternatePose
                ? (isAlternatePoseEnabled ? "通常ポーズに切り替え" : "ポーズを切り替え")
                : "切り替え可能なポーズ画像がありません"
            )

            MemoVerticalScaleSlider(
                value: $sliderScale,
                sliderLength: 200,
                compact: true
            )
            .frame(width: 40)
        }
    }

    private var shutterButton: some View {
        Button {
            captureSnapshot(viewSize: lastViewSize)
        } label: {
            ZStack {
                Circle().fill(Color.white.opacity(0.28)).frame(width: 78, height: 78)
                Circle().fill(Color.white).frame(width: 62, height: 62)
            }
        }
        .disabled(isCapturing || takeBackgroundSnapshot == nil)
        .opacity((isCapturing || takeBackgroundSnapshot == nil) ? 0.6 : 1.0)
    }

    @ViewBuilder
    private var captureSurface: some View {
        if mode == .ar {
            if cameraPosition == .back {
                MemoRouteARCameraBackgroundView { snapshotter in
                    DispatchQueue.main.async {
                        self.takeBackgroundSnapshot = snapshotter
                    }
                }
                .id("memo_route_ar_back")
            } else {
                MemoRouteCameraPreviewView(position: .front) { snapshotter in
                    DispatchQueue.main.async {
                        self.takeBackgroundSnapshot = snapshotter
                    }
                }
                .id("memo_route_front")
            }
        } else {
            MemoPlainBackgroundView(assetName: plainBackgroundAssetName)
                .onAppear {
                    self.takeBackgroundSnapshot = { completion in
                        completion(renderPlainBackground(assetName: plainBackgroundAssetName, viewSize: lastViewSize))
                    }
                }
                .onChange(of: lastViewSize) { _, _ in
                    self.takeBackgroundSnapshot = { completion in
                        completion(renderPlainBackground(assetName: plainBackgroundAssetName, viewSize: lastViewSize))
                    }
                }
        }
    }

    private var characterGesture: some Gesture {
        SimultaneousGesture(
            DragGesture()
                .onChanged { value in
                    characterOffset = CGSize(
                        width: lastOffset.width + value.translation.width,
                        height: lastOffset.height + value.translation.height
                    )
                }
                .onEnded { _ in
                    lastOffset = characterOffset
                },
            MagnificationGesture()
                .onChanged { value in
                    characterScale = max(0.4, min(2.8, lastScale * value))
                }
                .onEnded { _ in
                    lastScale = characterScale
                }
        )
    }

    private func captureSnapshot(viewSize: CGSize) {
        guard viewSize.width > 1, viewSize.height > 1 else { return }
        guard !isCapturing else { return }
        guard let takeBackgroundSnapshot else { return }

        let fixedCharacterAssetName = displayedCharacterAssetName
        let fixedCharacterOffset = characterOffset
        let fixedCharacterScale = characterScale
        let fixedRoutePlacement = routeOverlayPlacement
        let fixedRouteColor = routeLineColorStyle.swiftUIColor

        let routeOverlayImage = renderRouteOverlayAsImage(
            viewSize: viewSize,
            strokeColor: fixedRouteColor,
            placement: fixedRoutePlacement
        )

        isCapturing = true

        takeBackgroundSnapshot { background in
            defer {
                DispatchQueue.main.async {
                    self.isCapturing = false
                }
            }

            guard let background else { return }

            let normalizedBackground = background.fixedOrientation().croppedToAspectFill(of: viewSize)
                ?? background.fixedOrientation()

            let composed = composeFinalImage(
                background: normalizedBackground,
                viewSize: viewSize,
                characterAssetName: fixedCharacterAssetName,
                characterOffset: fixedCharacterOffset,
                characterScale: fixedCharacterScale,
                routeOverlayImage: routeOverlayImage
            )

            DispatchQueue.main.async {
                onCapture(composed)
            }
        }
    }

    private func composeFinalImage(
        background: UIImage,
        viewSize: CGSize,
        characterAssetName: String,
        characterOffset: CGSize,
        characterScale: CGFloat,
        routeOverlayImage: UIImage?
    ) -> UIImage {
        let backgroundSize = background.size
        let scaleX = backgroundSize.width / max(viewSize.width, 1)
        let scaleY = backgroundSize.height / max(viewSize.height, 1)

        let baseCharacterWidth = min(viewSize.width * 0.45, 220)
        let renderedCharacterWidth = baseCharacterWidth * characterScale
        let characterImage = UIImage(named: characterAssetName) ?? UIImage()
        let characterWidth = renderedCharacterWidth * scaleX
        let characterAspect = characterImage.size.height / max(characterImage.size.width, 1)
        let characterHeight = characterWidth * characterAspect

        let centerX = (viewSize.width * 0.5 + characterOffset.width) * scaleX
        let centerY = (viewSize.height * 0.5 + characterOffset.height) * scaleY

        let drawRect = CGRect(
            x: centerX - characterWidth * 0.5,
            y: centerY - characterHeight * 0.5,
            width: characterWidth,
            height: characterHeight
        )

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = background.scale
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: backgroundSize, format: format)
        return renderer.image { context in
            background.draw(in: CGRect(origin: .zero, size: backgroundSize))

            if let routeOverlayImage {
                context.cgContext.saveGState()
                context.cgContext.scaleBy(x: scaleX, y: scaleY)
                routeOverlayImage.draw(in: CGRect(origin: .zero, size: viewSize))
                context.cgContext.restoreGState()
            }

            characterImage.draw(in: drawRect)
        }
    }

    private func renderRouteOverlayAsImage(
        viewSize: CGSize,
        strokeColor: Color,
        placement: WorkoutRouteOverlayPlacement
    ) -> UIImage? {
        guard viewSize.width > 1, viewSize.height > 1 else { return nil }
        guard !routePoints.isEmpty else { return nil }

        let content = WorkoutRouteLineOverlayView(
            points: routePoints,
            strokeColor: strokeColor,
            placement: placement
        )
        .frame(width: viewSize.width, height: viewSize.height)
        .background(Color.clear)

        if #available(iOS 16.0, *) {
            let renderer = ImageRenderer(content: content)
            renderer.proposedSize = ProposedViewSize(width: viewSize.width, height: viewSize.height)
            renderer.scale = UIScreen.main.scale
            renderer.isOpaque = false
            return renderer.uiImage
        }

        let hostingController = UIHostingController(rootView: content)
        hostingController.view.backgroundColor = .clear
        hostingController.view.bounds = CGRect(origin: .zero, size: viewSize)
        hostingController.additionalSafeAreaInsets = .zero
        hostingController.view.insetsLayoutMarginsFromSafeArea = false
        hostingController.view.layoutMargins = .zero
        hostingController.view.setNeedsLayout()
        hostingController.view.layoutIfNeeded()

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = UIScreen.main.scale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: viewSize, format: format)
        return renderer.image { context in
            hostingController.view.layer.render(in: context.cgContext)
        }
    }

    private func renderPlainBackground(assetName: String, viewSize: CGSize) -> UIImage? {
        guard viewSize.width > 1, viewSize.height > 1 else { return nil }
        guard let image = UIImage(named: assetName) else { return nil }

        let scale = UIScreen.main.scale
        let targetSize = CGSize(width: viewSize.width * scale, height: viewSize.height * scale)
        let renderer = UIGraphicsImageRenderer(size: targetSize)

        return renderer.image { _ in
            let imageSize = image.size
            let ratio = max(
                targetSize.width / max(imageSize.width, 1),
                targetSize.height / max(imageSize.height, 1)
            )
            let drawWidth = imageSize.width * ratio
            let drawHeight = imageSize.height * ratio
            let rect = CGRect(
                x: (targetSize.width - drawWidth) * 0.5,
                y: (targetSize.height - drawHeight) * 0.5,
                width: drawWidth,
                height: drawHeight
            )
            image.draw(in: rect)
        }
    }

    private func updateWindowSafeArea() {
        let safeInsets = Self.currentWindowSafeAreaInsets()
        windowSafeTop = safeInsets.top
        windowSafeBottom = safeInsets.bottom
        windowSafeTrailing = safeInsets.right
    }

    private static func currentWindowSafeAreaInsets() -> UIEdgeInsets {
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.compactMap { $0 as? UIWindowScene }.first
        let window = windowScene?.windows.first(where: { $0.isKeyWindow }) ?? windowScene?.windows.first
        return window?.safeAreaInsets ?? .zero
    }
}

private struct MemoRouteIconPillButton: View {
    let systemImage: String
    let isEnabled: Bool
    var foregroundColor: Color = .white

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(foregroundColor.opacity(isEnabled ? 1.0 : 0.55))
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.black.opacity(0.5), in: Capsule())
            .contentShape(Capsule())
    }
}

private struct MemoVerticalScaleSlider: View {
    @Binding var value: Double
    let sliderLength: CGFloat
    let compact: Bool

    var body: some View {
        VStack(spacing: compact ? 8 : 10) {
            Image(systemName: "plus")
                .font(.system(size: compact ? 12 : 14, weight: .bold))
                .foregroundStyle(.white)

            ZStack {
                Slider(value: $value, in: 0.4...2.8)
                    .frame(width: sliderLength)
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: compact ? 18 : 22, height: sliderLength)
            .clipped()

            Image(systemName: "minus")
                .font(.system(size: compact ? 12 : 14, weight: .bold))
                .foregroundStyle(.white)
        }
        .padding(.vertical, compact ? 10 : 12)
        .padding(.horizontal, compact ? 6 : 8)
        .background(.black.opacity(0.35), in: Capsule())
    }
}

private struct MemoPlainBackgroundView: View {
    let assetName: String

    var body: some View {
        Image(assetName)
            .resizable()
            .scaledToFill()
            .ignoresSafeArea()
    }
}

private struct MemoRouteCameraPreviewView: UIViewRepresentable {
    typealias Snapshotter = MemoRouteCameraCaptureView.Snapshotter

    enum Position {
        case front
        case back
    }

    let position: Position
    let onSnapshotReady: (@escaping Snapshotter) -> Void

    init(position: Position = .back, onSnapshotReady: @escaping (@escaping Snapshotter) -> Void) {
        self.position = position
        self.onSnapshotReady = onSnapshotReady
    }

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView(position: position)
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
    }

    static func dismantleUIView(_ uiView: PreviewUIView, coordinator: ()) {
        uiView.stopRunning()
    }

    final class PreviewUIView: UIView, AVCapturePhotoCaptureDelegate {
        private let session = AVCaptureSession()
        private let previewLayer = AVCaptureVideoPreviewLayer()
        private let photoOutput = AVCapturePhotoOutput()
        private var photoCompletion: ((UIImage?) -> Void)?
        private let position: Position

        init(position: Position) {
            self.position = position
            super.init(frame: .zero)
            setupSession()
        }

        override init(frame: CGRect) {
            self.position = .back
            super.init(frame: frame)
            setupSession()
        }

        required init?(coder: NSCoder) {
            self.position = .back
            super.init(coder: coder)
            setupSession()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            previewLayer.frame = bounds
        }

        private func setupSession() {
            previewLayer.session = session
            previewLayer.videoGravity = .resizeAspectFill
            layer.addSublayer(previewLayer)

            guard let device = AVCaptureDevice.default(
                .builtInWideAngleCamera,
                for: .video,
                position: position == .front ? .front : .back
            ), let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) else {
                return
            }

            session.beginConfiguration()
            session.sessionPreset = .photo
            session.addInput(input)

            if session.canAddOutput(photoOutput) {
                session.addOutput(photoOutput)
            }
            session.commitConfiguration()
        }

        func startRunning() {
            DispatchQueue.global(qos: .userInitiated).async {
                if !self.session.isRunning {
                    self.session.startRunning()
                }
            }
        }

        func stopRunning() {
            DispatchQueue.global(qos: .userInitiated).async {
                if self.session.isRunning {
                    self.session.stopRunning()
                }
            }
        }

        func capturePhoto(completion: @escaping (UIImage?) -> Void) {
            photoCompletion = completion
            let settings = AVCapturePhotoSettings()
            settings.flashMode = .off
            photoOutput.capturePhoto(with: settings, delegate: self)
        }

        func photoOutput(
            _ output: AVCapturePhotoOutput,
            didFinishProcessingPhoto photo: AVCapturePhoto,
            error: Error?
        ) {
            let image: UIImage?
            if let data = photo.fileDataRepresentation() {
                image = UIImage(data: data)
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

private struct MemoRouteARCameraBackgroundView: UIViewRepresentable {
    typealias Snapshotter = MemoRouteCameraCaptureView.Snapshotter

    let onSnapshotReady: (@escaping Snapshotter) -> Void

    init(onSnapshotReady: @escaping (@escaping Snapshotter) -> Void) {
        self.onSnapshotReady = onSnapshotReady
    }

    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero)
        view.isUserInteractionEnabled = false

        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]

        view.automaticallyConfigureSession = false
        view.session.run(configuration)
        view.renderOptions.insert(.disableMotionBlur)

        DispatchQueue.main.async {
            onSnapshotReady { completion in
                view.snapshot(saveToHDR: false) { image in
                    completion(image)
                }
            }
        }

        return view
    }

    func updateUIView(_ uiView: ARView, context: Context) {
    }

    static func dismantleUIView(_ uiView: ARView, coordinator: ()) {
        uiView.session.pause()
    }
}

private extension UIImage {
    func fixedOrientation() -> UIImage {
        guard imageOrientation != .up else { return self }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }

    func croppedToAspectFill(of viewSize: CGSize) -> UIImage? {
        guard let cgImage else { return nil }
        guard viewSize.width > 0, viewSize.height > 0 else { return nil }

        let imageWidth = CGFloat(cgImage.width)
        let imageHeight = CGFloat(cgImage.height)
        let targetAspect = viewSize.width / viewSize.height
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

        guard let cropped = cgImage.cropping(to: cropRect.integral) else {
            return nil
        }

        return UIImage(cgImage: cropped, scale: scale, orientation: .up)
    }
}
