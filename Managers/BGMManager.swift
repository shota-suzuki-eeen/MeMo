//
//  BGMManager.swift
//  MeMo
//
//  Updated for per-screen BGM with fade transitions.
//  SoundEffect mappings adjusted for adopted SE/BGM assets only.
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

    // MARK: - Notifications used by Home sound hooks

    static let happinessHeartDidAppearNotification = Notification.Name(
        "BGMManager.happinessHeartDidAppearNotification"
    )

    static let manualToiletCleanupDidFinishNotification = Notification.Name(
        "BGMManager.manualToiletCleanupDidFinishNotification"
    )

    // MARK: - Sound Effect

    enum SoundEffect: CaseIterable, Hashable {
        case button
        case food
        case gacha
        case gachaDo
        case touch
        case wc
        case wcCleanup

        // Existing call-site compatibility
        static let push: SoundEffect = .button
        static let open: SoundEffect = .button
        static let buy: SoundEffect = .button
        static let bath: SoundEffect = .button
        static let eat: SoundEffect = .food
        static let love: SoundEffect = .touch
        static let crap: SoundEffect = .wcCleanup

        var resourceName: String {
            switch self {
            case .button:
                return "effect_button"
            case .food:
                return "effect_food"
            case .gacha:
                return "effect_gacha"
            case .gachaDo:
                return "effect_gacha_do"
            case .touch:
                return "effect_touch"
            case .wc, .wcCleanup:
                return "effect_wc"
            }
        }

        var allowsOverlap: Bool {
            switch self {
            case .touch:
                return false
            default:
                return true
            }
        }

        var fadeOutDuration: TimeInterval? {
            resourceName == "effect_wc" ? 3.0 : nil
        }
    }

    enum BackgroundTrack: String, CaseIterable {
        case main = "BGM_main"
        case gacha = "BGM_gacha"
        case zukan = "BGM_zukan"
        case takibi = "takibi"
    }

    private final class ActiveSEPlayback {
        let effect: SoundEffect
        let player: AVAudioPlayer
        var fadeTask: Task<Void, Never>?

        init(effect: SoundEffect, player: AVAudioPlayer) {
            self.effect = effect
            self.player = player
        }
    }

    private let defaultTrack: BackgroundTrack = .main
    private let targetBGMVolume: Float = 0.7

    private var player: AVAudioPlayer?
    private var currentTrack: BackgroundTrack?
    private var hasPrepared: Bool = false

    private var fadeTask: Task<Void, Never>?

    private var activeSEPlaybacks: [UUID: ActiveSEPlayback] = [:]
    private var nonOverlappingEffectsInFlight: Set<SoundEffect> = []

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
        if !effect.allowsOverlap, nonOverlappingEffectsInFlight.contains(effect) {
            return
        }

        do {
            try configureAudioSessionIfNeeded()

            let sePlayer = try makeAudioPlayer(named: effect.resourceName)
            let id = UUID()
            let playback = ActiveSEPlayback(effect: effect, player: sePlayer)

            sePlayer.delegate = self
            sePlayer.volume = max(0.0, min(1.0, volume))
            sePlayer.numberOfLoops = 0
            sePlayer.prepareToPlay()

            activeSEPlaybacks[id] = playback

            if !effect.allowsOverlap {
                nonOverlappingEffectsInFlight.insert(effect)
            }

            sePlayer.play()

            if let fadeOutDuration = effect.fadeOutDuration {
                scheduleSEFadeOut(for: id, duration: fadeOutDuration)
            }
        } catch {
            print("❌ SE再生に失敗しました: \(effect.resourceName) / \(error.localizedDescription)")
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

        NotificationCenter.default.publisher(for: Self.happinessHeartDidAppearNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.playSE(.touch)
            }
            .store(in: &notificationCancellables)

        NotificationCenter.default.publisher(for: Self.manualToiletCleanupDidFinishNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.playSE(.wcCleanup)
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

    private func scheduleSEFadeOut(for playbackID: UUID, duration: TimeInterval) {
        guard let playback = activeSEPlaybacks[playbackID] else { return }

        playback.fadeTask?.cancel()

        let startVolume = max(0, min(1.0, playback.player.volume))
        let safeDuration = max(0.01, duration)
        let stepCount = max(1, Int((safeDuration / 0.05).rounded(.up)))
        let sleepNanoseconds = UInt64((safeDuration / Double(stepCount)) * 1_000_000_000)

        playback.fadeTask = Task { @MainActor in
            for step in 0...stepCount {
                guard !Task.isCancelled else { return }
                guard let playback = activeSEPlaybacks[playbackID] else { return }

                let progress = Float(step) / Float(stepCount)
                playback.player.volume = max(0, min(1.0, startVolume * (1.0 - progress)))

                if step < stepCount {
                    try? await Task.sleep(nanoseconds: sleepNanoseconds)
                }
            }

            guard let playback = activeSEPlaybacks[playbackID] else { return }
            playback.player.stop()
            removeSEPlayback(for: playbackID)
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
        guard let id = activeSEPlaybacks.first(where: { $0.value.player === target })?.key else {
            return
        }
        removeSEPlayback(for: id)
    }

    private func removeSEPlayback(for id: UUID) {
        guard let playback = activeSEPlaybacks.removeValue(forKey: id) else { return }
        playback.fadeTask?.cancel()

        if !playback.effect.allowsOverlap {
            nonOverlappingEffectsInFlight.remove(playback.effect)
        }
    }
}
