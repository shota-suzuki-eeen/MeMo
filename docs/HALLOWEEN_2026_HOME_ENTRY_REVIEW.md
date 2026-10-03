# Halloween Home entry — selected 05 layout verification

Date: 2026-10-03. Base: `974a2e32739133f41639a88e8731a6f9da8c258c` (PR22). Branch: `codex/halloween-home-entry-review`. PR23 contains the user-selected layout and the completed local verification below.

## Final change

The user selected the actual `05-fixed-home-hidden.png` layout. EVENT is the fourth button in the existing right-side status column, after camera, happiness rewards and sleep. Home uses the existing 56-point status-button size and 10-point spacing. The component retains its existing event date, badge, sound, accessibility label and opening action. It is hidden while the Home menu, top-info, sleep, no-food or food-selector panel is open.

The selected wallpaper previously participated in Home canvas sizing. The default Home and concrete assets have a different aspect ratio from the Halloween wallpaper; actual baseline builds also moved the bottom controls when selecting Halloween. Home now preserves the default wallpaper's existing canvas and fills/clips the selected wallpaper inside that canvas. Existing bottom/toilet dimensions, padding, care operations and route handling are unchanged.

EVENT remains inside the existing Home content, below the root poop gesture layer. The user explicitly accepted visual overlap with the toilet thought bubble because non-cleanup actions must be blocked while poop is active. No new care-lock bypass or separate event overlay is introduced.

Changed product files:

- `MeMo/Views/HomeView.swift`
- `MeMo/Views/Components/EventUIComponents.swift`

## Actual layout evidence

Only the isolated **MeMo Halloween QA** iPhone17Pro/iOS26 Simulator `72D15C18-E7C8-48F0-B484-47BD7AFD292E` was used (402×874 points, 1206×2622 pixels). This is an iPhone17 layout proxy, not a physical-device test.

The selected implementation was restored exactly from the preserved `proposed-home-layout.patch`, based on `1bc3764`. Source hashes match the selected 05 build. Actual unmodified screenshots and diagnostic logs remain outside Git in `task-2/qa-home-layout/`:

| Evidence | State |
|---|---|
| `05-fixed-home-hidden.png` | User-selected default Home layout, toilet hidden |
| `06-fixed-home-shown.png` | Same selected layout, toilet shown; accepted thought-bubble overlap |
| `07-fixed-halloween-hidden.png` / `08-fixed-halloween-shown.png` | Same selected implementation, Halloween wallpaper, both toilet states |
| `15-selected05-home-hidden.png` | Restored selected implementation, actual default Home screen |
| `selected05-home-hidden.stderr.log` | QA-only geometry measurements of restored implementation |

Final measured coordinates on the QA phone:

| Element | Global frame (points) |
|---|---|
| Home canvas | (-7, -1.2189, 416, 904.4378) |
| Existing bottom-bar container | (-7, 731.2189, 416, 100) |
| Existing toilet-ticket button | (315, 669.2189, 76, 76) |
| EVENT | (325, 352.7811, 56, 56) |

No generated image, composite or screenshot edit was used. No additional image export, Library transfer or Python installation is required for the selected local review flow.

## Verification

Xcode **26.0.1** signed Debug generic iOS Simulator product build: **BUILD SUCCEEDED** (`selected05-product-build.log`). Existing HealthKit remains in the simulated entitlement payload. The final product executable contains no `MeMoQA` diagnostic code. Existing, unchanged ignored asset catalogs were used without adding them to Git. No project/capability/package changes.

Commands actually run from the independent product checkout:

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

Event **178059**, regular tickets **101**, HUD **220**: **178380 assertions PASS** on the selected source. CI is not configured.

The native XCTest UI target exists only in an independent QA project. Product project metadata is unchanged. Both `selected05-ui-test.xcresult` and `selected05-revalidation-ui-test.xcresult` report **one test, zero failures, TEST EXECUTE SUCCEEDED**. Physical-coordinate taps verified that active poop blocks EVENT, camera, happiness rewards, sleep, menu, gacha, shop and fishing. Character taps did not increment petting counts. The existing toilet-ticket control cleared poop; afterward EVENT opened CANDY RUN and Back returned Home. Opening the Home menu removed EVENT. This validates the selected 05 arrangement, superseding checks of earlier draft placements that allowed event navigation while poop was active.

### Corrected happiness comparison

The earlier comparison incorrectly expected happiness to stay unchanged across toilet cleanup. The user approved correcting that test, without changing the existing happiness behavior. An observation-only QA copy recorded actual pending decay, each successful decay step and the cleanup gain. Task09 source was never used.

- Initial fixture: **Lv0, 8 points, fullness 0**, decay anchor **2026-10-03 00:10:34.101477 UTC**; fixture created **00:51:04.101477 UTC**.
- Pending check at **00:51:40.969500 UTC**: eight five-minute intervals were due. Eight actual steps produced **8→7→6→5→4→3→2→1→0**, remaining at Lv0.
- Cleanup at **00:51:49.789553 UTC**: the existing +10-point reward produced **0→10** exactly once. Final points equal **8−8+10=10**, not an unexplained +2.
- Toilet-ticket inventory changed **wc3→2 exactly once**. Other items, wallet, current/owned pets, foods, event progress, pity/guarantee state, claim state, unlocks and petting counts matched the fixture/backup comparisons. No gacha, purchase, ad or reward claim was performed.

Evidence: `selected05-happiness-fixture.json`, `selected05-happiness-transitions.jsonl`, `selected05-happiness-revalidation.json` and the revalidation xcresult.

### QA restoration and final binary

The Simulator returned a nonexistent app data path during preparation. With user approval, the local QA helper was corrected to require one physically existing container with MeMo's exact bundle identity inside the named QA device, after shutdown. The original backups were preserved. This was a local validation-tool correction; the cause of the nonexistent returned path is not established.

After successful revalidation, the diagnostic-free signed product was installed and the original QA SQLite and plist restored. **The entire SQLite logical dump matches the original backup, and plist bytes match exactly** (`selected05-revalidation-final-state.json`). Final executable SHA256: `1f25c33803720390f28dabdff20bbacb09cfe60a8f9ccad5d3b22e27158fb561`. The QA Simulator is shut down. The original user checkout and production Simulator/data were not modified.

## Persistence compatibility and remaining scope

**No persistent-data contract changed.** SwiftData models/fields, existing UserDefaults keys, photo paths, App Group, Widget/Watch protocols, StoreKit and entitlements are unchanged. Task09's additive checkpoint work is isolated in a separate checkout and was excluded from all PR23 builds and comparisons.

Physical touch/call behavior, game balance, updating an existing installed app, live ads, actual Widget/Watch/HealthKit service behavior, Small-phone and iPad checks remain unverified as recorded for task08. No distribution or App Store submission was performed; task08 is not marked complete by this layout verification.
