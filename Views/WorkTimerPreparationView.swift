//
//  WorkTimerPreparationView.swift
//  MeMo
//
//  旧集中タイマーの呼び出し口を維持しながら、
//  フィッシュポイントを壁紙へ交換する画面へ置き換える。
//

import SwiftUI

struct WorkTimerPreparationView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var bgmManager: BGMManager

    @ObservedObject private var fishingStore = FishingStore.shared

    @AppStorage(WallpaperCatalog.selectedHomeWallpaperAssetNameKey)
    private var selectedHomeWallpaperAssetName: String = WallpaperCatalog.defaultWallpaper.assetName

    @State private var activeAlert: FishingExchangeAlert?

    private let offers = FishingWallpaperOffer.defaultOffers

    var body: some View {
        GeometryReader { geo in
            ZStack {
                FishingExchangeBackground()

                VStack(spacing: 16) {
                    header
                    pointBalanceCard

                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 16) {
                            ForEach(offers) { offer in
                                wallpaperCard(offer)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, geo.safeAreaInsets.top + 14)
                .padding(.bottom, max(geo.safeAreaInsets.bottom, 18))
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
        .onAppear {
            bgmManager.switchBackground(to: .main)
            fishingStore.refresh(now: Date())
        }
        .onDisappear {
            bgmManager.restoreDefaultBackground()
        }
        .alert(item: $activeAlert) { alert in
            switch alert {
            case .exchanged(let offer):
                return Alert(
                    title: Text("壁紙を獲得しました"),
                    message: Text("「\(offer.wallpaper.name)」が壁紙一覧に追加されました。"),
                    primaryButton: .default(Text("この壁紙にする")) {
                        selectedHomeWallpaperAssetName = offer.wallpaper.assetName
                    },
                    secondaryButton: .cancel(Text("あとで設定"))
                )

            case .insufficient(let offer):
                return Alert(
                    title: Text("ポイントが足りません"),
                    message: Text("「\(offer.wallpaper.name)」の交換にはあと\(max(0, offer.price - fishingStore.pointBalance))pt必要です。"),
                    dismissButton: .default(Text("わかった"))
                )
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button {
                bgmManager.playSE(.push)
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.black.opacity(0.42), in: Circle())
            }
            .buttonStyle(.plain)

            Spacer()

            Text("かべがみ交換所")
                .font(.system(size: 23, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.35), radius: 4, x: 0, y: 2)

            Spacer()

            Color.clear
                .frame(width: 44, height: 44)
        }
    }

    private var pointBalanceCard: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.10, green: 0.63, blue: 0.88))
                    .frame(width: 48, height: 48)

                Image(systemName: "fish.fill")
                    .font(.system(size: 23, weight: .black))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("所持フィッシュポイント")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.secondary)

                Text("\(fishingStore.pointBalance) pt")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
            }

            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 15)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.34), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.16), radius: 12, x: 0, y: 7)
    }

    private func wallpaperCard(_ offer: FishingWallpaperOffer) -> some View {
        let isUnlocked = fishingStore.isWallpaperUnlocked(assetName: offer.wallpaper.assetName)
        let isSelected = selectedHomeWallpaperAssetName == offer.wallpaper.assetName

        return VStack(spacing: 0) {
            ZStack(alignment: .topTrailing) {
                Image(offer.wallpaper.assetName)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 205)
                    .frame(maxWidth: .infinity)
                    .clipped()

                if isUnlocked {
                    Text(isSelected ? "使用中" : "獲得済み")
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(isSelected ? Color.green : Color.black.opacity(0.64), in: Capsule())
                        .padding(12)
                }
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(offer.wallpaper.name)
                        .font(.system(size: 20, weight: .black, design: .rounded))

                    HStack(spacing: 6) {
                        Image(systemName: "fish.fill")
                        Text("\(offer.price) pt")
                            .monospacedDigit()
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.secondary)
                }

                Spacer()

                if isUnlocked {
                    Button {
                        bgmManager.playSE(.push)
                        selectedHomeWallpaperAssetName = offer.wallpaper.assetName
                    } label: {
                        Text(isSelected ? "設定中" : "設定する")
                            .font(.system(size: 14, weight: .black))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .frame(height: 42)
                            .background(isSelected ? Color.gray : Color.green, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(isSelected)
                } else {
                    Button {
                        bgmManager.playSE(.push)
                        exchange(offer)
                    } label: {
                        Text("交換")
                            .font(.system(size: 15, weight: .black))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 22)
                            .frame(height: 44)
                            .background(
                                fishingStore.pointBalance >= offer.price
                                    ? Color(red: 0.10, green: 0.63, blue: 0.88)
                                    : Color.gray,
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.30), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.17), radius: 12, x: 0, y: 7)
    }

    private func exchange(_ offer: FishingWallpaperOffer) {
        guard fishingStore.pointBalance >= offer.price else {
            activeAlert = .insufficient(offer)
            return
        }

        guard fishingStore.exchangeWallpaper(
            assetName: offer.wallpaper.assetName,
            price: offer.price
        ) else {
            return
        }

        activeAlert = .exchanged(offer)
    }
}

enum FishingExchangeAlert: Identifiable {
    case exchanged(FishingWallpaperOffer)
    case insufficient(FishingWallpaperOffer)

    var id: String {
        switch self {
        case .exchanged(let offer):
            return "exchanged.\(offer.id)"
        case .insufficient(let offer):
            return "insufficient.\(offer.id)"
        }
    }
}

struct FishingWallpaperOffer: Identifiable, Hashable {
    let wallpaper: WallpaperCatalog.WallpaperItem
    let price: Int

    var id: String { wallpaper.id }

    static let defaultOffers: [FishingWallpaperOffer] = [
        make(assetName: "field_background", price: 100),
        make(assetName: "concrete_background", price: 250),
        make(assetName: "japanese_background", price: 450),
        make(assetName: "office_background", price: 700),
        make(assetName: "bath_background", price: 1_000),
        make(assetName: "beach_background", price: 1_500)
    ].compactMap { $0 }

    private static func make(assetName: String, price: Int) -> FishingWallpaperOffer? {
        guard let wallpaper = WallpaperCatalog.item(for: assetName) else { return nil }
        return FishingWallpaperOffer(wallpaper: wallpaper, price: max(0, price))
    }
}

private struct FishingExchangeBackground: View {
    var body: some View {
        ZStack {
            Image("fishing_background")
                .resizable()
                .scaledToFill()
                .blur(radius: 3)
                .scaleEffect(1.02)

            LinearGradient(
                colors: [
                    Color.black.opacity(0.20),
                    Color.black.opacity(0.34)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
