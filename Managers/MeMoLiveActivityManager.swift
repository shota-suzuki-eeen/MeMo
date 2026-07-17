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
            Self.enabledStorageKey: false
        ])
    }

    nonisolated static let enabledStorageKey = "memo.liveActivity.careStatus.enabled"

    private static let activityStartedAtStorageKey = "memo.liveActivity.careStatus.startedAt"

    private let stepUpdateThreshold = 1
    private let defaultStaleInterval: TimeInterval = 60 * 30

    /// Live Activity は通常最大 8 時間で終了するため、期限直前まで待たず、
    /// アプリが前面に戻ったタイミングで十分に古い Activity だけ安全に差し替える。
    /// 毎回再生成はせず、通常は既存の 1 件を更新し続ける。
    private let proactiveRefreshInterval: TimeInterval = 60 * 60 * 4

    private struct StepSnapshot {
        let dayKey: String
        let steps: Int
        let capturedAt: Date
    }

    /// 複数の更新要求が await をまたいで同時進行しないよう、1 本の処理ループへ集約する。
    private var isReconciling = false
    private var reconcileRequested = false
    private var pendingState: AppState?
    private var pendingForceUpdate = false
    private var pendingRefreshIfAging = false

    /// HealthKit から届いた最も新しい歩数。AppState 側のキャッシュより優先して Live Activity へ反映する。
    private var latestStepSnapshot: StepSnapshot?

    var isUserEnabled: Bool {
        get { readBool(forKey: Self.enabledStorageKey, defaultValue: false) }
        set { UserDefaults.standard.set(newValue, forKey: Self.enabledStorageKey) }
    }

    var isSupported: Bool {
        if #available(iOS 16.1, *) {
            return ActivityAuthorizationInfo().areActivitiesEnabled
        }
        return false
    }

    private func readBool(forKey key: String, defaultValue: Bool) -> Bool {
        if UserDefaults.standard.object(forKey: key) == nil {
            return defaultValue
        }
        return UserDefaults.standard.bool(forKey: key)
    }

    // MARK: - Public synchronization

    /// アプリ起動・復帰時の同期。
    /// 原則として既存の Live Activity を再利用し、重複があれば 1 件だけ残す。
    /// 8 時間制限が近い場合のみ、排他的に安全な再生成を行う。
    func synchronizeOnAppLaunch(from state: AppState) async {
        await enqueueReconciliation(
            from: state,
            force: true,
            refreshIfAging: true
        )
    }

    func startIfNeeded(from state: AppState) async {
        await enqueueReconciliation(
            from: state,
            force: true,
            refreshIfAging: false
        )
    }

    func update(from state: AppState) async {
        await updateIfNeeded(from: state, force: true)
    }

    func updateIfNeeded(from state: AppState, force: Bool = false) async {
        await enqueueReconciliation(
            from: state,
            force: force,
            refreshIfAging: false
        )
    }

    func updateImmediately(from state: AppState) async {
        await updateIfNeeded(from: state, force: true)
    }

    /// HealthKit の Observer / Background Delivery から最新歩数だけを受け取るための入口。
    /// AppState が利用できないバックグラウンド更新でも、既存 Live Activity の歩数を更新できる。
    func updateTodaySteps(_ steps: Int, now: Date = Date()) async {
        latestStepSnapshot = StepSnapshot(
            dayKey: makeDayKey(now),
            steps: max(0, steps),
            capturedAt: now
        )

        await enqueueReconciliation(
            from: nil,
            force: false,
            refreshIfAging: false
        )
    }

    func setEnabled(_ enabled: Bool, state: AppState?) async {
        isUserEnabled = enabled

        await enqueueReconciliation(
            from: enabled ? state : nil,
            force: true,
            refreshIfAging: false
        )
    }

    /// 互換用。現在は設定画面から直接呼ばれない。
    func endAll() async {
        await endAllActivities(clearStoredStartDate: true)
    }

    // MARK: - Serialized reconciliation

    private func enqueueReconciliation(
        from state: AppState?,
        force: Bool,
        refreshIfAging: Bool
    ) async {
        if let state {
            pendingState = state
        }
        pendingForceUpdate = pendingForceUpdate || force
        pendingRefreshIfAging = pendingRefreshIfAging || refreshIfAging
        reconcileRequested = true

        guard !isReconciling else { return }

        isReconciling = true
        defer { isReconciling = false }

        while reconcileRequested {
            reconcileRequested = false

            let stateForPass = pendingState
            let forceForPass = pendingForceUpdate
            let refreshForPass = pendingRefreshIfAging

            pendingState = nil
            pendingForceUpdate = false
            pendingRefreshIfAging = false

            await performReconciliation(
                from: stateForPass,
                force: forceForPass,
                refreshIfAging: refreshForPass
            )
        }
    }

    private func performReconciliation(
        from state: AppState?,
        force: Bool,
        refreshIfAging: Bool
    ) async {
        guard isSupported else { return }

        guard isUserEnabled else {
            await endAllActivities(clearStoredStartDate: true)
            return
        }

        guard #available(iOS 16.1, *) else { return }

        var activities = Activity<MeMoCareActivityAttributes>.activities

        // 旧実装などで複数生成されていた場合も、常に 1 件へ自己修復する。
        if activities.count > 1 {
            let primary = activities.max { lhs, rhs in
                currentContentState(for: lhs).updatedAt < currentContentState(for: rhs).updatedAt
            } ?? activities[0]

            for duplicate in activities where duplicate.id != primary.id {
                await endActivityImmediately(duplicate)
            }
            activities = [primary]
        }

        // 毎回の起動で作り直すのではなく、寿命が近い場合だけ安全に差し替える。
        if refreshIfAging,
           !activities.isEmpty,
           shouldProactivelyRefreshExistingActivity(now: Date()) {
            await endAllActivities(clearStoredStartDate: true)
            activities.removeAll()
        }

        var primaryActivity = activities.first

        // 新規作成には AppState が必要。HealthKit の歩数単独更新では Activity を勝手に新設しない。
        if primaryActivity == nil, let state {
            primaryActivity = requestNewActivity(from: state, now: Date())
        }

        guard let primaryActivity else { return }

        if UserDefaults.standard.object(forKey: Self.activityStartedAtStorageKey) == nil {
            UserDefaults.standard.set(Date(), forKey: Self.activityStartedAtStorageKey)
        }

        if let state {
            await updateActivity(
                primaryActivity,
                with: makeContentState(from: state, now: Date()),
                force: force
            )
        } else if let latestStepSnapshot {
            await updateActivityStepsOnly(
                primaryActivity,
                snapshot: latestStepSnapshot,
                force: force
            )
        }
    }

    // MARK: - Activity creation / update

    @available(iOS 16.1, *)
    private func requestNewActivity(
        from state: AppState,
        now: Date
    ) -> Activity<MeMoCareActivityAttributes>? {
        // request() 自体は同期 API なので、MainActor 上でこのブロック中に別 request が割り込まない。
        // さらに全ての入口を reconciliation へ集約して二重生成を防ぐ。
        guard Activity<MeMoCareActivityAttributes>.activities.isEmpty else {
            return Activity<MeMoCareActivityAttributes>.activities.first
        }

        let attributes = MeMoCareActivityAttributes(appDisplayName: "ミーモ")
        let contentState = makeContentState(from: state, now: now)

        do {
            let activity: Activity<MeMoCareActivityAttributes>

            if #available(iOS 16.2, *) {
                let content = ActivityContent(
                    state: contentState,
                    staleDate: staleDate(for: contentState, now: now)
                )
                activity = try Activity<MeMoCareActivityAttributes>.request(
                    attributes: attributes,
                    content: content,
                    pushType: nil
                )
            } else {
                activity = try Activity<MeMoCareActivityAttributes>.request(
                    attributes: attributes,
                    contentState: contentState,
                    pushType: nil
                )
            }

            UserDefaults.standard.set(now, forKey: Self.activityStartedAtStorageKey)
            return activity
        } catch {
            print("[MeMoLiveActivityManager] start failed: \(error)")
            return nil
        }
    }

    @available(iOS 16.1, *)
    private func updateActivity(
        _ activity: Activity<MeMoCareActivityAttributes>,
        with newContentState: MeMoCareActivityAttributes.ContentState,
        force: Bool
    ) async {
        let oldContentState = currentContentState(for: activity)
        guard force || shouldPublishUpdate(old: oldContentState, new: newContentState) else {
            return
        }

        let now = Date()

        if #available(iOS 16.2, *) {
            let content = ActivityContent(
                state: newContentState,
                staleDate: staleDate(for: newContentState, now: now)
            )
            await activity.update(content)
        } else {
            await activity.update(using: newContentState)
        }
    }

    @available(iOS 16.1, *)
    private func updateActivityStepsOnly(
        _ activity: Activity<MeMoCareActivityAttributes>,
        snapshot: StepSnapshot,
        force: Bool
    ) async {
        let oldContentState = currentContentState(for: activity)
        var newContentState = oldContentState

        guard snapshot.dayKey == makeDayKey(Date()) else { return }

        if oldContentState.dayKey == snapshot.dayKey {
            newContentState.todaySteps = max(oldContentState.clampedTodaySteps, snapshot.steps)
        } else {
            newContentState.todaySteps = snapshot.steps
        }
        newContentState.dayKey = snapshot.dayKey
        newContentState.updatedAt = snapshot.capturedAt

        // 個別表示設定は廃止。既存 Activity が旧設定値を保持していても必ず通常表示へ戻す。
        newContentState.showsLockScreenCard = true
        newContentState.showsDynamicIslandContent = true

        await updateActivity(
            activity,
            with: newContentState,
            force: force
        )
    }

    @available(iOS 16.1, *)
    private func makeContentState(
        from state: AppState,
        now: Date = Date()
    ) -> MeMoCareActivityAttributes.ContentState {
        var contentState = state.makeLiveActivityContentState(
            now: now,
            showsLockScreenCard: true,
            showsDynamicIslandContent: true
        )

        if let snapshot = latestStepSnapshot,
           snapshot.dayKey == makeDayKey(now) {
            contentState.todaySteps = max(contentState.clampedTodaySteps, snapshot.steps)
            contentState.dayKey = snapshot.dayKey
            contentState.updatedAt = max(contentState.updatedAt, snapshot.capturedAt)
        }

        return contentState
    }

    // MARK: - Activity lifetime / duplicate cleanup

    @available(iOS 16.1, *)
    private func endActivityImmediately(
        _ activity: Activity<MeMoCareActivityAttributes>
    ) async {
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

    private func endAllActivities(clearStoredStartDate: Bool) async {
        guard #available(iOS 16.1, *) else { return }

        for activity in Activity<MeMoCareActivityAttributes>.activities {
            await endActivityImmediately(activity)
        }

        if clearStoredStartDate {
            UserDefaults.standard.removeObject(forKey: Self.activityStartedAtStorageKey)
        }
    }

    @available(iOS 16.1, *)
    private func shouldProactivelyRefreshExistingActivity(now: Date) -> Bool {
        guard !Activity<MeMoCareActivityAttributes>.activities.isEmpty else { return false }

        guard let startedAt = UserDefaults.standard.object(
            forKey: Self.activityStartedAtStorageKey
        ) as? Date else {
            // 旧バージョンからの移行時は一度だけ安全に再生成し、
            // 旧個別表示設定や不明な残り寿命をリセットする。
            return true
        }

        return now.timeIntervalSince(startedAt) >= proactiveRefreshInterval
    }

    // MARK: - Content helpers

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
    private func staleDate(
        for contentState: MeMoCareActivityAttributes.ContentState,
        now: Date
    ) -> Date {
        var candidates: [Date] = [now.addingTimeInterval(defaultStaleInterval)]

        if let fullnessNextDecayAt = contentState.fullnessNextDecayAt,
           fullnessNextDecayAt > now {
            candidates.append(fullnessNextDecayAt)
        }

        if let fullnessZeroAt = contentState.fullnessZeroAt,
           fullnessZeroAt > now {
            candidates.append(fullnessZeroAt)
        }

        if contentState.toiletFlagAt == nil,
           let toiletNextSpawnAt = contentState.toiletNextSpawnAt,
           toiletNextSpawnAt > now {
            candidates.append(toiletNextSpawnAt)
        }

        return candidates.min() ?? now.addingTimeInterval(defaultStaleInterval)
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
        if old.fullnessLastUpdatedAt != new.fullnessLastUpdatedAt { return true }
        if old.fullnessDecayUnitSeconds != new.fullnessDecayUnitSeconds { return true }
        if old.fullnessNextDecayAt != new.fullnessNextDecayAt { return true }
        if old.fullnessZeroAt != new.fullnessZeroAt { return true }

        if old.clampedHappinessLevel != new.clampedHappinessLevel { return true }
        if old.clampedHappinessPoint != new.clampedHappinessPoint { return true }
        if old.clampedHappinessMaxPoint != new.clampedHappinessMaxPoint { return true }

        if old.clampedWalletSteps != new.clampedWalletSteps { return true }
        if old.clampedTenGachaCost != new.clampedTenGachaCost { return true }

        if old.toiletFlagAt != new.toiletFlagAt { return true }
        if old.toiletNextSpawnAt != new.toiletNextSpawnAt { return true }

        return false
    }

    private func makeDayKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyyMMdd"
        return formatter.string(from: date)
    }
}
