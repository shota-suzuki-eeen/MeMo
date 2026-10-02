# Halloween 2026 — task 05 verification

Date: 2026-10-02. Specification: [Notion 作業予定リスト / 作業05](https://app.notion.com/p/3be9c0c2893c804f85fdde911ee1fae3). Base: `28cc38f568f8a49e5fbdcdc5b10cde21f7e433c1`.

## Implemented

- Event-only single50 / ten500 candy draws, N66/R30/SR4, real19N foods and8R foods + wc. Regular machines keep their prices/probabilities and exclude new Halloween characters.
- SR normal ticket1 (60,10/day), yakiniku1 (20,2/day), existing fishing balance+500 (20,2/day). Each draw removes capped candidates; no empty reward. Exhausted SR normalizes N/R to68.75/31.25. SR resets in Asia/Tokyo;50 progress persists across days.
- Every50 draws grants one random unowned verified Halloween character, immediately after its boundary draw in the result list. Remaining ten draws carry into the next cycle. All-owned produces no replacement reward.
- Existing rewardGacha SDK/ad unit grants free10 in the three existing device-calendar slots. Event use is separate from normal use and valid through the reward grace period.
- Pending journal and completion receipt are additive optional Codable fields in the existing event payload. Absolute delivery targets recover through existing AppState food/item/pet APIs, FishingStore balance and ModelContext.save. Startup completes recovery before exposing inventory. Completed stale journals are discarded and persisted in canonical form.

## Validation

- `bash scripts/test_halloween_event.sh`: **PASS 178059 assertions**, including exact probability intervals, caps within a ten, JST rollover, periods/grace/closure, old payloads, independent ad slots,50 boundary ordering/carry, insufficient funds, duplicate IDs and stale journal repair.
- Xcode26.0.1, MeMo scheme, Debug, generic iOS Simulator, ad-hoc signing, copied unchanged ignored asset catalogs: **BUILD SUCCEEDED**. Final build reported no errors or warnings. MeMo dependencies include Widget, Watch and Complication. Existing HealthKit Simulator entitlement retained. No project/config/entitlement changes.
- Named isolated **MeMo Halloween QA**, iPhone17Pro iOS26, UDID `72D15C18-E7C8-48F0-B484-47BD7AFD292E`: actual app update preserved prior BEST567/TOTAL1751,25-stage completion, claims, wallpaper, pet and food state.
- Single draw:327→277 candy,0→1 count,beer+1. Real SDK test-ad completion: candy277 retained, count11, ten rewards, only event evening slot used. Normal ad slots remained unused.
- Paid ten from progress49:1000→500 candy, total59/progress9, ten N/R items plus new harpy shown immediately after first draw. Full SR caps remained10/2/2. Repeated ten operation consumed one batch; no-funds and used-ad buttons disabled.
- Partial cross-store fixture: pre-applied fishing500 remained500; cold launch delivered missing food/ticket/wc/pet targets, cleared pending, recorded completion. Realistic replay with completion marker removed did not duplicate any reward and durably completed. A contradictory completed+pending fixture was safely normalized. Prior failed disk assertion came from that contradictory fixture, not a duplicate reward.
- Previous-day capped SR showed0 counts and66/30/4 again. All25 owned UI showed completion. Paid ten across50 yielded ten ordinary rewards without alternative last-one. Ad interrupted before reward left candy, counts and slot unchanged and released controls. Final cold relaunch retained all data and no pending journal.
- `git diff --check` passed. No SwiftData stored model, photos/memories path, Widget/AppGroup key or Watch protocol changes. User original checkout and original-data Simulator untouched.

## Resource mapping

All25 original base PNGs and their wc/blink variants (100 PNGs total) were SHA-256 matched to the copied Asset Catalog. Original materials directory: `MeMo_material/キャラクター/ハロウィン`; catalog group: `Assets.xcassets/character(26'ハロウィン)`. Assets remain intentionally ignored and were not committed. Display names use verified base names; no unapproved translations.

| Character ID | Base asset / original PNG stem |
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

Each base also maps to `<base>_wc`, `<base>_idle_blink_0001` and `<base>_idle_blink_0002`.

## Limits

CI is not configured; local build/test evidence is the gate. Live ad-server no-fill/offline presentation was not forced; actual test-ad success and pre-reward cancellation plus failure admission/source paths were checked. Physical-device calls, play balance, real-user installation upgrade and broad integration QA remain for task08; this is not an App Store/release-ready claim. UI integration is task07. Distribution was not performed.
