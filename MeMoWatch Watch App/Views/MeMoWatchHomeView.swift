//
//  MeMoWatchHomeView.swift
//  MeMo Watch App
//
//  iPhone HomeView asset based Watch Home UI.
//  Uses the same asset names as iPhone HomeView:
//  - Home_background / selected wallpaper asset
//  - shoes
//  - current pet asset from PetMaster
//  - glass_heart
//  - numeric level badge assets: "0"..."20"
//  - glass_stomach
//

import SwiftUI

struct MeMoWatchHomeView: View {
    @StateObject private var viewModel = MeMoWatchHomeViewModel()

    private let referenceSize = CGSize(width: 368, height: 448)

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let safeHeight = geometry.size.height
            let scale = width / referenceSize.width
            let layoutHeight = max(safeHeight, referenceSize.height * scale)
            let layoutWidth = referenceSize.width * scale

            ZStack(alignment: .topLeading) {
                Color.black
                    .ignoresSafeArea()

                ZStack {
                    backgroundLayer(width: layoutWidth, height: layoutHeight)

                    stepMeter(scale: scale)
                        .position(x: layoutWidth * 0.50, y: 72 * scale)

                    characterLayer(scale: scale)
                        .position(x: layoutWidth * 0.50, y: 248 * scale)

                    iPhoneAssetHappinessGauge(
                        scale: scale,
                        point: viewModel.happinessPoint,
                        maxPoint: viewModel.happinessMaxPoint,
                        level: viewModel.happinessLevel
                    )
                    .position(x: 75 * scale, y: 356 * scale)

                    iPhoneAssetFullnessGauge(
                        scale: scale,
                        level: viewModel.fullnessLevel,
                        maxLevel: viewModel.fullnessMaxLevel
                    )
                    .position(x: layoutWidth - (75 * scale), y: 356 * scale)
                }
                .frame(width: layoutWidth, height: layoutHeight)
                .position(x: width * 0.5, y: layoutHeight * 0.5)
            }
            .frame(width: width, height: layoutHeight)
            .contentShape(Rectangle())
            .ignoresSafeArea()
        }
        .ignoresSafeArea()
        .watchSystemOverlayHiddenIfAvailable()
        .task {
            await viewModel.start()
        }
    }

    private func backgroundLayer(width: CGFloat, height: CGFloat) -> some View {
        Image(viewModel.backgroundAssetName)
            .resizable()
            .scaledToFill()
            .frame(width: width, height: height)
            .clipped()
            .background(Color(red: 0.95, green: 0.88, blue: 0.78))
    }

    private func stepMeter(scale: CGFloat) -> some View {
        let cardWidth = 278 * scale
        let cardHeight = 64 * scale
        let shoeSize = 41 * scale
        let progressWidth = 92 * scale
        let progressHeight = max(2.2 * scale, 2)
        let numberFontSize = 38 * scale
        let suffixFontSize = 14 * scale

        return ZStack {
            Capsule(style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.92),
                            Color(red: 0.92, green: 0.90, blue: 0.87).opacity(0.88)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Color.white.opacity(0.82), lineWidth: max(1, 1 * scale))
                )
                .shadow(color: .black.opacity(0.12), radius: 7 * scale, x: 0, y: 4 * scale)

            HStack(alignment: .center, spacing: 13 * scale) {
                Image("shoes")
                    .resizable()
                    .scaledToFit()
                    .frame(width: shoeSize, height: shoeSize)
                    .shadow(color: .black.opacity(0.10), radius: 2 * scale, x: 0, y: 1 * scale)

                HStack(alignment: .firstTextBaseline, spacing: 7 * scale) {
                    Text(Self.stepFormatter.string(from: NSNumber(value: viewModel.todaySteps)) ?? "\(viewModel.todaySteps)")
                        .font(.system(size: numberFontSize, weight: .regular, design: .rounded))
                        .foregroundStyle(Color(red: 0.17, green: 0.17, blue: 0.17))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.45)

                    Text("歩")
                        .font(.system(size: suffixFontSize, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.18, green: 0.18, blue: 0.18))
                        .offset(y: -1 * scale)
                }
            }
            .offset(y: -7 * scale)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.black.opacity(0.10))
                    .frame(width: progressWidth, height: progressHeight)

                Capsule()
                    .fill(Color(red: 0.17, green: 0.50, blue: 1.0))
                    .frame(
                        width: progressWidth * CGFloat(min(1, max(0, viewModel.stepProgress))),
                        height: progressHeight
                    )
            }
            .offset(x: 31 * scale, y: 20 * scale)
        }
        .frame(width: cardWidth, height: cardHeight)
    }

    private func characterLayer(scale: CGFloat) -> some View {
        Image(viewModel.currentCharacterAssetName)
            .resizable()
            .scaledToFit()
            .frame(width: 190 * scale, height: 282 * scale)
            .scaleEffect(viewModel.isPettingFeedbackActive ? 1.025 : 1.0)
            .animation(.spring(response: 0.16, dampingFraction: 0.62), value: viewModel.isPettingFeedbackActive)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { _ in
                        viewModel.petCharacter()
                    }
            )
    }

    private func iPhoneAssetHappinessGauge(
        scale: CGFloat,
        point: Int,
        maxPoint: Int,
        level: Int
    ) -> some View {
        let outerSize = 88 * scale
        let innerSize = 75 * scale
        let fillFraction = CGFloat(min(1, max(0, Double(point) / Double(max(maxPoint, 1)))))
        let levelAssetName = "\(min(20, max(0, level)))"

        return ZStack {
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.22, green: 0.52, blue: 1.0).opacity(0.95),
                                Color(red: 0.05, green: 0.18, blue: 0.78).opacity(0.95)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: innerSize * fillFraction)
            }
            .frame(width: innerSize, height: innerSize)
            .clipShape(WatchHeartFillMask())
            .opacity(0.92)

            Image("glass_heart")
                .resizable()
                .scaledToFit()
                .frame(width: outerSize, height: outerSize)

            Image(levelAssetName)
                .resizable()
                .scaledToFit()
                .frame(width: outerSize * 0.58, height: outerSize * 0.32)
                .offset(y: outerSize * 0.03)
                .shadow(color: .black.opacity(0.16), radius: 4 * scale, x: 0, y: 2 * scale)
        }
        .frame(width: outerSize, height: outerSize)
        .shadow(color: .black.opacity(0.16), radius: 7 * scale, x: 0, y: 4 * scale)
    }

    private func iPhoneAssetFullnessGauge(
        scale: CGFloat,
        level: Int,
        maxLevel: Int
    ) -> some View {
        let outerSize = 88 * scale
        let innerSize = 75 * scale
        let fillFraction = CGFloat(min(1, max(0, Double(level) / Double(max(maxLevel, 1)))))

        return ZStack {
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.52, green: 0.88, blue: 0.98).opacity(0.96),
                                Color(red: 0.23, green: 0.58, blue: 0.76).opacity(0.92)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: innerSize * fillFraction)
            }
            .frame(width: innerSize, height: innerSize)
            .clipShape(WatchStomachFillMask())
            .opacity(0.88)

            Image("glass_stomach")
                .resizable()
                .scaledToFit()
                .frame(width: outerSize, height: outerSize)
        }
        .frame(width: outerSize, height: outerSize)
        .shadow(color: .black.opacity(0.16), radius: 7 * scale, x: 0, y: 4 * scale)
    }

    private static let stepFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter
    }()
}

private struct WatchHeartFillMask: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        path.move(to: CGPoint(x: w * 0.50, y: h * 0.90))
        path.addCurve(
            to: CGPoint(x: w * 0.06, y: h * 0.35),
            control1: CGPoint(x: w * 0.20, y: h * 0.70),
            control2: CGPoint(x: w * 0.04, y: h * 0.53)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.30, y: h * 0.10),
            control1: CGPoint(x: w * 0.06, y: h * 0.19),
            control2: CGPoint(x: w * 0.17, y: h * 0.10)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.50, y: h * 0.24),
            control1: CGPoint(x: w * 0.39, y: h * 0.10),
            control2: CGPoint(x: w * 0.46, y: h * 0.16)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.70, y: h * 0.10),
            control1: CGPoint(x: w * 0.54, y: h * 0.16),
            control2: CGPoint(x: w * 0.61, y: h * 0.10)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.94, y: h * 0.35),
            control1: CGPoint(x: w * 0.83, y: h * 0.10),
            control2: CGPoint(x: w * 0.94, y: h * 0.19)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.50, y: h * 0.90),
            control1: CGPoint(x: w * 0.96, y: h * 0.53),
            control2: CGPoint(x: w * 0.80, y: h * 0.70)
        )
        path.closeSubpath()
        return path
    }
}

private struct WatchStomachFillMask: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        path.move(to: CGPoint(x: w * 0.55, y: h * 0.10))
        path.addCurve(
            to: CGPoint(x: w * 0.78, y: h * 0.14),
            control1: CGPoint(x: w * 0.65, y: h * 0.03),
            control2: CGPoint(x: w * 0.76, y: h * 0.04)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.78, y: h * 0.33),
            control1: CGPoint(x: w * 0.80, y: h * 0.22),
            control2: CGPoint(x: w * 0.76, y: h * 0.27)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.92, y: h * 0.52),
            control1: CGPoint(x: w * 0.82, y: h * 0.40),
            control2: CGPoint(x: w * 0.92, y: h * 0.41)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.52, y: h * 0.91),
            control1: CGPoint(x: w * 0.92, y: h * 0.75),
            control2: CGPoint(x: w * 0.74, y: h * 0.91)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.13, y: h * 0.63),
            control1: CGPoint(x: w * 0.28, y: h * 0.91),
            control2: CGPoint(x: w * 0.13, y: h * 0.80)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.47, y: h * 0.37),
            control1: CGPoint(x: w * 0.13, y: h * 0.45),
            control2: CGPoint(x: w * 0.32, y: h * 0.38)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.55, y: h * 0.10),
            control1: CGPoint(x: w * 0.57, y: h * 0.36),
            control2: CGPoint(x: w * 0.48, y: h * 0.20)
        )
        path.closeSubpath()
        return path
    }
}

private extension View {
    @ViewBuilder
    func watchSystemOverlayHiddenIfAvailable() -> some View {
        #if os(watchOS)
        if #available(watchOS 9.0, *) {
            self.persistentSystemOverlays(.hidden)
        } else {
            self
        }
        #else
        self
        #endif
    }
}

#Preview {
    MeMoWatchHomeView()
}
