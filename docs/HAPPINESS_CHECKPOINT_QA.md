# Happiness checkpoint — task09 verification

Date:2026-10-03. Specification: [Notion 作業予定リスト／作業09](https://app.notion.com/p/3be9c0c2893c804f85fdde911ee1fae3). Independent base: merged PR23 main `c711b61553e0a7f0b69499ac24576d3d61008eea`. Task10 changes are excluded.

## Implementation and persistence

The existing happiness owner retains the highest attained multiple-of-five floor for gains, reads, reload repair, elapsed-decay calculation and one-step decay. Legacy initialization uses only the current saved level rounded down to5; it does not infer a peak from claims or unlocks. Lv17 retains floor15, Lv40 retains floor40 and the cap remains75. Reaching the floor resets the decay anchor, so later gains are not consumed by stale elapsed backlog. Pending work is bounded before Int conversion.

**Persistent data changed additively; backward compatibility verified as follows:** new integer `memo.happiness.reachedCheckpointLevel.v1` uses the existing standard/reward-owner context mapping. Original level, point, petting, timestamps, sleep and claims keys retain their names/types. Casual shares its parent reward context. Actual non-empty QA stores loaded and retained wallet, owned pets/foods, claims, tickets, event payload, pity, unlocks, photos/workout rows and legacy notification fields. Reading a checkpoint grants no reward or compensation. AppState/TodayPhotoEntry/WorkoutSessionRecord schemas, Documents/memories, App Group, Widget/Watch contracts and StoreKit/entitlements are unchanged.

## Model and build verification

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bash scripts/test_happiness_checkpoints.sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bash scripts/test_gacha_tickets.sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bash scripts/test_halloween_event.sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bash scripts/test_halloween_hud.sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project MeMo.xcodeproj -scheme MeMo -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath ../memo_stage09_derived -clonedSourcePackagesDirPath ../memo_packages \
  -disableAutomaticPackageResolution -onlyUsePackageVersionsFromResolvedFile \
  CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- build
```

Results: **1610 happiness,101 ticket,178059 event and220 HUD assertions PASS**. Happiness tests compile the production happiness owner, Gacha ledger and PetMaster mapping with isolated AppState/defaults dependency shells. Binary-plist reload exercises actual payload shapes, while the iOS checks below validate real SwiftData/UserDefaults. No terminal test writes the real app's defaults/store.

Xcode26.0.1 signed Debug MeMo build for generic iOS Simulator: **BUILD SUCCEEDED**, including configured Widget/Watch/Complication dependencies. Existing HealthKit Simulator entitlement was retained. Real ignored catalogs were physically copied byte-identically into the isolated work area (1807 main,37 Watch,477 Widget files); no assets were added to Git. Product project, targets, packages, capabilities and signing configuration are unchanged. Existing CameraStyle/Watch isolation, extension-version and AppIntents metadata warnings remain baseline warnings.

## Native UI and real saved-state verification

Only **MeMo Halloween QA**, iPhone17Pro/iOS26, UDID `72D15C18-E7C8-48F0-B484-47BD7AFD292E`, bundle `com.shota-eeen.MeMo`, was used. A separate native XCTest project copied the product sources/catalogs; its happiness model was byte-identical to the product (`a48ca8bee9e0638992b27d89e04bae171425a3faa4a0e1da698e51dc880ab510`). QA-only accessibility IDs and Home display JSON logs were not committed or installed as the final product.

| Case | Actual UI, runtime and saved-state result |
|---|---|
| Legacy current17.37; checkpoint absent;20-day empty elapsed | Floor15 initialized;237 decay steps produced all238 display states down to15.0. Every displayed point/level matched the owner. Lv5 claim changed normal tickets0→10 and claims[15]→[5,15] with one ledger marker. Popup closes on claim, was reopened, and the visible claimed check/no claim button passed. Two cold relaunches retained15.0/floor15 and the same10 tickets. |
| Happiness point/level/checkpoint keys absent | Missing meter initialized to0.0/floor0 and survived cold relaunch. Existing non-empty inventory/claims were retained; no rewards granted. This is fresh meter data, not a new-install/onboarding test. |
| Saved checkpoint40 with raw17.37 | Load repair wrote40.0/floor40; actual UI and cold relaunch agreed. No automatic tickets, compensation, claims or unlocks were added. |
| Reward12.03; checkpoint absent; normal witness17.60/floor15 |203 decay steps produced all204 states to10.0/floor10. Actual Zukan selection and「お世話する」switched reward_000→reward_000_casual. UI and cold relaunch retained shared10.0; no independent casual key appeared. Normal meter17.60/floor15 and inventories/claims remained unchanged. |

Final native results: **four tests, zero failures, TEST EXECUTE SUCCEEDED** (`legacy-confirmed`, `fresh`, `repair`, `contexts` xcresults). Screenshots/accessibility attachments remain in the xcresults. Initial helper assertions failed because the claim popup intentionally closes and the next focused row can be outside the lazy viewport; the corrected test observes closure, reopens, scrolls the claimed row into view, and retains visible marker/label/button checks. Product code was unchanged during this correction. PNG attachment export encountered a separate sandbox permission error and was not retried.

## Backup completeness and restoration

Before fixtures, the real container was required to exist and match the bundle metadata inside the named QA device. A reported absent container was resolved only to the unique identified existing container, never by creating a database. SQLite backup API copies included committed live WAL data. Closed fixed backups had no pending WAL/journal frames; full logical dumps and exact plist bytes matched the authoritative original backup. SHM cache size was recorded, not used as a completeness gate. `immutable=1` was used only for fixed backup reads; live databases used ordinary connections.

After all tests, the signed clean product binary was installed, the original full logical database and exact plist bytes were restored, and QA **Shutdown** was verified. The binary SHA256 is recorded in the local `final-qa-result.json`. User's original checkout and production Simulator were untouched. Local evidence is under `task-2/qa-task09-checkpoint/`, especially that JSON, case verification JSONs, transitions, immutable-backup completeness and restore-confirmed records. These private QA data/artifacts are not Git deliverables.

## Remaining limits

Physical-device long idle and real existing-install upgrade are **unverified**. Live HealthKit/Widget/Watch/device calls and other task08 release gates remain open; Simulator fixture success does not mark them complete. QA developer mode intentionally avoids live advertising in the character-switch case. No CI is configured; empty remote statuses are not CI PASS. No distribution or App Store submission was performed or authorized.
