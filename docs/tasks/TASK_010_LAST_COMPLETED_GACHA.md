# Task: 最後に正常実行した通常ガチャマシーンの再表示

## Status

`Done` — implementation, model regressions, signed product build and15 native UI/real saved-state cases passed. Physical-device/live-ad and actual iPad/new-install checks remain unverified.

## Authoritative source and scope

[Notion 作業予定リスト／Codex作業10](https://app.notion.com/p/3be9c0c2893c804f85fdde911ee1fae3), re-fetched2026-10-03 (page edited2026-10-03T02:36:25.541Z). Base updated to merged PR24 main `d564cca290dd42983e1b6acfeb877d9906d7ac34`. The protected task10 diff was reapplied; the merged task09 happiness model is unchanged.

The source describes entering the screen that currently defaults to 「いつでもガチャ」. The existing `GachaView` contains six selectable normal machines: `always`, `food`, `moja`, `streetAnimals`, `cyberpunkRacers`, `hyakkaryouran`. Its catalog and navigation establish the implementation scope. `Halloween2026GachaView` is a distinct one-machine screen reached through the event, so event draws do not overwrite normal selection or cause automatic cross-screen navigation. This is an interpretation grounded in the existing screen structure and the original screen-entry requirement, not a newly stated user specification; the delegated task10 instruction authorized proceeding in that scope.

## Behavior and owner

- Restore the stable ID of the most recent successful draw when entering the normal screen; A draw→B browsing→reopen restores A, while a successful B draw replaces it with B.
- `AppState+Gacha.swift` retains the existing UserDefaults owner and adds String key `memo.gacha.lastCompletedMachineID.v1`. Read-only fallback uses the available default. No unlock, inventory, pity or reward claim is inferred from this key.
- Missing/malformed/unknown/deleted/locked/expired IDs never force availability, crash, or rewrite history simply by displaying fallback. Current normal machines have no expiration; an omitted current-screen ID is treated as unavailable.
- Walk-currency single/ten, normal-ticket single/ten, guaranteed-character ticket, earned-ad free ten, tutorial free ten and initial-iPad free ten all converge on `beginDraw`. Record only once after full reward count and `modelContext.save()` success, before reveal. Partial/empty generation and save errors retain history; existing consumption/grant failure handling is preserved.
- Viewing/swiping, confirmation cancellation, insufficient balance, ad unavailable/failed/stale callbacks do not reach successful recording. Existing phase/presentation-token guards remain; `beginDraw` also requires idle phase. Repeated same-ID recording is idempotent.
- Tutorial and pending initial-iPad selection remain Always-only; their completed draw records `always` normally. No probability, price, ticket-count, event-payment, schema, entitlement, photograph or Widget/Watch contract changes.

## Verification

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bash scripts/test_gacha_selection.sh`:4522 assertions PASS. Actual Gacha owner and payment/slot policies compile with isolated dependency shells; every machine, old/invalid history, fallback/availability, Always restrictions, incomplete results, save failure, duplicate writes, payment routes and binary-plist reload are covered.
- Existing regressions PASS:1610 happiness,178059 event,101 normal-ticket and220 HUD assertions. No existing stored property, literal key, price, probability, resource contract or project metadata changed.
- Signed Xcode26.0.1 MeMo generic Simulator build and separate QA build-for-testing PASS, with real ignored catalogs physically copied byte-identically and the existing HealthKit entitlement retained.
- Fifteen native XCTest cases on only MeMo Halloween QA passed actual navigation, completion/payment/grant counts, view/cancel/failure history retention, cold relaunch, fallback, initial restrictions and event separation. The Gacha model is byte-identical between product and QA; QA-only observation/control code does not ship.
- Original full logical SQLite dump and exact plist bytes restored; clean product binary SHA256 matched the installation; the named QA Simulator was verified Shutdown. User original checkout and production Simulator were untouched.

See [full QA record](../LAST_COMPLETED_GACHA_QA.md). Draft→ready→merge follows the required successful gates. CI is unconfigured, and distribution is not authorized.

## Remaining limits

The earned free route uses existing developer-mode behavior; ad unavailable/duplicate, save failure and partial-result faults are controlled only in the QA copy. This does not verify live ad SDK failure/recovery. Tutorial initialization and iPad idiom are injected on the existing approved iPhone Simulator; real new-install onboarding and actual iPad UI are unverified. Real-device calls/idle/existing-install updates and final Small/iPad layouts remain open under task08/11.
