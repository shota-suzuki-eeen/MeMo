# Task: 幸せ度の5刻み到達下限

## Status

`Done` — implementation and required model/build/Simulator UI/persistent-store checks passed. Physical-device idle verification remains unverified.

## Source and approved behavior

[Notion 作業予定リスト／Codex作業09](https://app.notion.com/p/3be9c0c2893c804f85fdde911ee1fae3) is authoritative. Base: PR23 merged main `c711b61553e0a7f0b69499ac24576d3d61008eea`.

- Reached Lv17 retains floor15; Lv40 retains floor40; maximum level remains75.
- Approved legacy initialization: current level rounded down to a multiple of5, e.g.12→10. Levels below5 retain floor0. Do not infer a historical peak from claims or unlocks.
- Preserve standard/reward meter separation and casual/parent shared context.
- Store the attained checkpoint additively, retain old point/level/claim keys, and never lower it through normal decay.
- Preserve fullness/sleep behavior, owned inventory and claims. Loading or retaining a checkpoint grants no reward or compensation.

## Implementation owner

`MeMo/Models/AppState+Happiness.swift` owns read/load repair, gains, petting, pending elapsed decay and one-step decay. Food, cleanup, Widget and Watch care paths already use `addHappinessPoints`; no second store or SwiftData property is introduced.

Key: `memo.happiness.reachedCheckpointLevel.v1`, with the existing reward-owner suffix when applicable. Integer100-point thresholds prevent a floating-point boundary from dropping below the floor. Pending steps are bounded before conversion to Int; reaching the floor updates the timestamp so future gains are not consumed by old elapsed backlog.

## Verification

`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bash scripts/test_happiness_checkpoints.sh`: **1610 assertions PASS**. Tests compile the actual happiness owner, Gacha ledger and PetMaster mapping, with isolated AppState/defaults shells. Serialized plist round trips validate payload reload; they do not substitute for actual iOS UserDefaults/SwiftData upgrade verification.

Covered: every legacy level0...75, missing keys,4→5/9→10/14→15/39→40/74→75,17→15, zero/max floors, huge/infinite/NaN elapsed dates, fullness/sleep, timestamp reset at floor, context separation/casual sharing, corrupted/interrupted lower-bound writes, legacy claim retention and ticket/machine/casual duplicate-claim prevention.

Signed Xcode26.0.1 Debug MeMo Simulator build: **BUILD SUCCEEDED** (`task-2/task09-product-build.log`). Existing catalogs were physically copied byte-identically from the verified work checkout (1807/37/477 files) and remain ignored by Git. Product project, capabilities and entitlements are unchanged.

Native XCUITest and actual iOS saved-state comparison: **four tests, zero failures**, covering missing happiness keys, legacy17.37→15.0, retained checkpoint40 repair, and a real Zukan reward→casual character switch with the shared10.0 meter. Two cold relaunches retained the standard Lv5 claim and exactly10 normal tickets; no duplicate grant occurred. Runtime Home display values matched the owner throughout all238 standard and204 reward decay states. Existing inventories, wallet, claims, event progress, pity and unlocks were preserved.

The clean product binary was installed after testing; the original QA SQLite full logical dump and exact plist bytes were restored, and the named QA Simulator was verified Shutdown. QA-only identifiers/logging and the native test project do not ship. See [verification record](../HAPPINESS_CHECKPOINT_QA.md).

## Remaining release checks

Physical-device long idle, real existing-install update, calls and live Widget/Watch/HealthKit behavior are unverified. Task08's device/release checks remain open. CI is unconfigured; the recorded local tests/build/UI success is not a CI result. Distribution and App Store submission are not authorized.
