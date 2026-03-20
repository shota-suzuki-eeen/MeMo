//
//  BGMManager.swift
//  MeMo
//
//  Created by shota suzuki on 2026/03/20.
//

import Foundation
import AVFoundation
import Combine
import UIKit

@MainActor
final class BGMManager: NSObject, ObservableObject, AVAudioPlayerDelegate {

    // MARK: - Sound Effect

    enum SoundEffect: String, CaseIterable {
        case bath
        case buy
        case crap
        case eat
        case love
        case open
        case push
        case wc
    }

    // ✅ 仕様：アセット名（ユーザー指定）
    private let bgmAssetName: String = "もじゃもじゃ日和"

    private var player: AVAudioPlayer?

    // ✅ 多重起動防止（startIfNeeded用）
    private var hasPrepared: Bool = false

    // ✅ 効果音は重なって鳴る可能性があるため、再生中インスタンスを保持
    private var activeSEPlayers: [UUID: AVAudioPlayer] = [:]

    // ✅ Bundle/DataAsset 探索結果をキャッシュ
    private var bundleAudioURLCache: [String: URL] = [:]
    private var dataAssetCache: [String: Data] = [:]

    override init() {
        super.init()
    }

    // MARK: - Public

    /// ✅ すでに再生中なら何もしない。止まっていたら再開する。
    func startIfNeeded() {
        // すでに再生中なら終了
        if let player, player.isPlaying { return }

        // 準備済みなら再開
        if hasPrepared, let player {
            player.play()
            return
        }

        // 未準備なら準備して再生
        prepareAndPlay()
    }

    /// ✅ 停止（現仕様では基本呼ばないが、将来の設定ON/OFF用）
    func stop() {
        player?.stop()
    }

    /// ✅ 効果音再生
    func playSE(_ effect: SoundEffect, volume: Float = 1.0) {
        do {
            try configureAudioSessionIfNeeded()

            let sePlayer = try makeAudioPlayer(named: effect.rawValue)
            let id = UUID()

            sePlayer.delegate = self
            sePlayer.volume = max(0.0, min(1.0, volume))
            sePlayer.numberOfLoops = 0
            sePlayer.prepareToPlay()
            sePlayer.play()

            activeSEPlayers[id] = sePlayer
        } catch {
            print("❌ SE再生に失敗しました: \(effect.rawValue) / \(error.localizedDescription)")
        }
    }

    // MARK: - AVAudioPlayerDelegate

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            removeFinishedSEPlayer(player)
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in
            removeFinishedSEPlayer(player)
            if let error {
                print("❌ SEデコードエラー: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Private

    private func prepareAndPlay() {
        do {
            try configureAudioSessionIfNeeded()

            let p = try makeAudioPlayer(named: bgmAssetName)
            configureAndPlay(player: p)
        } catch {
            print("❌ BGM再生準備に失敗: \(error.localizedDescription)")
        }
    }

    private func configureAndPlay(player p: AVAudioPlayer) {
        p.numberOfLoops = -1      // ✅ 無限ループ
        p.volume = 0.7            // ✅ お好みで調整
        p.prepareToPlay()
        p.play()

        self.player = p
        self.hasPrepared = true
    }

    private func configureAudioSessionIfNeeded() throws {
        // ✅ BGM/SEともにミュートスイッチに従う
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.ambient, mode: .default, options: [])
        try session.setActive(true)
    }

    private func makeAudioPlayer(named name: String) throws -> AVAudioPlayer {
        // 1) Bundle内ファイル
        if let url = findAudioFileURLInBundle(named: name) {
            return try AVAudioPlayer(contentsOf: url)
        }

        // 2) Data Asset
        if let data = findAudioDataAsset(named: name) {
            return try AVAudioPlayer(data: data)
        }

        throw NSError(
            domain: "BGMManager",
            code: 404,
            userInfo: [NSLocalizedDescriptionKey: "音源が見つかりません: \(name)"]
        )
    }

    private func findAudioFileURLInBundle(named name: String) -> URL? {
        if let cached = bundleAudioURLCache[name] {
            return cached
        }

        // よくある拡張子を順に試す（必要なら追加OK）
        let exts = ["m4a", "mp3", "wav", "aif", "aiff", "caf"]
        for ext in exts {
            if let url = Bundle.main.url(forResource: name, withExtension: ext) {
                bundleAudioURLCache[name] = url
                return url
            }
        }
        return nil
    }

    private func findAudioDataAsset(named name: String) -> Data? {
        if let cached = dataAssetCache[name] {
            return cached
        }

        if let data = NSDataAsset(name: name)?.data {
            dataAssetCache[name] = data
            return data
        }

        return nil
    }

    private func removeFinishedSEPlayer(_ target: AVAudioPlayer) {
        if let key = activeSEPlayers.first(where: { $0.value === target })?.key {
            activeSEPlayers.removeValue(forKey: key)
        }
    }
}
