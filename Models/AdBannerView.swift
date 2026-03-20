////
////  AdBannerView.swift
////  MeMo
////
////  Created by shota suzuki on 2026/03/20.
////
//
//import SwiftUI
//
///// ✅ 使う側はこれを置くだけ
///// - 例：Home の上部 / 下部など
//struct AdBannerView: View {
//    @AppStorage("isDeveloperMode") private var isDeveloperMode: Bool = false
//
//    var height: CGFloat = 70
//    var maxBannerWidth: CGFloat? = 320
//    var contentHeight: CGFloat = 50
//
//    // ✅ 追加：ここで微調整
//    var topOffset: CGFloat = 10
//
//    var body: some View {
//        Group {
//            if isDeveloperMode {
//                EmptyView()
//            } else {
//                BannerArea(
//                    height: height,
//                    adUnitID: AdUnitID.bannerHome,
//                    maxWidth: maxBannerWidth,
//                    contentHeight: contentHeight,
//                    topOffset: topOffset
//                )
//                .frame(height: height)
//            }
//        }
//    }
//}
