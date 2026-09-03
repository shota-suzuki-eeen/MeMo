//
//  Halloween2026RewardView.swift
//  MeMo
//
//  ハイスコア報酬 / 累計距離報酬のタブ、次の報酬、プログレスバー、受取処理。
//

import SwiftUI
import SwiftData

struct Halloween2026RewardWindow: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var bgmManager: BGMManager

    let state: AppState
    @ObservedObject var store: Halloween2026EventStore
    let onClose: () -> Void

    @State private var selectedTrack: HalloweenRewardTrack = .highScore
    @State private var message: String?

    var body: some View {
        ZStack {
            Color.black.opacity(0.52)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { onClose() }

            VStack(spacing: 16) {
                header
                trackPicker
                nextRewardPanel
                rewardList

                if let message {
                    Text(message)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 20)
            .frame(maxWidth: 360)
            .frame(maxHeight: 650)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(Color.white.opacity(0.45), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.32), radius: 28, x: 0, y: 16)
            .padding(.horizontal, 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text("イベント報酬")
                .font(.system(size: 22, weight: .black, design: .rounded))

            Spacer()

            Button {
                bgmManager.playSE(.push)
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(.primary)
                    .frame(width: 38, height: 38)
                    .background(Color.secondary.opacity(0.14), in: Circle())
            }
            .buttonStyle(.plain)
        }
    }

    private var trackPicker: some View {
        HStack(spacing: 8) {
            ForEach(HalloweenRewardTrack.allCases) { track in
                Button {
                    bgmManager.playSE(.push)
                    withAnimation(.easeInOut(duration: 0.16)) {
                        selectedTrack = track
                        message = nil
                    }
                } label: {
                    Text(track.title)
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(selectedTrack == track ? Color.white : Color.primary)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(
                            selectedTrack == track ? Color.orange : Color.secondary.opacity(0.12),
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var nextRewardPanel: some View {
        let current = currentDistance

        if let next = nextUnclaimedReward {
            let progress = min(1, Double(current) / Double(max(1, next.targetDistance)))
            let remaining = max(0, next.targetDistance - current)

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    HalloweenRewardIcon(reward: next.reward, size: 46)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(next.isReached(in: store) ? "受け取り可能！" : "次の報酬")
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundStyle(next.isReached(in: store) ? Color.orange : Color.secondary)

                        Text(next.reward.displayName)
                            .font(.system(size: 17, weight: .black, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }

                    Spacer(minLength: 0)
                }

                ProgressView(value: progress)
                    .tint(.orange)
                    .scaleEffect(x: 1, y: 1.6, anchor: .center)

                HStack {
                    Text("\(current.formatted()) / \(next.targetDistance.formatted())m")
                    Spacer()
                    Text(remaining == 0 ? "達成！" : "あと \(remaining.formatted())m")
                }
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
                .monospacedDigit()
            }
            .padding(14)
            .background(Color.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.orange.opacity(0.24), lineWidth: 1)
            }
        } else {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.green)

                Text("このタブの報酬はすべて獲得済みです")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color.green.opacity(0.10), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    private var rewardList: some View {
        ScrollView(.vertical, showsIndicators: true) {
            LazyVStack(spacing: 10) {
                ForEach(rewards) { reward in
                    rewardRow(reward)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func rewardRow(_ reward: HalloweenDistanceReward) -> some View {
        let reached = reward.isReached(in: store)
        let claimed = reward.isClaimed(in: store)

        return HStack(spacing: 12) {
            HalloweenRewardIcon(reward: reward.reward, size: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text("\(reward.targetDistance.formatted())m")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .monospacedDigit()

                Text(reward.reward.displayName)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 4)

            if claimed {
                Label("獲得済み", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(.green)
            } else if reached {
                Button {
                    claim(reward)
                } label: {
                    Text("受け取る")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 36)
                        .background(Color.orange, in: Capsule())
                }
                .buttonStyle(.plain)
            } else {
                Text("未達成")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var rewards: [HalloweenDistanceReward] {
        Halloween2026RewardCatalog.rewards(for: selectedTrack)
    }

    private var currentDistance: Int {
        switch selectedTrack {
        case .highScore:
            return store.bestDistance
        case .totalDistance:
            return store.totalDistance
        }
    }

    private var nextUnclaimedReward: HalloweenDistanceReward? {
        rewards.first { !$0.isClaimed(in: store) }
    }

    private func claim(_ reward: HalloweenDistanceReward) {
        bgmManager.playSE(.push)

        guard EventManager.isActive(.halloween2026) else {
            message = "イベントは終了しました。"
            return
        }

        guard Halloween2026RewardGranting.claim(
            reward: reward,
            state: state,
            store: store
        ) else {
            message = "報酬を受け取れませんでした。"
            return
        }

        do {
            try modelContext.save()
            message = "\(reward.reward.displayName)を獲得しました！"
        } catch {
            message = "報酬は反映されましたが、保存処理を確認してください。"
        }
    }
}
