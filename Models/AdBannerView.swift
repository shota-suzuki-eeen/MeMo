//
//  AdBannerView.swift
//  MeMo
//
//  Updated for Home / Work banner selection.
//  2026/06 update: MonetizationPolicy 経由で広告表示可否を判定し、
//  開発者モード・広告停止中・Premium時はバナー領域自体を生成しない。
//

import SwiftUI

struct AdBannerView: View {
    enum Placement {
        case home
        case work

        var adUnitID: String {
            switch self {
            case .home:
                return AdUnitID.bannerHome
            case .work:
                return AdUnitID.bannerWork
            }
        }
    }

    @AppStorage(DeveloperModeStore.key) private var isDeveloperMode: Bool = false
    @ObservedObject private var subscriptionAccessManager = SubscriptionAccessManager.shared

    var placement: Placement = .home
    var height: CGFloat = 50
    var maxBannerWidth: CGFloat? = 320
    var contentHeight: CGFloat = 50
    var topOffset: CGFloat = 0

    private var shouldShowBanner: Bool {
        MonetizationPolicy.shouldShowPassiveAdvertising(
            isDeveloperMode: isDeveloperMode,
            hasPremiumAccess: subscriptionAccessManager.hasPremiumAccess
        )
    }

    var body: some View {
        Group {
            if shouldShowBanner {
                BannerArea(
                    height: height,
                    adUnitID: placement.adUnitID,
                    maxWidth: maxBannerWidth,
                    contentHeight: contentHeight,
                    topOffset: topOffset
                )
                .frame(height: height)
            } else {
                EmptyView()
            }
        }
    }
}
