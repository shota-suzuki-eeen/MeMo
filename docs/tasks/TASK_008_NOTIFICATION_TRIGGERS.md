# Task: Local Notification 発火タイミング・スケジューリング

## Status

`Ready for Codex`

## Goal

TASK_007で導入したLocal Notification基盤へ、MeMoの実状態に基づく6種類の通知発火タイミングを接続する。

アプリがforegroundにいない場合でも、既存状態から将来日時を予測できる通知は `UNUserNotificationCenter` へ事前scheduleし、状態変更時には必ずcancel / rescheduleしてstale notificationを残さない。

通知設定・OS permission・既存ゲーム状態を尊重し、同じイベントの重複通知を発生させない。

## Background

通知対象:

### Home

- 満腹度が0になった時
- トイレフラグ成立時
- おやすみモード終了時

### Gacha

- 広告視聴無料10回ガチャが可能になった時

### Fishing

- タイムブースト終了時
- 釣りカゴがいっぱいになった時

既存実装には将来日時・状態計算に利用できる情報がすでに存在する。

例:

- `AppState.satisfactionLevel`
- `AppState.satisfactionLastUpdatedAt`
- `AppState.fullnessDecayUnitSeconds`
- `toiletFlagAt`
- `toiletNextSpawnAt`
- `happinessSleepModeEndsAt`
- `GachaFreeAdSlot`
- `memo.gacha.freeAd.*`
- `FishingStore.timeBoostEndsAt`
- `FishingStore.pendingCatchCount`
- `FishingStore.basketCapacity`
- `FishingStore.lastCalculatedAt`
- Fishingの進行倍率 / time boost / `maximumAwayDuration`

これらと異なる並列stateを新たに作らない。

## Dependency

`TASK_007_NOTIFICATION_FOUNDATION_SETTINGS.md` が先に実装・マージ済みであること。

TASK_007で作成された以下を再利用する。

- notification manager / coordinator
- notification kind
- settings
- request identifier
- route contract
- permission state
- cancel / schedule API

同種の基盤をTASK_008で重複実装しない。

## Scope

### In scope

- 6通知のschedule / cancel / reschedule。
- アプリ起動 / foreground復帰時の全通知reconciliation。
- relevant state変更時の個別reconciliation。
- 将来日時の安全な算出helper。
- Gacha free-ad slotの時刻通知。
- Fishing basket fullの予測。
- stale pending notificationの削除。
- master / individual OFF時のcancel。
- permission変更後のreconciliation。
- foreground / background / terminated状態を想定したschedule。

### Out of scope

- Remote Push。
- APNs。
- server / DB。
- 通知設定UIの再設計。
- notification tap routeの再設計。
- fishing tap boost終了通知。
- bath通知。
- food flag通知。
- notification badge。
- Apple Watch独自通知。
- Widget独自通知。
- ゲーム状態の仕様変更。
- 釣果生成ロジック変更。
- Gacha free-ad時間帯変更。
- おやすみ時間変更。

## 最初に確認する既存実装

現在の `main` を使用し、TASK_007 merge後のコードを最初に確認する。

最低限:

- TASK_007で追加されたnotification manager / settings / route
- `MeMo/Models/AppState.swift`
  - fullness calculation
  - `satisfactionLevel`
  - `satisfactionLastUpdatedAt`
  - `fullnessDecayUnitSeconds`
  - `toiletFlagAt`
  - `toiletNextSpawnAt`
- `MeMo/Models/AppState+Happiness.swift`
  - `happinessSleepModeEndsAt`
  - `activateHappinessSleepMode`
  - sleep mode終了処理
- `MeMo/Models/AppState+Gacha.swift`
  - `GachaFreeAdSlot`
  - `gachaAvailableFreeAdSlot`
  - `gachaUsedFreeAdSlots`
  - `gachaConsumeFreeTenDraw`
- `MeMo/Views/HomeView.swift`
  - state refresh / scenePhase
  - feed / toilet / sleep state変更箇所
- `MeMo/Views/GachaView.swift`
  - free 10 draw
- `MeMo/Views/FishingView.swift`
  - `FishingStore`
  - `refresh`
  - `activateTimeBoost`
  - `claimOnePendingCatch`
  - `claimPendingCatches`
  - gear upgrade
  - `shortenNextCatch`
  - basket capacity
  - time boost
  - progression calculation
- `MeMo/Models/MeMoApp.swift`

既存計算helperを再利用し、同じ意味の時間計算を別式で複製しない。

## Required assets

| Asset | Runtime name/path | Git 管理 | Notes |
|---|---|---|---|
| なし | - | - | system notificationのみ |

## Notification identifiers

TASK_007で一元定義済みのidentifier contractを使用する。

TASK_007にまだ具体値がない場合は以下を採用し、一元定義する。

- `memo.notification.fullnessZero`
- `memo.notification.toilet`
- `memo.notification.sleepEnded`
- `memo.notification.gachaFreeTen.morning`
- `memo.notification.gachaFreeTen.noon`
- `memo.notification.gachaFreeTen.evening`
- `memo.notification.fishingTimeBoostEnded`
- `memo.notification.fishingBasketFull`

同じeventのreschedule時は同じidentifierを使用し、pending requestを置換またはcancelして重複させない。

## Notification content

初期copy:

| Kind | Title | Body |
|---|---|---|
| fullnessZero | お腹が空いています | ミーモのお腹が空っぽになりました。ごはんをあげましょう。 |
| toilet | トイレのお世話が必要です | トイレのお世話ができるようになりました。 |
| sleepEnded | おやすみモード終了 | ミーモのおやすみモードが終了しました。 |
| gachaFreeTen | 無料10回ガチャ | 無料10回ガチャができる時間になりました。 |
| fishingTimeBoostEnded | タイムブースト終了 | 釣りのタイムブーストが終了しました。 |
| fishingBasketFull | 釣りカゴがいっぱいです | 釣りカゴがいっぱいになりました。釣果を受け取りましょう。 |

- default soundを使用する。
- badgeは設定しない。
- copy調整のためにidentifier / route contractを変更しない。

## Functional requirements

### 共通

1. notification master OFFなら全MeMo pending notificationをcancelする。
2. individual OFFなら該当kindのpending notificationをcancelする。
3. OS authorizationが通知不可なら新規scheduleを行わない。
4. authorization復帰後、app foreground時に現在stateから再scheduleする。
5. app launch / foreground復帰時に全kindをreconcileする。
6. relevant stateが変化したとき、該当kindをreconcileする。
7. stale notificationを残さない。
8. 同一eventのpending requestを重複させない。
9. すでに成立済みの状態に対し、設定ONへ戻しただけで過去イベントの即時通知を送らない。
10. future transitionがある場合のみscheduleする。
11. appが起動していなくても発火できるものはtime/calendar triggerとして事前予約する。
12. UserDefaultsに「通知発火済み」flagを乱造しない。
13. pending notification identifier + source stateを正として可能な限りreconcileする。
14. ゲームstateの永続化意味を変更しない。

### A. 満腹度0

15. 現在のfullness計算ロジックと同じ意味で「0になる将来日時」を求める。
16. `fullnessDecayUnitSeconds` 等の既存定数を使用する。
17. `satisfactionLevel` と `satisfactionLastUpdatedAt` の既存semanticsを確認する。
18. fullnessがすでに0の場合、新しい即時通知をscheduleしない。
19. fullness > 0で将来0になる日時が算出できる場合、その日時へscheduleする。
20. ごはんをあげる等でfullness stateが変化した場合、旧requestをcancel / replaceする。
21. clock skew / nil timestampに対して既存fullness計算と矛盾しないfallbackを使用する。
22. 通知のためだけにfullness値を保存し直さない。

### B. トイレフラグ成立

23. `toiletNextSpawnAt` がfutureであり、現在`toiletFlagAt == nil`なら、その成立予定日時へscheduleする。
24. `toiletFlagAt != nil` ですでに成立済みの場合、設定ON時にstaleな即時通知を追加しない。
25. toilet clean / next spawn再設定時にscheduleを更新する。
26. `toiletNextSpawnAt` が変更・nil化された場合、旧requestをcancelする。
27. onboarding用の強制toilet stateと本番stateを混同せず、mandatory tutorial中に不要な通知を出さない。

### C. おやすみモード終了

28. `happinessSleepModeEndsAt` がfutureの場合、その日時へscheduleする。
29. sleep mode再発動 / end延長時は同identifierでrescheduleする。
30. sleep mode終了済み / nilならpending requestをcancelする。
31. sleep mode終了処理自体のhappiness decay semanticsを変更しない。

### D. 広告視聴無料10回ガチャ

32. 現在の`GachaFreeAdSlot`を正とする。
33. 時間帯は既存仕様のまま:
    - morning: `05:00`
    - noon: `10:00`
    - evening: `15:00`
34. 「可能になった時」はslot開始時刻を意味する。
35. ad SDKの`isReady`はapp未起動中に保証できないため、Local Notificationの発火条件には含めない。
36. 通知は「free-ad slotの時間条件が開始した」ことを知らせる。
37. 3つのdaily repeating `UNCalendarNotificationTrigger` を優先する。
38. local timezone / Calendar.currentに追従する。
39. 23:00-05:00に追加slotを作らない。
40. current slotをすでに消費した後に設定変更しても、そのslotについてstaleな即時通知を送らない。
41. repeating requestは次回同slot時刻から継続してよい。
42. free draw consumption / pity / draw logicは変更しない。
43. temporary AdMob pauseの内部仕様は変更しない。

### E. 釣りタイムブースト終了

44. `FishingStore.timeBoostEndsAt` がfutureの場合、その日時へscheduleする。
45. boost開始時にschedule / rescheduleする。
46. boost終了済み / nilの場合はpending requestをcancelする。
47. time boostの倍率・duration・釣果計算は変更しない。
48. tap boost終了通知は作らない。

### F. 釣りカゴ満杯

49. 現在の`pendingCatchCount`と`basketCapacity`から残り枠数を求める。
50. すでにfullなら、新しい即時通知をscheduleしない。
51. fullになる将来日時を、現在のFishingStore進行ロジックと同じsemanticsで予測する。
52. speciesのrandomnessは満杯時刻に影響しないため、catch count progressionだけで計算する。
53. `lastCalculatedAt` のpartial progressを考慮する。
54. bobber levelによる`timeProgressMultiplier`を考慮する。
55. active `timeBoostStartedAt` / `timeBoostEndsAt` の境界を考慮する。
56. `baseCatchInterval`を再利用する。
57. `maximumAwayDuration`を無視して、実際のoffline進行仕様より先の「満杯」を通知しない。
58. 現在のstore semantics上、app processの追加refreshなしでは満杯到達を保証できない未来なら、その時点のbasket-full通知を無理にscheduleしない。
59. 予測ロジックは可能なら`FishingStore`のpure helperとして追加し、UI側に別計算を複製しない。
60. prediction helperはゲームstateを書き換えない。
61. `refresh`、claim、basket upgrade、bobber upgrade、time boost開始、tap shorten等、満杯予測時刻が変化する操作後にreconcileする。
62. basketから魚を受け取りfull解除した場合、新しい予測日時へrescheduleする。
63. basket level変更でcapacityが変わった場合rescheduleする。
64. notification実装のために釣果生成数・乱数・point・capacityを変更しない。

## Reconciliation requirements

中央のreconcile APIを用意する。

概念:

- `reconcileAll(...)`
- `reconcileHome(...)`
- `reconcileGacha(...)`
- `reconcileFishing(...)`

名前は既存architectureに合わせて変更可。

呼び出し候補:

- app launch / root ready
- scenePhase -> `.active`
- permission / notification setting変更
- feed完了
- toilet state更新 / clean
- sleep activation
- free draw consumption後（pending repeating scheduleの整合確認のみ）
- FishingStore state更新後

注意:

- SwiftUI body評価のたびに大量のschedule APIを呼ばない。
- 同じstateに対して無限rescheduleしない。
- MainActor / async API境界を適切に扱う。
- `UNUserNotificationCenter.getPendingNotificationRequests` が必要ならidentifierで差分更新する。

## UI / interaction requirements

このTaskでは通知設定UIを再設計しない。

通知タップrouteはTASK_007のcontractを使用。

- fullnessZero -> Home
- toilet -> Home
- sleepEnded -> Home
- gachaFreeTen -> Gacha
- fishingTimeBoostEnded -> Fishing
- fishingBasketFull -> Fishing

foregroundでもTASK_007のdelegate policyを使用する。

## Persistence requirements

### No new app-state persistence

TASK_007で導入した設定UserDefaults以外に、新しいgame-state persistenceを追加しない。

原則として追加禁止:

- notification-fired flags
- last-notified dateの独自store
- mirror copy of fullness / toilet / sleep / fishing / gacha state
- SwiftData stored property
- new Data payload

OSのpending notification自体は `UNUserNotificationCenter` が管理する。

既存keyの意味を変更しない。

## Existing-user compatibility

既存ユーザーの以下を維持する。

- SwiftData
- `notifyFeed / notifyBath / notifyToilet` Legacy property
- fullness
- toilet schedule
- happiness / sleep mode
- gacha used free-ad slots
- gacha pity / guaranteed / ownership / unlock
- fishing pending counts / point / gear / boost state
- onboarding
- photos
- walk
- Widget / Watch

update後に既存stateからnotification scheduleを再構築できること。

例:

- active sleep mode -> 残り終了日時へschedule
- active fishing time boost -> 残り終了日時へschedule
- future toilet spawn -> schedule
- current fullness > 0 -> zero dateへschedule
- fishing basket not full -> current progressionから安全に予測可能ならschedule

## Xcode / target impact

- affected target(s):
  - `MeMo`
- `MeMo.xcodeproj` 変更必要?:
  - 原則source-only
  - 不要なproject変更をしない
- Target Membership change?:
  - helper追加時のみ確認
- entitlements / capability change?:
  - なし
  - Push Notifications capabilityを追加しない
- Swift Package change?:
  - なし
- ignored/local Asset dependency?:
  - なし

## 不要に変更してはいけない file

以下は必要なintegration箇所以外、仕様変更しない。

- SwiftData schema
- `AppState` existing stored property
- `AppState+Gacha` persistence key
- `AppState+Happiness` persistence key
- FishingStore persistence key
- AdMob logic
- Gacha draw / pity
- fishing reward generation
- Documents
- Widget / App Group
- WatchConnectivity
- StoreKit / entitlements

## Acceptance criteria

- [ ] master OFFでpending MeMo通知がcancelされる
- [ ] individual OFFで該当kindのみcancelされる
- [ ] ONへ戻すとcurrent stateからfuture notificationが再構築される
- [ ] fullness 0日時へscheduleされる
- [ ] feed後にfullness通知日時が更新される
- [ ] already 0でstale即時通知を作らない
- [ ] future toilet flag日時へscheduleされる
- [ ] toilet成立済み状態でstale即時通知を作らない
- [ ] sleep endへscheduleされる
- [ ] sleep end変更時にreplaceされる
- [ ] Gacha 05:00 / 10:00 / 15:00の通知が設定される
- [ ] ad SDK readinessをLocal Notification条件にしない
- [ ] fishing time boost endへscheduleされる
- [ ] tap boost通知を作っていない
- [ ] basket full予測がexisting progression semanticsと一致する
- [ ] basket full済みでstale即時通知を作らない
- [ ] basket claim / gear / boost / progress変更後に予測が更新される
- [ ] maximumAwayDurationを超えた誤通知をしない
- [ ] identifier重複通知がない
- [ ] notification tap routeはTASK_007どおり
- [ ] new game-state persistenceがない
- [ ] existing user dataが読める
- [ ] unrelated behaviorが変わらない
- [ ] project file changeが必要最小限
- [ ] Cloudでbuildできない場合、affected targetをlocal Xcodeで確認する

## Verification

### Codex Cloud

静的 / deterministic testを可能な範囲で追加・実行。

最低限確認:

- fullness:
  - level 1 / partial progress
  - level 5
  - already 0
- toilet:
  - future
  - active
  - nil
- sleep:
  - future
  - expired
  - extended
- gacha:
  - 05:00 / 10:00 / 15:00
  - 23:00-05:00に余計なslotなし
- fishing time boost:
  - active
  - expired
- basket:
  - empty
  - partially full
  - one slot remaining
  - already full
  - bobber Lv差
  - active boost boundary跨ぎ
  - basket capacity変更
  - maximumAwayDuration境界

Commands / checks:

- `rg -n 'UNNotificationRequest|UN.*NotificationTrigger|memo\.notification' MeMo`
- `rg -n 'maximumAwayDuration|baseCatchInterval|timeBoostEndsAt|basketCapacity|pendingCatchCount' MeMo/Views/FishingView.swift`
- `git diff --check`
- persistence key / SwiftData property diff確認
- entitlements差分確認
- usable Xcode toolchainがある場合のみ `MeMo` scheme build

### Local Xcode

- affected scheme:
  - `MeMo`
- device:
  - iPhone 15実機を優先
  - iPhone 17 Pro Simulatorも確認
- Settings:
  - master / individual
  - OS許可
- 各通知:
  - dateを短時間テスト用に安全に差し替え可能なdebug方法が既存方針に合う場合のみ利用
  - 本番duration定数を恒久変更しない
- background / terminated:
  - sleep end
  - time boost end
  - scheduled notification tap
- route:
  - Home
  - Gacha
  - Fishing
- duplicate:
  - foreground/restoreを繰り返してもpending identifierが増殖しない

### Upgrade test

既存リリースデータを保持したupdate test。

確認:

- future toilet stateからscheduleされる
- active sleep modeからscheduleされる
- active fishing boostからscheduleされる
- existing pending fish countからbasket full予測が再構築される
- gacha used slot / pity / ownershipが変化しない
- fullness stateが変化しない
- notification scheduleのために既存game stateが書き換えられない
- Legacy notification SwiftData propertyが維持される

## Codex final report

Codex は以下を報告すること。

- changed files
- implementation summary
- notification schedule architecture
- identifier一覧
- notification copy
- fullness zero date calculation
- toilet scheduling
- sleep scheduling
- gacha repeating schedule
- fishing time boost scheduling
- basket full prediction algorithm
- `maximumAwayDuration` handling
- schedule / cancel / reconcile call sites
- persistence impact
- existing-user compatibility
- Xcode / target impact
- entitlement / capability impact
- Cloud verification
- local Xcode verification required
- migration / upgrade verification
- remaining risks
