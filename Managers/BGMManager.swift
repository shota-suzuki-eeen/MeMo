//
//  BGMManager.swift
//  MeMo
//
//  Updated for per-screen BGM with fade transitions.
//  Fixed build error for StepViewModel notification references.
//

import Foundation
import AVFoundation
import Combine
import UIKit

@MainActor
final class BGMManager: NSObject, ObservableObject, AVAudioPlayerDelegate {

    // MARK: - Notifications used by StepViewModel

    static let stepSessionDidEnterWorkoutNotification = Notification.Name(
        "BGMManager.stepSessionDidEnterWorkoutNotification"
    )

    static let stepSessionDidExitWorkoutNotification = Notification.Name(
        "BGMManager.stepSessionDidExitWorkoutNotification"
    )

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

    enum BackgroundTrack: String, CaseIterable {
        case main = "BGM_main"
        case gacha = "BGM_gacha"
        case zukan = "BGM_zukan"
    }

    private let defaultTrack: BackgroundTrack = .main
    private let targetBGMVolume: Float = 0.7

    private var player: AVAudioPlayer?
    private var currentTrack: BackgroundTrack?
    private var hasPrepared: Bool = false

    private var fadeTask: Task<Void, Never>?

    private var activeSEPlayers: [UUID: AVAudioPlayer] = [:]

    private var bundleAudioURLCache: [String: URL] = [:]
    private var dataAssetCache: [String: Data] = [:]
    private var notificationCancellables: Set<AnyCancellable> = []

    override init() {
        super.init()
        bindNotifications()
    }

    // MARK: - Public

    func startIfNeeded() {
        startIfNeeded(track: defaultTrack)
    }

    func startIfNeeded(
        track: BackgroundTrack,
        fadeDuration: TimeInterval = 0.55
    ) {
        if currentTrack == track, let player, player.isPlaying {
            return
        }

        switchBackground(to: track, fadeDuration: fadeDuration)
    }

    func switchBackground(
        to track: BackgroundTrack,
        fadeDuration: TimeInterval = 0.55
    ) {
        fadeTask?.cancel()

        do {
            try configureAudioSessionIfNeeded()

            if currentTrack == track, let player {
                if !player.isPlaying {
                    if player.currentTime >= player.duration {
                        player.currentTime = 0
                    }
                    player.play()
                }
                let startVolume = max(0, min(targetBGMVolume, player.volume))
                scheduleFade(
                    player: player,
                    from: startVolume,
                    to: targetBGMVolume,
                    duration: fadeDuration
                )
                return
            }

            let nextPlayer = try makeAudioPlayer(named: track.rawValue)
            nextPlayer.numberOfLoops = -1
            nextPlayer.volume = 0
            nextPlayer.prepareToPlay()
            nextPlayer.play()

            let previousPlayer = player
            player = nextPlayer
            currentTrack = track
            hasPrepared = true

            scheduleCrossfade(
                from: previousPlayer,
                to: nextPlayer,
                duration: fadeDuration
            )
        } catch {
            print("❌ BGM切り替えに失敗しました: \(track.rawValue) / \(error.localizedDescription)")
        }
    }

    func stop(fadeDuration: TimeInterval = 0.4) {
        guard let player else { return }
        fadeTask?.cancel()

        let startVolume = max(0, min(targetBGMVolume, player.volume))
        scheduleFade(
            player: player,
            from: startVolume,
            to: 0,
            duration: fadeDuration
        ) { [weak self, weak player] in
            guard let self, let player else { return }
            player.stop()
            player.currentTime = 0
            if self.player === player {
                self.player = nil
                self.currentTrack = nil
                self.hasPrepared = false
            }
        }
    }

    func stopImmediately() {
        fadeTask?.cancel()
        player?.stop()
        player?.currentTime = 0
        player = nil
        currentTrack = nil
        hasPrepared = false
    }

    func restoreDefaultBackground(fadeDuration: TimeInterval = 0.55) {
        switchBackground(to: defaultTrack, fadeDuration: fadeDuration)
    }

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

    // MARK: - Notification Binding

    private func bindNotifications() {
        NotificationCenter.default.publisher(for: Self.stepSessionDidEnterWorkoutNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.stop(fadeDuration: 0.45)
            }
            .store(in: &notificationCancellables)

        NotificationCenter.default.publisher(for: Self.stepSessionDidExitWorkoutNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.restoreDefaultBackground(fadeDuration: 0.55)
            }
            .store(in: &notificationCancellables)
    }

    // MARK: - Private

    private func scheduleCrossfade(
        from oldPlayer: AVAudioPlayer?,
        to newPlayer: AVAudioPlayer,
        duration: TimeInterval
    ) {
        fadeTask?.cancel()

        let safeDuration = max(0.01, duration)
        let stepCount = max(1, Int((safeDuration / 0.05).rounded(.up)))
        let sleepNanoseconds = UInt64((safeDuration / Double(stepCount)) * 1_000_000_000)

        fadeTask = Task { @MainActor in
            for step in 0...stepCount {
                guard !Task.isCancelled else { return }

                let progress = Float(step) / Float(stepCount)
                newPlayer.volume = targetBGMVolume * progress

                if let oldPlayer {
                    oldPlayer.volume = targetBGMVolume * (1.0 - progress)
                }

                if step < stepCount {
                    try? await Task.sleep(nanoseconds: sleepNanoseconds)
                }
            }

            if let oldPlayer {
                oldPlayer.stop()
                oldPlayer.currentTime = 0
            }

            fadeTask = nil
        }
    }

    private func scheduleFade(
        player: AVAudioPlayer,
        from startVolume: Float,
        to endVolume: Float,
        duration: TimeInterval,
        completion: (() -> Void)? = nil
    ) {
        fadeTask?.cancel()

        let safeDuration = max(0.01, duration)
        let stepCount = max(1, Int((safeDuration / 0.05).rounded(.up)))
        let sleepNanoseconds = UInt64((safeDuration / Double(stepCount)) * 1_000_000_000)

        fadeTask = Task { @MainActor in
            for step in 0...stepCount {
                guard !Task.isCancelled else { return }

                let progress = Float(step) / Float(stepCount)
                let nextVolume = startVolume + ((endVolume - startVolume) * progress)
                player.volume = max(0, min(targetBGMVolume, nextVolume))

                if step < stepCount {
                    try? await Task.sleep(nanoseconds: sleepNanoseconds)
                }
            }

            completion?()
            fadeTask = nil
        }
    }

    private func configureAudioSessionIfNeeded() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.ambient, mode: .default, options: [])
        try session.setActive(true)
    }

    private func makeAudioPlayer(named name: String) throws -> AVAudioPlayer {
        if let url = findAudioFileURLInBundle(named: name) {
            return try AVAudioPlayer(contentsOf: url)
        }

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
