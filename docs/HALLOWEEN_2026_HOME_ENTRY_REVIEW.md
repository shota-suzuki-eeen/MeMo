# Halloween Home entry — additional review

Date: 2026-10-02. Base: `974a2e32739133f41639a88e8731a6f9da8c258c` (PR22). Branch: `codex/halloween-home-entry-review`. The user requested preserving the original bottom buttons and toilet row, adjusting EVENT only, and reviewing screenshots before any further merge. **This change is not authorized for merge until that review.**

## Comparison and change

- GitHub records PR22 as merged at **2026-10-02 10:18:56 UTC / 19:18:56 JST**.
- `HomeView.swift` is byte-identical between `28cc38f` and the pre-PR22 merge `cae4edde`. Between that baseline and PR22, Home changes were the event-opening closure and adding the entry layer; existing bottom-button/toilet constants and operations were unchanged.
- Actual pre-PR22 and PR22 builds on the same QA phone confirmed unchanged bottom-button/toilet positions, but EVENT overlapped the toilet-ticket button. Pre-PR22 EVENT covered part of the toilet button; PR22's entry within Home left the toilet button above part of EVENT. Code constants alone were insufficient to verify stacking and layout.
- `HomeView.swift`: attach EVENT as an overlay to the home scene so it does not contribute to the home canvas size. Position its bottom at **158 + 76 + 16 = 250 points**, using the existing toilet row offset, button size and spacing. This moves only EVENT upward 80 points from 170, leaving a 16-point gap above the toilet-ticket row. Horizontal alignment with the existing fishing column is retained.
- `EventUIComponents.swift`: remove the entry's full-canvas frame and hard-coded 170-point bottom padding; Home owns placement. Existing button, badge, event period, sound/opening action and home-only navigation scope remain.
- During QA, the higher entry overlapped Settings in the existing Home menu. EVENT alone is now hidden while the existing menu, top-info, sleep, no-food or food-selector panel is open; closing the panel restores it. Existing panels and care/permission behavior are unchanged.

No bottom-button dimensions/padding, toilet visibility condition, toilet cleanup/consumption, poop gestures, care lock, menu routing or RootView run exclusion was edited. No project, asset or entitlement change.

## Verification and screenshots

Xcode 26.0.1, existing HealthKit entitlement, signed Debug generic iOS Simulator build: **BUILD SUCCEEDED** (`qa-home-entry/fixed-build-final.log`), no new warnings/errors. Existing unchanged catalogs were used; no assets added to Git. `git diff --check` passed. Final rerun: event tests **PASS 178059**, regular-ticket tests **PASS 101**, HUD tests **PASS 220**, total **178380**; no CI configured.

Commands actually run from the independent checkout:

```sh
bash scripts/test_halloween_event.sh
bash scripts/test_gacha_tickets.sh
bash scripts/test_halloween_hud.sh
git diff --check
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project MeMo.xcodeproj -scheme MeMo -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /Users/shota.suzuki/Documents/Codex/2026-10-02/task-2/memo_stage05_derived \
  -clonedSourcePackagesDirPath /Users/shota.suzuki/Documents/Codex/2026-10-02/task-2/memo_packages \
  -disableAutomaticPackageResolution -onlyUsePackageVersionsFromResolvedFile \
  CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- build
```

Actual **MeMo Halloween QA** iPhone17Pro/iOS26, `72D15C18-E7C8-48F0-B484-47BD7AFD292E`, matching iPhone17 layout at402×874 points. This is a layout proxy, not a physical iPhone17 test.

Four unmodified real Simulator PNGs (1206×2622) are retained under `task-2/qa-home-entry/`:

| File | Actual build/state |
|---|---|
| `01-before-main974a2e3-toilet-hidden.png` | PR22/main974a2e3, no toilet flag |
| `02-before-main974a2e3-toilet-shown.png` | PR22/main974a2e3, toilet flag/wc4, overlap visible |
| `03-after-review-build-toilet-hidden.png` | Final additional-review build, no toilet flag |
| `04-after-review-build-toilet-shown.png` | Final additional-review build, toilet flag/wc4, EVENT above the unchanged toilet row |

Additional actual pre-PR22 and final-menu screenshots are retained locally as `reference-pre-pr22-cae4edde-toilet-shown.png` and `reference-final-menu-no-event.png`. No generated image, composite or mockup is used.

- Both toilet states visibly retain the existing four bottom buttons and their position. The final toilet state separates EVENT from the toilet ticket and its count badge.
- Final toilet state: EVENT opened the event screen, Back returned with the toilet state intact. Toilet-ticket action then cleared the flag/poop and consumed **wc4→3 exactly once**. Every tracked wallet/other-item/food/pet/pity/event/ad-slot/unlock field matched before/after after accounting for that one ticket. No gacha/reward was performed during these checks.
- Existing care locks were retained: while the flag was active the bottom menu/gacha/shop/fishing actions did not navigate; after cleanup the first placement build opened/returned from regular gacha, shop and fishing normally. Existing tutorials were dismissed in QA only, without accepting new permissions or consuming purchases/ads.
- Final menu: all four menu actions visible, EVENT absent. Settings, Zukan character/wallpaper tabs and Memories opened and returned normally with no event entry covering those screens. Closing the Home menu restored EVENT. Existing Back behavior was retained.
- Final happiness-detail, sleep panel (cancel only) and food selector (open/close only) removed EVENT while open and restored it on close, without granting/consuming items. The no-food-message branch was not separately forced.
- **Remaining final action check:** EVENT is visible in the final no-toilet Home screenshot, but the final no-toilet opening tap was interrupted by the Mac becoming locked. Computer Use reported that automatic unlock failed. Manual Mac unlock is required before that tap/return can be completed; the final toilet-state opening/return passed. Do not count the interrupted tap as passed.

QA state fixtures/backups live outside Git and affect only the named disposable Simulator. Original user checkout and production data were not modified. Original QA plist/SQLite backups were restored after these checks; every tracked wallet, item, food, pet, event, pity, ad-slot and unlock field matched the original task08 snapshot exactly (`qa-stage06-fixtures/home-entry-restored-original.json`). This is a tracked-field comparison, not a claim that foreground care timestamps or every SQLite byte remained identical.

## Persistence compatibility, delivery and review hold

**No persistent-data contract changed.** No SwiftData model/property/key, UserDefaults key, photo path, App Group/Widget/Watch protocol, StoreKit right or capability change. Only EVENT placement/visibility is altered; existing Home/toilet/menu owners remain intact. Physical touch/call/balance and Small/iPad verification remain outside the agreed screen scope.

The four screenshot files are ready for user review. Native Library delivery initially failed before any upload began because the available Python 3.9 could not import the current helper's Python 3.10+ annotations. No compatible existing runtime was verified. The user-approved official Python 3.14.8 installer was downloaded, and its SHA256 matched the official value. Initial sandbox `pkgutil --check-signature` returned **invalid signature / exit 1**, so installation stopped. Read-only verification of the same bytes in the normal macOS environment subsequently returned **exit 0, Apple-issued distribution signature, trusted Apple notarization and trusted timestamp**; all chain certificates were within their validity dates. The sandbox verification environment is the likely cause of the different result, not a proven package defect. No trust setting or signature bypass was applied, and the installer remains unexecuted. Administrative input and the locked Mac require user handoff. No Library save or file ID is claimed until successful upload confirmation.

Keep the additional PR **draft/unmerged**, preserve these images and test evidence, and resume the outstanding action/delivery checks after user handoff. PR22 remains merged; no destructive rollback is proposed.
