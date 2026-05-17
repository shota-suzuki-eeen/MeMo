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

import SwiftUI
import Foundation
import UIKit
import MetalKit
import simd

enum MetalCircularLiquidQuality: Equatable {
    case balanced
    case low
    case still

    var preferredFramesPerSecond: Int {
        switch self {
        case .balanced:
            return 30
        case .low:
            return 15
        case .still:
            return 1
        }
    }

    var motionScale: Float {
        switch self {
        case .balanced:
            return 1.0
        case .low:
            return 0.45
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

    private var clampedFillFraction: CGFloat {
        max(0, min(1, fillFraction))
    }

    private var quality: MetalCircularLiquidQuality {
        if reduceMotion { return .still }
        if ProcessInfo.processInfo.isLowPowerModeEnabled { return .low }
        return .balanced
    }

    var body: some View {
        Group {
            if MetalCircularLiquidRepresentable.isMetalAvailable {
                MetalCircularLiquidRepresentable(
                    fillFraction: clampedFillFraction,
                    mainColor: mainColor,
                    deepColor: deepColor,
                    highlightColor: highlightColor,
                    isActive: isActive,
                    quality: quality
                )
            } else {
                SwiftUICircularLiquidFallback(
                    fillFraction: clampedFillFraction,
                    mainColor: mainColor,
                    deepColor: deepColor,
                    highlightColor: highlightColor,
                    isActive: isActive && quality != .still
                )
            }
        }
        .compositingGroup()
        .accessibilityHidden(true)
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
        view.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        view.colorPixelFormat = .bgra8Unorm
        view.framebufferOnly = true
        view.preferredFramesPerSecond = quality.preferredFramesPerSecond
        view.contentScaleFactor = UIScreen.main.scale
        view.enableSetNeedsDisplay = false
        view.isPaused = false

        guard let device else {
            view.isPaused = true
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

    func updateUIView(_ view: MTKView, context: Context) {
        view.preferredFramesPerSecond = quality.preferredFramesPerSecond

        guard let renderer = context.coordinator.renderer else { return }
        updateRenderer(renderer, view: view)
    }

    private func updateRenderer(_ renderer: MetalCircularLiquidRenderer, view: MTKView) {
        let safeFill = Float(max(0, min(1, fillFraction)))
        let allowsSmoothing = isActive && quality != .still
        let targetMotionScale: Float = (allowsSmoothing && safeFill > 0.001) ? quality.motionScale : 0.0

        renderer.update(
            targetFillFraction: safeFill,
            targetMainColor: mainColor.metalRGBA,
            targetDeepColor: deepColor.metalRGBA,
            targetHighlightColor: highlightColor.metalRGBA,
            targetMotionScale: targetMotionScale,
            allowsSmoothing: allowsSmoothing
        )

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

private final class MetalCircularLiquidRenderer: NSObject, MTKViewDelegate {
    private struct RenderState {
        var targetFillFraction: Float = 0.0
        var renderedFillFraction: Float = 0.0

        var targetMotionScale: Float = 1.0
        var renderedMotionScale: Float = 1.0

        var targetMainColor: SIMD4<Float> = SIMD4<Float>(0.12, 0.50, 0.18, 1.0)
        var targetDeepColor: SIMD4<Float> = SIMD4<Float>(0.03, 0.16, 0.05, 1.0)
        var targetHighlightColor: SIMD4<Float> = SIMD4<Float>(0.55, 0.92, 0.58, 1.0)

        var renderedMainColor: SIMD4<Float> = SIMD4<Float>(0.12, 0.50, 0.18, 1.0)
        var renderedDeepColor: SIMD4<Float> = SIMD4<Float>(0.03, 0.16, 0.05, 1.0)
        var renderedHighlightColor: SIMD4<Float> = SIMD4<Float>(0.55, 0.92, 0.58, 1.0)

        var renderedTime: Float = 0.0
        var allowsSmoothing: Bool = true
        var hasReceivedFirstState: Bool = false
    }

    private struct CircularLiquidUniforms {
        var time: Float
        var fillFraction: Float
        var aspectRatio: Float
        var motionScale: Float
        var mainColor: SIMD4<Float>
        var deepColor: SIMD4<Float>
        var highlightColor: SIMD4<Float>
        var foamColor: SIMD4<Float>
    }

    private let commandQueue: MTLCommandQueue?
    private let pipelineState: MTLRenderPipelineState?
    private let lock = NSLock()
    private var state = RenderState()
    private var lastFrameTimestamp: CFTimeInterval?

    private let fillSnapThreshold: Float = 0.0008
    private let colorSnapThreshold: Float = 0.0020

    init(device: MTLDevice, colorPixelFormat: MTLPixelFormat) {
        commandQueue = device.makeCommandQueue()

        if let library = device.makeDefaultLibrary(),
           let vertexFunction = library.makeFunction(name: "circularLiquidVertex"),
           let fragmentFunction = library.makeFunction(name: "circularLiquidFragment") {
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = vertexFunction
            descriptor.fragmentFunction = fragmentFunction
            descriptor.colorAttachments[0].pixelFormat = colorPixelFormat
            descriptor.colorAttachments[0].isBlendingEnabled = true
            descriptor.colorAttachments[0].rgbBlendOperation = .add
            descriptor.colorAttachments[0].alphaBlendOperation = .add
            descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
            descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
            descriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
            descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
            pipelineState = try? device.makeRenderPipelineState(descriptor: descriptor)
        } else {
            pipelineState = nil
            print("⚠️ CircularLiquidShaders.metal がアプリターゲットに含まれていないか、関数名が一致していません。")
        }

        super.init()
    }

    var needsContinuousDrawing: Bool {
        lock.lock()
        let result = shouldContinueDrawingLocked(state)
        lock.unlock()
        return result
    }

    func update(
        targetFillFraction: Float,
        targetMainColor: SIMD4<Float>,
        targetDeepColor: SIMD4<Float>,
        targetHighlightColor: SIMD4<Float>,
        targetMotionScale: Float,
        allowsSmoothing: Bool
    ) {
        lock.lock()

        let safeTargetFill = max(0, min(1, targetFillFraction))
        let safeMotionScale = max(0, targetMotionScale)

        state.targetFillFraction = safeTargetFill
        state.targetMainColor = targetMainColor
        state.targetDeepColor = targetDeepColor
        state.targetHighlightColor = targetHighlightColor
        state.targetMotionScale = safeMotionScale
        state.allowsSmoothing = allowsSmoothing

        // 初回表示、Home非表示中、バックグラウンド中、reduce motion中は即座に現在値へ同期します。
        // さらに lastFrameTimestamp を捨てることで、復帰時に停止中の経過時間をまとめて消化しません。
        if !state.hasReceivedFirstState || !allowsSmoothing {
            state.renderedFillFraction = safeTargetFill
            state.renderedMainColor = targetMainColor
            state.renderedDeepColor = targetDeepColor
            state.renderedHighlightColor = targetHighlightColor
            state.renderedMotionScale = safeMotionScale
            state.hasReceivedFirstState = true
            lastFrameTimestamp = nil
        }

        lock.unlock()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard let pipelineState,
              let commandQueue,
              let descriptor = view.currentRenderPassDescriptor,
              let drawable = view.currentDrawable,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
            return
        }

        let now = CACurrentMediaTime()
        let current = advanceState(now: now)
        let drawableSize = view.drawableSize
        let aspectRatio = drawableSize.height > 0 ? Float(drawableSize.width / drawableSize.height) : 1.0

        var uniforms = CircularLiquidUniforms(
            time: current.renderedTime,
            fillFraction: current.renderedFillFraction,
            aspectRatio: aspectRatio,
            motionScale: current.renderedMotionScale,
            mainColor: current.renderedMainColor,
            deepColor: current.renderedDeepColor,
            highlightColor: current.renderedHighlightColor,
            foamColor: SIMD4<Float>(1.0, 1.0, 1.0, 1.0)
        )

        encoder.setRenderPipelineState(pipelineState)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<CircularLiquidUniforms>.stride, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        encoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()

        // 0%まで滑らかに減った後など、継続描画が不要になったら停止します。
        if !shouldContinueDrawing(current) {
            DispatchQueue.main.async { [weak view] in
                guard let view else { return }
                view.enableSetNeedsDisplay = true
                view.isPaused = true
                view.setNeedsDisplay()
            }
        }
    }

    private func advanceState(now: CFTimeInterval) -> RenderState {
        lock.lock()
        defer { lock.unlock() }

        guard state.allowsSmoothing else {
            lastFrameTimestamp = nil
            state.renderedMotionScale = 0
            return state
        }

        let previousTimestamp = lastFrameTimestamp
        let rawDeltaTime: Float
        if let previousTimestamp {
            rawDeltaTime = Float(max(0, now - previousTimestamp))
        } else {
            rawDeltaTime = 1.0 / 30.0
        }

        // 復帰直後や一時的なメインスレッド停止で大きい delta が来ても、一気に波を進めません。
        let deltaTime = min(rawDeltaTime, 1.0 / 12.0)
        lastFrameTimestamp = now

        let isIncreasing = state.targetFillFraction >= state.renderedFillFraction
        let fillResponse: Float = isIncreasing ? 3.2 : 4.0
        let colorResponse: Float = 8.0
        let motionResponse: Float = 10.0

        state.renderedFillFraction = smoothedScalar(
            current: state.renderedFillFraction,
            target: state.targetFillFraction,
            deltaTime: deltaTime,
            response: fillResponse,
            snapThreshold: fillSnapThreshold
        )

        state.renderedMotionScale = smoothedScalar(
            current: state.renderedMotionScale,
            target: state.targetMotionScale,
            deltaTime: deltaTime,
            response: motionResponse,
            snapThreshold: 0.001
        )

        state.renderedMainColor = smoothedVector(
            current: state.renderedMainColor,
            target: state.targetMainColor,
            deltaTime: deltaTime,
            response: colorResponse,
            snapThreshold: colorSnapThreshold
        )

        state.renderedDeepColor = smoothedVector(
            current: state.renderedDeepColor,
            target: state.targetDeepColor,
            deltaTime: deltaTime,
            response: colorResponse,
            snapThreshold: colorSnapThreshold
        )

        state.renderedHighlightColor = smoothedVector(
            current: state.renderedHighlightColor,
            target: state.targetHighlightColor,
            deltaTime: deltaTime,
            response: colorResponse,
            snapThreshold: colorSnapThreshold
        )

        state.renderedTime += deltaTime * max(0, state.renderedMotionScale)

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

        let alpha = 1.0 - exp(-response * deltaTime)
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
        let maxDifference = max(
            max(abs(difference.x), abs(difference.y)),
            max(abs(difference.z), abs(difference.w))
        )

        if maxDifference <= snapThreshold {
            return target
        }

        let alpha = 1.0 - exp(-response * deltaTime)
        return current + difference * alpha
    }

    private func shouldContinueDrawing(_ state: RenderState) -> Bool {
        if state.renderedMotionScale > 0.001 { return true }
        return shouldContinueDrawingLocked(state)
    }

    private func shouldContinueDrawingLocked(_ state: RenderState) -> Bool {
        if state.targetMotionScale > 0.001 { return true }
        if abs(state.targetFillFraction - state.renderedFillFraction) > fillSnapThreshold { return true }
        if maxColorDifference(state.targetMainColor, state.renderedMainColor) > colorSnapThreshold { return true }
        if maxColorDifference(state.targetDeepColor, state.renderedDeepColor) > colorSnapThreshold { return true }
        if maxColorDifference(state.targetHighlightColor, state.renderedHighlightColor) > colorSnapThreshold { return true }
        return false
    }

    private func maxColorDifference(_ a: SIMD4<Float>, _ b: SIMD4<Float>) -> Float {
        let difference = a - b
        return max(
            max(abs(difference.x), abs(difference.y)),
            max(abs(difference.z), abs(difference.w))
        )
    }
}

private struct SwiftUICircularLiquidFallback: View {
    let fillFraction: CGFloat
    let mainColor: Color
    let deepColor: Color
    let highlightColor: Color
    let isActive: Bool

    @State private var displayedFillFraction: CGFloat = 0
    @State private var waveTime: CGFloat = 0
    @State private var lastTimelineDate: Date?

    private var clampedFillFraction: CGFloat {
        max(0, min(1, fillFraction))
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: isActive ? 1.0 / 20.0 : 1.0)) { timeline in
            Canvas { context, size in
                let fraction = max(0, min(1, displayedFillFraction))
                guard fraction > 0 else { return }

                let width = max(size.width, 1)
                let height = max(size.height, 1)
                let baseY = height * (1 - fraction)

                var path = Path()
                path.move(to: CGPoint(x: 0, y: height))
                path.addLine(to: CGPoint(x: 0, y: baseY))

                for x in stride(from: CGFloat.zero, through: width, by: 2) {
                    let progress = x / width
                    let wave1 = sin(progress * .pi * 2.3 + waveTime * 1.45) * 5.0
                    let wave2 = sin(progress * .pi * 4.7 - waveTime * 0.95) * 2.4
                    path.addLine(to: CGPoint(x: x, y: baseY + wave1 + wave2))
                }

                path.addLine(to: CGPoint(x: width, y: height))
                path.closeSubpath()

                context.fill(
                    path,
                    with: .linearGradient(
                        Gradient(colors: [
                            highlightColor.opacity(0.90),
                            mainColor.opacity(0.96),
                            deepColor.opacity(0.94)
                        ]),
                        startPoint: CGPoint(x: width * 0.5, y: baseY),
                        endPoint: CGPoint(x: width * 0.5, y: height)
                    )
                )
            }
            .onChange(of: timeline.date) { _, newDate in
                advanceWaveTimeIfNeeded(now: newDate)
            }
        }
        .onAppear {
            displayedFillFraction = clampedFillFraction
            lastTimelineDate = nil
        }
        .onChange(of: isActive) { _, newValue in
            if !newValue {
                lastTimelineDate = nil
            }
        }
        .onChange(of: clampedFillFraction) { _, newValue in
            guard isActive else {
                displayedFillFraction = newValue
                return
            }

            withAnimation(.easeInOut(duration: 0.45)) {
                displayedFillFraction = newValue
            }
        }
    }

    private func advanceWaveTimeIfNeeded(now: Date) {
        guard isActive else {
            lastTimelineDate = nil
            return
        }

        let rawDeltaTime: TimeInterval
        if let lastTimelineDate {
            rawDeltaTime = max(0, now.timeIntervalSince(lastTimelineDate))
        } else {
            rawDeltaTime = 1.0 / 20.0
        }

        lastTimelineDate = now
        let deltaTime = min(rawDeltaTime, 1.0 / 12.0)
        waveTime += CGFloat(deltaTime)
    }
}

private extension Color {
    var metalRGBA: SIMD4<Float> {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        if uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            return SIMD4<Float>(Float(red), Float(green), Float(blue), Float(alpha))
        }

        return SIMD4<Float>(1.0, 1.0, 1.0, 1.0)
    }
}
