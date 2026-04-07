//
//  LoopingVideoPlayer.swift
//  MeMo
//
//  Created by shota suzuki on 2026/04/07.
//

import SwiftUI
import AVFoundation
import Combine

@MainActor
final class LoopingVideoPlayerController: ObservableObject {
    let objectWillChange = ObservableObjectPublisher()
    let player = AVQueuePlayer()

    private var looper: AVPlayerLooper?
    private var currentAssetName: String?

    init() {
        player.isMuted = true
        player.actionAtItemEnd = .none
    }

    func prepare(assetName: String) {
        guard currentAssetName != assetName else { return }
        objectWillChange.send()
        currentAssetName = assetName

        player.pause()
        player.removeAllItems()
        looper = nil

        guard let url = Self.assetURL(named: assetName) else { return }

        let item = AVPlayerItem(url: url)
        looper = AVPlayerLooper(player: player, templateItem: item)
    }

    func play() {
        player.play()
    }

    func pause() {
        player.pause()
    }

    private static func assetURL(named assetName: String) -> URL? {
        let candidates = ["mp4", "mov", "m4v"]
        for ext in candidates {
            if let url = Bundle.main.url(forResource: assetName, withExtension: ext) {
                return url
            }
        }
        return nil
    }
}

struct LoopingVideoPlayer: UIViewRepresentable {
    @ObservedObject var controller: LoopingVideoPlayerController

    func makeUIView(context: Context) -> PlayerContainerView {
        let view = PlayerContainerView()
        view.playerLayer.videoGravity = .resizeAspectFill
        view.playerLayer.player = controller.player
        return view
    }

    func updateUIView(_ uiView: PlayerContainerView, context: Context) {
        uiView.playerLayer.player = controller.player
    }
}

final class PlayerContainerView: UIView {
    override class var layerClass: AnyClass {
        AVPlayerLayer.self
    }

    var playerLayer: AVPlayerLayer {
        guard let layer = self.layer as? AVPlayerLayer else {
            fatalError("Failed to cast layer to AVPlayerLayer")
        }
        return layer
    }
}
