//
//  CameraCaptureView.swift
//  MeMo
//
//  Created by shota suzuki on 2026/03/20.
//

import SwiftUI
import UIKit
import AVFoundation
import ARKit
import RealityKit
import CoreLocation
import Combine

struct CameraCaptureView: View {

    typealias Snapshotter = (@escaping (UIImage?) -> Void) -> Void
    typealias MetricValueProvider = () -> (steps: Int, activeKcal: Int, totalKcal: Int)

    enum Mode: String, Identifiable {
        case ar
        case plain

        var id: String { rawValue }
        var title: String { self == .ar ? "AR" : "通常" }
    }

    enum MetricDisplay: CaseIterable, Equatable {
        case none
        case steps

        var next: MetricDisplay {
            let all = Self.allCases
            guard let index = all.firstIndex(of: self) else { return .none }
            return all[(index + 1) % all.count]
        }

        var title: String {
            switch self {
            case .none: return "なし"
            case .steps: return "STEPS"
            }
        }

        var unit: String {
            switch self {
            case .none: return ""
            case .steps: return "steps"
            }
        }

        var systemImage: String {
            switch self {
            case .none: return "nosign"
            case .steps: return "figure.walk"
            }
        }
    }

    enum MetricTextColor: Equatable {
        case white
        case black

        var toggled: MetricTextColor { self == .white ? .black : .white }
        var systemImage: String { "circle.lefthalf.filled" }
        var foreground: UIColor { self == .white ? .white : .black }
        var swiftUIColor: Color { self == .white ? .white : .black }
        var titleSwiftUIColor: Color { swiftUIColor.opacity(0.92) }
        var unitSwiftUIColor: Color { swiftUIColor.opacity(0.78) }
    }

    private enum CameraPosition {
        case front
        case back
    }

    let initialMode: Mode
    let onCancel: () -> Void
    let onCapture: (UIImage) -> Void
    let onCaptureWithPlace: ((UIImage, String?, Double?, Double?) -> Void)?

    let todaySteps: Int
    let todayActiveKcal: Int
    let todayTotalKcal: Int
    let plainBackgroundAssetName: String
    let characterAssetName: String
    let metricValueProvider: MetricValueProvider?

    @State private var mode: Mode
    @State private var characterOffset: CGSize = .zero
    @State private var characterScale: CGFloat = 1.0
    @State private var lastOffset: CGSize = .zero
    @State private var lastScale: CGFloat = 1.0
    @State private var sliderScale: Double = 1.0
    @State private var metricDisplay: MetricDisplay = .none
    @State private var metricTextColor: MetricTextColor = .white
    @State private var isAlternatePoseEnabled: Bool = false
    @State private var cameraPosition: CameraPosition = .back
    @State private var lastViewSize: CGSize = .zero
    @State private var takeBackgroundSnapshot: Snapshotter?
    @State private var isCapturing: Bool = false
    @State private var lastCapturedCardImage: UIImage?

    @State private var windowSafeTop: CGFloat = 0
    @State private var windowSafeBottom: CGFloat = 0
    @State private var windowSafeTrailing: CGFloat = 0

    @StateObject private var locationProvider = LocationProvider()

    init(
        initialMode: Mode,
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
        _mode = State(initialValue: initialMode)
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
        GeometryReader { geo in
            let characterWidth = min(geo.size.width * 0.45, 220)
            let metrics = currentMetricValues
            let captureCardRect = captureRect(in: geo.size)

            ZStack {
                Color.black.ignoresSafeArea()

                backgroundContainer
                    .onAppear {
                        lastViewSize = geo.size
                        updateWindowSafeArea()
                        locationProvider.prepare()
                    }
                    .onChange(of: geo.size) { _, newSize in
                        lastViewSize = newSize
                        updateWindowSafeArea()
                    }

                Image(displayedCharacterAssetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: characterWidth)
                    .scaleEffect(characterScale)
                    .offset(characterOffset)
                    .gesture(characterGesture)
                    .zIndex(10)

                MetricOverlayView(
                    display: metricDisplay,
                    steps: metrics.steps,
                    activeKcal: metrics.activeKcal,
                    totalKcal: metrics.totalKcal,
                    textColor: metricTextColor,
                    captureRect: captureCardRect
                )
                .allowsHitTesting(false)
                .zIndex(40)

                CaptureGuideOverlay(captureRect: captureCardRect)
                    .allowsHitTesting(false)
                    .zIndex(50)
            }
            .ignoresSafeArea()
            .overlay(alignment: .top) {
                topBar
                    .padding(.top, windowSafeTop + 8)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }
            .overlay(alignment: .bottomTrailing) {
                VStack(spacing: 10) {
                    if metricDisplay != .none {
                        Button {
                            metricTextColor = metricTextColor.toggled
                        } label: {
                            IconPillButton(systemImage: metricTextColor.systemImage, isEnabled: true)
                                .foregroundStyle(metricTextColor.swiftUIColor)
                        }
                        .accessibilityLabel(metricTextColor == .white ? "文字色を黒に" : "文字色を白に")
                    }

                    Button {
                        guard canUseAlternatePose else {
                            isAlternatePoseEnabled = false
                            return
                        }
                        isAlternatePoseEnabled.toggle()
                    } label: {
                        IconPillButton(systemImage: poseToggleSystemImage, isEnabled: canUseAlternatePose)
                    }
                    .disabled(!canUseAlternatePose)

                    VerticalScaleSlider(
                        value: $sliderScale,
                        sliderLength: 200,
                        compact: true
                    )
                    .frame(width: 40)
                }
                .padding(.trailing, 14 + windowSafeTrailing)
                .padding(.bottom, 60 + windowSafeBottom)
                .zIndex(200)
            }
            .overlay(alignment: .bottom) {
                shutterButton
                    .padding(.bottom, 40 + windowSafeBottom)
                    .zIndex(300)
            }
            .overlay(alignment: .bottomLeading) {
                LastCapturedPreviewCard(image: lastCapturedCardImage)
                    .padding(.leading, 18)
                    .padding(.bottom, 42 + windowSafeBottom)
                    .zIndex(250)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            sliderScale = Double(characterScale)
            updateWindowSafeArea()
            locationProvider.prepare()
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

    private func captureRect(in viewSize: CGSize) -> CGRect {
        let horizontalPadding: CGFloat = 22
        let topReserved = max(windowSafeTop + 92, 128)
        let bottomReserved = max(windowSafeBottom + 182, 220)
        let usableWidth = max(120, viewSize.width - (horizontalPadding * 2))
        let usableHeight = max(160, viewSize.height - topReserved - bottomReserved)

        let widthFromHeight = usableHeight * MemoryPhotoCardMetrics.aspectRatio
        let cardWidth = min(usableWidth, widthFromHeight)
        let cardHeight = cardWidth / MemoryPhotoCardMetrics.aspectRatio
        let originX = (viewSize.width - cardWidth) * 0.5
        let centeredY = topReserved + ((usableHeight - cardHeight) * 0.34)
        let originY = max(topReserved, centeredY - 10)

        return CGRect(x: originX, y: originY, width: cardWidth, height: cardHeight)
    }

    private func updateWindowSafeArea() {
        let insets = Self.currentWindowSafeAreaInsets()
        windowSafeTop = insets.top
        windowSafeBottom = insets.bottom
        windowSafeTrailing = insets.right
    }

    private static func currentWindowSafeAreaInsets() -> UIEdgeInsets {
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.compactMap { $0 as? UIWindowScene }.first
        let window = windowScene?.windows.first(where: { $0.isKeyWindow }) ?? windowScene?.windows.first
        return window?.safeAreaInsets ?? .zero
    }

    @ViewBuilder
    private var backgroundContainer: some View {
        ZStack { captureSurface }
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

            Button { metricDisplay = metricDisplay.next } label: {
                IconPillButton(systemImage: metricDisplay.systemImage, isEnabled: true)
            }

            Button {
                guard mode == .ar else { return }
                cameraPosition = (cameraPosition == .back) ? .front : .back
                takeBackgroundSnapshot = nil
            } label: {
                let icon = (cameraPosition == .back) ? "camera.rotate" : "camera.rotate.fill"
                IconPillButton(systemImage: icon, isEnabled: mode == .ar)
            }
            .disabled(mode == .plain)

            Picker("撮影", selection: $mode) {
                ForEach([Mode.ar, .plain]) { currentMode in
                    Text(currentMode.title).tag(currentMode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 170)
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
                ARCameraBackgroundView { snapshotter in
                    DispatchQueue.main.async {
                        takeBackgroundSnapshot = snapshotter
                    }
                }
                .id("ar_back")
            } else {
                CameraPreviewView(position: .front) { snapshotter in
                    DispatchQueue.main.async {
                        takeBackgroundSnapshot = snapshotter
                    }
                }
                .id("cam_front")
            }
        } else {
            PlainHomeBackgroundView(assetName: plainBackgroundAssetName)
                .onAppear {
                    takeBackgroundSnapshot = { completion in
                        completion(renderPlainBackground(assetName: plainBackgroundAssetName, viewSize: lastViewSize))
                    }
                }
                .onChange(of: lastViewSize) { _, _ in
                    takeBackgroundSnapshot = { completion in
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

        let captureCardRect = captureRect(in: viewSize)
        let metrics = currentMetricValues
        let fixedMetric = metricDisplay
        let fixedMetricColor = metricTextColor
        let fixedOffset = characterOffset
        let fixedScale = characterScale
        let fixedCharacterAssetName = displayedCharacterAssetName

        let metricOverlayImage: UIImage? = {
            guard fixedMetric != .none else { return nil }
            return renderMetricOverlayAsImage(
                viewSize: viewSize,
                display: fixedMetric,
                steps: metrics.steps,
                activeKcal: metrics.activeKcal,
                totalKcal: metrics.totalKcal,
                textColor: fixedMetricColor,
                captureRect: captureCardRect
            )
        }()

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

            let composedFullImage = composeFullImage(
                background: normalizedBackground,
                viewSize: viewSize,
                characterAssetName: fixedCharacterAssetName,
                characterOffset: fixedOffset,
                characterScale: fixedScale,
                metricOverlayImage: metricOverlayImage
            )

            let cardImage = cropCardImage(
                from: composedFullImage,
                viewSize: viewSize,
                captureRect: captureCardRect
            ) ?? composedFullImage

            DispatchQueue.main.async {
                lastCapturedCardImage = cardImage
            }

            Task {
                let info = await locationProvider.currentPlaceInfo(timeoutSeconds: 1.2)
                await MainActor.run {
                    if let onCaptureWithPlace {
                        onCaptureWithPlace(cardImage, info.placeName, info.latitude, info.longitude)
                    } else {
                        onCapture(cardImage)
                    }
                }
            }
        }
    }

    private func composeFullImage(
        background: UIImage,
        viewSize: CGSize,
        characterAssetName: String,
        characterOffset: CGSize,
        characterScale: CGFloat,
        metricOverlayImage: UIImage?
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
            characterImage.draw(in: drawRect)

            if let metricOverlayImage {
                context.cgContext.saveGState()
                context.cgContext.scaleBy(x: scaleX, y: scaleY)
                metricOverlayImage.draw(in: CGRect(origin: .zero, size: viewSize))
                context.cgContext.restoreGState()
            }
        }
    }

    private func cropCardImage(from image: UIImage, viewSize: CGSize, captureRect: CGRect) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        let scaleX = CGFloat(cgImage.width) / max(viewSize.width, 1)
        let scaleY = CGFloat(cgImage.height) / max(viewSize.height, 1)
        let cropRect = CGRect(
            x: captureRect.origin.x * scaleX,
            y: captureRect.origin.y * scaleY,
            width: captureRect.width * scaleX,
            height: captureRect.height * scaleY
        ).integral

        guard let cropped = cgImage.cropping(to: cropRect) else { return nil }
        return UIImage(cgImage: cropped, scale: image.scale, orientation: .up)
    }

    private func renderMetricOverlayAsImage(
        viewSize: CGSize,
        display: MetricDisplay,
        steps: Int,
        activeKcal: Int,
        totalKcal: Int,
        textColor: MetricTextColor,
        captureRect: CGRect
    ) -> UIImage? {
        guard viewSize.width > 1, viewSize.height > 1 else { return nil }
        guard display != .none else { return nil }

        let content = MetricOverlayView(
            display: display,
            steps: steps,
            activeKcal: activeKcal,
            totalKcal: totalKcal,
            textColor: textColor,
            captureRect: captureRect
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

        let host = UIHostingController(rootView: content)
        host.view.backgroundColor = .clear
        host.view.bounds = CGRect(origin: .zero, size: viewSize)
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = UIScreen.main.scale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: viewSize, format: format)
        return renderer.image { context in
            host.view.layer.render(in: context.cgContext)
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
            let ratio = max(targetSize.width / max(imageSize.width, 1), targetSize.height / max(imageSize.height, 1))
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
}

private struct CaptureGuideOverlay: View {
    let captureRect: CGRect

    var body: some View {
        GeometryReader { proxy in
            let fullRect = CGRect(origin: .zero, size: proxy.size)
            let path = Path { path in
                path.addRect(fullRect)
                path.addRoundedRect(
                    in: captureRect,
                    cornerSize: CGSize(width: MemoryPhotoCardMetrics.cornerRadius, height: MemoryPhotoCardMetrics.cornerRadius)
                )
            }

            path
                .fill(Color.black.opacity(0.42), style: FillStyle(eoFill: true))
                .overlay {
                    RoundedRectangle(cornerRadius: MemoryPhotoCardMetrics.cornerRadius, style: .continuous)
                        .stroke(Color.white.opacity(0.94), lineWidth: 2)
                        .frame(width: captureRect.width, height: captureRect.height)
                        .position(x: captureRect.midX, y: captureRect.midY)
                }
        }
    }
}

private struct LastCapturedPreviewCard: View {
    let image: UIImage?

    var body: some View {
        Group {
            if let image {
                MemoryPhotoCardView(image: image, showsTiltEffect: false)
                    .frame(width: 68)
            } else {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.black.opacity(0.36))
                    .frame(width: 68, height: 94)
                    .overlay {
                        Image(systemName: "photo")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white.opacity(0.82))
                    }
            }
        }
        .animation(.spring(response: 0.26, dampingFraction: 0.84), value: image)
    }
}

private struct IconPillButton: View {
    let systemImage: String
    let isEnabled: Bool

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(.white.opacity(isEnabled ? 1.0 : 0.55))
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.black.opacity(0.5), in: Capsule())
            .contentShape(Capsule())
    }
}

private struct VerticalScaleSlider: View {
    @Binding var value: Double
    let sliderLength: CGFloat
    let compact: Bool

    var body: some View {
        VStack(spacing: compact ? 8 : 10) {
            Image(systemName: "plus")
                .font(.system(size: compact ? 12 : 14, weight: .bold))
                .foregroundStyle(.white)

            Slider(value: $value, in: 0.4...2.8)
                .frame(width: sliderLength)
                .rotationEffect(.degrees(-90))
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

private struct MetricOverlayView: View {
    let display: CameraCaptureView.MetricDisplay
    let steps: Int
    let activeKcal: Int
    let totalKcal: Int
    let textColor: CameraCaptureView.MetricTextColor
    let captureRect: CGRect

    private var value: String {
        switch display {
        case .none:
            return ""
        case .steps:
            return "\(max(0, max(steps, totalKcal)))"
        }
    }

    var body: some View {
        GeometryReader { proxy in
            if display != .none {
                VStack(spacing: 6) {
                    Text(display.title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(textColor.titleSwiftUIColor)

                    Text(value)
                        .font(.system(size: min(72, captureRect.width * 0.24), weight: .black))
                        .italic()
                        .foregroundStyle(textColor.swiftUIColor)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)

                    Text(display.unit)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(textColor.unitSwiftUIColor)
                }
                .frame(width: captureRect.width, height: captureRect.height, alignment: .top)
                .padding(.top, 26)
                .position(x: captureRect.midX, y: captureRect.midY)
            }
        }
    }
}

private struct PlainHomeBackgroundView: View {
    let assetName: String

    var body: some View {
        Image(assetName)
            .resizable()
            .scaledToFill()
            .ignoresSafeArea()
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

    func mirroredHorizontally() -> UIImage? {
        let source = fixedOrientation()
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
            cropRect = CGRect(x: (imageWidth - newWidth) * 0.5, y: 0, width: newWidth, height: imageHeight)
        } else {
            let newHeight = imageWidth / targetAspect
            cropRect = CGRect(x: 0, y: (imageHeight - newHeight) * 0.5, width: imageWidth, height: newHeight)
        }

        guard let cropped = cgImage.cropping(to: cropRect.integral) else { return nil }
        return UIImage(cgImage: cropped, scale: scale, orientation: .up)
    }
}

@MainActor
private final class LocationProvider: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()

    private var latestLocation: CLLocation?
    private var didRequestAuth = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func prepare() {
        guard !didRequestAuth else { return }
        didRequestAuth = true

        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            manager.startUpdatingLocation()
        default:
            break
        }
    }

    func currentPlaceInfo(timeoutSeconds: Double) async -> (placeName: String?, latitude: Double?, longitude: Double?) {
        let status = manager.authorizationStatus
        guard status == .authorizedAlways || status == .authorizedWhenInUse else {
            return (nil, nil, nil)
        }

        let deadline = Date().addingTimeInterval(timeoutSeconds)
        manager.startUpdatingLocation()

        while latestLocation == nil && Date() < deadline {
            try? await Task.sleep(nanoseconds: 120_000_000)
        }

        guard let location = latestLocation else { return (nil, nil, nil) }
        let placeName = await reverseGeocodeWithTimeout(location: location, seconds: timeoutSeconds)
        return (placeName, location.coordinate.latitude, location.coordinate.longitude)
    }

    private func reverseGeocodeWithTimeout(location: CLLocation, seconds: Double) async -> String? {
        await withTaskGroup(of: String?.self) { group in
            group.addTask { [geocoder] in
                do {
                    let placemarks = try await geocoder.reverseGeocodeLocation(
                        location,
                        preferredLocale: Locale(identifier: "ja_JP")
                    )
                    guard let placemark = placemarks.first else { return nil }
                    return Self.formatPlaceName(placemark)
                } catch {
                    return nil
                }
            }

            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                return nil
            }

            let value = await group.next() ?? nil
            group.cancelAll()
            return value
        }
    }

    nonisolated private static func formatPlaceName(_ placemark: CLPlacemark) -> String? {
        func clean(_ value: String?) -> String? {
            guard let value else { return nil }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }

        if let pointOfInterest = clean(placemark.areasOfInterest?.first) {
            return pointOfInterest
        }

        let prefecture = clean(placemark.administrativeArea)
        let city = clean(placemark.locality ?? placemark.subAdministrativeArea ?? placemark.subLocality)

        if let prefecture, let city {
            return prefecture + city
        }

        return city ?? prefecture ?? clean(placemark.name)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        if status == .authorizedAlways || status == .authorizedWhenInUse {
            manager.startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        latestLocation = locations.last
        manager.stopUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    }
}

private struct CameraPreviewView: UIViewRepresentable {
    typealias Snapshotter = CameraCaptureView.Snapshotter

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

            guard
                let device = AVCaptureDevice.default(
                    .builtInWideAngleCamera,
                    for: .video,
                    position: position == .front ? .front : .back
                ),
                let input = try? AVCaptureDeviceInput(device: device),
                session.canAddInput(input)
            else { return }

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
            if let data = photo.fileDataRepresentation(), let captured = UIImage(data: data) {
                if position == .front {
                    image = captured.mirroredHorizontally() ?? captured
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

private struct ARCameraBackgroundView: UIViewRepresentable {
    typealias Snapshotter = CameraCaptureView.Snapshotter

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
