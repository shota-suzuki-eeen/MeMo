# Release & Regression Checklist

Use this checklist for implementation work intended for a released MeMo version.

---

## 1. Repository / diff safety

- [ ] `AGENTS.md` read
- [ ] `SwiftDataOperationPolicy.md` read
- [ ] task specification read
- [ ] local `.xcodeproj` / `.xcworkspace` confirmed
- [ ] changed files are limited to task scope
- [ ] no accidental file/type renames
- [ ] no accidental resource renames
- [ ] no unrelated cleanup mixed into the change

---

## 2. SwiftData compatibility

- [ ] `AppState` remains registered
- [ ] `TodayPhotoEntry` remains registered
- [ ] `WorkoutSessionRecord` remains registered
- [ ] no existing stored property renamed
- [ ] no existing stored property deleted
- [ ] no existing stored property type changed
- [ ] encoded `Data` remains backward-decodable
- [ ] upgrade with an existing non-empty store was considered/tested

---

## 3. UserDefaults / AppStorage

- [ ] no existing literal key renamed
- [ ] legacy keys remain readable
- [ ] fallback/dual-write behavior preserved
- [ ] new keys are namespaced
- [ ] new keys have safe defaults
- [ ] old data is not reset on first launch after update

---

## 4. Files / memories

- [ ] `Documents/memories/` compatibility preserved
- [ ] existing `fileName` values still resolve
- [ ] existing JPEG files still load
- [ ] any directory/file migration is idempotent and retryable

---

## 5. Core smoke tests

- [ ] cold launch
- [ ] launch with existing user data
- [ ] Home renders
- [ ] step state loads
- [ ] current pet loads
- [ ] owned pets remain owned
- [ ] food inventory remains intact
- [ ] fullness state remains intact
- [ ] toilet/bath/feed scheduling still works
- [ ] notification toggles retain values
- [ ] happiness level/points remain intact
- [ ] claimed happiness rewards remain claimed
- [ ] gacha pity state remains intact
- [ ] gacha free-slot state behaves correctly
- [ ] gacha special items remain intact
- [ ] fishing points/inventory remain intact
- [ ] wallpaper selection/unlocks remain intact
- [ ] appearance/audio preferences remain intact
- [ ] memories still open
- [ ] historical workout/walk routes decode

---

## 6. Event-specific regression

When touching Halloween/event code:

- [ ] previous event progress still loads
- [ ] `memo.event.halloween2026.progress.v1` is not repurposed
- [ ] reward claims cannot be duplicated after update
- [ ] exchange balances do not reset
- [ ] run-game result persistence remains consistent

---

## 7. Widget / Live Activity

When affected:

- [ ] existing App Group identifier preserved
- [ ] shared keys preserved
- [ ] Widget kind preserved unless explicitly migrated
- [ ] app writes shared snapshot successfully
- [ ] Widget reads previous snapshot format
- [ ] Widget refresh works
- [ ] Live Activity state starts/updates/ends normally

---

## 8. Apple Watch

When affected:

- [ ] WatchConnectivity session activates
- [ ] old/missing message fields are tolerated
- [ ] phone-to-watch sync works
- [ ] watch-to-phone action works
- [ ] application-context/background path works
- [ ] current pet/step/care state is not reset
- [ ] dynamic asset behavior remains functional

---

## 9. Build matrix

At minimum build every touched target.

Suggested checks:

- [ ] iOS app target
- [ ] Widget extension target if affected
- [ ] Watch app target if affected
- [ ] Debug build
- [ ] Release build before distribution when practical

Use the actual local scheme names; do not invent scheme names from the GitHub folder structure.

---

## 10. Final release gate

Do not mark a task release-ready if any of these are unresolved:

- data migration uncertainty
- undecodable previous payloads
- accidental key changes
- existing photo/file path breakage
- Watch protocol incompatibility
- Widget shared-state incompatibility
- unverified build for a changed target
