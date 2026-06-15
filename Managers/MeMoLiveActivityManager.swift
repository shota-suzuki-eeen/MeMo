//
//  MeMoLiveActivityManager.swift
//  MeMo
//
//  App-side controller for starting, updating, and ending the care-status Live Activity.
//  Add this file to the MeMo app target only.
//

import ActivityKit
import Foundation

@MainActor
final class MeMoLiveActivityManager {
    static let shared = MeMoLiveActivityManager()

    private init() {
        UserDefaults.standard.register(defaults: [
            Self.enabledStorageKey: false,
            Self.lockScreenEnabledStorageKey: true,
            Self.dynamicIslandEnabledStorageKey: true
        ])
    }

    nonisolated static let enabledStorageKey = "memo.liveActivity.careStatus.enabled"
    nonisolated static let lockScreenEnabledStorageKey = "memo.liveActivity.careStatus.lockScreen.enabled"
    nonisolated static let dynamicIslandEnabledStorageKey = "memo.liveActivity.careStatus.dynamicIsland.enabled"

    private let stepUpdateThreshold = 50

    var isUserEnabled: Bool {
        get { readBool(forKey: Self.enabledStorageKey, defaultValue: false) }
        set { UserDefaults.standard.set(newValue, forKey: Self.enabledStorageKey) }
    }

    var isLockScreenEnabled: Bool {
        get { readBool(forKey: Self.lockScreenEnabledStorageKey, defaultValue: true) }
        set { UserDefaults.standard.set(newValue, forKey: Self.lockScreenEnabledStorageKey) }
    }

    var isDynamicIslandEnabled: Bool {
        get { readBool(forKey: Self.dynamicIslandEnabledStorageKey, defaultValue: true) }
        set { UserDefaults.standard.set(newValue, forKey: Self.dynamicIslandEnabledStorageKey) }
    }

    private var hasAnyVisibleDestination: Bool {
        isLockScreenEnabled || isDynamicIslandEnabled
    }

    var isSupported: Bool {
        if #available(iOS 16.1, *) {
            return ActivityAuthorizationInfo().areActivitiesEnabled
        }
        return false
    }

    @available(iOS 16.1, *)
    private var currentActivity: Activity<MeMoCareActivityAttributes>? {
        Activity<MeMoCareActivityAttributes>.activities.first
    }

    private func readBool(forKey key: String, defaultValue: Bool) -> Bool {
        if UserDefaults.standard.object(forKey: key) == nil {
            return defaultValue
        }
        return UserDefaults.standard.bool(forKey: key)
    }

    @available(iOS 16.1, *)
    private func makeContentState(from state: AppState, now: Date = Date()) -> MeMoCareActivityAttributes.ContentState {
        state.makeLiveActivityContentState(
            now: now,
            showsLockScreenCard: isLockScreenEnabled,
            showsDynamicIslandContent: isDynamicIslandEnabled
        )
    }

    func startIfNeeded(from state: AppState) async {
        guard isUserEnabled else { return }
        guard isSupported else { return }

        if !hasAnyVisibleDestination {
            await endAll()
            return
        }

        if #available(iOS 16.1, *) {
            if currentActivity != nil {
                await update(from: state)
                return
            }

            let attributes = MeMoCareActivityAttributes(appDisplayName: "ミーモ")
            let contentState = makeContentState(from: state)

            do {
                if #available(iOS 16.2, *) {
                    let content = ActivityContent(
                        state: contentState,
                        staleDate: Date().addingTimeInterval(60 * 30)
                    )
                    _ = try Activity<MeMoCareActivityAttributes>.request(
                        attributes: attributes,
                        content: content,
                        pushType: nil
                    )
                } else {
                    _ = try Activity<MeMoCareActivityAttributes>.request(
                        attributes: attributes,
                        contentState: contentState,
                        pushType: nil
                    )
                }
            } catch {
                print("[MeMoLiveActivityManager] start failed: \(error)")
            }
        }
    }

    func update(from state: AppState) async {
        await updateIfNeeded(from: state, force: true)
    }

    func updateIfNeeded(from state: AppState, force: Bool = false) async {
        guard isUserEnabled else {
            await endAll()
            return
        }
        guard isSupported else { return }

        if !hasAnyVisibleDestination {
            await endAll()
            return
        }

        if #available(iOS 16.1, *) {
            guard !Activity<MeMoCareActivityAttributes>.activities.isEmpty else {
                await startIfNeeded(from: state)
                return
            }

            let newContentState = makeContentState(from: state)

            for activity in Activity<MeMoCareActivityAttributes>.activities {
                let oldContentState = currentContentState(for: activity)
                guard force || shouldPublishUpdate(old: oldContentState, new: newContentState) else {
                    continue
                }

                if #available(iOS 16.2, *) {
                    let content = ActivityContent(
                        state: newContentState,
                        staleDate: Date().addingTimeInterval(60 * 30)
                    )
                    await activity.update(content)
                } else {
                    await activity.update(using: newContentState)
                }
            }
        }
    }

    func updateImmediately(from state: AppState) async {
        await updateIfNeeded(from: state, force: true)
    }

    func setEnabled(_ enabled: Bool, state: AppState?) async {
        isUserEnabled = enabled

        if enabled {
            guard let state else { return }
            await startIfNeeded(from: state)
        } else {
            await endAll()
        }
    }

    func setDisplayPreferences(
        lockScreenEnabled: Bool? = nil,
        dynamicIslandEnabled: Bool? = nil,
        state: AppState?
    ) async {
        if let lockScreenEnabled {
            isLockScreenEnabled = lockScreenEnabled
        }
        if let dynamicIslandEnabled {
            isDynamicIslandEnabled = dynamicIslandEnabled
        }

        guard let state else { return }

        if isUserEnabled {
            if hasAnyVisibleDestination {
                await startIfNeeded(from: state)
                await updateImmediately(from: state)
            } else {
                await endAll()
            }
        }
    }

    func endAll() async {
        guard #available(iOS 16.1, *) else { return }

        for activity in Activity<MeMoCareActivityAttributes>.activities {
            if #available(iOS 16.2, *) {
                let finalState = activity.content.state
                await activity.end(
                    ActivityContent(state: finalState, staleDate: nil),
                    dismissalPolicy: .immediate
                )
            } else {
                let finalState = activity.contentState
                await activity.end(using: finalState, dismissalPolicy: .immediate)
            }
        }
    }

    @available(iOS 16.1, *)
    private func currentContentState(
        for activity: Activity<MeMoCareActivityAttributes>
    ) -> MeMoCareActivityAttributes.ContentState {
        if #available(iOS 16.2, *) {
            return activity.content.state
        } else {
            return activity.contentState
        }
    }

    @available(iOS 16.1, *)
    private func shouldPublishUpdate(
        old: MeMoCareActivityAttributes.ContentState,
        new: MeMoCareActivityAttributes.ContentState
    ) -> Bool {
        if old.petName != new.petName { return true }
        if old.petImageName != new.petImageName { return true }
        if old.wallpaperAssetName != new.wallpaperAssetName { return true }

        if old.showsLockScreenCard != new.showsLockScreenCard { return true }
        if old.showsDynamicIslandContent != new.showsDynamicIslandContent { return true }

        if old.dayKey != new.dayKey { return true }
        if abs(old.clampedTodaySteps - new.clampedTodaySteps) >= stepUpdateThreshold { return true }
        if old.dailyStepGoal != new.dailyStepGoal { return true }

        if old.clampedFullnessLevel != new.clampedFullnessLevel { return true }
        if old.clampedFullnessMaxLevel != new.clampedFullnessMaxLevel { return true }

        if old.clampedHappinessLevel != new.clampedHappinessLevel { return true }
        if old.clampedHappinessPoint != new.clampedHappinessPoint { return true }
        if old.clampedHappinessMaxPoint != new.clampedHappinessMaxPoint { return true }

        if old.clampedWalletSteps != new.clampedWalletSteps { return true }
        if old.clampedTenGachaCost != new.clampedTenGachaCost { return true }

        return false
    }
}
