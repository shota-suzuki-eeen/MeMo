//
//  MetalCircularLiquidLayer.swift
//  MeMo
//
//  円形メーター内の液体部分だけをMetalで描画するための部品です。
//  アセット画像へのマスクは行わず、呼び出し側で .clipShape(Circle()) を適用します。
//
//  2026/04/28 update:
//  メーター値の増減時に液面が瞬間移動しないよう、Renderer内部で
//  targetFillFraction に向かって renderedFillFraction を補間します。
//
//  2026/05 update:
//  バックグラウンド中は波の描画時間を進めず、復帰時に一気に波が進んだように
//  見える挙動を防ぎます。
//
//  2026/07/14 update:
//  波を常時動かしたまま発熱を抑えるため、通常時15fps、値・色の変化中30fpsへ
//  自動切り替えします。低電力モードでは10fps、高温時は8fpsへ降速します。
//  Metal描画解像度は最大2xに制限し、非表示・バックグラウンド時は完全停止します。
//
//  2026/07/29 update:
//  iPhoneとApple Watchのメーター表現を統一するため、液体表現を
//  「2つの波・3色グラデーション・薄い白波」に簡略化しました。
//  既存のMetal描画、省電力制御、温度制御、液量・色の補間は維持します.
//

import SwiftUI
import Foundation
import UIKit
import MetalKit
import simd

enum MetalCircularLiquidQuality: Equatable {
    case normal
    case reduced
    case thermal
    case still

    var steadyFramesPerSecond: Int {
        switch self {
        case .normal:
            return 15
        case .reduced:
            return 10
        case .thermal:
            return 8
        case .still:
            return 1
        }
    }

    var transitionFramesPerSecond: Int {
        switch self {
        case .normal:
            return 30
        case .reduced:
            return 15
        case .thermal:
            return 12
        case .still:
            return 1
        }
    }

    var motionScale: Float {
        switch self {
        case .normal:
            return 1.0
        case .reduced:
            return 0.78
        case .thermal:
            return 0.62
        case .still:
            return 0.0
        }
    }
}

struct MetalCircularLiquidLayer: View {
    let fillFraction: CGFloat
    let mainColor: Color
    let deepColor: Color
    let highlightColor: Color
    let isActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    @State private var isLowPowerModeEnabled =
        ProcessInfo.processInfo.isLowPowerModeEnabled
    @State private var thermalState =
        ProcessInfo.processInfo.thermalState

    private var clampedFillFraction: CGFloat {
        max(0, min(1, fillFraction))
    }

    private var quality: MetalCircularLiquidQuality {
        if reduceMotion {
            return .still
        }

        switch thermalState {
        case .serious, .critical:
            return .thermal
        case .fair:
            return .reduced
        case .nominal:
            return isLowPowerModeEnabled ? .reduced : .normal
        @unknown default:
            return isLowPowerModeEnabled ? .reduced : .normal
        }
    }

    private var shouldAnimate: Bool {
        isActive && scenePhase == .active && quality != .still
    }

    var body: some View {
        Group {
            if MetalCircularLiquidRepresentable.isMetalAvailable {
                MetalCircularLiquidRepresentable(
                    fillFraction: clampedFillFraction,
                    mainColor: mainColor,
                    deepColor: deepColor,
                    highlightColor: highlightColor,
                    isActive: shouldAnimate,
                    quality: quality
                )
            } else {
                SwiftUICircularLiquidFallback(
                    fillFraction: clampedFillFraction,
                    mainColor: mainColor,
                    deepColor: deepColor,
                    highlightColor: highlightColor,
                    isActive: shouldAnimate,
                    framesPerSecond: quality.steadyFramesPerSecond,
                    motionScale: CGFloat(quality.motionScale)
                )
            }
        }
        .compositingGroup()
        .accessibilityHidden(true)
        .onReceive(
            NotificationCenter.default.publisher(
                for: .NSProcessInfoPowerStateDidChange
            )
        ) { _ in
            isLowPowerModeEnabled =
                ProcessInfo.processInfo.isLowPowerModeEnabled
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: ProcessInfo.thermalStateDidChangeNotification
            )
        ) { _ in
            thermalState = ProcessInfo.processInfo.thermalState
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }

            isLowPowerModeEnabled =
                ProcessInfo.processInfo.isLowPowerModeEnabled
            thermalState =
                ProcessInfo.processInfo.thermalState
        }
    }
}

private struct MetalCircularLiquidRepresentable: UIViewRepresentable {
    static var isMetalAvailable: Bool {
        MTLCreateSystemDefaultDevice() != nil
    }

    let fillFraction: CGFloat
    let mainColor: Color
    let deepColor: Color
    let highlightColor: Color
    let isActive: Bool
    let quality: MetalCircularLiquidQuality

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> MTKView {
        let device = MTLCreateSystemDefaultDevice()
        let view = MTKView(frame: .zero, device: device)

        view.isOpaque = false
        view.layer.isOpaque = false
        view.backgroundColor = .clear
        view.clearColor = MTLClearColor(
            red: 0,
            green: 0,
            blue: 0,
            alpha: 0
        )
        view.colorPixelFormat = .bgra8Unorm
        view.framebufferOnly = true
        view.autoResizeDrawable = true
        view.preferredFramesPerSecond =
            quality.steadyFramesPerSecond

        // 小さな円形ゲージでは3x描画との差が視認しづらいため、
        // 最大2xに制限してフラグメント処理量と発熱を抑えます。
        view.contentScaleFactor =
            min(UIScreen.main.scale, 2.0)

        view.enableSetNeedsDisplay = true
        view.isPaused = true

        guard let device else {
            return view
        }

        let renderer = MetalCircularLiquidRenderer(
            device: device,
            colorPixelFormat: view.colorPixelFormat
        )

        context.coordinator.renderer = renderer
        view.delegate = renderer

        updateRenderer(renderer, view: view)
        return view
    }

    func updateUIView(
        _ view: MTKView,
        context: Context
    ) {
        guard let renderer =
                context.coordinator.renderer else {
            view.isPaused = true
            return
        }

        updateRenderer(renderer, view: view)
    }

    static func dismantleUIView(
        _ uiView: MTKView,
        coordinator: Coordinator
    ) {
        uiView.isPaused = true
        uiView.enableSetNeedsDisplay = true
        uiView.delegate = nil
        coordinator.renderer = nil
    }

    private func updateRenderer(
        _ renderer: MetalCircularLiquidRenderer,
        view: MTKView
    ) {
        let safeFill =
            Float(max(0, min(1, fillFraction)))
        let allowsSmoothing =
            isActive && quality != .still
        let targetMotionScale: Float =
            (allowsSmoothing && safeFill > 0.001)
            ? quality.motionScale
            : 0.0

        let recommendedFramesPerSecond =
            renderer.update(
                targetFillFraction: safeFill,
                targetMainColor: mainColor.metalRGBA,
                targetDeepColor: deepColor.metalRGBA,
                targetHighlightColor:
                    highlightColor.metalRGBA,
                targetMotionScale: targetMotionScale,
                allowsSmoothing: allowsSmoothing,
                steadyFramesPerSecond:
                    quality.steadyFramesPerSecond,
                transitionFramesPerSecond:
                    quality.transitionFramesPerSecond
            )

        if view.preferredFramesPerSecond !=
            recommendedFramesPerSecond {
            view.preferredFramesPerSecond =
                recommendedFramesPerSecond
        }

        if renderer.needsContinuousDrawing {
            view.enableSetNeedsDisplay = false
            view.isPaused = false
        } else {
            view.enableSetNeedsDisplay = true
            view.isPaused = true
            view.setNeedsDisplay()
        }
    }

    final class Coordinator {
        var renderer: MetalCircularLiquidRenderer?
    }
}

private final class MetalCircularLiquidRenderer:
    NSObject,
    MTKViewDelegate {

    private struct RenderState {
        var targetFillFraction: Float = 0.0
        var renderedFillFraction: Float = 0.0

        var targetMotionScale: Float = 0.0
        var renderedMotionScale: Float = 0.0

        var targetMainColor =
            SIMD4<Float>(0.12, 0.50, 0.18, 1.0)
        var targetDeepColor =
            SIMD4<Float>(0.03, 0.16, 0.05, 1.0)
        var targetHighlightColor =
            SIMD4<Float>(0.55, 0.92, 0.58, 1.0)

        var renderedMainColor =
            SIMD4<Float>(0.12, 0.50, 0.18, 1.0)
        var renderedDeepColor =
            SIMD4<Float>(0.03, 0.16, 0.05, 1.0)
        var renderedHighlightColor =
            SIMD4<Float>(0.55, 0.92, 0.58, 1.0)

        var renderedTime: Float = 0.0
        var allowsSmoothing = false
        var hasReceivedFirstState = false

        var steadyFramesPerSecond = 15
        var transitionFramesPerSecond = 30
    }

    // CircularLiquidShaders.metal の同名構造体と
    // フィールド順・アラインメントを一致させます。
    private struct CircularLiquidUniforms {
        var time: Float
        var fillFraction: Float
        var padding: SIMD2<Float>
        var mainColor: SIMD4<Float>
        var deepColor: SIMD4<Float>
        var highlightColor: SIMD4<Float>
    }

    private let commandQueue: MTLCommandQueue?
    private let pipelineState: MTLRenderPipelineState?
    private let lock = NSLock()

    private var state = RenderState()
    private var lastFrameTimestamp: CFTimeInterval?

    private let fillSnapThreshold: Float = 0.0008
    private let colorSnapThreshold: Float = 0.0020
    private let motionSnapThreshold: Float = 0.0010

    init(
        device: MTLDevice,
        colorPixelFormat: MTLPixelFormat
    ) {
        commandQueue = device.makeCommandQueue()

        if let library = device.makeDefaultLibrary(),
           let vertexFunction =
                library.makeFunction(
                    name: "circularLiquidVertex"
                ),
           let fragmentFunction =
                library.makeFunction(
                    name: "circularLiquidFragment"
                ) {

            let descriptor =
                MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = vertexFunction
            descriptor.fragmentFunction = fragmentFunction
            descriptor.colorAttachments[0].pixelFormat =
                colorPixelFormat
            descriptor.colorAttachments[0]
                .isBlendingEnabled = true
            descriptor.colorAttachments[0]
                .rgbBlendOperation = .add
            descriptor.colorAttachments[0]
                .alphaBlendOperation = .add
            descriptor.colorAttachments[0]
                .sourceRGBBlendFactor = .sourceAlpha
            descriptor.colorAttachments[0]
                .destinationRGBBlendFactor =
                    .oneMinusSourceAlpha
            descriptor.colorAttachments[0]
                .sourceAlphaBlendFactor = .one
            descriptor.colorAttachments[0]
                .destinationAlphaBlendFactor =
                    .oneMinusSourceAlpha

            pipelineState =
                try? device.makeRenderPipelineState(
                    descriptor: descriptor
                )
        } else {
            pipelineState = nil
            print(
                "⚠️ CircularLiquidShaders.metal がアプリターゲットに含まれていないか、関数名が一致していません。"
            )
        }

        super.init()
    }

    var needsContinuousDrawing: Bool {
        lock.lock()
        let result =
            shouldContinueDrawingLocked(state)
        lock.unlock()
        return result
    }

    @discardableResult
    func update(
        targetFillFraction: Float,
        targetMainColor: SIMD4<Float>,
        targetDeepColor: SIMD4<Float>,
        targetHighlightColor: SIMD4<Float>,
        targetMotionScale: Float,
        allowsSmoothing: Bool,
        steadyFramesPerSecond: Int,
        transitionFramesPerSecond: Int
    ) -> Int {
        lock.lock()
        defer { lock.unlock() }

        let safeTargetFill =
            max(0, min(1, targetFillFraction))
        let safeMotionScale =
            max(0, targetMotionScale)

        state.targetFillFraction =
            safeTargetFill
        state.targetMainColor =
            targetMainColor
        state.targetDeepColor =
            targetDeepColor
        state.targetHighlightColor =
            targetHighlightColor
        state.targetMotionScale =
            safeMotionScale
        state.allowsSmoothing =
            allowsSmoothing
        state.steadyFramesPerSecond =
            max(1, steadyFramesPerSecond)
        state.transitionFramesPerSecond =
            max(
                state.steadyFramesPerSecond,
                transitionFramesPerSecond
            )

        // 初回表示、Home非表示中、バックグラウンド中、
        // Reduce Motion中は即座に現在値へ同期します。
        if !state.hasReceivedFirstState ||
            !allowsSmoothing {

            state.renderedFillFraction =
                safeTargetFill
            state.renderedMainColor =
                targetMainColor
            state.renderedDeepColor =
                targetDeepColor
            state.renderedHighlightColor =
                targetHighlightColor
            state.renderedMotionScale =
                safeMotionScale
            state.hasReceivedFirstState = true
            lastFrameTimestamp = nil
        }

        return recommendedFramesPerSecondLocked(
            state
        )
    }

    func mtkView(
        _ view: MTKView,
        drawableSizeWillChange size: CGSize
    ) {}

    func draw(in view: MTKView) {
        guard
            let pipelineState,
            let commandQueue,
            let descriptor =
                view.currentRenderPassDescriptor,
            let drawable = view.currentDrawable,
            let commandBuffer =
                commandQueue.makeCommandBuffer(),
            let encoder =
                commandBuffer.makeRenderCommandEncoder(
                    descriptor: descriptor
                )
        else {
            return
        }

        let now = CACurrentMediaTime()
        let current = advanceState(now: now)

        var uniforms = CircularLiquidUniforms(
            time: current.renderedTime,
            fillFraction:
                current.renderedFillFraction,
            padding: .zero,
            mainColor:
                current.renderedMainColor,
            deepColor:
                current.renderedDeepColor,
            highlightColor:
                current.renderedHighlightColor
        )

        encoder.setRenderPipelineState(
            pipelineState
        )
        encoder.setFragmentBytes(
            &uniforms,
            length:
                MemoryLayout<CircularLiquidUniforms>
                .stride,
            index: 0
        )
        encoder.drawPrimitives(
            type: .triangle,
            vertexStart: 0,
            vertexCount: 6
        )
        encoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()

        let desiredFramesPerSecond =
            recommendedFramesPerSecond(
                for: current
            )

        if view.preferredFramesPerSecond !=
            desiredFramesPerSecond {

            DispatchQueue.main.async {
                [weak view] in

                guard
                    let view,
                    view.preferredFramesPerSecond !=
                        desiredFramesPerSecond
                else {
                    return
                }

                view.preferredFramesPerSecond =
                    desiredFramesPerSecond
            }
        }

        if !shouldContinueDrawing(current) {
            DispatchQueue.main.async {
                [weak view] in

                guard let view else { return }

                view.enableSetNeedsDisplay = true
                view.isPaused = true
                view.setNeedsDisplay()
            }
        }
    }

    private func advanceState(
        now: CFTimeInterval
    ) -> RenderState {
        lock.lock()
        defer { lock.unlock() }

        guard state.allowsSmoothing else {
            lastFrameTimestamp = nil
            state.renderedMotionScale = 0
            return state
        }

        let rawDeltaTime: Float

        if let lastFrameTimestamp {
            rawDeltaTime =
                Float(
                    max(
                        0,
                        now - lastFrameTimestamp
                    )
                )
        } else {
            rawDeltaTime =
                1.0 /
                Float(
                    max(
                        state.transitionFramesPerSecond,
                        1
                    )
                )
        }

        // 8fps動作にも対応しつつ、
        // 長時間停止後の大ジャンプを防ぎます。
        let deltaTime =
            min(rawDeltaTime, 1.0 / 6.0)
        lastFrameTimestamp = now

        let isIncreasing =
            state.targetFillFraction >=
            state.renderedFillFraction
        let fillResponse: Float =
            isIncreasing ? 3.2 : 4.0
        let colorResponse: Float = 8.0
        let motionResponse: Float = 10.0

        state.renderedFillFraction =
            smoothedScalar(
                current:
                    state.renderedFillFraction,
                target:
                    state.targetFillFraction,
                deltaTime: deltaTime,
                response: fillResponse,
                snapThreshold:
                    fillSnapThreshold
            )

        state.renderedMotionScale =
            smoothedScalar(
                current:
                    state.renderedMotionScale,
                target:
                    state.targetMotionScale,
                deltaTime: deltaTime,
                response: motionResponse,
                snapThreshold:
                    motionSnapThreshold
            )

        state.renderedMainColor =
            smoothedVector(
                current:
                    state.renderedMainColor,
                target:
                    state.targetMainColor,
                deltaTime: deltaTime,
                response: colorResponse,
                snapThreshold:
                    colorSnapThreshold
            )

        state.renderedDeepColor =
            smoothedVector(
                current:
                    state.renderedDeepColor,
                target:
                    state.targetDeepColor,
                deltaTime: deltaTime,
                response: colorResponse,
                snapThreshold:
                    colorSnapThreshold
            )

        state.renderedHighlightColor =
            smoothedVector(
                current:
                    state.renderedHighlightColor,
                target:
                    state.targetHighlightColor,
                deltaTime: deltaTime,
                response: colorResponse,
                snapThreshold:
                    colorSnapThreshold
            )

        // フレーム数ではなく実時間差分で位相を進めるため、
        // 15fpsや8fpsでも波の速度が不自然に遅くなりません。
        state.renderedTime +=
            deltaTime *
            max(0, state.renderedMotionScale)

        return state
    }

    private func smoothedScalar(
        current: Float,
        target: Float,
        deltaTime: Float,
        response: Float,
        snapThreshold: Float
    ) -> Float {
        let difference = target - current

        if abs(difference) <= snapThreshold {
            return target
        }

        let alpha =
            1.0 - exp(-response * deltaTime)
        return current + difference * alpha
    }

    private func smoothedVector(
        current: SIMD4<Float>,
        target: SIMD4<Float>,
        deltaTime: Float,
        response: Float,
        snapThreshold: Float
    ) -> SIMD4<Float> {
        let difference = target - current
        let maxDifference =
            max(
                max(
                    abs(difference.x),
                    abs(difference.y)
                ),
                max(
                    abs(difference.z),
                    abs(difference.w)
                )
            )

        if maxDifference <= snapThreshold {
            return target
        }

        let alpha =
            1.0 - exp(-response * deltaTime)
        return current + difference * alpha
    }

    private func recommendedFramesPerSecond(
        for state: RenderState
    ) -> Int {
        if isTransitioning(state) {
            return state.transitionFramesPerSecond
        }

        return state.steadyFramesPerSecond
    }

    private func recommendedFramesPerSecondLocked(
        _ state: RenderState
    ) -> Int {
        recommendedFramesPerSecond(
            for: state
        )
    }

    private func isTransitioning(
        _ state: RenderState
    ) -> Bool {
        if abs(
            state.targetFillFraction -
            state.renderedFillFraction
        ) > fillSnapThreshold {
            return true
        }

        if abs(
            state.targetMotionScale -
            state.renderedMotionScale
        ) > motionSnapThreshold {
            return true
        }

        if maxColorDifference(
            state.targetMainColor,
            state.renderedMainColor
        ) > colorSnapThreshold {
            return true
        }

        if maxColorDifference(
            state.targetDeepColor,
            state.renderedDeepColor
        ) > colorSnapThreshold {
            return true
        }

        if maxColorDifference(
            state.targetHighlightColor,
            state.renderedHighlightColor
        ) > colorSnapThreshold {
            return true
        }

        return false
    }

    private func shouldContinueDrawing(
        _ state: RenderState
    ) -> Bool {
        if state.renderedMotionScale >
            motionSnapThreshold {
            return true
        }

        return shouldContinueDrawingLocked(
            state
        )
    }

    private func shouldContinueDrawingLocked(
        _ state: RenderState
    ) -> Bool {
        if state.targetMotionScale >
            motionSnapThreshold {
            return true
        }

        return isTransitioning(state)
    }

    private func maxColorDifference(
        _ a: SIMD4<Float>,
        _ b: SIMD4<Float>
    ) -> Float {
        let difference = a - b

        return max(
            max(
                abs(difference.x),
                abs(difference.y)
            ),
            max(
                abs(difference.z),
                abs(difference.w)
            )
        )
    }
}

private struct SwiftUICircularLiquidFallback: View {
    let fillFraction: CGFloat
    let mainColor: Color
    let deepColor: Color
    let highlightColor: Color
    let isActive: Bool
    let framesPerSecond: Int
    let motionScale: CGFloat

    @State private var displayedFillFraction:
        CGFloat = 0
    @State private var waveTime:
        CGFloat = 0
    @State private var lastTimelineDate:
        Date?

    private var clampedFillFraction: CGFloat {
        max(0, min(1, fillFraction))
    }

    var body: some View {
        Group {
            if isActive {
                TimelineView(
                    .animation(
                        minimumInterval:
                            1.0 /
                            Double(
                                max(
                                    framesPerSecond,
                                    1
                                )
                            )
                    )
                ) { timeline in
                    liquidCanvas
                        .onChange(
                            of: timeline.date
                        ) { _, newDate in
                            advanceWaveTimeIfNeeded(
                                now: newDate
                            )
                        }
                }
            } else {
                liquidCanvas
            }
        }
        .onAppear {
            displayedFillFraction =
                clampedFillFraction
            lastTimelineDate = nil
        }
        .onChange(of: isActive) {
            _, newValue in

            if !newValue {
                lastTimelineDate = nil
            }
        }
        .onChange(
            of: clampedFillFraction
        ) { _, newValue in
            guard isActive else {
                displayedFillFraction =
                    newValue
                return
            }

            withAnimation(
                .easeInOut(duration: 0.45)
            ) {
                displayedFillFraction =
                    newValue
            }
        }
    }

    private var liquidCanvas: some View {
        Canvas { context, size in
            let fraction =
                max(
                    0,
                    min(
                        1,
                        displayedFillFraction
                    )
                )

            guard fraction > 0 else {
                return
            }

            let width =
                max(size.width, 1)
            let height =
                max(size.height, 1)
            let phase =
                waveTime * 1.35
            let amplitude =
                max(1.5, height * 0.045)

            let primaryPath =
                makeLiquidPath(
                    width: width,
                    height: height,
                    fillFraction: fraction,
                    phase: phase,
                    amplitude: amplitude
                )

            context.fill(
                primaryPath,
                with: .linearGradient(
                    Gradient(
                        colors: [
                            highlightColor
                                .opacity(0.96),
                            mainColor
                                .opacity(0.98),
                            deepColor
                                .opacity(0.98)
                        ]
                    ),
                    startPoint: CGPoint(
                        x: width * 0.5,
                        y: height *
                            (1 - fraction)
                    ),
                    endPoint: CGPoint(
                        x: width * 0.5,
                        y: height
                    )
                )
            )

            let secondaryFraction =
                max(0, fraction - 0.02)

            if secondaryFraction > 0.001 {
                let secondaryPath =
                    makeLiquidPath(
                        width: width,
                        height: height,
                        fillFraction:
                            secondaryFraction,
                        phase: phase + 1.65,
                        amplitude:
                            amplitude * 1.35
                    )

                context.fill(
                    secondaryPath,
                    with: .color(
                        Color.white.opacity(0.10)
                    )
                )
            }
        }
    }

    private func makeLiquidPath(
        width: CGFloat,
        height: CGFloat,
        fillFraction: CGFloat,
        phase: CGFloat,
        amplitude: CGFloat
    ) -> Path {
        var path = Path()

        let safeFill =
            max(0, min(1, fillFraction))

        guard safeFill > 0.001 else {
            return path
        }

        let surfaceBaseY =
            height - (height * safeFill)
        let sampleStep =
            max(1, width / 32)

        path.move(
            to: CGPoint(x: 0, y: height)
        )

        var x: CGFloat = 0

        while x <= width {
            let normalizedX =
                x / width
            let wave =
                sin(
                    normalizedX *
                    .pi *
                    2 *
                    1.10 +
                    phase
                ) *
                amplitude
                +
                sin(
                    normalizedX *
                    .pi *
                    2 *
                    2.15 -
                    phase *
                    0.76 +
                    1.4
                ) *
                amplitude *
                0.45

            let y =
                min(
                    height,
                    max(
                        0,
                        surfaceBaseY + wave
                    )
                )

            path.addLine(
                to: CGPoint(x: x, y: y)
            )

            x += sampleStep
        }

        let finalWave =
            sin(
                .pi * 2 * 1.10 +
                phase
            ) *
            amplitude
            +
            sin(
                .pi * 2 * 2.15 -
                phase * 0.76 +
                1.4
            ) *
            amplitude *
            0.45

        let finalY =
            min(
                height,
                max(
                    0,
                    surfaceBaseY + finalWave
                )
            )

        path.addLine(
            to: CGPoint(
                x: width,
                y: finalY
            )
        )
        path.addLine(
            to: CGPoint(
                x: width,
                y: height
            )
        )
        path.closeSubpath()

        return path
    }

    private func advanceWaveTimeIfNeeded(
        now: Date
    ) {
        guard isActive else {
            lastTimelineDate = nil
            return
        }

        let rawDeltaTime: TimeInterval

        if let lastTimelineDate {
            rawDeltaTime =
                max(
                    0,
                    now.timeIntervalSince(
                        lastTimelineDate
                    )
                )
        } else {
            rawDeltaTime =
                1.0 /
                Double(
                    max(
                        framesPerSecond,
                        1
                    )
                )
        }

        lastTimelineDate = now

        let deltaTime =
            min(
                rawDeltaTime,
                1.0 / 6.0
            )

        waveTime +=
            CGFloat(deltaTime) *
            max(motionScale, 0)
    }
}

private extension Color {
    var metalRGBA: SIMD4<Float> {
        let uiColor = UIColor(self)

        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        if uiColor.getRed(
            &red,
            green: &green,
            blue: &blue,
            alpha: &alpha
        ) {
            return SIMD4<Float>(
                Float(red),
                Float(green),
                Float(blue),
                Float(alpha)
            )
        }

        return SIMD4<Float>(
            1.0,
            1.0,
            1.0,
            1.0
        )
    }
}
