# Halloween 2026 — task 06 verification

Date: 2026-10-02. Specification: [Notion 作業予定リスト / 作業06](https://app.notion.com/p/3be9c0c2893c804f85fdde911ee1fae3). Base: `e82c6ad2b6effac4b250384ab28ab0d06fb91a5d` (task05, PR19).

## Implemented

- The regular gacha inventory sheet uses existing special-item counts and exact released IDs `gachaTicket_nomal` / `gachaTicket_special`. Its button sits below the emission list using the same style.
- Paid single/ten draws prefer one/ten normal tickets when sufficient; otherwise they use the unchanged full500/5000 step prices. Labels and affordability follow the same policy. Tickets never combine with steps, unlock machines, or pay for event gacha.
- A special-ticket button below free ten grants one unowned SR character from the selected unlocked regular machine. Only that ticket is consumed. It is hidden for zero tickets or a completed machine. Existing tutorial and initial-iPad restrictions remain.
- Completed regular machines require the specified confirmation before paid draws or ads. Cancel does not draw, consume resources, or begin advertising. The selected machine is captured, and controls stay locked through confirmation, advertising and reveal. An ad presentation token rejects repeated/stale callbacks.
- Rewards are saved before the reveal animation. Existing AppState inventory APIs, regular pity rules and ad slots remain the owners; no stored SwiftData model, persistence key, photos, Widget or Watch contract is changed.

## Validation

- `bash scripts/test_gacha_tickets.sh`: **PASS101 assertions** covering single/ten thresholds, insufficient tickets, wallet boundaries, unchanged IDs and no mixed payments.
- `bash scripts/test_halloween_event.sh`: **PASS178059 assertions**; event regression unchanged.
- Xcode26.0.1, Debug, generic iOS Simulator, existing HealthKit entitlement and ad-hoc signing, unchanged copied ignored asset catalogs: **BUILD SUCCEEDED** including Widget/Watch/Complication dependencies. Final build has no errors or warnings. No project, entitlement or asset changes committed.
- Isolated **MeMo Halloween QA**, iPhone17Pro iOS26, UDID `72D15C18-E7C8-48F0-B484-47BD7AFD292E`: initial update retained the prior task05 state. Only named QA test fixtures were edited, with plist/SQLite backups; original user data and checkout were untouched.
- Wallet0, normal tickets2: single enabled with ticket1, ten disabled with5000 steps, special button hidden. Inventory displayed2/0 with the existing ticket images. Actual single consumed2→1 tickets, retained wallet0 and granted sandwich1.
- Unlocked food machine, wallet10000, normal11, special3: switching machines retained ticket pricing. Special consumed3→2, granted previously unowned `food_satumaimo`, retained normal11/wallet10000 and reset food pity only. The full two-line button and SR reveal were visually verified.
- Paid ten consumed normal11→1, retained wallet10000, granted nine foods plus wc1. Next ten with only one ticket retained that ticket and consumed wallet10000→5000, again granting ten rewards. Remaining ticket single consumed1→0 with wallet5000 unchanged; labels returned to500/5000 steps.
- All20 food characters owned: completed overlay shown and special button hidden despite special2; switching back to an incomplete machine showed the button. Paid and free-ad confirmation used the exact specified text. Both cancellations left all tracked persisted state identical.
- Confirmed completed-machine single consumed normal1→0, retained wallet5000/special2 and all pets, and granted one ordinary food. Confirmed real SDK test ad granted exactly ten foods, consumed only the normal evening slot and retained tickets/steps/event state. Event count remained109 throughout all regular operations.
- Cold relaunch before opening the final capsules retained all grants, wallet, items, pets, pity, normal slot and event payload exactly. Wallet499 with both tickets0 disabled both paid buttons and hid special; inventory displayed0/0 and closed normally.
- `git diff --check` passed. Regular base N66/R30/SR3 and machine definitions remain unchanged. No CI is configured; local tests/build/UI evidence forms the gate.

## Remaining integration checks

Broader screen-size integration is task07. Physical-device calls/play balance, real existing-install upgrade, forced live ad-server no-fill/offline and overall release QA are tracked for task08. This stage does not claim those checks or authorize distribution.
