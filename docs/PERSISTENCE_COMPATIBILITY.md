# Persistence & Backward Compatibility Contract

## Why this document exists

MeMo is already released. Local persistence is therefore part of the product's external compatibility surface.

A code change can compile successfully and still cause user-data loss if a stored property, UserDefaults key, encoded payload, file path, or cross-target identifier changes.

This document defines the minimum compatibility rules Codex must apply.

---

# 1. SwiftData schema

Current registered models:

| Model | Source | Role |
|---|---|---|
| `AppState` | `Models/AppState.swift` | Core application/progression state |
| `TodayPhotoEntry` | `Models/TodayPhotoEntry.swift` | Memory-photo metadata |
| `WorkoutSessionRecord` | `Models/StepModels.swift` | Walking/workout records |

## `AppState` — existing stored names are frozen unless migrated

Verified stored properties include, among others:

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

Some names represent legacy terminology intentionally retained for compatibility.

**Do not rename them for readability.**

Use computed properties/helpers when a new semantic name is needed.

## `WorkoutSessionRecord`

Existing stored contract includes:

- `id`
- `startedAt`
- `endedAt`
- `elapsedSeconds`
- `totalDistanceMeters`
- `routeData`
- `memo`
- `characterID`
- `createdAt`

`routeData` decodes `[WorkoutRoutePoint]`.

If the route-point shape changes, old route data must remain decodable.

## `TodayPhotoEntry`

Existing stored contract includes:

- `dayKey`
- `date`
- `fileName`
- `placeName`
- `latitude`
- `longitude`

---

# 2. File-system persistence

Memory images are stored in:

`Documents/memories/`

The database stores the `fileName`; the image is loaded using that name.

Frozen without migration:

- `memories` directory name
- existing file naming behavior
- JPEG storage assumptions
- mapping from SwiftData metadata to physical file

A directory move requires a migration that copies/moves old files and verifies success before abandoning the old location.

---

# 3. UserDefaults / AppStorage

## Rule

The literal key string is the identity of the stored value.

Renaming a Swift constant is safe only if the literal key remains identical. Renaming the literal itself is not safe without migration.

## Verified key families / examples

The following were observed in the audited snapshot.

### Gacha

Legacy values intentionally retained:

- `memo.gacha.pityCounter`
- `memo.gacha.guaranteedGoldNext`

Newer per-machine state:

- `memo.gacha.pityCountersByGacha`
- `memo.gacha.guaranteedGoldNextByGacha`
- `memo.gacha.freeAd.dayKey`
- `memo.gacha.freeAd.usedSlots`
- `memo.gacha.specialItemCounts`
- `memo.gacha.initialIPadFreeTenDrawConsumed`

The current code preserves fallback/dual-write behavior for the legacy default gacha. Do not remove this compatibility path casually.

### Happiness

Base keys include:

- `memo.happiness.point`
- `memo.happiness.level`
- `memo.happiness.lastDecayAt`
- `memo.happiness.petting.touchCountToday`
- `memo.happiness.petting.pointsToday`
- `memo.happiness.petting.dayKey`
- `memo.happiness.claimedRewardLevels`
- `memo.happiness.sleepMode.endsAt`

Some keys are dynamically suffixed by a happiness storage context / pet ID.

Do not assume a repository search for one exact literal finds every effective runtime key.

### Onboarding

Observed namespace includes:

- `memo.onboarding.mandatory.started`
- `memo.onboarding.mandatory.completed`
- `memo.onboarding.mandatory.currentStep`

Additional onboarding keys exist in the source. Search the complete file before modifying onboarding persistence.

### Walk challenge

Observed namespace includes:

- `memo.walk.activeSession`
- `memo.walk.pendingResult`
- `memo.walk.*`

Search `Models/WalkChallengeStore.swift` before modifying walking-session persistence.

### Fishing

Observed namespace includes:

- `memo.fishing.pointBalance`
- `memo.fishing.pendingCounts`
- `memo.fishing.lifetime*`

Search `Views/FishingView.swift` before modifying fishing state.

### Halloween 2026 event

- `memo.event.halloween2026.progress.v1`

The explicit version suffix is part of the key and must be preserved for existing progress.

### Sound settings

- `memo.sound.bgm.enabled`
- `memo.sound.bgm.volumeStep`
- `memo.sound.effect.enabled`

### Wallpaper

- `selectedHomeWallpaperAssetName`
- `memo.work.focus.unlockedRewardAssetNames`

### Appearance

- `memoAppearanceMode`

### Developer mode

- `isDeveloperMode`

### Ads

Observed state includes:

- `memo.admob.rewarded.loadFailureRecords`
- `memo.admob.temporaryPauseUntil`

### Widget / shared state

Current code references App Group:

`group.com.shota.CalPet`

Observed shared values include:

- `memo.homeWidget.snapshot.v1`
- `memo.homeWidget.snapshot.signature.v1`
- `currentPetID`
- `todaySteps`
- `toiletFlag`
- additional widget snapshot keys

The exact registry must be re-searched at implementation time.

---

# 4. Cross-target compatibility

## Widget

Do not casually change:

- App Group ID
- Widget kind
- shared UserDefaults keys
- snapshot Codable shape
- signatures/cache keys

## Apple Watch

Treat WatchConnectivity dictionaries as a protocol.

Before changing the bridge:

1. Identify every message/context key.
2. Check both sender and receiver.
3. Consider old iPhone ↔ new Watch and new iPhone ↔ old Watch combinations.
4. Add keys additively where possible.
5. Preserve default/fallback behavior for missing keys.
6. Do not require a newly added key unless the peer version can safely omit it.

---

# 5. JSON/Data compatibility

Persistent encoded data currently includes multiple domains, including:

- owned food counts
- toilet poop state
- step-enjoy logs
- owned pet IDs
- workout route points
- gacha dictionaries
- happiness claimed levels
- event/fishing/walk payloads

When modifying a Codable model:

- adding optional fields is safer than adding required fields
- provide defaults for missing values
- prefer custom decoding / `decodeIfPresent` when needed
- never assume all installed users have the latest encoded shape

---

# 6. Migration design rules

A migration must be:

- idempotent
- non-destructive
- retryable after interruption
- backward-readable until migration succeeds
- explicit about source and destination format

Recommended sequence:

1. Read new format.
2. If unavailable, read old format.
3. Convert in memory.
4. Write new format.
5. Verify new format can be read.
6. Keep old data unless deletion is explicitly required and safely staged.

Never implement “migration” as unconditional reset-to-default.

---

# 7. Mandatory compatibility review before merge

For any PR touching persistence, Codex must answer:

- Which stored models/keys/files/protocol fields were touched?
- Were any literal keys renamed?
- Were any SwiftData stored properties renamed/deleted/type-changed?
- Can data from the previous release still be read?
- Can an interrupted migration be retried?
- Were existing photo files preserved?
- Were Widget shared values preserved?
- Were Watch peers with older payloads considered?
- Was an upgrade scenario tested with non-empty existing data?

If any answer is unknown, the change is not release-ready.
