//
//  AGENTS.md
//  MeMo
//
//  Created by shota suzuki on 2026/09/26.
//

# MeMo Codex Instructions

## Scope

This file defines repository-wide implementation rules for MeMo.

- Repository: `shota-suzuki-eeen/MeMo`
- Audited branch: `main`
- Audited Git snapshot: `92563441704cf11712b17705b77b8b18f83c430f`
- Audit date: `2026-09-26`
- Product status: **released application**
- Primary client: iOS
- Related targets/features visible in the repository: Apple Watch, Widget / Live Activity, HealthKit, WeatherKit, AdMob, SpriteKit-based event game, local photo memories, walking route records.

Codex must read this file before changing code.

---

# 1. Highest-priority rule: preserve existing user data

MeMo is already released. Existing users may have long-lived local data.

**Data compatibility has higher priority than refactoring quality, naming consistency, architectural cleanup, or code simplification.**

Before changing any persistent state, Codex must inspect the current implementation and confirm that existing users can still read the data produced by previous released versions.

Do not assume that a value is safe to rename merely because its current Swift name looks outdated.

Examples already present in the codebase include legacy backing names whose semantic meaning has changed while their persistent names intentionally remain unchanged.

---

# 2. Persistent data contracts that must not be changed casually

The following are compatibility contracts.

## SwiftData

Current `.modelContainer(for:)` registration contains:

- `AppState`
- `TodayPhotoEntry`
- `WorkoutSessionRecord`

Do not, without an explicit migration plan:

- rename an existing `@Model`
- remove an existing `@Model`
- remove a registered model from `.modelContainer(for:)`
- rename a stored property
- delete a stored property
- change a stored property's type
- change uniqueness semantics
- reinterpret existing stored data incompatibly

If a new field is required, prefer an additive, backward-compatible change. If migration risk is unclear, stop the implementation at the design/report stage rather than guessing.

Read the existing root document `SwiftDataOperationPolicy.md` before modifying any SwiftData model.

## UserDefaults / @AppStorage

Existing keys are public compatibility identifiers for released users.

Do not:

- rename an existing key string
- replace a legacy key with a new key and stop reading the old key
- change an encoded payload to an incompatible shape
- reset a key simply because a new feature is introduced
- reuse an existing key for a different semantic meaning

When a new key supersedes an old key:

1. Continue to read the old key.
2. Migrate safely or provide fallback behavior.
3. Preserve dual-read / dual-write behavior where existing code intentionally does so.
4. Do not remove the legacy path until a separately approved migration policy exists.

## Documents storage

`TodayPhotoEntry` stores metadata while image bytes are stored under:

`Documents/memories/`

Do not change without migration:

- `memories` directory name
- existing file-name rules
- JPEG representation expectations
- the relationship between `TodayPhotoEntry.fileName` and the physical file

## Encoded Data / JSON

Several models persist JSON-encoded data in `Data` properties or UserDefaults.

Do not change a Codable payload so old values become undecodable.

Use one or more of:

- additive optional fields
- `decodeIfPresent`
- explicit versioning
- old-format fallback
- a tested migration path

## Cross-target shared identifiers

Treat the following as compatibility contracts:

- App Group identifier currently referenced by code: `group.com.shota.CalPet`
- existing Widget kind identifiers
- existing App Group UserDefaults keys
- existing WatchConnectivity message / context keys
- Live Activity identifiers and state contracts

Do not rename them as part of cleanup.

---

# 3. Required persistence preflight before implementation

Before editing a feature that reads or writes state, Codex must search the repository for:

- `@Model`
- `.modelContainer`
- `UserDefaults`
- `@AppStorage`
- `forKey:`
- `data(forKey:`
- `string(forKey:`
- `integer(forKey:`
- `bool(forKey:`
- `suiteName:`
- `FileManager`
- `.documentDirectory`
- `JSONEncoder`
- `JSONDecoder`
- `Codable`
- `WCSession`
- `sendMessage`
- `updateApplicationContext`
- Widget kind identifiers
- App Group identifiers

For every persistence-affecting task, include a short compatibility impact section in the final report.

---

# 4. Architecture and implementation rules

Prefer the current architecture over introducing parallel systems.

Current organization includes:

- `Models/` — domain state, persistence, policies, feature stores
- `Managers/` — system/service coordination
- `ViewModels/` — presentation/domain coordination
- `Views/` — SwiftUI/SpriteKit UI
- `MeMoWatch Watch App/` — Watch application and connectivity
- `MeMoWidget/` — Widget / Live Activity
- `BGMs/` — bundled audio resources
- `Movie/` — widget snapshot publishing support

Implementation rules:

- Modify existing abstractions when they already own the responsibility.
- Do not create a second persistence mechanism for the same state.
- Do not move persistence responsibilities during an unrelated feature task.
- Avoid broad refactors while implementing a feature.
- Avoid renaming files/types merely for style consistency.
- Preserve existing public/internal call sites unless the task explicitly requires a change.
- Prefer small, reviewable changes.
- Keep feature-specific state namespaced.
- Preserve existing legacy fallback logic.

---

# 5. GitHub snapshot limitation

The audited GitHub tree does not expose a complete Xcode project/workspace or the main asset catalog.

In addition, `.gitignore` excludes:

- `MeMoWatch Watch App/WatchAssets.xcassets/`
- `MeMoWidget/Assets.xcassets/`

Therefore, before implementation Codex must inspect the **local working copy** and confirm:

- actual `.xcodeproj` / `.xcworkspace`
- build targets and target membership
- local asset catalogs
- bundle resources
- signing / capabilities configuration
- local files not represented in the GitHub snapshot

Do not infer target membership only from the GitHub tree.

---

# 6. Build and verification

After implementation:

1. Inspect `git diff`.
2. Confirm no unrelated persistence keys or stored properties changed.
3. Build the affected iOS target.
4. Build affected Widget / Watch targets when touched.
5. Resolve compile errors caused by the change.
6. Run available tests.
7. Perform migration/compatibility checks if persistent data changed.
8. Report exactly what was changed.

Do not silently delete warnings that indicate data migration or decoding problems.

---

# 7. Required final report from Codex

Every completed implementation should report:

## Changed files
List every modified/created/deleted file.

## Implementation
Summarize functional changes.

## Persistence compatibility
State one of:

- `No persistent-data contract changed.`
- `Persistent data changed additively; backward compatibility verified as follows: ...`
- `Migration required; implementation not safe to release until: ...`

## Verification
Include:

- build command/result
- tests run/result
- affected targets
- manual checks performed

## Remaining risks
List any unverified behavior, especially:

- SwiftData migration
- UserDefaults migration
- Documents files
- Widget/App Group state
- WatchConnectivity
- StoreKit/entitlements
