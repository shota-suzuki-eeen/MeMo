# Halloween Home entry artwork QA — task11

Verified on2026-10-03 from base main `28b8de3695b64e42962676d41b51aa1354af1d0e` (PR25). The user approved the pumpkin/purple-hat artwork, the native ImageIO crop with1px of transparent right margin, overlap with the toilet thought bubble, and merging the verified implementation before screenshot sharing/review.

## Product change and asset distribution

Only `HalloweenHomeEntryButton` artwork changes to `Image("halloween_event_entry")`, original rendering, `scaledToFit`, and a hidden decorative accessibility element. The existing button frame, badge, rounded hit shape, shadow, accessibility label, action, sound, event dates, hiding and poop lock remain intact. `HomeView.swift` is unchanged.

The actual new PNG and its two Contents.json files are tracked in `MeMo/HalloweenEventAssets.xcassets`. The existing synchronized MeMo group compiles the new catalog into the main app; the signed build log confirms membership. This feature's new artwork is available from Git and does not depend on a private untracked copy. No project, scheme, package, entitlement or ignore-rule changes are required.

Existing main, Watch and Widget catalogs remain intentionally ignored. Builds used byte-identical physical copies from the user's read-only original:1807/37/477 files respectively. No dummy catalog or force-added legacy asset is included. A standalone clone still needs the pre-existing real local catalogs under the repository's established build contract.

## Crop evidence

| Property | Approved original | Adopted PNG |
| --- | --- | --- |
| Size |1254×1254 RGBA8 |1160×1160 RGBA8 |
| Nonzero-alpha bounds, exclusive |[50,68,1209,1228) |[0,0,1159,1160) |
| Fully transparent outer margins L/T/R/B |50/68/45/26px |0/0/1/0px |
| Nonzero-alpha pixels |972961 |972961 |
| SHA256 |`0f1ddef06ef3a4171b9646af578fc32bd71b013da2765575c1551f1d91675f6f` |`97a0f1661923172df48358c74da588e653dc20ae62ad8600132ce4562328a534` |

Native macOS ImageIO cropped the rectangle[50,68,1210,1228). No regeneration, resampling or redesign occurred. Every corresponding RGBA pixel is identical; visible pixels changed:0. The1px right margin is the minimum needed for a square that preserves the full1159×1160 silhouette. Transparent silhouette corners remain naturally present. The original Library item and local source were preserved.

## Automated checks and signed build

| Command | Result |
| --- | --- |
| `bash scripts/test_halloween_event.sh` |178059 assertions PASS |
| `bash scripts/test_gacha_tickets.sh` |101 assertions PASS |
| `bash scripts/test_halloween_hud.sh` |220 assertions PASS |
| `bash scripts/test_gacha_selection.sh` |4522 assertions PASS |
| `bash scripts/test_happiness_checkpoints.sh` |1610 assertions PASS |
| `git diff --check` |PASS |

Total:184512 assertions PASS. Selection tests use the documented isolated dependency shells; checkpoint tests use the production owner and gacha ledger.

Xcode26.0.1 signed Debug Simulator build: **BUILD SUCCEEDED**. The actual command used `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`, `xcodebuild -project MeMo.xcodeproj -scheme MeMo -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath ../memo_stage11_derived -clonedSourcePackagesDirPath ../memo_packages -disableAutomaticPackageResolution -onlyUsePackageVersionsFromResolvedFile CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- build`. `codesign --verify --deep --strict` passed. Existing HealthKit is present in the embedded Simulator entitlements and Simulated.xcent; existing WeatherKit is present. Project and entitlement sources match base main. Existing compiler/extension metadata warnings were retained.

The verified, diagnostic-free installed product had executable SHA256 `c8a9942903cb51c161453e7abab28b02d74129e9b996a91c240283afa0d511c0` and debug dylib SHA256 `12c40cc9d1765969dae1c3fce350e338c5146fab30bddfda1fe88a15b3106ab7`.

## Native UI and actual saved-state checks

Only **MeMo Halloween QA**, iPhone17Pro/iOS26, `72D15C18-E7C8-48F0-B484-47BD7AFD292E`, was used. Native XCTest physical taps and XCUIScreen PNG capture ran in a separate observation copy, scheme `HomeEntryQA`. Product project and all model/manager/store sources remained unchanged. QA-only additions observed geometry, rendered the old artwork for before images, and injected dates only into entry visibility; the production OS clock and EventManager were unchanged.

| Case | Native result | Saved-state/geometry result | Final native PNGs |
| --- | --- | --- | --- |
| Bright wallpaper, Light appearance |1 test/0 failures |PASS |7 |
| Bright wallpaper, Dark appearance |1 test/0 failures |PASS |7 |
| Dark wallpaper, Light appearance |1 test/0 failures |PASS |7 |
| Dark wallpaper, Dark appearance |1 test/0 failures |PASS |7 |
| Entry date boundaries and plain accessibility label |1 test/0 failures |PASS |6 |

Total:5 native tests/0 failures,34 final unmodified native PNGs. Initial-run evidence is preserved separately. The first saved-state check stopped on existing fishing catch-up after an old time anchor; the user approved setting only the QA fixture's `memo.fishing.lastCalculatedAt` to fixture creation time. Pending catches, points, lifetime totals and gear were not normalized. The rerun and all remaining cases passed.

Four appearance cases verified before/after with poop shown, poop lock, cleanup, poop hidden, event→Back, transparent-area hit, menu hiding, and notification badge label. Covered non-cleanup operations remained blocked:EVENT, camera, rewards, sleep, menu, normal gacha, shop, fishing and character. Cleanup consumed exactly1 existing ticket and added the existing10 happiness points. A transparent pixel within the unchanged rounded hit shape still opened CANDY RUN after cleanup. Both badge and plain Japanese accessibility labels were verified.

Stable global frames in points matched PR23's approved placement:

| Element |x |y |width |height |
| --- | --- | --- | --- | --- |
| Home scene |-7 |-1.2189054726368 |416 |904.4378109452736 |
| Bottom bar |-7 |731.2189054726368 |416 |100 |
| Toilet button |315 |669.2189054726368 |76 |76 |
| EVENT |325 |352.7810945273632 |56 |56 |

The period case verified entry absence before event start; presence at start, at minigame end and1sec before reward end; absence at and after reward end, including coordinate taps. Injected entry dates do not validate the entire event screen at those dates; event-engine boundary behavior is covered separately by the domain checks.

Actual post-run database/plist inspection confirmed protected wallet, current/owned pets, food inventory, notification/goal/step-enjoy fields, complete photo/workout tables, event progress/rewards, gacha/fishing/unlock/claim ledgers and appearance/wallpaper. Existing care/sync timestamps and expected cleanup fields changed normally. Normal Home refresh updated shared snapshots; this is not a live Watch/Widget peer test.

## Restoration, evidence and remaining checks

**No persistent-data contract changed.** No SwiftData schema, existing key, Documents/photo path, App Group, Widget/Watch protocol, StoreKit or entitlement source changed. The complete original QA database was restored by logical comparison, and the original plist was restored byte-for-byte. The clean signed product was reinstalled and its executable/dylib hashes verified. QA was shut down. The user's original checkout HEAD/status matched the preflight record; the production Simulator was not touched.

Raw evidence is retained outside Git in the task workspace's `qa-task11-entry/`:five xcresult bundles, test/build logs, before/after stores/plists, crop and geometry verification,34 final screenshots, initial stopped-run evidence and `final-qa-result.json`. QA copies, local user data and large logs/screenshots are not included in the PR.

Library sharing remains incomplete. The original ordered19-image official helper batch failed with `Library prepare_uploads is not available`; one explicitly user-authorized identical retry failed with the same error. No new file ID/version or successful write result was returned. Read-only exact-name and post-attempt creation checks found no corresponding retained Library items; they do not prove that no transient preparation/transfer began. No further retry or alternate write path is authorized by this task's completion step. Local PNGs remain protected, and screenshot review is deferred by the user.

Physical-device incoming-call/playability/existing-install upgrade checks, Small-phone/iPad final layouts, live Widget/Watch/HealthKit/advertising services, Release/distribution/App Store submission remain unverified. Task08 is not complete; this is an implementation merge, not a release-readiness claim. CI remains unconfigured.
