//
//  AdBannerView.swift
//  MeMo
//
//  Updated for Home / Work banner selection.
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

    @AppStorage("isDeveloperMode") private var isDeveloperMode: Bool = false

    var placement: Placement = .home
    var height: CGFloat = 70
    var maxBannerWidth: CGFloat? = 320
    var contentHeight: CGFloat = 50
    var topOffset: CGFloat = 10

    var body: some View {
        Group {
            if isDeveloperMode {
                EmptyView()
            } else {
                BannerArea(
                    height: height,
                    adUnitID: placement.adUnitID,
                    maxWidth: maxBannerWidth,
                    contentHeight: contentHeight,
                    topOffset: topOffset
                )
                .frame(height: height)
            }
        }
    }
}
