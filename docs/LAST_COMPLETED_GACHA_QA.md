# Last completed normal gacha — task10 verification

Date:2026-10-03. [Notion 作業予定リスト／作業10](https://app.notion.com/p/3be9c0c2893c804f85fdde911ee1fae3). Base: merged PR24 main `d564cca290dd42983e1b6acfeb877d9906d7ac34`.

## Behavior and persistence

Entering the normal GachaView restores the stable ID of the last fully generated, successfully saved1/10 draw. Browsing/selection, cancelled confirmation, insufficient resources, unavailable ad, partial generation and failed save do not record history. All normal payment/free routes converge on the existing `beginDraw`; history records once after grants and SwiftData save, before reveal. Finishing the overlay does not record a second time. Tutorial and pending initial-iPad draws preserve the Always-only restriction.

**Persistent data changed additively; backward compatibility verified.** String key `memo.gacha.lastCompletedMachineID.v1` uses the existing UserDefaults owner and remains separate from machine unlocks. Missing, malformed, unknown, removed, locked or currently omitted IDs use an available default without rewriting the key or unlocking a machine. Existing SwiftData schema/properties, encoded ledgers, tickets, prices, probabilities, claims, photograph paths, App Group/Widget/Watch/LiveActivity and StoreKit/HealthKit contracts are unchanged.

The scope follows the original screen that defaults to Always and its six-machine catalog (`always`, `food`, `moja`, `streetAnimals`, `cyberpunkRacers`, `hyakkaryouran`). The existing Halloween view has a separate event entry and one machine; it does not call normal recording or automatically navigate between screens. This is an interpretation of the existing code and screen-entry specification, not a new explicit user specification.

## Terminal and signed-build checks

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bash scripts/test_gacha_selection.sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bash scripts/test_happiness_checkpoints.sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bash scripts/test_halloween_event.sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bash scripts/test_gacha_tickets.sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bash scripts/test_halloween_hud.sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project MeMo.xcodeproj -scheme MeMo -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath ../memo_stage10_derived -clonedSourcePackagesDirPath ../memo_packages \
  -disableAutomaticPackageResolution -onlyUsePackageVersionsFromResolvedFile \
  CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- build
```

PASS:4522 selection/commit/payment/reload,1610 happiness,178059 event,101 ticket and220 HUD assertions. Selection tests compile the actual Gacha owner and payment/free-slot policies with isolated dependency shells. Binary-plist round trips exercise payload reload; terminal tests do not write the app's real defaults/store or substitute for native persistence checks.

Xcode26.0.1 signed Debug MeMo generic Simulator build and separate QA build-for-testing succeeded, including configured Widget/Watch/Complication dependencies. Existing HealthKit entitlement was retained. Real ignored catalogs were copied physically and byte-identically (1807 main,37 Watch,477 Widget files); no catalogs were added to Git. Product project, targets, package versions, capabilities and signing configuration are unchanged. Baseline CameraStyle/Watch isolation, extension-version and AppIntents warnings remain.

## Native UI and actual saved-state checks

Only MeMo Halloween QA, iPhone17Pro/iOS26, UDID `72D15C18-E7C8-48F0-B484-47BD7AFD292E`, bundle `com.shota-eeen.MeMo`, was used. The production Gacha owner was byte-identical in the separate QA copy: SHA256 `80d77c6dee4bb024be58268e0ee75d0b358b7d61c833738a6b779cfff0b0d14e`. QA-only accessibility identifiers, runtime observations, controlled callbacks/faults and tutorial/iPad branch injection were confined to that copy.

All15 cases completed with zero native test failures and PASS saved-state comparisons; each includes cold relaunch. Screenshots and accessibility hierarchies are retained in native xcresults.

| Case | Actual result |
|---|---|
| Walk payment, six machines; browsing/cancel | Always1 draw→Food browsing/confirmation cancel→reopen Always. Food10 success→reopen Food. Moja/Street/Cyber/Hyakka single draws each recorded their stable ID; cold relaunch restored Hyakka. Exactly7500 steps consumed and actual reward lists matched saved foods/items/characters. |
| Normal tickets | Street single consumed1 normal ticket; Hyakka10 consumed10. Wallet unchanged; grants matched actual rewards; restart retained Hyakka. |
| Guaranteed-character ticket | Moja single consumed1 special ticket, awarded one previously unowned Moja character and recorded Moja; wallet unchanged. |
| Earned free ten, duplicate callback | Existing developer-mode earned route reached the actual view callback twice. First accepted, second rejected; one10-draw completion and one noon slot consumption; Cyber retained on restart. This is not a live ad SDK test. |
| Controlled ad unavailable | Actual unavailable callback returned idle without a draw/slot/resource/history update; restart retained Always. |
| Controlled save failure | Complete generated results with a failed save result did not overwrite Always. Existing grant/consumption failure handling was preserved; no rollback guarantee is added. |
| Controlled partial result | Nine reported rewards for a10-draw request failed the completion guard; history remained Always after restart. |
| Insufficient resources | Single/ten controls disabled; Food browsing did not change history or resources; reopen/restart retained Always. |
| Missing history | Always fallback; no history key created, no unlock/resource changes. |
| Unknown/deleted/expired ID witness | Safe Always fallback, invalid String retained unchanged; no forced unlock/resource changes. Current normal machines do not expire; omitted availability is also covered in model tests. |
| Malformed history type | Integer fixture retained unchanged; safe Always fallback. |
| Locked history | Food ID remained stored while actually unavailable; Always fallback with no forced unlock. |
| Tutorial branch | QA-only tutorial initialization restricted selection to Always, executed the real10 reward path, consumed/completed first-visit markers, disabled repeat in the same presentation, recorded Always and retained it on ordinary restart. This is not new-install onboarding. |
| Initial-iPad branch | QA-only idiom injection on the approved iPhone restricted initial selection to Always despite saved Food. Real initial10 path guaranteed a character, consumed the one-time key, recorded Always, then restored normal selection availability. Restart showed no repeated initial benefit. No iPad device was added. |
| Event separation | Event single consumed50 candy and committed exactly one event batch/draw. Normal Food history survived event navigation and cold relaunch. |

Successful normal routes compare actual reward kinds/IDs against exact saved inventory deltas, rather than assuming a random roll. Protected current-pet/notification/daily-goal fields and photograph/workout rows remained unchanged; unlock sets were unchanged. No-execution cases also preserved wallet, inventory, pity and free-slot ledgers. Normal cases preserved event payload bytes.

## Fixtures, evidence and restoration

Backups were matched to the authoritative restored QA baseline before changes. A reported absent container was resolved only to the unique physically existing bundle-identified container inside the approved QA device. Live SQLite used an existing `mode=rw` connection and backup API; fixed backups were read immutable only with absent/empty WAL and rollback journal. SHM cache size is not a completeness gate.

Fixtures use the existing owner's sorted unlock representation and consistent claimed-machine records. Unlock comparisons use sets and still detect additions/removals. An initial order-sensitive assertion and inconsistent fixture were corrected with user authorization; the first native case and its evidence were preserved and rerun under `missing-confirmed`. Python syntax validation runs in memory without cache writes or new permissions. Product code was unchanged by these QA corrections.

After all cases, the signed clean product was installed; original full logical SQLite dump and exact plist bytes were restored. Installed executable/debug-dylib SHA256 matched the product and the named Simulator was verified Shutdown. Original checkout and production Simulator were untouched. No QA project, private snapshots or diagnostic code ships.

Local evidence is under `task-2/qa-task10-gacha/`: `final-qa-result.json`,15 verification JSONs, transitions, fixtures/after snapshots, native xcresults, original backups and `restore-final-restore-state.json`. Optional post-test Xcode diagnostics collection continues to report an internal `xcrun simctl` lookup warning; native commands return success and screenshots/hierarchies remain in xcresults. Global xcode-select and OS permissions were not changed; no attachment-export retry was performed.

## Remaining release limits

Live ad SDK failure/recovery, real-device calls/long idle/existing-install upgrades, actual iPad/new-install onboarding and final Small/iPad layouts are unverified. Task08/11 release gates remain open. No CI is configured; empty remote statuses do not mean CI PASS. Distribution and App Store submission were not performed or authorized.
