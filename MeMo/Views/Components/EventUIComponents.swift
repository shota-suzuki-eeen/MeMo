//
//  EventUIComponents.swift
//  MeMo
//

import SwiftUI

struct EventNotificationBadge: View {
    var body: some View {
        Circle()
            .fill(Color(red: 0.70, green: 0.94, blue: 0.16))
            .frame(width: 15, height: 15)
            .overlay {
                Circle()
                    .stroke(Color.white.opacity(0.96), lineWidth: 2)
            }
            .shadow(color: .black.opacity(0.22), radius: 2, x: 0, y: 1)
            .accessibilityHidden(true)
    }
}

struct HalloweenCandyIcon: View {
    let size: CGFloat

    var body: some View {
        Image("halloween_candy")
            .resizable()
            .scaledToFit()
            .frame(width: size * 1.15, height: size * 1.15)
            .accessibilityHidden(true)
    }
}

struct HalloweenEventBackground: View {
    let assetName: String

    var body: some View {
        GeometryReader { proxy in
            Image(assetName).resizable().scaledToFill()
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped().overlay(.black.opacity(0.26))
        }.ignoresSafeArea().accessibilityHidden(true)
    }
}

struct HalloweenLevelPumpkins: View {
    let level: Int
    var size: CGFloat = 32

    var body: some View {
        HStack(spacing: 7) {
            ForEach(1...5, id: \.self) { index in
                Image("halloween_level_pumpkin")
                    .renderingMode(index <= level ? .original : .template)
                    .resizable().scaledToFit().foregroundStyle(.black)
                    .frame(width: size, height: size)
            }
        }.accessibilityElement(children: .ignore)
            .accessibilityLabel("レベル\(level)、最大5")
    }
}

struct HalloweenRewardIcon: View {
    let reward: HalloweenRewardContent
    var size: CGFloat = 48

    var body: some View {
        Group {
            if let assetName = reward.assetName {
                Image(assetName)
                    .resizable()
                    .scaledToFit()
            } else if case .candy = reward {
                HalloweenCandyIcon(size: size * 0.82)
            } else if let systemImageName = reward.systemImageName {
                Image(systemName: systemImageName)
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.16)
            } else {
                Image(systemName: "gift.fill")
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.16)
            }
        }
        .frame(width: size, height: size)
    }
}
