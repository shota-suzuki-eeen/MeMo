import SwiftUI
import SwiftData

struct Halloween2026GachaView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var bgmManager: BGMManager
    @ObservedObject var store: Halloween2026EventStore
    let state: AppState
    @ObservedObject private var adManager = AdMobManager.shared
    @ObservedObject private var rewarded = AdMobManager.shared.rewardGacha
    @State private var result: HalloweenGachaBatch?
    @State private var activeAdID: String?
    @State private var message: String?

    private var busy: Bool { activeAdID != nil || result != nil || store.pendingGachaBatch != nil }

    var body: some View {
        TimelineView(.periodic(from: Date(), by: 1)) { timeline in
            let open = EventManager.areRewardsAvailable(.halloween2026, at: timeline.date)
            let claim = store.availableEventAdClaim(at: timeline.date)
            ScrollView {
                VStack(spacing: 18) {
                    HStack {
                        Text("イベントガチャ").font(.title2.bold())
                        Spacer()
                        Button("閉じる") { dismiss() }.disabled(activeAdID != nil || store.pendingGachaBatch != nil)
                    }
                    HStack(spacing: 8) {
                        HalloweenCandyIcon(size: 30)
                        Text("\(store.candyCount)").font(.title.bold()).monospacedDigit()
                        Spacer()
                        Text("11/7まで").font(.subheadline.bold())
                    }
                    Image("gatyaMachine_halloween").resizable().scaledToFit().frame(maxHeight: 290)
                        .accessibilityLabel("ハロウィンガチャマシン")
                    VStack(spacing: 8) {
                        if HalloweenGachaCatalog.characterIDs.allSatisfy({ state.ownedPetIDs().contains($0) }) {
                            Text("ハロウィンキャラクター コンプリート").font(.headline)
                            Text("アイテムの抽選は引き続き楽しめます").font(.caption)
                        } else {
                            Text("ラストワンまで あと\(50 - store.gachaDrawProgress)回").font(.headline)
                            ProgressView(value: Double(store.gachaDrawProgress), total: 50).tint(.orange)
                            Text("50回ごとに未所持キャラクター1体 · 日付をまたいでも持ち越し").font(.caption)
                        }
                    }.padding(14).background(.black.opacity(0.32), in: RoundedRectangle(cornerRadius: 18))
                    if open {
                        HStack(spacing: 12) {
                            action("1回 / 50キャンディ", enabled: !busy && store.candyCount >= 50) { draw(count: 1) }
                            action("10回 / 500キャンディ", enabled: !busy && store.candyCount >= 500) { draw(count: 10) }
                        }
                        action(rewarded.isLoading ? "広告を準備中" : (rewarded.isAvailableWithoutAd ? "無料10回ガチャ" : "広告視聴で無料10回"),
                               enabled: !busy && claim != nil && rewarded.isReady) { if let claim { showAd(claim: claim) } }
                        Text(claim.map { "\($0.slot.title)の枠（\($0.slot.windowText)）" } ?? "無料枠は時間外または使用済みです")
                            .font(.caption).multilineTextAlignment(.center)
                        Text("無料枠：5〜10時 / 10〜15時 / 15〜23時 · 各1回\n通常ガチャの無料枠とは別です")
                            .font(.caption).multilineTextAlignment(.center)
                    } else { Text("イベントガチャは終了しました").font(.headline) }
                    if let message { Text(message).font(.subheadline).foregroundStyle(.yellow) }
                    if store.pendingGachaBatch != nil {
                        action("報酬の保存を再試行", enabled: true) { recover() }
                    }
                    rewardInformation(at: timeline.date)
                }
                .foregroundStyle(.white).padding(20).frame(maxWidth: 560).frame(maxWidth: .infinity)
            }
            .background {
                Image("halloween_shop").resizable().scaledToFill().ignoresSafeArea()
                    .overlay(.black.opacity(0.3)).clipped()
            }
        }
        .sheet(item: $result) { batch in
            HalloweenGachaResultView(batch: batch)
        }
        .onAppear {
            recover()
            bgmManager.switchBackground(to: .gacha)
            AdMobManager.shared.prepareRewardGacha()
        }
        .onDisappear { bgmManager.switchBackground(to: .fishing) }
        .onChange(of: rewarded.isPresentingAd) { _, presenting in
            // An ad dismissed without earning a reward releases the UI lock without consuming a slot.
            if !presenting { activeAdID = nil }
        }
    }

    private func action(_ title: String, enabled: Bool, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            Text(title).font(.headline).multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 56).padding(.horizontal, 6)
        }.memoGlassButtonStyle(prominent: true, tint: .orange).disabled(!enabled).opacity(enabled ? 1 : 0.45)
    }

    private func rewardInformation(at date: Date) -> some View {
        let counts = store.currentSRCounts(at: date)
        let exhausted = HalloweenGachaCatalog.availableSRIDs(counts: counts).isEmpty
        return VStack(alignment: .leading, spacing: 10) {
            Text("排出内容").font(.headline)
            Text(exhausted ? "N 68.75% / R 31.25%（本日のSRは上限）" : "N 66% / R 30% / SR 4%")
            Text("N：食べ物19種 / R：食べ物8種・トイレ\n各1個 · キャラクターはラストワン限定")
            Text("SR（残りの景品から重みを再計算）").font(.subheadline.bold())
            Text("通常チケット：\(min(10, counts["gachaTicket_nomal"] ?? 0))/10枚 · 基準60%")
            Text("焼肉定食：\(min(2, counts["yakiniku"] ?? 0))/2個 · 基準20%")
            Text("フィッシュポイント500：\(min(2, counts["fishingPoints500"] ?? 0))/2回 · 基準20%")
            Text("SR上限は毎日0時（日本時間）に戻ります").font(.caption)
            Text("ラストワン対象：\(HalloweenGachaCatalog.characterAssetNames.joined(separator: "・"))").font(.caption)
        }.font(.subheadline).padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(.black.opacity(0.4), in: RoundedRectangle(cornerRadius: 20))
    }

    private func draw(count: Int, id: String = UUID().uuidString, claim: HalloweenGachaAdClaim? = nil) {
        guard result == nil else { return }
        do {
            guard let batch = try Halloween2026GachaGranting.draw(id: id, count: count, state: state, store: store, context: context, adClaim: claim) else {
                message = "残高・無料枠・開催期間を確認してください"; return
            }
            message = nil
            bgmManager.playSE(.gachaDo)
            result = batch
        } catch { message = "報酬の保存を完了できませんでした。再試行してください。" }
    }

    private func showAd(claim: HalloweenGachaAdClaim) {
        guard !busy, rewarded.isReady else { return }
        let id = UUID().uuidString
        activeAdID = id
        rewarded.show(onReward: {
            guard activeAdID == id else { return }
            activeAdID = nil
            draw(count: 10, id: id, claim: claim)
        }, onUnavailable: {
            guard activeAdID == id else { return }
            activeAdID = nil
            message = adManager.rewardedUnavailableMessage
            AdMobManager.shared.prepareRewardGacha()
        })
    }

    private func recover() {
        do {
            if let batch = try Halloween2026GachaGranting.recover(state: state, store: store, context: context) { result = batch }
            message = nil
        } catch { message = "報酬の保存を完了できませんでした。再試行してください。" }
    }
}

private struct HalloweenGachaResultView: View {
    let batch: HalloweenGachaBatch
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(batch.rewards) { reward in
                        HStack(spacing: 16) {
                            if reward.kind == .fishingPoints {
                                Image(systemName: "fish.fill").font(.system(size: 48)).frame(width: 72, height: 72)
                            } else {
                                Image(image(reward)).resizable().scaledToFit().frame(width: 72, height: 72)
                            }
                            VStack(alignment: .leading, spacing: 5) {
                                Text(reward.rarity).font(.headline).foregroundStyle(reward.kind == .character ? .orange : .primary)
                                Text(title(reward)).font(.headline)
                                Text("\(reward.drawNumber)回目\(reward.kind == .character ? " · ラストワン" : "")").font(.caption)
                            }
                            Spacer()
                        }.padding(12).background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    }
                }.padding(18)
            }.navigationTitle("獲得した報酬")
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完了") { dismiss() } } }
        }
    }
    private func image(_ reward: HalloweenGachaReward) -> String {
        switch reward.kind {
        case .food: return FoodCatalog.byId(reward.itemID)?.assetName ?? reward.itemID
        case .character: return PetMaster.assetName(for: reward.itemID)
        case .fishingPoints: return ""
        case .item: return reward.itemID
        }
    }
    private func title(_ reward: HalloweenGachaReward) -> String {
        switch reward.kind {
        case .food: return "\(FoodCatalog.byId(reward.itemID)?.name ?? reward.itemID) ×1"
        case .character: return PetMaster.all.first { $0.id == reward.itemID }?.name ?? reward.itemID
        case .fishingPoints: return "フィッシュポイント +500"
        case .item: return reward.itemID == "wc" ? "トイレ ×1" : "通常ガチャチケット ×1"
        }
    }
}
