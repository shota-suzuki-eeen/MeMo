# Task 011: Halloween Home entry artwork

## Status

Implementation and isolated Simulator QA passed on2026-10-03. The user explicitly authorized merging the verified implementation before screenshot sharing/review is complete. See `docs/HALLOWEEN_HOME_ENTRY_ASSET_QA.md` for results and deferred checks.

## Source and scope

The latest Notion 「作業予定リスト」 and its task11 require a transparent, square, original clay Halloween entry asset. The user approved the orange pumpkin with a purple hat and no lettering, then explicitly approved a native macOS ImageIO crop without regenerating the artwork. Use the PR23 selected05 placement. The later user instruction permits overlap with the toilet thought bubble and requires all non-cleanup operations to remain locked while poop is active.

Replace only the artwork in the existing `HalloweenHomeEntryButton`. Keep the Home56-point status-button frame, 10-point column spacing, badge, content shape, shadow, accessibility label, sound, action, panel hiding and event date checks. Do not add a second entry or change Home sizing, root gesture layers, EventManager or persistence.

## Asset and provenance

- Approved original: Library `libfile_d0deae1f72308191a6ee71b74938e79a`, version0, filename `memo11-halloween-preview.png`, file `file_000000008cfc81f5afb980afe6400ae7`.
- Source:1254×1254, RGBA8, SHA256 `0f1ddef06ef3a4171b9646af578fc32bd71b013da2765575c1551f1d91675f6f`.
- Alpha bounds:[50,68,1209,1228), width1159/height1160. Crop:[50,68,1210,1228), size1160×1160. Rightmost1px remains transparent to keep a square without cutting or distorting the silhouette; the user approved this exact result.
- Adopted PNG SHA256:`97a0f1661923172df48358c74da588e653dc20ae62ad8600132ce4562328a534`. All corresponding RGBA pixels and972961 nontransparent pixels match exactly. The original file and its Library ID/version metadata remain intact outside the checkout.
- Actual new artwork lives in `MeMo/HalloweenEventAssets.xcassets/halloween_event_entry.imageset`. Track only this requested new catalog, which is outside the existing ignored catalog paths. Do not force-add, recreate, rename or replace existing ignored assets.

## Verification and acceptance

1. Verify PNG transparency, minimum square crop and pixel equality; inspect the adopted image.
2. Run related event, ticket, HUD, selection and checkpoint checks plus `git diff --check`.
3. Build the signed MeMo scheme with Xcode26.0.1 and existing HealthKit entitlement, using byte-identical real local catalogs. Verify the new catalog's actual app resource membership; do not change project/capability/package settings.
4. On isolated **MeMo Halloween QA** `72D15C18-E7C8-48F0-B484-47BD7AFD292E` only, verify bright/dark wallpapers and appearance, poop hidden/shown, the fixed Home/bottom/toilet/entry geometry and badge label.
5. Use native XCTest physical taps to verify all covered actions remain blocked while poop exists; cleanup then event→Back, transparent hit area and menu hiding remain functional.
6. Test dates before start, at boundaries and after reward end in an independent observation-only QA copy. Keep production EventManager and store/model source unchanged.
7. Restore the entire original QA database logically and exact plist bytes, reinstall the clean signed product and shut down QA. Do not touch the user's original checkout or production Simulator.
8. Preserve actual comparison PNGs and report verification results. The user's later explicit instruction authorizes task11 merge before screenshot sharing/review. Library sharing remains blocked and must not be reported as complete. Physical-device, Small-phone and iPad final-layout checks remain deferred; do not mark task08 complete.

## Persistence

**No persistent-data contract changed.** No model/schema, key, photo path, App Group, Widget/Watch, StoreKit or entitlement changes are in scope. QA fixtures remain isolated and reversible.
