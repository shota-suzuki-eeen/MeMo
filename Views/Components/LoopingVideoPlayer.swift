//
//  LoopingVideoPlayer.swift
//  MeMo
//
//  Created by shota suzuki on 2026/04/07.
//

import SwiftUI
import AVFoundation
import Combine
import UIKit

@MainActor
final class LoopingVideoPlayerController: ObservableObject {
    let objectWillChange = ObservableObjectPublisher()
    let player = AVQueuePlayer()

    private var looper: AVPlayerLooper?
    private var currentAssetName: String?

    init() {
        player.isMuted = true
        player.actionAtItemEnd = .none
        player.automaticallyWaitsToMinimizeStalling = false
    }

    func prepare(assetName: String) {
        guard currentAssetName != assetName else { return }

        objectWillChange.send()
        currentAssetName = assetName

        player.pause()
        player.removeAllItems()
        looper = nil

        guard let url = Self.assetURL(named: assetName) else { return }

        let asset = AVURLAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        item.preferredForwardBufferDuration = 1

        looper = AVPlayerLooper(player: player, templateItem: item)
    }

    func play() {
        player.playImmediately(atRate: 1.0)
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
        view.setPlayer(controller.player)
        return view
    }

    func updateUIView(_ uiView: PlayerContainerView, context: Context) {
        uiView.setPlayer(controller.player)
    }

    static func dismantleUIView(_ uiView: PlayerContainerView, coordinator: ()) {
        uiView.setPlayer(nil)
    }
}

final class PlayerContainerView: UIView {
    let playerLayer = AVPlayerLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        isOpaque = true
        backgroundColor = .black
        clipsToBounds = true

        playerLayer.videoGravity = .resizeAspectFill
        playerLayer.backgroundColor = UIColor.black.cgColor
        playerLayer.contentsGravity = .resizeAspectFill

        layer.addSublayer(playerLayer)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
    }

    func setPlayer(_ player: AVPlayer?) {
        if playerLayer.player !== player {
            playerLayer.player = player
        }
    }
}
