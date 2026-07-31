//
//  WorkTimerPreparationView.swift
//  MeMo
//
//  旧集中タイマーの呼び出し口を維持しながら、
//  フィッシュポイントと壁紙を交換・取得する画面。
//

import SwiftUI
import UIKit

struct WorkTimerPreparationView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var bgmManager: BGMManager

    @ObservedObject private var fishingStore = FishingStore.shared

    @AppStorage(WallpaperCatalog.selectedHomeWallpaperAssetNameKey)
    private var selectedHomeWallpaperAssetName: String = WallpaperCatalog.defaultWallpaper.assetName

    @State private var presentedExchangeModal: FishingExchangeModal?

    private let offers = FishingWallpaperOffer.defaultOffers

    var body: some View {
        GeometryReader { geo in
            let windowSafeAreaTop = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .first(where: { $0.isKeyWindow })?
                .safeAreaInsets.top ?? 0
            let resolvedSafeAreaTop = max(geo.safeAreaInsets.top, windowSafeAreaTop)

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
                .padding(.top, max(resolvedSafeAreaTop, 54) + 30)
                .padding(.bottom, max(geo.safeAreaInsets.bottom, 18))
                .allowsHitTesting(presentedExchangeModal == nil)

                if let presentedExchangeModal {
                    exchangeModalOverlay(presentedExchangeModal)
                        .zIndex(10_000)
                        .transition(.opacity.combined(with: .scale(scale: 0.97)))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .animation(.easeInOut(duration: 0.18), value: presentedExchangeModal?.id)
        }
        .ignoresSafeArea()
        .onAppear {
            bgmManager.switchBackground(to: .main)
            fishingStore.refresh(now: Date())
        }
        .onDisappear {
            bgmManager.restoreDefaultBackground()
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
            .accessibilityLabel("釣り画面へ戻る")

            Spacer()

            Text("かべがみ交換所")
                .font(.system(size: 21, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .padding(.horizontal, 6)
                .shadow(color: .black.opacity(0.35), radius: 4, x: 0, y: 2)

            Spacer()

            Color.clear
                .frame(width: 44, height: 44)
                .accessibilityHidden(true)
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
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.34), lineWidth: 1)
                .allowsHitTesting(false)
        }
        .shadow(color: .black.opacity(0.16), radius: 12, x: 0, y: 7)
        .accessibilityElement(children: .combine)
    }

    private func wallpaperCard(_ offer: FishingWallpaperOffer) -> some View {
        let isUnlocked = fishingStore.isWallpaperUnlocked(assetName: offer.wallpaper.assetName)
        let isSelected = selectedHomeWallpaperAssetName == offer.wallpaper.assetName
        let canAfford = fishingStore.pointBalance >= offer.price
        let remainingBalance = max(0, fishingStore.pointBalance - offer.price)
        let shortage = max(0, offer.price - fishingStore.pointBalance)

        return VStack(spacing: 0) {
            ZStack(alignment: .topTrailing) {
                Image(offer.wallpaper.assetName)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 205)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .allowsHitTesting(false)

                if isUnlocked {
                    Text(isSelected ? "使用中" : "取得済み")
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(isSelected ? Color.green : Color.black.opacity(0.64), in: Capsule())
                        .padding(12)
                        .allowsHitTesting(false)
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

                    if !isUnlocked {
                        Text(canAfford ? "交換後 \(remainingBalance) pt" : "あと \(shortage) pt必要")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(canAfford ? Color.secondary : Color.red)
                            .monospacedDigit()
                    }
                }
                .allowsHitTesting(false)

                Spacer(minLength: 8)

                if isUnlocked {
                    Button {
                        bgmManager.playSE(.push)
                        selectedHomeWallpaperAssetName = offer.wallpaper.assetName
                    } label: {
                        Text(isSelected ? "設定中" : "設定する")
                            .font(.system(size: 14, weight: .black))
                            .foregroundStyle(.white)
                            .frame(minWidth: 88, minHeight: 44)
                            .background(isSelected ? Color.gray : Color.green, in: Capsule())
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(isSelected)
                    .accessibilityLabel(
                        isSelected
                            ? "\(offer.wallpaper.name)を設定中"
                            : "\(offer.wallpaper.name)を壁紙に設定"
                    )
                } else {
                    Text("交換")
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(.white)
                        .frame(minWidth: 88, minHeight: 44)
                        .background(
                            canAfford
                                ? Color(red: 0.10, green: 0.63, blue: 0.88)
                                : Color.gray,
                            in: Capsule()
                        )
                        .contentShape(Rectangle())
                        .highPriorityGesture(
                            TapGesture()
                                .onEnded {
                                    requestExchange(offer)
                                }
                        )
                        .accessibilityElement()
                        .accessibilityAddTraits(.isButton)
                        .accessibilityLabel("\(offer.wallpaper.name)を\(offer.price)ポイントで交換")
                        .accessibilityHint(
                            canAfford
                                ? "交換内容を確認します"
                                : "不足しているポイント数を表示します"
                        )
                        .accessibilityAction {
                            requestExchange(offer)
                        }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.30), lineWidth: 1)
                .allowsHitTesting(false)
        }
        .shadow(color: .black.opacity(0.17), radius: 12, x: 0, y: 7)
    }

    private func requestExchange(_ offer: FishingWallpaperOffer) {
        bgmManager.playSE(.push)

        guard !fishingStore.isWallpaperUnlocked(assetName: offer.wallpaper.assetName) else {
            presentedExchangeModal = .alreadyOwned(offer)
            return
        }

        let shortage = max(0, offer.price - fishingStore.pointBalance)
        guard shortage == 0 else {
            presentedExchangeModal = .insufficient(offer, shortage: shortage)
            return
        }

        presentedExchangeModal = .confirmation(
            offer,
            remainingBalance: max(0, fishingStore.pointBalance - offer.price)
        )
    }

    private func completeExchange(_ offer: FishingWallpaperOffer) {
        guard !fishingStore.isWallpaperUnlocked(assetName: offer.wallpaper.assetName) else {
            presentedExchangeModal = .alreadyOwned(offer)
            return
        }

        let shortage = max(0, offer.price - fishingStore.pointBalance)
        guard shortage == 0 else {
            presentedExchangeModal = .insufficient(offer, shortage: shortage)
            return
        }

        guard fishingStore.exchangeWallpaper(
            assetName: offer.wallpaper.assetName,
            price: offer.price
        ) else {
            presentedExchangeModal = .failed(offer)
            return
        }

        bgmManager.playSE(.push)
        presentedExchangeModal = .exchanged(
            offer,
            remainingBalance: fishingStore.pointBalance
        )
    }

    @ViewBuilder
    private func exchangeModalOverlay(_ modal: FishingExchangeModal) -> some View {
        ZStack {
            Color.black.opacity(0.48)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    presentedExchangeModal = nil
                }

            VStack(spacing: 18) {
                modalIcon(modal)

                VStack(spacing: 8) {
                    Text(modal.title)
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .multilineTextAlignment(.center)

                    Text(modal.message)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }

                modalButtons(modal)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 24)
            .frame(maxWidth: 340)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.white.opacity(0.38), lineWidth: 1)
                    .allowsHitTesting(false)
            }
            .shadow(color: .black.opacity(0.28), radius: 24, x: 0, y: 14)
            .padding(.horizontal, 26)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func modalIcon(_ modal: FishingExchangeModal) -> some View {
        let iconName: String
        let tint: Color

        switch modal {
        case .confirmation:
            iconName = "arrow.left.arrow.right.circle.fill"
            tint = Color(red: 0.10, green: 0.63, blue: 0.88)
        case .exchanged:
            iconName = "checkmark.circle.fill"
            tint = .green
        case .insufficient:
            iconName = "exclamationmark.circle.fill"
            tint = .orange
        case .alreadyOwned:
            iconName = "checkmark.seal.fill"
            tint = .green
        case .failed:
            iconName = "xmark.circle.fill"
            tint = .red
        }

        return Image(systemName: iconName)
            .font(.system(size: 46, weight: .bold))
            .foregroundStyle(tint)
    }

    @ViewBuilder
    private func modalButtons(_ modal: FishingExchangeModal) -> some View {
        switch modal {
        case .confirmation(let offer, _):
            VStack(spacing: 10) {
                Button {
                    completeExchange(offer)
                } label: {
                    Text("\(offer.price) ptで交換")
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(Color(red: 0.10, green: 0.63, blue: 0.88), in: Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    presentedExchangeModal = nil
                } label: {
                    Text("キャンセル")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.plain)
            }

        case .exchanged(let offer, _):
            VStack(spacing: 10) {
                Button {
                    selectedHomeWallpaperAssetName = offer.wallpaper.assetName
                    presentedExchangeModal = nil
                } label: {
                    Text("この壁紙にする")
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(Color.green, in: Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    presentedExchangeModal = nil
                } label: {
                    Text("あとで設定")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.plain)
            }

        case .alreadyOwned(let offer):
            VStack(spacing: 10) {
                Button {
                    selectedHomeWallpaperAssetName = offer.wallpaper.assetName
                    presentedExchangeModal = nil
                } label: {
                    Text("この壁紙にする")
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(Color.green, in: Capsule())
                }
                .buttonStyle(.plain)

                closeModalButton
            }

        case .insufficient, .failed:
            closeModalButton
        }
    }

    private var closeModalButton: some View {
        Button {
            presentedExchangeModal = nil
        } label: {
            Text("閉じる")
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(Color.secondary, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

private enum FishingExchangeModal: Identifiable {
    case confirmation(FishingWallpaperOffer, remainingBalance: Int)
    case exchanged(FishingWallpaperOffer, remainingBalance: Int)
    case insufficient(FishingWallpaperOffer, shortage: Int)
    case alreadyOwned(FishingWallpaperOffer)
    case failed(FishingWallpaperOffer)

    var id: String {
        switch self {
        case .confirmation(let offer, _):
            return "confirmation.\(offer.id)"
        case .exchanged(let offer, _):
            return "exchanged.\(offer.id)"
        case .insufficient(let offer, _):
            return "insufficient.\(offer.id)"
        case .alreadyOwned(let offer):
            return "alreadyOwned.\(offer.id)"
        case .failed(let offer):
            return "failed.\(offer.id)"
        }
    }

    var title: String {
        switch self {
        case .confirmation:
            return "壁紙と交換しますか？"
        case .exchanged:
            return "壁紙と交換しました"
        case .insufficient:
            return "ポイントが足りません"
        case .alreadyOwned:
            return "取得済みの壁紙です"
        case .failed:
            return "交換できませんでした"
        }
    }

    var message: String {
        switch self {
        case .confirmation(let offer, let remainingBalance):
            return "「\(offer.wallpaper.name)」と交換します。\n交換後の残高は\(remainingBalance) ptです。"

        case .exchanged(let offer, let remainingBalance):
            return "「\(offer.wallpaper.name)」を取得しました。\n残りのフィッシュポイント：\(remainingBalance) pt"

        case .insufficient(let offer, let shortage):
            return "「\(offer.wallpaper.name)」との交換には、あと\(shortage) pt必要です。"

        case .alreadyOwned(let offer):
            return "「\(offer.wallpaper.name)」はすでに取得しています。"

        case .failed(let offer):
            return "「\(offer.wallpaper.name)」との交換処理を完了できませんでした。ポイント残高を確認して、もう一度お試しください。"
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
