//
//  MemoryPhotoCardView.swift
//  MeMo
//
//  Created by shota suzuki on 2026/04/17.
//

import SwiftUI
import UIKit
import CoreMotion
import Combine

enum MemoryPhotoCardMetrics {
    static let cornerRadius: CGFloat = 20
    static let aspectRatio: CGFloat = 367.0 / 512.0
    static let maxRotationDegree: Double = 10
    static let shadowRadius: CGFloat = 10
    static let shadowYOffset: CGFloat = 20
}

struct MemoryPhotoCardView: View {
    let image: UIImage?
    var placeholderSystemImage: String = "photo"
    var showsTiltEffect: Bool = true
    var showsStroke: Bool = true

    @StateObject private var motion = DeviceTiltCardMotionManager()

    private var hoverLocationRatio: CGPoint {
        motion.locationRatio
    }

    private var isInteractive: Bool {
        showsTiltEffect && motion.isActive
    }

    private var rotationDegrees: CGPoint {
        CGPoint(
            x: -MemoryPhotoCardMetrics.maxRotationDegree * ((hoverLocationRatio.x - 0.5) / 0.5),
            y: MemoryPhotoCardMetrics.maxRotationDegree * ((hoverLocationRatio.y - 0.5) / 0.5)
        )
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack {
                RoundedRectangle(cornerRadius: MemoryPhotoCardMetrics.cornerRadius, style: .continuous)
                    .fill(Color.white.opacity(image == nil ? 0.12 : 0.08))

                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: size.width, height: size.height)
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: MemoryPhotoCardMetrics.cornerRadius,
                                style: .continuous
                            )
                        )
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: placeholderSystemImage)
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(.white.opacity(0.92))

                        Text("画像を表示できません")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.84))
                    }
                }

                LinearGradient(
                    colors: [
                        .white.opacity(0.24),
                        .clear,
                        .black.opacity(0.10)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: MemoryPhotoCardMetrics.cornerRadius,
                        style: .continuous
                    )
                )

                if showsStroke {
                    RoundedRectangle(cornerRadius: MemoryPhotoCardMetrics.cornerRadius, style: .continuous)
                        .stroke(Color.white.opacity(0.92), lineWidth: 1)
                }
            }
            .brightness(isInteractive ? 0.05 : 0)
            .contrast(isInteractive ? 1.3 : 1.0)
            .rotation3DEffect(
                Angle(degrees: rotationDegrees.x),
                axis: (x: 0, y: 1.0, z: 0),
                anchorZ: 0,
                perspective: 1.0
            )
            .rotation3DEffect(
                Angle(degrees: rotationDegrees.y),
                axis: (x: 1.0, y: 0, z: 0),
                anchorZ: 0,
                perspective: 1.0
            )
            .shadow(
                color: .black.opacity(0.5),
                radius: MemoryPhotoCardMetrics.shadowRadius,
                x: 0,
                y: MemoryPhotoCardMetrics.shadowYOffset
            )
        }
        .aspectRatio(MemoryPhotoCardMetrics.aspectRatio, contentMode: .fit)
        .onAppear {
            guard showsTiltEffect else { return }
            motion.start()
        }
        .onDisappear {
            motion.stop()
        }
    }
}

@MainActor
final class DeviceTiltCardMotionManager: ObservableObject {
    @Published private(set) var locationRatio: CGPoint = .init(x: 0.5, y: 0.5)
    @Published private(set) var isActive: Bool = false

    private let motionManager = CMMotionManager()
    private let queue = OperationQueue()
    private let maximumTiltAngle: Double = .pi / 7.0

    private var referenceAttitude: CMAttitude?

    func start() {
        stop()

        guard motionManager.isDeviceMotionAvailable else {
            isActive = false
            locationRatio = .init(x: 0.5, y: 0.5)
            return
        }

        queue.name = "memo.device.tilt.card.motion"
        queue.qualityOfService = .userInteractive
        motionManager.deviceMotionUpdateInterval = 1.0 / 30.0

        motionManager.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: queue) { [weak self] motion, _ in
            guard let self, let motion else { return }

            if self.referenceAttitude == nil {
                self.referenceAttitude = motion.attitude.copy() as? CMAttitude
            }

            guard
                let referenceAttitude = self.referenceAttitude,
                let relativeAttitude = motion.attitude.copy() as? CMAttitude
            else {
                Task { @MainActor in
                    self.locationRatio = .init(x: 0.5, y: 0.5)
                    self.isActive = false
                }
                return
            }

            relativeAttitude.multiply(byInverseOf: referenceAttitude)

            let normalizedX = Self.makeLocationRatioValue(
                from: relativeAttitude.roll,
                maximumAngle: self.maximumTiltAngle
            )
            let normalizedY = Self.makeLocationRatioValue(
                from: -relativeAttitude.pitch,
                maximumAngle: self.maximumTiltAngle
            )

            Task { @MainActor in
                self.locationRatio = CGPoint(x: normalizedX, y: normalizedY)
                self.isActive = true
            }
        }
    }

    func stop() {
        motionManager.stopDeviceMotionUpdates()
        referenceAttitude = nil
        isActive = false
        locationRatio = .init(x: 0.5, y: 0.5)
    }

    private static func makeLocationRatioValue(from angle: Double, maximumAngle: Double) -> CGFloat {
        guard maximumAngle > 0 else { return 0.5 }
        let normalized = max(-1.0, min(1.0, angle / maximumAngle))
        return CGFloat(0.5 + (normalized * 0.5))
    }
}
