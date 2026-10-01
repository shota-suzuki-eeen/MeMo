import Foundation
import Combine
import UserNotifications

/// Converts existing game state into the complete desired local-notification set.
/// OS authorization and pending-request ownership remain in `MemoNotificationManager`.
@MainActor
final class MemoNotificationReconciler {
    static let shared = MemoNotificationReconciler()

    private weak var appState: AppState?
    private var fishingObservation: AnyCancellable?
    private var pendingFishingReconciliation: Task<Void, Never>?

    private init() {
        fishingObservation = FishingStore.shared.objectWillChange.sink { [weak self] _ in
            Task { @MainActor [weak self] in
                await Task.yield()
                self?.scheduleFishingReconciliation()
            }
        }
    }

    func register(appState: AppState) {
        self.appState = appState
    }

    func reconcileAll(now: Date = Date()) async {
        guard let appState else { return }
        let status = await MemoNotificationManager.shared.refreshAuthorizationStatus()
        guard MemoNotificationPreferences.value(forKey: MemoNotificationPreferences.masterEnabledKey),
              status == .authorized || status == .provisional || status == .ephemeral
        else {
            MemoNotificationManager.shared.cancelAll()
            return
        }

        let requests = homeRequests(state: appState, now: now)
            + gachaRequests()
            + fishingRequests(store: .shared, now: now)
        await MemoNotificationManager.shared.reconcile(with: requests)
    }

    func reconcileHome(now: Date = Date()) async { await reconcileAll(now: now) }
    func reconcileGacha() async { await reconcileAll() }
    func reconcileFishing(now: Date = Date()) async { await reconcileAll(now: now) }

    private func homeRequests(state: AppState, now: Date) -> [MemoLocalNotificationRequest] {
        guard state.memoMandatoryOnboardingCompleted else { return [] }
        var requests: [MemoLocalNotificationRequest] = []

        if let fireDate = state.fullnessZeroDate(now: now), fireDate > now {
            requests.append(dateRequest(id: .fullnessZero, title: "お腹が空いています", body: "ミーモのお腹が空っぽになりました。ごはんをあげましょう。", fireDate: fireDate))
        }
        if state.toiletFlagAt == nil, let fireDate = state.toiletNextSpawnAt, fireDate > now {
            requests.append(dateRequest(id: .toilet, title: "トイレのお世話が必要です", body: "トイレのお世話ができるようになりました。", fireDate: fireDate))
        }
        if let fireDate = state.happinessSleepModeEndsAt, fireDate > now {
            requests.append(dateRequest(id: .sleepEnded, title: "おやすみモード終了", body: "ミーモのおやすみモードが終了しました。", fireDate: fireDate))
        }
        return requests
    }

    private func gachaRequests() -> [MemoLocalNotificationRequest] {
        [gachaRequest(id: .gachaFreeTenMorning, slot: .morning),
         gachaRequest(id: .gachaFreeTenNoon, slot: .noon),
         gachaRequest(id: .gachaFreeTenEvening, slot: .evening)]
    }

    private func fishingRequests(store: FishingStore, now: Date) -> [MemoLocalNotificationRequest] {
        var requests: [MemoLocalNotificationRequest] = []
        if let fireDate = store.timeBoostEndsAt, fireDate > now {
            requests.append(dateRequest(id: .fishingTimeBoostEnded, title: "タイムブースト終了", body: "釣りのタイムブーストが終了しました。", fireDate: fireDate))
        }
        if let fireDate = store.predictedBasketFullDate(now: now), fireDate > now {
            requests.append(dateRequest(id: .fishingBasketFull, title: "釣りカゴがいっぱいです", body: "釣りカゴがいっぱいになりました。釣果を受け取りましょう。", fireDate: fireDate))
        }
        return requests
    }

    private func dateRequest(id: MemoNotificationRequestID, title: String, body: String, fireDate: Date) -> MemoLocalNotificationRequest {
        let components = Calendar.current.dateComponents(
            [.calendar, .timeZone, .year, .month, .day, .hour, .minute, .second],
            from: fireDate
        )
        return MemoLocalNotificationRequest(
            requestID: id,
            title: title,
            body: body,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        )
    }

    private func gachaRequest(id: MemoNotificationRequestID, slot: GachaFreeAdSlot) -> MemoLocalNotificationRequest {
        return MemoLocalNotificationRequest(
            requestID: id,
            title: "無料10回ガチャ",
            body: "無料10回ガチャができる時間になりました。",
            trigger: UNCalendarNotificationTrigger(dateMatching: DateComponents(calendar: .current, timeZone: .current, hour: slot.startHour, minute: 0), repeats: true)
        )
    }

    private func scheduleFishingReconciliation() {
        pendingFishingReconciliation?.cancel()
        pendingFishingReconciliation = Task { @MainActor [weak self] in
            await Task.yield()
            guard !Task.isCancelled else { return }
            await self?.reconcileFishing()
        }
    }
}
