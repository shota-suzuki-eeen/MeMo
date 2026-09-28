# 永続化・後方互換ルール

## 目的

MeMo はすでにリリース済みです。

以下の変更は compile が通っても既存ユーザーのデータ破損につながる可能性があります。

- SwiftData stored property
- UserDefaults / @AppStorage key
- Codable payload
- Documents path
- Widget / App Group identifier
- WatchConnectivity protocol

現在の source path は `MeMo/` 配下です。

---

# 1. SwiftData

現在登録されている model:

| Model | Source | Role |
|---|---|---|
| `AppState` | `MeMo/Models/AppState.swift` | core application / progression state |
| `TodayPhotoEntry` | `MeMo/Models/TodayPhotoEntry.swift` | memory photo metadata |
| `WorkoutSessionRecord` | `MeMo/Models/StepModels.swift` | walking / workout records |

## `AppState`

既存 stored property 名は migration なしに変更しないこと。

代表例:

- `walletSteps`
- `pendingKcal`
- `lastSyncedAt`
- `dailyGoalKcal`
- `lastDayKey`
- `cachedTodaySteps`
- `cachedTodayKcal`
- `satisfactionLevel`
- `satisfactionLastUpdatedAt`
- `foodFlagAt`
- `foodLastRaisedAt`
- `foodNextSpawnAt`
- `bathFlagAt`
- `bathLastRaisedAt`
- `bathNextSpawnAt`
- `toiletFlagAt`
- `toiletLastRaisedAt`
- `toiletNextSpawnAt`
- `toiletPoopsData`
- `toiletPoopLastSpawnAt`
- `currentPetID`
- `ownedPetIDsData`
- `notifyFeed`
- `notifyBath`
- `notifyToilet`
- `ownedFoodCountsData`
- `superFavoriteRevealedData`
- `stepEnjoyLastCheckedAt`
- `stepEnjoyTotalSteps`
- `stepEnjoyLastDeltaSteps`
- `stepEnjoyLogsData`
- `stepEnjoyDailyCycleStart`
- `stepEnjoyDailyRewardCount`
- `stepEnjoyDailyRewardStepBank`
- `stepEnjoyLastRewardAt`

古い用語の property 名でも、readability のためだけに rename しないこと。

### Legacy notification settings

- `notifyFeed`
- `notifyBath`
- `notifyToilet`

上記は現在の通知機能では使用しない。
既存SwiftData schemaとの互換性維持のためAppStateから削除しないこと。
新規通知設定では再利用しない。

## `WorkoutSessionRecord`

Source:

`MeMo/Models/StepModels.swift`

`routeData` は `[WorkoutRoutePoint]` を encode/decode します。

Shape を変更する場合でも旧 routeData が decode できるようにしてください。

## `TodayPhotoEntry`

Source:

`MeMo/Models/TodayPhotoEntry.swift`

既存 metadata:

- `dayKey`
- `date`
- `fileName`
- `placeName`
- `latitude`
- `longitude`

---

# 2. Documents

画像は以下へ保存:

`Documents/memories/`

migration なしに変更しない:

- `memories` directory
- fileName rule
- JPEG 前提
- metadata と physical file の対応

移動する場合は old path → new path migration を作り、new file が読めることを確認してから old data を扱うこと。

---

# 3. UserDefaults / @AppStorage

literal key string が保存値の identity です。

Swift constant 名の変更は literal が同じなら問題ありませんが、literal key 自体の変更は migration が必要です。

## Gacha

Source:

`MeMo/Models/AppState+Gacha.swift`

Legacy:

- `memo.gacha.pityCounter`
- `memo.gacha.guaranteedGoldNext`

Newer:

- `memo.gacha.pityCountersByGacha`
- `memo.gacha.guaranteedGoldNextByGacha`
- `memo.gacha.freeAd.dayKey`
- `memo.gacha.freeAd.usedSlots`
- `memo.gacha.specialItemCounts`
- `memo.gacha.initialIPadFreeTenDrawConsumed`

既存 fallback / dual-write を維持すること。

## Happiness

Source:

`MeMo/Models/AppState+Happiness.swift`

- `memo.happiness.point`
- `memo.happiness.level`
- `memo.happiness.lastDecayAt`
- `memo.happiness.petting.touchCountToday`
- `memo.happiness.petting.pointsToday`
- `memo.happiness.petting.dayKey`
- `memo.happiness.claimedRewardLevels`
- `memo.happiness.sleepMode.endsAt`

Runtime では context / pet ID suffix が付く key もあります。

## Onboarding

- `memo.onboarding.mandatory.started`
- `memo.onboarding.mandatory.completed`
- `memo.onboarding.mandatory.currentStep`

## Walk

- `memo.walk.activeSession`
- `memo.walk.pendingResult`
- `memo.walk.*`

Source:

`MeMo/Models/WalkChallengeStore.swift`

## Fishing

- `memo.fishing.pointBalance`
- `memo.fishing.pendingCounts`
- `memo.fishing.lifetime*`

Source:

`MeMo/Views/FishingView.swift`

## Halloween 2026

- `memo.event.halloween2026.progress.v1`

`v1` も key の一部です。

## Sound

- `memo.sound.bgm.enabled`
- `memo.sound.bgm.volumeStep`
- `memo.sound.effect.enabled`

## Wallpaper

- `selectedHomeWallpaperAssetName`
- `memo.work.focus.unlockedRewardAssetNames`

## Appearance

- `memoAppearanceMode`

## Developer mode

- `isDeveloperMode`

## Ads

- `memo.admob.rewarded.loadFailureRecords`
- `memo.admob.temporaryPauseUntil`

## Widget shared state

App Group:

`group.com.shota.CalPet`

代表例:

- `memo.homeWidget.snapshot.v1`
- `memo.homeWidget.snapshot.signature.v1`
- `currentPetID`
- `todaySteps`
- `toiletFlag`

実装時は現在の source を再検索してください。

---

# 4. Cross-target compatibility

## Widget

Source:

`MeMo/MeMoWidget/`

変更注意:

- App Group ID
- Widget kind
- shared UserDefaults key
- snapshot Codable shape
- signature/cache key

## Apple Watch

Bridge:

`MeMo/MeMoWatch Watch App/Models/MeMoWatchConnectivityBridge.swift`

WatchConnectivity dictionary は protocol として扱ってください。

変更時:

1. sender / receiver 両方を確認
2. old iPhone ↔ new Watch を考慮
3. new iPhone ↔ old Watch を考慮
4. additive field を優先
5. missing key に default を用意
6. 新 key を必須化しない

---

# 5. Codable / Data

保存対象には以下が含まれます。

- food counts
- toilet state
- step-enjoy log
- owned pet IDs
- workout route
- gacha dictionary
- happiness claim
- event / fishing / walk payload

変更時:

- Optional field 追加を優先
- missing value の default
- `decodeIfPresent`
- custom decoder
- old format fallback

を検討してください。

---

# 6. Migration 原則

Migration は以下を満たすこと。

- idempotent
- non-destructive
- retryable
- migration 完了まで old data が読める
- source / destination format が明確

推奨:

1. new format を読む
2. なければ old format を読む
3. memory 上で変換
4. new format を保存
5. new format が読めることを確認
6. 明示的に安全と判断できるまで old data を消さない

「初期値へリセット」は migration とみなさないこと。

---

# 7. PR / merge 前チェック

Persistence を触る場合は答えること。

- どの model / key / file / protocol field を変更したか
- literal key を rename していないか
- SwiftData stored property を rename / delete / type-change していないか
- previous release data が読めるか
- interrupted migration を再実行できるか
- existing photo が残るか
- Widget shared value が残るか
- older Watch peer を考慮したか
- non-empty existing data で upgrade test したか

不明点が残る場合は release-ready としないこと。
