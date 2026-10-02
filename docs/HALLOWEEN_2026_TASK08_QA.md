# Halloween 2026 — task 08 integration and handoff

Date: 2026-10-02. Specification: [Notion 作業予定リスト / 作業08](https://app.notion.com/p/3be9c0c2893c804f85fdde911ee1fae3), re-read on this date. Base: `cae4edde3683c63258902b31444b44f3b545990b` (task07, PR21). User authorized sequential testing and PR merges; distribution and App Store submission remain outside this task.

## Completed stages and changed files

| Stage | Result | Evidence |
|---|---|---|
| 05 Event gacha, last-one, advert slots and delivery recovery | [PR19 merged](https://github.com/shota-suzuki-eeen/MeMo/pull/19), `e82c6ad2b6effac4b250384ab28ab0d06fb91a5d` | [task05 QA](HALLOWEEN_2026_TASK05_QA.md) |
| 06 Regular gacha ticket inventory/payment and confirmations | [PR20 merged](https://github.com/shota-suzuki-eeen/MeMo/pull/20), `ce32d5b5afda142bbd7c9f7f3eae9dc1be8530a5` | [task06 QA](HALLOWEEN_2026_TASK06_QA.md) |
| 07 Registered assets, HUD, effects and event UI | [PR21 merged](https://github.com/shota-suzuki-eeen/MeMo/pull/21), `cae4edde3683c63258902b31444b44f3b545990b` | [task07 QA](HALLOWEEN_2026_TASK07_QA.md) |
| 08 Integration QA and Home-only entry repair | This change | Checks below; physical checks remain explicitly pending |

Task08 product changes:

- `MeMo/Views/Components/EventUIComponents.swift`: move the existing EVENT entry, layout and reward badge into `HalloweenHomeEntryLayer`, observing the existing shared event store.
- `MeMo/Views/HomeView.swift`: attach that layer to the home scene inside its NavigationStack; receive an event-opening closure.
- `MeMo/Views/RootView.swift`: pass the existing opening action to HomeView and remove the root overlay. Existing event fullScreenCover, time guard, sound and run-active exclusion of Home remain intact.
- `docs/HALLOWEEN_2026_TASK08_QA.md`: integration results, setup and remaining checks.

The root overlay previously remained above pushed Zukan/Settings/Memories destinations, obscuring part of Zukan. The user explicitly approved fixing it. During the move an unused old helper caused a compile failure; work paused, the error was shared, and the user approved its removal and re-verification. Final product build and tests passed after removal.

## Final build and static checks

Run from the independent `task-2/memo-halloween` checkout:

```sh
bash scripts/test_halloween_event.sh
bash scripts/test_gacha_tickets.sh
bash scripts/test_halloween_hud.sh
git diff --check

env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project MeMo.xcodeproj -scheme MeMo -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath ../memo_stage05_derived \
  -clonedSourcePackagesDirPath ../memo_packages \
  -disableAutomaticPackageResolution -onlyUsePackageVersionsFromResolvedFile \
  CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- build
```

- **PASS178059** event persistence/session/boundary/tuning assertions, **PASS101** regular-ticket/payment assertions, **PASS220** HUD/safe-area/reaction assertions. Latest local logs: `memo_stage08_event_tests_final.log`, `memo_stage08_ticket_tests_final.log`, `memo_stage08_hud_tests_final.log`.
- **BUILD SUCCEEDED**, Xcode26.0.1, signed Debug simulator app with existing HealthKit entitlement; Widget/Watch/Complication dependencies built. Latest product log: `memo_stage08_build_final2.log`. No errors or warnings from the changed entry/Home/Root files.
- Existing `CameraStyleView.swift:1637/1647` actor-isolation warnings remain (repeated for simulator architectures). Fresh QA-copy builds also exposed baseline WatchConnectivity actor-isolation/conformance and extension/container-version warnings. CameraStyleView, WatchConnectivityBridge and project.pbxproj were byte-identical to the known `28cc38f` baseline. These unrelated warnings were reported and left unchanged under user scope; this is not a claim of a warning-free fresh build.
- `git diff --check` passed. No CI is configured; no remote CI pass is claimed.

## Actual isolated Simulator integration

Only **MeMo Halloween QA**, iPhone17Pro/iOS26, `72D15C18-E7C8-48F0-B484-47BD7AFD292E`, received test data/builds. Xcode device profiles confirm iPhone17 and17Pro both1206×2622 pixels at3×, **402×874 points**. It is an exact layout proxy, not verification of iPhone17 hardware. User narrowed the task07/08 screen gate to iPhone17; Small/iPad final verification is deferred.

| Check | Result and observed evidence |
|---|---|
| Normal run | Stage6/Lv2,30-second HUD, two colored/three black pumpkins and movement controls visible. Final Home-entry build started and closed the run, returned to event then Home; stage6 remained incomplete, candy52/BEST567/TOTAL1804 retained. |
| Bonus run | Task07 actual bonus5 ran20 seconds and collected152. Result displayed **152個 GET!**, candy0→152, completed4→5, distance records unchanged. No fixed300 payout. |
| Endless | Task07 actual collision53m saved the measured distance and collection; BEST567 retained and TOTAL1751→1804. HUD/background/current character and close controls verified. Level/difficulty/path policies are additionally covered by the event tests. |
| Background/resume | Task07 actual normal run froze at22 seconds on Simulator Home, displayed PAUSED, resumed through a3-second countdown with the same22 seconds. Closing discarded provisional stage reward and cleared the active session. This does not substitute for a physical incoming-call test. |
| Event gacha | Tasks05/07 actual single/ten/reveal/close, SR day/cap fixtures, progress49→59 ten boundary, all-owned last-one behavior, earned SDK test ad and early-aborted ad verified. Task07 final single draws152→102→52 granted nabe1 then beer1, event109→111. Task08 failure cases below leave all grants/slots unchanged. |
| Tickets/regular gacha | Task06 actual normal-ticket single/ten, insufficient-ticket full-step fallback, special selected-machine unowned SR, complete-machine confirmations/cancel and real SDK test ad verified. Final Home-entry build with wallet499/tickets0 disabled both500/5000 paid buttons, hid special-ticket action, displayed0/0 inventory and closed/returned normally. |
| Wallpaper | Actual Zukan selection of existing owned `halloween_main` with 設定する changed Home background. Ownership list contains it once; existing Home/field wallpapers remain. Selection/ownership survived QA-copy app updates, product restoration and final cold relaunch. Initial one-time clear grant/deduplication is covered by stage/session policy tests; this selection check did not claim a physical25-stage playthrough. |
| Navigation | Final product: Home→Zukan characters and wallpapers, Settings and Memories showed no EVENT overlay; Zukan cards/page control were unobscured. Back to Home restored the entry. Event→run→event→Home and regular gacha/inventory→Home passed. No new OS permissions accepted. |
| Restart/update, without uninstall | Non-empty QA inventory, event history and wallpaper retained across signed app installations and cold launches. Final before/after restart snapshots matched every tracked inventory/event/pity/slot/unlock field exactly. Released-user installation and photos were not copied into QA. |

Final tracked QA state after restart: wallet499; normal/special tickets0/0; wc4;46 owned pets;76 total food items; pity food32/always1; regular evening advert slot used; event advert slots unused; event111 draws/progress11; candy52; BEST567/TOTAL1804; completed5/next6; no active session or pending gacha batch. Wallpaper remains selected/owned `halloween_main`. These are disposable QA fixture results, not user production data.

## Advert failure branch verification

QA-only copies under `task-2/qa-stage08/fault-source` were built from the task07 merge with unchanged copied catalogs and original signing. No injection code or assets are included in this PR.

1. **No-fill:** only the copied SDK load invocation was replaced by a typed completion returning nil and `MeMoQA.NoFill`. The original production completion/error handler ran. Event advert action became disabled without loading indefinitely; paid single and close remained usable. An existing AdMob load-failure record was persisted. Full tracked snapshots `stage08-before-fault.json` and `stage08-nofill-open.json` matched exactly: no grant, consumption or slot use.
2. **Presentation failure:** restored the copied production load code, loaded the actual SDK test ad, then replaced only presentation with the original failure delegate invocation (`MeMoQA.Presentation`). Tapping the ready advert displayed the existing Japanese preparation message, released the interaction lock, disabled unavailable advertising, and allowed paid/close controls. `stage08-presentation-before.json` and `stage08-presentation-after.json` matched exactly.
3. **Restore:** installed/launched the final unmodified product build. Its binary contained neither injected error-domain marker nor injection text. Wallpaper/inventory/event history retained. `stage08-final-before-restart.json` and `stage08-final-after-restart.json` matched after another cold relaunch.

This verifies actual app UI and production error branches with injected SDK failure results. **Real ad-server no-fill and OS/network offline were not forced or verified.** Earlier real SDK test-ad success/early-abort checks and deterministic duplicate/stale callback tests remain separately documented in tasks05/06. Preparatory symlink catalogs failed actool; byte-identical real catalog copies resolved that QA setup issue before the successful builds.

## Persistence compatibility and setup

**No persistent-data contract changed in task08.** Task05 extended the existing event Codable payload additively, retaining legacy reads and existing distance/candy/claim/exchange fields; its recovery/old-payload tests and non-empty simulator journal-replay checks passed. Task06 reused the released ticket IDs, inventory APIs, regular pity and slots. Task07/08 only changed presentation/calculation.

- SwiftData stored models/properties, `Documents/memories/` photo naming/path, App Group `group.com.shota.CalPet`, Widget/Watch/Live Activity contracts, StoreKit rights and entitlements remain unchanged. No user original checkout, production Simulator or saved user data was modified.
- MeMo app sources are the affected target. No project metadata, memberships, capabilities, minimum iOS version, bundle IDs, Info.plist, package versions or signing settings changed. Widget/Watch build success does not imply hardware connectivity/runtime verification.
- Ignored catalogs must exist locally to build: root `Assets.xcassets`, Widget `MeMo/MeMoWidget/Assets.xcassets`, Watch `MeMo/MeMoWatch Watch App/WatchAssets.xcassets`. They were copied byte-for-byte from the read-only original into the work and QA areas under explicit approval. Keep them ignored; do not add dummy assets or alter the originals. Task07 lists all25 character IDs and100 variant PNG mappings.
- Use the existing reward-ad ID and existing permissions; no new credential, permission expansion or App Store/AdMob manual configuration is required by these changes. Simulator commands target the named QA UDID only. Data fixtures were backed up and applied only in that isolated environment.

## Remaining checks and limits

- **Physical device not tested:** incoming calls/system interruptions, sustained play/frame rate, sound/haptics, Lv5 evasion margin and reaction visibility, measured time/collection to50 candy, and the300-object bonus layout/collection rate. The approved provisional values remain unchanged: normal30s, bonus20s/max300, clear50, levels250/600/1050/1600m, existing speed/spawn/safety values. Simulator bonus152 is not a physical balance measurement.
- **Released-install upgrade not tested:** real non-empty SwiftData photo/workout/care data, actual App Store installation update and purchased rights. Old payload/persistence policy and non-empty QA update/restart passed, but do not cover every released-user record.
- **External/runtime checks not tested:** real-server advert no-fill, device offline/recovery, physical Widget/Watch connectivity, real HealthKit behavior. Existing baseline concurrency/version warnings remain for separate maintenance.
- **Small/iPad final visual sign-off deferred** by the user's latest scope. Geometry assertions and partial earlier observations do not claim those devices passed.
- No distribution/App Store submission or ZIP was performed. This integration record completes the authorized implementation/merge workflow with the specification's explicit allowance to leave physical tuning provisional; it is not a release certification. Notion checklist status was not changed by this task.
