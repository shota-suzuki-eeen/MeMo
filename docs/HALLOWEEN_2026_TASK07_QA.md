# Halloween 2026 — task 07 verification

Date: 2026-10-02. Specification: [Notion 作業予定リスト / 作業07](https://app.notion.com/p/3be9c0c2893c804f85fdde911ee1fae3). Base: `ce32d5b5afda142bbd7c9f7f3eae9dc1be8530a5` (task06, PR20).

## Implemented

- Registered assets now render the event top (`halloween_main`), every run (`halloween_run`), rewards, gacha and results (`halloween_shop`), candy, wood, pumpkins and Halloween machine. Run player uses the current owned character through the existing PetMaster mapping.
- Top shows current stage/Lv, five matching colored/black pumpkin silhouettes, candy, gacha entry and separate game/claim deadlines. Endless explicitly starts at Lv1. Scrollable safe-area content, rounded typography and shorter cards leave all controls visible on the target phone.
- HUD separates time/distance, Lv/pumpkins and candy. Bonus targets the upper-central candy counter with bounded fly/pulse/light effects, existing sound, and the actual collected count enlarged in results. Reduce Motion omits the fly effects. Cached textures and a ten-effect cap keep effects separate from the difficulty/drain object layer.
- Close and left/right controls respect safe areas and the existing countdown/interruption guards. Field objects become visible below the HUD, using the same safe-area edge as the existing minimum one-second obstacle reaction clamp. Existing provisional stage/balance/collision/spawn values remain unchanged.
- Reward detail text uses resolved label color for readable material contrast. Event gacha advert control uses red/prominent glass and a loading spinner; result sheet uses dark colors against the shop background. No reward/payment/persistence logic changes.

## Validation

- `bash scripts/test_halloween_hud.sh`: **PASS220 assertions** covering safe areas, HUD row/pumpkin/counter spacing, and minimum reaction time at Lv1–5 across 320×568 through430×932 geometries. These geometry assertions do not imply actual-device UI coverage.
- `bash scripts/test_halloween_event.sh`: **PASS178059 assertions**; `bash scripts/test_gacha_tickets.sh`: **PASS101 assertions**.
- Xcode26.0.1, Debug generic iOS Simulator, existing HealthKit entitlement and ad-hoc signing, byte-identical copied ignored asset catalogs: **BUILD SUCCEEDED**, including Widget/Watch/Complication dependencies. Final log `memo_stage07_build_final4.log` has no errors or warnings.
- Primary isolated **MeMo Halloween QA**, iPhone17Pro iOS26, `72D15C18-E7C8-48F0-B484-47BD7AFD292E`. Xcode device profiles confirm iPhone17 and17Pro both1206×2622 pixels at3× (**402×874 points**). This is a layout proxy; iPhone17 hardware-specific behavior has not been tested.
- Actual top: stage6/Lv2, exactly two colored/three black pumpkins, BEST567/TOTAL1804, candy152, all buttons/deadlines clear of the island/home indicator. Both reward tabs, remaining distances, reward names and claim states are readable; close returns correctly.
- Actual endless: run texture/current-pet sprite, distance/Lv/pumpkin/candy HUD and close/left/right visible. Collision53m gave shop result; BEST567 retained and TOTAL1751→1804 exactly. Normal stage6 showed30sec/Lv2/two colored pumpkins, collision results/retry/close returned to the unchanged incomplete stage.
- Actual bonus5 fixture:20-second run collected152, fly-to-counter effects observed, shop result enlarged **152個 GET!**. Candy0→152 and completed4→5; distance records unchanged. The displayed/credited count is the measured simulator count, not the300-placement total or a fixed payout.
- Actual normal background/resume: Home froze at22sec with PAUSED; foreground showed3-second resume countdown with the same22sec, then resumed. Closing retained candy152/completed5 and removed the active session without a clear payout.
- Latest signed updates/cold launches retained tickets, wallet, owned pets/foods, regular pity/slots and event history. Event single draws152→102→52, granted nabe1 then beer1, event draws109→111; wallet499/tickets0 and regular history retained. Latest result heading/cards/done are readable and close works. Ten is disabled below500; advert preparation shows red spinner.
- One transient Simulator launch refusal after a fixture reboot was shared and paused. User approved one retry, which succeeded; no credential/capability/entitlement changes were made.
- Small/iPad isolated QA devices were created and partially inspected under prior approval. User subsequently narrowed this stage to **iPhone17** and deferred other-size adjustments. iPad top/gacha fitted the existing393×852 phone canvas, but final iPad/Small UI and contrast are **not signed off**; these are excluded from this stage's gate by that instruction.
- `git diff --check` passed. No CI is configured; local test/build/UI checks form the gate. Original user checkout and saved data untouched.

## Asset mapping and setup

All25 IDs below resolve to the exact existing catalog base name, with four variants: base, `_wc`, `_idle_blink_0001`, `_idle_blink_0002`. All100 PNGs were hash-matched against the original material and catalog. Main/run/shop/candy/wood/pumpkin/machine PNGs also match the original catalog. Assets remain intentionally ignored and are not added to Git.

| Character ID | Asset base |
|---|---|
| halloween_arachne | arachne |
| halloween_barky | barky |
| halloween_baty | baty |
| halloween_boogie | boogie |
| halloween_clownie | clownie |
| halloween_dracella | dracella |
| halloween_drya | drya |
| halloween_dully | dully |
| halloween_fin | fin |
| halloween_frank | frank |
| halloween_gide | gide |
| halloween_goths | goths |
| halloween_harpy | harpy |
| halloween_jack-o | jack-o |
| halloween_kinny | kinny |
| halloween_medy | medy |
| halloween_mia | mia |
| halloween_mummy | mummy |
| halloween_neroa | neroa |
| halloween_reaper | reaper |
| halloween_skelly | skelly |
| halloween_spookey | spookey |
| halloween_vampy | vampy |
| halloween_werfa | werfa |
| halloween_wivy | wivy |

The catalog source is the read-only original checkout `Desktop/personal development/MeMo/Assets.xcassets`, with materials under `MeMo_material/キャラクター/ハロウィン`. The machine uses the exact `gatyaMachine_halloween` spelling. Build workspace catalogs are copied unchanged; no dummy assets or project membership edits.

## Compatibility and remaining checks

**No persistent-data contract changed.** No SwiftData stored model/key, photo path, App Group/Widget/Watch message, project, capability or entitlement change. Existing AppState/Store grant APIs remain owners. No distribution/AppStore action.

Task08 retains physical-device call/playing/balance checks, actual released-install upgrade, forced live ad-server no-fill/offline, and final integration reporting. Physical50-candy rate/Lv5/bonus300 balance is not verified and provisional values remain. Other-device visual adjustments are deferred by the user.
