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

    private init() {}

    private let enabledStorageKey = "memo.liveActivity.careStatus.enabled"

    var isUserEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: enabledStorageKey) }
        set { UserDefaults.standard.set(newValue, forKey: enabledStorageKey) }
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

    func startIfNeeded(from state: AppState) async {
        guard isUserEnabled else { return }
        guard isSupported else { return }

        if #available(iOS 16.1, *) {
            if currentActivity != nil {
                await update(from: state)
                return
            }

            let attributes = MeMoCareActivityAttributes(appDisplayName: "ミーモ")
            let contentState = state.makeLiveActivityContentState()

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
        guard isUserEnabled else { return }
        guard isSupported else { return }

        if #available(iOS 16.1, *) {
            let contentState = state.makeLiveActivityContentState()

            for activity in Activity<MeMoCareActivityAttributes>.activities {
                if #available(iOS 16.2, *) {
                    let content = ActivityContent(
                        state: contentState,
                        staleDate: Date().addingTimeInterval(60 * 30)
                    )
                    await activity.update(content)
                } else {
                    await activity.update(using: contentState)
                }
            }
        }
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
}
