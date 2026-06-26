//
//  CameraStyleView.swift
//  MeMo
//
//  Created for MeMo camera printing UI adjustment.
//  BUILD_FIX_V5_APPLIED.
//

import SwiftUI
import UIKit
import AVFoundation
import ARKit
import RealityKit

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

    @State private var mode: Mode
    @State private var cameraPosition: CameraPosition = .back

    @State private var characterOffset: CGSize = .zero
    @State private var characterScale: CGFloat = 1.0
    @State private var lastOffset: CGSize = .zero
    @State private var lastScale: CGFloat = 1.0
    @State private var sliderScale: Double = 1.0

    @State private var takeBackgroundSnapshot: Snapshotter?
    @State private var lastPreviewSize: CGSize = .zero
    @State private var safeAreaInsets: UIEdgeInsets = .zero

    @State private var isCapturing: Bool = false
    @State private var isPrinting: Bool = false
    @State private var isSlotExpanded: Bool = false
    @State private var printProgress: CGFloat = 0
    @State private var printingPhoto: UIImage?
    @State private var recentPhotos: [PicoPrintedPhoto] = []
    @State private var selectedPhoto: PicoPrintedPhoto?

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

    private var cameraRotateEnabled: Bool {
        mode == .plain || mode == .ar
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                backgroundBody

                VStack(spacing: 0) {
                    topSpacer(height: geometry.safeAreaInsets.top)

                    printerArea(screenSize: geometry.size)
                        .padding(.top, 12)

                    controlsArea
                        .padding(.top, 42)

                    Spacer(minLength: 24)

                    appMark
                        .padding(.bottom, 34)

                    photoTray
                        .frame(height: max(230, geometry.size.height * 0.30))
                        .padding(.horizontal, 18)
                        .padding(.bottom, 18 + geometry.safeAreaInsets.bottom)
                }
                .frame(width: geometry.size.width, height: geometry.size.height)

                if let printingPhoto {
                    printingPhotoLayer(image: printingPhoto, screenSize: geometry.size)
                        .zIndex(240)
                        .allowsHitTesting(false)
                }

                topCloseButton
                    .padding(.top, geometry.safeAreaInsets.top + 12)
                    .padding(.leading, 18)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .zIndex(500)

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
            .ignoresSafeArea()
            .onAppear {
                safeAreaInsets = Self.currentWindowSafeAreaInsets()
                sliderScale = Double(characterScale)
            }
            .onChange(of: geometry.size) { _, _ in
                safeAreaInsets = Self.currentWindowSafeAreaInsets()
            }
            .onChange(of: mode) { _, newMode in
                takeBackgroundSnapshot = nil
                if newMode == .ar {
                    cameraPosition = .back
                }
            }
            .onChange(of: sliderScale) { _, newValue in
                let clamped = max(0.55, min(2.4, newValue))
                characterScale = CGFloat(clamped)
                lastScale = characterScale
            }
            .onChange(of: characterScale) { _, newValue in
                sliderScale = Double(newValue)
            }
        }
    }

    private var backgroundBody: some View {
        LinearGradient(
            colors: [
                Color(red: 1.00, green: 0.20, blue: 0.17),
                Color(red: 0.93, green: 0.11, blue: 0.10),
                Color(red: 1.00, green: 0.24, blue: 0.17)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .overlay(alignment: .top) {
            LinearGradient(
                colors: [.white.opacity(0.26), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 44)
        }
        .overlay(alignment: .bottom) {
            LinearGradient(
                colors: [.clear, .black.opacity(0.22)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 64)
        }
        .ignoresSafeArea()
    }

    private func topSpacer(height: CGFloat) -> some View {
        Color.clear.frame(height: max(0, height))
    }

    private func printerArea(screenSize: CGSize) -> some View {
        let expandedWidth = min(screenSize.width * 0.68, 330)
        let compactWidth = min(screenSize.width * 0.72, 360)
        let width = isSlotExpanded ? compactWidth : expandedWidth
        let height: CGFloat = isSlotExpanded ? 74 : min(screenSize.height * 0.27, 260)
        let corner: CGFloat = isSlotExpanded ? 38 : 56

        return ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(Color.black)
                .overlay(
                    RoundedRectangle(cornerRadius: corner, style: .continuous)
                        .stroke(Color(red: 1.0, green: 0.36, blue: 0.32), lineWidth: 4)
                )
                .shadow(color: .black.opacity(0.34), radius: 12, x: 0, y: 8)
                .shadow(color: .white.opacity(0.18), radius: 3, x: 0, y: -1)

            if !isSlotExpanded {
                cameraPreviewWindow
                    .padding(.horizontal, 18)
                    .padding(.top, 30)
                    .padding(.bottom, 18)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }

            if !isSlotExpanded {
                Circle()
                    .fill(Color(red: 0.17, green: 0.90, blue: 0.42))
                    .frame(width: 10, height: 10)
                    .padding(.top, 16)
                    .transition(.opacity)
            }

            if isSlotExpanded {
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(Color.black)
                    .frame(height: 50)
                    .padding(.horizontal, 10)
                    .padding(.top, 12)
                    .shadow(color: .black.opacity(0.55), radius: 8, x: 0, y: 4)
            }
        }
        .frame(width: width, height: height)
        .animation(.spring(response: 0.36, dampingFraction: 0.82), value: isSlotExpanded)
    }

    private var cameraPreviewWindow: some View {
        GeometryReader { proxy in
            ZStack {
                captureSurface

                Image(characterAssetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: min(proxy.size.width * 0.32, 132))
                    .scaleEffect(characterScale)
                    .offset(characterOffset)
                    .gesture(characterGesture)
                    .shadow(color: .black.opacity(0.26), radius: 8, x: 0, y: 5)
                    .zIndex(10)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            }
            .onAppear { lastPreviewSize = proxy.size }
            .onChange(of: proxy.size) { _, newSize in lastPreviewSize = newSize }
        }
    }

    @ViewBuilder
    private var captureSurface: some View {
        if mode == .ar && cameraPosition == .back {
            PicoARCameraBackgroundView { snapshotter in
                DispatchQueue.main.async {
                    takeBackgroundSnapshot = snapshotter
                }
            }
            .id("pico_ar_back")
        } else {
            PicoCameraPreviewView(position: cameraPosition == .front ? .front : .back) { snapshotter in
                DispatchQueue.main.async {
                    takeBackgroundSnapshot = snapshotter
                }
            }
            .id("pico_camera_\(cameraPosition == .front ? "front" : "back")_\(mode.rawValue)")
        }
    }

    private var controlsArea: some View {
        VStack(spacing: 26) {
            PicoCameraModeSelector(selection: $mode, isDisabled: isCapturing || isPrinting)
                .frame(maxWidth: 260)

            HStack(alignment: .center, spacing: 58) {
                Button {
                    // 見た目だけのフラッシュOFFボタン。実撮影は常に flashMode = .off。
                } label: {
                    PicoRoundControlButton(
                        systemImage: "bolt.slash.fill",
                        size: 58,
                        fill: Color(red: 0.47, green: 0.55, blue: 0.18),
                        foreground: Color.black.opacity(0.50),
                        lineWidth: 0
                    )
                }
                .disabled(true)
                .opacity(0.90)

                Button {
                    captureAndPrint()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color(red: 1.0, green: 0.20, blue: 0.16))
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
                .disabled(isCapturing || isPrinting || takeBackgroundSnapshot == nil)
                .opacity((isCapturing || isPrinting || takeBackgroundSnapshot == nil) ? 0.58 : 1.0)
                .accessibilityLabel("撮影")

                Button {
                    guard cameraRotateEnabled else { return }
                    cameraPosition = cameraPosition == .back ? .front : .back
                    takeBackgroundSnapshot = nil
                } label: {
                    PicoRoundControlButton(
                        systemImage: "arrow.triangle.2.circlepath.camera",
                        size: 58,
                        fill: .clear,
                        foreground: Color.black.opacity(0.58),
                        lineWidth: 3
                    )
                }
                .disabled(!cameraRotateEnabled || isCapturing || isPrinting)
                .opacity((!cameraRotateEnabled || isCapturing || isPrinting) ? 0.36 : 1.0)
                .accessibilityLabel("カメラ切り替え")
            }

            VStack(spacing: 6) {
                Slider(value: $sliderScale, in: 0.55...2.4)
                    .tint(.white.opacity(0.88))
                    .frame(maxWidth: 230)
                Text("CHARACTER SIZE")
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(.white.opacity(0.74))
            }
            .opacity(isSlotExpanded ? 0 : 1)
            .animation(.easeInOut(duration: 0.18), value: isSlotExpanded)
        }
    }

    private var topCloseButton: some View {
        Button(action: onCancel) {
            Image(systemName: "xmark")
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(Color.black.opacity(0.24), in: Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .opacity(isPrinting ? 0.35 : 1.0)
        .disabled(isPrinting)
        .accessibilityLabel("閉じる")
    }

    private var appMark: some View {
        VStack(spacing: -5) {
            Text("MeMo")
                .font(.system(size: 32, weight: .black, design: .rounded))
            Text("cam")
                .font(.system(size: 24, weight: .black, design: .rounded))
        }
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.15), radius: 1, x: 0, y: 1)
        .opacity(isPrinting ? 0.60 : 1.0)
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
                                Image(uiImage: photo.image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 112)
                                    .shadow(color: .black.opacity(0.22), radius: 5, x: 0, y: 4)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 18)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(red: 0.16, green: 0.08, blue: 0.14).opacity(0.96))
                .shadow(color: .black.opacity(0.42), radius: 8, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.black.opacity(0.40), lineWidth: 2)
        )
    }

    private func printingPhotoLayer(image: UIImage, screenSize: CGSize) -> some View {
        let width = min(screenSize.width * 0.64, 315)
        let startY = safeAreaInsets.top + 48
        let endY = min(screenSize.height * 0.40, 360)
        let y = startY + ((endY - startY) * printProgress)

        return Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .frame(width: width)
            .rotationEffect(.degrees(Double(-2.0 + (printProgress * 2.0))))
            .opacity(printProgress < 0.03 ? 0 : 1)
            .shadow(color: .black.opacity(0.28), radius: 16, x: 0, y: 10)
            .position(x: screenSize.width * 0.5, y: y)
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
                    characterScale = max(0.55, min(2.4, lastScale * value))
                }
                .onEnded { _ in
                    lastScale = characterScale
                }
        )
    }

    private func captureAndPrint() {
        guard !isCapturing, !isPrinting else { return }
        guard let takeBackgroundSnapshot else { return }
        guard lastPreviewSize.width > 1, lastPreviewSize.height > 1 else { return }

        isCapturing = true

        let fixedCharacterOffset = characterOffset
        let fixedCharacterScale = characterScale
        let fixedCharacterAssetName = characterAssetName
        let fixedPreviewSize = lastPreviewSize
        let fixedMetrics = currentMetricValues

        takeBackgroundSnapshot { background in
            defer {
                DispatchQueue.main.async {
                    isCapturing = false
                }
            }

            guard let background else { return }

            let normalizedBackground = background
                .picoFixedOrientation()
                .picoCroppedToAspectFill(of: fixedPreviewSize)
                ?? background.picoFixedOrientation()

            let composed = PicoCameraImageComposer.composeScene(
                background: normalizedBackground,
                previewSize: fixedPreviewSize,
                characterAssetName: fixedCharacterAssetName,
                characterOffset: fixedCharacterOffset,
                characterScale: fixedCharacterScale,
                steps: fixedMetrics.steps
            )

            let polaroid = PicoCameraImageComposer.makePolaroid(from: composed)

            Task { @MainActor in
                startPrintAnimation(
                    finalImage: polaroid,
                    placeName: nil,
                    latitude: nil,
                    longitude: nil
                )
            }
        }
    }

    @MainActor
    private func startPrintAnimation(
        finalImage: UIImage,
        placeName: String?,
        latitude: Double?,
        longitude: Double?
    ) {
        guard !isPrinting else { return }

        printingPhoto = finalImage
        printProgress = 0
        isPrinting = true

        withAnimation(.spring(response: 0.30, dampingFraction: 0.82)) {
            isSlotExpanded = true
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 180_000_000)

            withAnimation(.easeOut(duration: 1.05)) {
                printProgress = 1
            }

            try? await Task.sleep(nanoseconds: 1_120_000_000)

            let printed = PicoPrintedPhoto(image: finalImage, date: Date())
            withAnimation(.spring(response: 0.36, dampingFraction: 0.82)) {
                recentPhotos.insert(printed, at: 0)
                if recentPhotos.count > 20 {
                    recentPhotos = Array(recentPhotos.prefix(20))
                }
            }

            if let onCaptureWithPlace {
                onCaptureWithPlace(finalImage, placeName, latitude, longitude)
            } else {
                onCapture(finalImage)
            }

            try? await Task.sleep(nanoseconds: 160_000_000)

            withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                isSlotExpanded = false
            }

            try? await Task.sleep(nanoseconds: 220_000_000)
            printingPhoto = nil
            printProgress = 0
            isPrinting = false
        }
    }

    private func deletePhoto(_ photo: PicoPrintedPhoto) {
        withAnimation(.easeInOut(duration: 0.18)) {
            recentPhotos.removeAll { $0.id == photo.id }
            selectedPhoto = nil
        }
    }

    private static func currentWindowSafeAreaInsets() -> UIEdgeInsets {
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.compactMap { $0 as? UIWindowScene }.first
        let window = windowScene?.windows.first(where: { $0.isKeyWindow }) ?? windowScene?.windows.first
        return window?.safeAreaInsets ?? .zero
    }
}

private struct PicoPrintedPhoto: Identifiable, Equatable {
    let id = UUID()
    let image: UIImage
    let date: Date

    static func == (lhs: PicoPrintedPhoto, rhs: PicoPrintedPhoto) -> Bool {
        lhs.id == rhs.id
    }
}

private struct PicoCameraModeSelector: View {
    @Binding var selection: CameraStyleView.Mode
    let isDisabled: Bool

    var body: some View {
        HStack(spacing: 6) {
            ForEach(CameraStyleView.Mode.allCases) { mode in
                Button {
                    guard !isDisabled else { return }
                    withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
                        selection = mode
                    }
                } label: {
                    Text(mode.shortTitle)
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .tracking(0.8)
                        .foregroundStyle(selection == mode ? .black : .white.opacity(0.80))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            Capsule()
                                .fill(selection == mode ? Color.white.opacity(0.92) : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(5)
        .background(Color.black.opacity(0.25), in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1))
        .opacity(isDisabled ? 0.48 : 1.0)
    }
}

private struct PicoRoundControlButton: View {
    let systemImage: String
    let size: CGFloat
    let fill: Color
    let foreground: Color
    let lineWidth: CGFloat

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.34, weight: .heavy))
            .foregroundStyle(foreground)
            .frame(width: size, height: size)
            .background(fill, in: Circle())
            .overlay(Circle().stroke(foreground.opacity(0.82), lineWidth: lineWidth))
            .shadow(color: .black.opacity(0.24), radius: 5, x: 0, y: 4)
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
            Color(red: 0.09, green: 0.04, blue: 0.08)
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
                            .overlay(Circle().stroke(Color.purple.opacity(0.32), lineWidth: 2))
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
                    .overlay(Capsule().stroke(Color.purple.opacity(0.32), lineWidth: 2))

                    Spacer()

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 23, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 56, height: 56)
                            .background(Color.white.opacity(0.06), in: Circle())
                            .overlay(Circle().stroke(Color.purple.opacity(0.32), lineWidth: 2))
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
    static func composeScene(
        background: UIImage,
        previewSize: CGSize,
        characterAssetName: String,
        characterOffset: CGSize,
        characterScale: CGFloat,
        steps: Int
    ) -> UIImage {
        let backgroundSize = background.size
        let scaleX = backgroundSize.width / max(previewSize.width, 1)
        let scaleY = backgroundSize.height / max(previewSize.height, 1)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = background.scale
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: backgroundSize, format: format)
        return renderer.image { context in
            background.draw(in: CGRect(origin: .zero, size: backgroundSize))

            if let characterImage = UIImage(named: characterAssetName) {
                let baseCharacterWidth = min(previewSize.width * 0.32, 132)
                let characterWidth = baseCharacterWidth * characterScale * scaleX
                let characterAspect = characterImage.size.height / max(characterImage.size.width, 1)
                let characterHeight = characterWidth * characterAspect
                let centerX = (previewSize.width * 0.5 + characterOffset.width) * scaleX
                let centerY = (previewSize.height * 0.5 + characterOffset.height) * scaleY
                let rect = CGRect(
                    x: centerX - characterWidth * 0.5,
                    y: centerY - characterHeight * 0.5,
                    width: characterWidth,
                    height: characterHeight
                )

                context.cgContext.saveGState()
                context.cgContext.setShadow(offset: CGSize(width: 0, height: 8), blur: 12, color: UIColor.black.withAlphaComponent(0.24).cgColor)
                characterImage.draw(in: rect)
                context.cgContext.restoreGState()
            }

            drawTinyStepStamp(steps: steps, canvasSize: backgroundSize)
        }
    }

    static func makePolaroid(from image: UIImage) -> UIImage {
        let outputSize = CGSize(width: 1200, height: 1380)
        let photoRect = CGRect(x: 92, y: 126, width: 1016, height: 1016)
        let paperRect = CGRect(origin: .zero, size: outputSize)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: outputSize, format: format)
        return renderer.image { context in
            let cg = context.cgContext

            UIColor(red: 0.94, green: 0.96, blue: 0.95, alpha: 1).setFill()
            cg.fill(paperRect)

            let paperGradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [
                    UIColor.white.withAlphaComponent(0.78).cgColor,
                    UIColor(red: 0.90, green: 0.93, blue: 0.92, alpha: 1).cgColor
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

            addPaperTexture(context: context, size: outputSize)

            let fixed = image.picoFixedOrientation()
            let cropped = fixed.picoCroppedToAspectFill(of: photoRect.size) ?? fixed

            cg.saveGState()
            cg.addPath(UIBezierPath(roundedRect: photoRect, cornerRadius: 7).cgPath)
            cg.clip()
            cropped.draw(in: photoRect)

            UIColor(red: 1.0, green: 0.96, blue: 0.78, alpha: 0.05).setFill()
            cg.fill(photoRect)
            cg.restoreGState()

            UIColor.black.withAlphaComponent(0.15).setStroke()
            UIBezierPath(roundedRect: photoRect, cornerRadius: 7).stroke()

            let bottomGloss = CGRect(x: 0, y: outputSize.height - 82, width: outputSize.width, height: 82)
            UIColor.black.withAlphaComponent(0.08).setFill()
            cg.fill(bottomGloss)
        }
    }

    private static func drawTinyStepStamp(steps: Int, canvasSize: CGSize) {
        guard steps > 0 else { return }

        let text = "\(steps) steps"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: max(20, canvasSize.width * 0.035), weight: .heavy),
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

    private static func addPaperTexture(context: UIGraphicsImageRendererContext, size: CGSize) {
        let cg = context.cgContext
        cg.saveGState()
        for index in 0..<900 {
            let x = CGFloat((index * 37) % Int(size.width))
            let y = CGFloat((index * 71) % Int(size.height))
            let alpha = CGFloat(0.012 + (Double(index % 7) * 0.003))
            UIColor.black.withAlphaComponent(alpha).setFill()
            cg.fill(CGRect(x: x, y: y, width: 1, height: 1))
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
    let onSnapshotReady: (@escaping Snapshotter) -> Void

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

            guard AVCaptureDevice.authorizationStatus(for: .video) != .denied else { return }

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
                guard AVCaptureDevice.authorizationStatus(for: .video) != .denied else { return }
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

private struct PicoARCameraBackgroundView: UIViewRepresentable {
    typealias Snapshotter = CameraStyleView.Snapshotter

    let onSnapshotReady: (@escaping Snapshotter) -> Void

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
            cropRect = CGRect(x: (imageWidth - newWidth) * 0.5, y: 0, width: newWidth, height: imageHeight)
        } else {
            let newHeight = imageWidth / targetAspect
            cropRect = CGRect(x: 0, y: (imageHeight - newHeight) * 0.5, width: imageWidth, height: newHeight)
        }

        guard let cropped = cgImage.cropping(to: cropRect.integral) else { return nil }
        return UIImage(cgImage: cropped, scale: scale, orientation: .up)
    }
}
