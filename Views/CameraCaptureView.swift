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

    // NOTE:
    // 既存呼び出し互換のため activeKcal / totalKcal の名前は残す。
    // 仕様上は歩数表示のみを使用する。
    typealias MetricValueProvider = () -> (steps: Int, activeKcal: Int, totalKcal: Int)

    enum Mode: String, Identifiable {
        case ar
        case plain
        var id: String { rawValue }
        var title: String { self == .ar ? "AR" : "通常" }
    }

    let initialMode: Mode
    let onCancel: () -> Void

    /// 既存（互換用）
    let onCapture: (UIImage) -> Void

    /// ✅ 追加：撮影場所（表示用の文字列） + 緯度経度も一緒に返す
    /// - placeName は取得できない/拒否された場合 nil
    /// - lat/lon は取得できない/拒否された場合 nil
    let onCaptureWithPlace: ((UIImage, String?, Double?, Double?) -> Void)?

    enum MetricDisplay: CaseIterable, Equatable {
        case none
        case steps

        var next: MetricDisplay {
            let all = Self.allCases
            guard let idx = all.firstIndex(of: self) else { return .none }
            return all[(idx + 1) % all.count]
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

    // ✅ 追加：Metric文字色（白/黒）
    enum MetricTextColor: Equatable {
        case white
        case black

        var toggled: MetricTextColor { self == .white ? .black : .white }
        var systemImage: String { "circle.lefthalf.filled" }

        var foreground: UIColor { self == .white ? .white : .black }
        var titleOpacity: CGFloat { 0.92 }
        var unitOpacity: CGFloat { 0.78 }

        var swiftUIColor: Color { self == .white ? .white : .black }
        var titleSwiftUIColor: Color { swiftUIColor.opacity(titleOpacity) }
        var unitSwiftUIColor: Color { swiftUIColor.opacity(unitOpacity) }
    }

    let todaySteps: Int
    let todayActiveKcal: Int
    let todayTotalKcal: Int
    let plainBackgroundAssetName: String

    // ✅ 追加：撮影画面に表示するキャラ（ホームで育成中のキャラ想定）
    // 既存呼び出しを壊さないため init でデフォルト "purpor" を入れる
    let characterAssetName: String

    // ✅ 追加：呼び出し元から最新値を取得するための任意クロージャ
    //    未指定時は従来通り init 時点の値を使用する
    let metricValueProvider: MetricValueProvider?

    @State private var mode: Mode

    @State private var characterOffset: CGSize = .zero
    @State private var characterScale: CGFloat = 1.0
    @State private var lastOffset: CGSize = .zero
    @State private var lastScale: CGFloat = 1.0

    @State private var sliderScale: Double = 1.0
    @State private var metricDisplay: MetricDisplay = .none

    // ✅ 追加：デフォルト白
    @State private var metricTextColor: MetricTextColor = .white

    // ✅ 追加：ポーズ切り替え
    @State private var isAlternatePoseEnabled: Bool = false

    private enum CameraPosition { case front, back }
    @State private var cameraPosition: CameraPosition = .back

    @State private var lastViewSize: CGSize = .zero
    @State private var takeBackgroundSnapshot: Snapshotter?
    @State private var isCapturing: Bool = false

    // ✅ GeometryReaderのsafeAreaInsetsに依存しない
    @State private var windowSafeTop: CGFloat = 0
    @State private var windowSafeBottom: CGFloat = 0
    @State private var windowSafeTrailing: CGFloat = 0

    // ✅ 追加：位置情報（撮影場所名の取得）
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

    // MARK: - Live Values

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
            let characterW = min(geo.size.width * 0.45, 220)
            let metrics = currentMetricValues

            ZStack {
                Color.black.ignoresSafeArea()

                backgroundContainer
                    .onAppear {
                        lastViewSize = geo.size
                        updateWindowSafeArea()
                        locationProvider.prepare()
                    }
                    .onChange(of: geo.size) { _, newValue in
                        lastViewSize = newValue
                        updateWindowSafeArea()
                    }

                Image(displayedCharacterAssetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: characterW)
                    .scaleEffect(characterScale)
                    .offset(characterOffset)
                    .gesture(characterGesture)
                    .zIndex(10)

                MetricOverlayView(
                    display: metricDisplay,
                    steps: metrics.steps,
                    activeKcal: metrics.activeKcal,
                    totalKcal: metrics.totalKcal,
                    textColor: metricTextColor
                )
                .allowsHitTesting(false)
                .zIndex(999)
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
                                .foregroundStyle(metricTextColor.swiftUIColor.opacity(1.0))
                        }
                        .accessibilityLabel(metricTextColor == .white ? "文字色を黒に" : "文字色を白に")
                    }

                    Button {
                        if canUseAlternatePose {
                            isAlternatePoseEnabled.toggle()
                        } else {
                            isAlternatePoseEnabled = false
                        }
                    } label: {
                        IconPillButton(
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
            if mode == .plain { cameraPosition = .back }
            updateWindowSafeArea()
        }
        .onChange(of: characterScale) { _, newValue in
            sliderScale = Double(newValue)
        }
    }

    // MARK: - Window Safe Area

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

    // MARK: - Background Container

    @ViewBuilder
    private var backgroundContainer: some View {
        ZStack { captureSurface }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: 12) {
            Button(action: { onCancel() }) {
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
                ForEach([Mode.ar, .plain]) { m in
                    Text(m.title).tag(m)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 170)
        }
    }

    // MARK: - Shutter

    private var shutterButton: some View {
        Button { captureSnapshot(viewSize: lastViewSize) } label: {
            ZStack {
                Circle().fill(Color.white.opacity(0.28)).frame(width: 78, height: 78)
                Circle().fill(Color.white).frame(width: 62, height: 62)
            }
        }
        .disabled(isCapturing || takeBackgroundSnapshot == nil)
        .opacity((isCapturing || takeBackgroundSnapshot == nil) ? 0.6 : 1.0)
    }

    // MARK: - Background Surface

    @ViewBuilder
    private var captureSurface: some View {
        if mode == .ar {
            if cameraPosition == .back {
                ARCameraBackgroundView { snapshotter in
                    DispatchQueue.main.async { self.takeBackgroundSnapshot = snapshotter }
                }
                .id("ar_back")
            } else {
                CameraPreviewView(position: .front) { snapshotter in
                    DispatchQueue.main.async { self.takeBackgroundSnapshot = snapshotter }
                }
                .id("cam_front")
            }
        } else {
            PlainHomeBackgroundView(assetName: plainBackgroundAssetName)
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

    // MARK: - Gesture

    private var characterGesture: some Gesture {
        SimultaneousGesture(
            DragGesture()
                .onChanged { value in
                    characterOffset = CGSize(
                        width: lastOffset.width + value.translation.width,
                        height: lastOffset.height + value.translation.height
                    )
                }
                .onEnded { _ in lastOffset = characterOffset },
            MagnificationGesture()
                .onChanged { value in
                    characterScale = max(0.4, min(2.8, lastScale * value))
                }
                .onEnded { _ in lastScale = characterScale }
        )
    }

    // MARK: - Capture

    private func captureSnapshot(viewSize: CGSize) {
        guard viewSize.width > 1, viewSize.height > 1 else { return }
        guard !isCapturing else { return }
        guard let takeBackgroundSnapshot else { return }

        let liveMetrics = currentMetricValues
        let fixedMetric = metricDisplay
        let fixedColor = metricTextColor
        let fixedSteps = liveMetrics.steps
        let fixedActive = liveMetrics.activeKcal
        let fixedTotal = liveMetrics.totalKcal
        let fixedOffset = characterOffset
        let fixedScale = characterScale
        let fixedCharacterAssetName = displayedCharacterAssetName

        let fixedMetricImage: UIImage? = {
            guard fixedMetric != .none else { return nil }
            return renderMetricOverlayAsImage(
                viewSize: viewSize,
                display: fixedMetric,
                steps: fixedSteps,
                activeKcal: fixedActive,
                totalKcal: fixedTotal,
                textColor: fixedColor
            )
        }()

        isCapturing = true

        takeBackgroundSnapshot { background in
            defer { DispatchQueue.main.async { self.isCapturing = false } }
            guard let background else { return }

            let normalizedBackground = background
                .fixedOrientation()
                .croppedToAspectFill(of: viewSize) ?? background.fixedOrientation()

            let composed = composeFinalImage(
                background: normalizedBackground,
                viewSize: viewSize,
                characterAssetName: fixedCharacterAssetName,
                characterOffset: fixedOffset,
                characterScale: fixedScale,
                metricOverlayImage: fixedMetricImage
            )

            Task {
                let info = await locationProvider.currentPlaceInfo(timeoutSeconds: 1.2)
                await MainActor.run {
                    if let onCaptureWithPlace {
                        onCaptureWithPlace(composed, info.placeName, info.latitude, info.longitude)
                    } else {
                        onCapture(composed)
                    }
                }
            }
        }
    }

    private func composeFinalImage(
        background: UIImage,
        viewSize: CGSize,
        characterAssetName: String,
        characterOffset: CGSize,
        characterScale: CGFloat,
        metricOverlayImage: UIImage?
    ) -> UIImage {

        let bgSize = background.size
        let sx = bgSize.width / max(viewSize.width, 1)
        let sy = bgSize.height / max(viewSize.height, 1)

        let baseCharacterWidthInView = min(viewSize.width * 0.45, 220)
        let finalCharacterWidthInView = baseCharacterWidthInView * characterScale

        let characterImage = UIImage(named: characterAssetName) ?? UIImage()
        let characterWidth = finalCharacterWidthInView * sx
        let aspect = characterImage.size.height / max(characterImage.size.width, 1)
        let characterHeight = characterWidth * aspect

        let centerXInView = viewSize.width / 2 + characterOffset.width
        let centerYInView = viewSize.height / 2 + characterOffset.height
        let centerX = centerXInView * sx
        let centerY = centerYInView * sy

        let drawRect = CGRect(
            x: centerX - characterWidth / 2,
            y: centerY - characterHeight / 2,
            width: characterWidth,
            height: characterHeight
        )

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = background.scale
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: bgSize, format: format)
        return renderer.image { ctx in
            background.draw(in: CGRect(origin: .zero, size: bgSize))
            characterImage.draw(in: drawRect)

            if let metricOverlayImage {
                ctx.cgContext.saveGState()
                ctx.cgContext.scaleBy(x: sx, y: sy)
                metricOverlayImage.draw(in: CGRect(origin: .zero, size: viewSize))
                ctx.cgContext.restoreGState()
            }
        }
    }

    private func renderMetricOverlayAsImage(
        viewSize: CGSize,
        display: MetricDisplay,
        steps: Int,
        activeKcal: Int,
        totalKcal: Int,
        textColor: MetricTextColor
    ) -> UIImage? {
        guard viewSize.width > 1, viewSize.height > 1 else { return nil }
        guard display != .none else { return nil }

        let content = MetricOverlayView(
            display: display,
            steps: steps,
            activeKcal: activeKcal,
            totalKcal: totalKcal,
            textColor: textColor
        )
        .ignoresSafeArea()
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
        host.additionalSafeAreaInsets = .zero
        host.view.insetsLayoutMarginsFromSafeArea = false
        host.view.layoutMargins = .zero
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = UIScreen.main.scale
        format.opaque = false
        let r = UIGraphicsImageRenderer(size: viewSize, format: format)
        return r.image { ctx in
            host.view.layer.render(in: ctx.cgContext)
        }
    }

    private func renderPlainBackground(assetName: String, viewSize: CGSize) -> UIImage? {
        guard viewSize.width > 1, viewSize.height > 1 else { return nil }
        guard let img = UIImage(named: assetName) else { return nil }

        let scale = UIScreen.main.scale
        let targetSize = CGSize(width: viewSize.width * scale, height: viewSize.height * scale)

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            let imgSize = img.size
            let s = max(targetSize.width / max(imgSize.width, 1), targetSize.height / max(imgSize.height, 1))
            let drawW = imgSize.width * s
            let drawH = imgSize.height * s
            let rect = CGRect(
                x: (targetSize.width - drawW) / 2,
                y: (targetSize.height - drawH) / 2,
                width: drawW,
                height: drawH
            )
            img.draw(in: rect)
        }
    }
}

// MARK: - UI Parts

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

private struct MetricOverlayView: View {
    let display: CameraCaptureView.MetricDisplay
    let steps: Int
    let activeKcal: Int
    let totalKcal: Int
    let textColor: CameraCaptureView.MetricTextColor

    private var value: String {
        switch display {
        case .none:
            return ""
        case .steps:
            return "\(max(0, max(steps, totalKcal)))"
        }
    }

    var body: some View {
        if display != .none {
            VStack(spacing: 6) {
                Text(display.title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(textColor.titleSwiftUIColor)

                Text(value)
                    .font(.system(size: 92, weight: .black))
                    .italic()
                    .foregroundStyle(textColor.swiftUIColor)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)

                Text(display.unit)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(textColor.unitSwiftUIColor)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.top, 40)
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

// MARK: - ✅ UIImage helpers（向き補正 + aspectFillクロップ）

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
        guard let cg = self.cgImage else { return nil }
        guard viewSize.width > 0, viewSize.height > 0 else { return nil }

        let imgW = CGFloat(cg.width)
        let imgH = CGFloat(cg.height)

        let targetAspect = viewSize.width / viewSize.height
        let imgAspect = imgW / imgH

        var crop: CGRect
        if imgAspect > targetAspect {
            let newW = imgH * targetAspect
            let x = (imgW - newW) / 2
            crop = CGRect(x: x, y: 0, width: newW, height: imgH)
        } else {
            let newH = imgW / targetAspect
            let y = (imgH - newH) / 2
            crop = CGRect(x: 0, y: y, width: imgW, height: newH)
        }

        guard let croppedCG = cg.cropping(to: crop.integral) else { return nil }
        return UIImage(cgImage: croppedCG, scale: self.scale, orientation: .up)
    }
}

// MARK: - ✅ Location Provider（撮影場所名）

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

        let status = manager.authorizationStatus
        switch status {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            manager.startUpdatingLocation()
        case .denied, .restricted:
            break
        @unknown default:
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
        guard let loc = latestLocation else { return (nil, nil, nil) }

        let lat = loc.coordinate.latitude
        let lon = loc.coordinate.longitude

        let placeName = await reverseGeocodeWithTimeout(location: loc, seconds: timeoutSeconds)
        return (placeName, lat, lon)
    }

    private func reverseGeocodeWithTimeout(location: CLLocation, seconds: Double) async -> String? {
        await withTaskGroup(of: String?.self) { group in
            group.addTask { [geocoder] in
                do {
                    let placemarks = try await geocoder.reverseGeocodeLocation(
                        location,
                        preferredLocale: Locale(identifier: "ja_JP")
                    )
                    guard let pm = placemarks.first else { return nil }
                    return Self.formatPlaceName(pm)
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

    nonisolated private static func formatPlaceName(_ pm: CLPlacemark) -> String? {
        func clean(_ s: String?) -> String? {
            guard let s else { return nil }
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? nil : t
        }

        func isTooGeneric(_ s: String) -> Bool {
            let generic: Set<String> = ["本州", "日本", "Japan", "アジア", "Asia", "東アジア", "太平洋"]
            if generic.contains(s) { return true }

            let lower = s.lowercased()
            if lower.contains("island") || lower.contains("sea") || lower.contains("ocean") {
                return true
            }
            return false
        }

        if let poi = clean(pm.areasOfInterest?.first), !isTooGeneric(poi) {
            return poi
        }

        let pref = clean(pm.administrativeArea)
        let city = clean(pm.locality ?? pm.subAdministrativeArea ?? pm.subLocality)
        if let pref, let city {
            let composed = "\(pref)\(city)"
            if !isTooGeneric(composed) { return composed }
        }

        if let city, !isTooGeneric(city) { return city }
        if let pref, !isTooGeneric(pref) { return pref }

        if let name = clean(pm.name), !containsDigit(name), !isTooGeneric(name) {
            return name
        }

        return nil
    }

    nonisolated private static func containsDigit(_ s: String) -> Bool {
        s.rangeOfCharacter(from: .decimalDigits) != nil
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.startUpdatingLocation()
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        latestLocation = locations.last
        manager.stopUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    }
}

// MARK: - Plain Camera

private struct CameraPreviewView: UIViewRepresentable {
    typealias Snapshotter = CameraCaptureView.Snapshotter
    let onSnapshotReady: (@escaping Snapshotter) -> Void

    enum Position { case front, back }
    let position: Position

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

    func updateUIView(_ uiView: PreviewUIView, context: Context) {}

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
                if !self.session.isRunning { self.session.startRunning() }
            }
        }

        func stopRunning() {
            DispatchQueue.global(qos: .userInitiated).async {
                if self.session.isRunning { self.session.stopRunning() }
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
            if let data = photo.fileDataRepresentation(), let capturedImage = UIImage(data: data) {
                if position == .front {
                    image = capturedImage.mirroredHorizontally() ?? capturedImage
                } else {
                    image = capturedImage
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

// MARK: - AR Background

private struct ARCameraBackgroundView: UIViewRepresentable {
    typealias Snapshotter = CameraCaptureView.Snapshotter
    let onSnapshotReady: (@escaping Snapshotter) -> Void

    init(onSnapshotReady: @escaping (@escaping Snapshotter) -> Void) {
        self.onSnapshotReady = onSnapshotReady
    }

    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero)
        view.isUserInteractionEnabled = false

        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]

        view.automaticallyConfigureSession = false
        view.session.run(config)
        view.renderOptions.insert(.disableMotionBlur)

        DispatchQueue.main.async {
            onSnapshotReady { completion in
                view.snapshot(saveToHDR: false) { img in completion(img) }
            }
        }
        return view
    }

    func updateUIView(_ uiView: ARView, context: Context) {}

    static func dismantleUIView(_ uiView: ARView, coordinator: ()) {
        uiView.session.pause()
    }
}
