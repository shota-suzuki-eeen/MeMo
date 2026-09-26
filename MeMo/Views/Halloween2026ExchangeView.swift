//
//  Halloween2026ExchangeView.swift
//  MeMo
//
//  キャンディを消費するイベント専用交換所。
//  2026/10/31のイベント終了と同時に利用不可（延長期間なし）。
//

import SwiftUI
import SwiftData

struct Halloween2026ExchangeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var bgmManager: BGMManager

    let state: AppState
    @ObservedObject var store: Halloween2026EventStore

    @State private var selectedOffer: HalloweenExchangeOffer?
    @State private var quantity: Int = 1
    @State private var resultMessage: String?

    var body: some View {
        TimelineView(.periodic(from: Date(), by: 15)) { timeline in
            ZStack {
                background

                VStack(spacing: 14) {
                    header
                        .padding(.horizontal, 18)

                    if EventManager.isActive(.halloween2026, at: timeline.date) {
                        ScrollView(.vertical, showsIndicators: false) {
                            LazyVStack(spacing: 12) {
                                ForEach(Halloween2026ExchangeCatalog.offers) { offer in
                                    offerCard(offer)
                                }
                            }
                            .padding(.horizontal, 18)
                            .padding(.top, 6)
                            .padding(.bottom, 30)
                        }
                    } else {
                        endedPanel
                            .padding(.horizontal, 24)
                        Spacer()
                    }
                }
                .padding(.top, 54)

                if let selectedOffer {
                    exchangeModal(offer: selectedOffer)
                        .zIndex(10_000)
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            bgmManager.switchBackground(to: .fishing)
        }
    }

    private var background: some View {
        LinearGradient(
            colors: [
                Color(red: 0.09, green: 0.04, blue: 0.18),
                Color(red: 0.24, green: 0.07, blue: 0.28),
                Color(red: 0.08, green: 0.03, blue: 0.14),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var header: some View {
        ZStack {
            HStack(spacing: 12) {
                Button {
                    bgmManager.playSE(.push)
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.black.opacity(0.36), in: Circle())
                }
                .buttonStyle(.plain)

                Spacer()

                HStack(spacing: 6) {
                    HalloweenCandyIcon(size: 22)
                    Text(store.candyCount.formatted())
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .monospacedDigit()
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .frame(minHeight: 40)
                .background(Color.black.opacity(0.38), in: Capsule())
            }

            Text("イベント交換所")
                .font(.system(size: 21, weight: .black, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(minHeight: 48)
    }

    private func offerCard(_ offer: HalloweenExchangeOffer) -> some View {
        let maximum = store.maximumExchangeQuantity(for: offer)
        let exchanged = store.exchangeCount(for: offer.id)

        return HStack(spacing: 14) {
            HalloweenRewardIcon(reward: offer.reward, size: 70)
                .padding(6)
                .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(offer.title)
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Text(offer.reward.displayName)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.70))

                Text(ownedText(for: offer))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.62))

                if let limit = offer.maxExchangeCount {
                    Text("交換回数 \(exchanged)/\(limit)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.orange)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                bgmManager.playSE(.push)
                quantity = 1
                resultMessage = nil
                selectedOffer = offer
            } label: {
                VStack(spacing: 3) {
                    HStack(spacing: 3) {
                        HalloweenCandyIcon(size: 16)
                        Text("\(offer.candyPrice)")
                            .monospacedDigit()
                    }
                    Text(maximum > 0 ? "交換" : "不足")
                }
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .frame(minWidth: 72, minHeight: 52)
                .background(maximum > 0 ? Color.orange : Color.gray.opacity(0.55), in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(maximum <= 0)
        }
        .padding(14)
        .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        }
    }

    private func ownedText(for offer: HalloweenExchangeOffer) -> String {
        switch offer.reward {
        case .food(let foodID, _):
            return "現在の所持数：\(state.foodCount(foodId: foodID))"
        case .toilet:
            return "現在の所持数：\(state.gachaSpecialItemCount(id: "wc"))"
        case .steps:
            return "現在の所持歩数：\(state.walletSteps.formatted())歩"
        case .candy:
            return "現在の所持数：\(store.candyCount)"
        }
    }

    private func exchangeModal(offer: HalloweenExchangeOffer) -> some View {
        let maximum = store.maximumExchangeQuantity(for: offer)
        let safeQuantity = maximum > 0 ? min(max(1, quantity), maximum) : 0
        let totalPrice = safeQuantity > 0 ? offer.candyPrice * safeQuantity : 0

        return ZStack {
            Color.black.opacity(0.56)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { selectedOffer = nil }

            VStack(spacing: 18) {
                HalloweenRewardIcon(reward: offer.reward, size: 82)

                VStack(spacing: 5) {
                    Text(offer.title)
                        .font(.system(size: 22, weight: .black, design: .rounded))

                    Text("交換する数を選択")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 18) {
                    quantityButton(
                        systemImage: "minus",
                        enabled: safeQuantity > 1,
                        background: safeQuantity > 1 ? Color.red.opacity(0.55) : Color.gray.opacity(0.42)
                    ) {
                        quantity = max(1, safeQuantity - 1)
                    }

                    VStack(spacing: 1) {
                        Text("\(safeQuantity)")
                            .font(.system(size: 34, weight: .black, design: .rounded))
                            .monospacedDigit()
                        Text("個")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                    .frame(minWidth: 70)

                    quantityButton(
                        systemImage: "plus",
                        enabled: safeQuantity < maximum,
                        background: safeQuantity < maximum ? Color.orange : Color.gray.opacity(0.42)
                    ) {
                        quantity = min(maximum, safeQuantity + 1)
                    }
                }

                HStack(spacing: 5) {
                    Text("必要")
                        .foregroundStyle(.secondary)
                    HalloweenCandyIcon(size: 16)
                    Text("\(totalPrice)")
                        .fontWeight(.black)
                        .monospacedDigit()
                    Spacer()
                    Text("交換後 \(max(0, store.candyCount - totalPrice))")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                .font(.system(size: 13, weight: .bold, design: .rounded))

                if let resultMessage {
                    Text(resultMessage)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Button {
                    performExchange(offer: offer, quantity: safeQuantity)
                } label: {
                    Text("\(safeQuantity)個交換する")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(safeQuantity > 0 ? Color.orange : Color.gray, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(safeQuantity <= 0)

                Button("閉じる") {
                    selectedOffer = nil
                }
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.secondary)
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 24)
            .frame(maxWidth: 340)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(color: .black.opacity(0.32), radius: 24, x: 0, y: 14)
            .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func quantityButton(
        systemImage: String,
        enabled: Bool,
        background: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            bgmManager.playSE(.push)
            action()
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(.white)
                .frame(width: 46, height: 46)
                .background(background, in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private func performExchange(offer: HalloweenExchangeOffer, quantity: Int) {
        bgmManager.playSE(.push)

        guard EventManager.isActive(.halloween2026) else {
            resultMessage = "イベントは終了しました。"
            return
        }

        guard Halloween2026RewardGranting.exchange(
            offer: offer,
            quantity: quantity,
            state: state,
            store: store
        ) else {
            resultMessage = "交換できませんでした。所持キャンディと交換上限を確認してください。"
            return
        }

        do {
            try modelContext.save()
            resultMessage = "\(offer.title)を\(quantity)個交換しました！"
        } catch {
            resultMessage = "交換は反映されましたが、保存処理を確認してください。"
        }

        self.quantity = 1
    }

    private var endedPanel: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(.orange)
            Text("交換所は終了しました")
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            Text("ゲームと交換所は2026/10/31で終了しています。")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.70))
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}
