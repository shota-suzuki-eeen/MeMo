//
//  CharacterVideoPlayerView.swift
//  MeMo
//
//  Created by shota suzuki on 2026/04/07.
//

import SwiftUI

struct CharacterVideoPlayerView: View {
    let assetName: String
    let isPlaying: Bool
    let waitingTitle: String
    let runningTitle: String

    @StateObject private var controller = LoopingVideoPlayerController()

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.black.opacity(0.28))

            LoopingVideoPlayer(controller: controller)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                }

            VStack {
                HStack {
                    Text(isPlaying ? runningTitle : waitingTitle)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.42), in: Capsule())
                    Spacer()
                }
                Spacer()
            }
            .padding(14)

            if !isPlaying {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.black.opacity(0.18))

                VStack(spacing: 8) {
                    Image(systemName: "figure.run")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white.opacity(0.88))

                    Text("スタート後にキャラクター動画がループ再生されます")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.82))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 16)
            }
        }
        .onAppear {
            controller.prepare(assetName: assetName)
            updatePlayback()
        }
        .onChange(of: assetName) { _, newValue in
            controller.prepare(assetName: newValue)
            updatePlayback()
        }
        .onChange(of: isPlaying) { _, _ in
            updatePlayback()
        }
        .onDisappear {
            controller.pause()
        }
    }

    private func updatePlayback() {
        if isPlaying {
            controller.play()
        } else {
            controller.pause()
        }
    }
}
