# Release / Regression Checklist

リリース済み MeMo の変更時に使用します。

---

## 1. Repository / diff

- [ ] `AGENTS.md` を読んだ
- [ ] `SwiftDataOperationPolicy.md` を読んだ
- [ ] task spec を読んだ
- [ ] current path が `MeMo/...` であることを確認した
- [ ] Target / project 影響がある場合 `project.pbxproj` を確認した
- [ ] ignored Asset 依存を確認した
- [ ] unrelated file change がない
- [ ] accidental rename がない
- [ ] unrelated cleanup がない

---

## 2. SwiftData

- [ ] `AppState` が残っている
- [ ] `TodayPhotoEntry` が残っている
- [ ] `WorkoutSessionRecord` が残っている
- [ ] stored property rename なし
- [ ] stored property delete なし
- [ ] stored property type change なし
- [ ] encoded `Data` が backward-decodable
- [ ] existing non-empty store で upgrade を考慮した

---

## 3. UserDefaults / AppStorage

- [ ] existing literal key rename なし
- [ ] legacy key が読める
- [ ] fallback / dual-write 維持
- [ ] new key は namespaced
- [ ] safe default がある
- [ ] update 後に旧データを reset しない

---

## 4. Documents / Memories

- [ ] `Documents/memories/` を維持
- [ ] existing `fileName` が解決できる
- [ ] existing JPEG が読める
- [ ] migration は idempotent / retryable

---

## 5. Core smoke test

- [ ] cold launch
- [ ] existing data で launch
- [ ] Home
- [ ] step state
- [ ] current pet
- [ ] owned pet
- [ ] food inventory
- [ ] fullness
- [ ] care scheduling
- [ ] notification settings
- [ ] happiness / claimed rewards
- [ ] gacha pity / free slot / special item
- [ ] fishing
- [ ] wallpaper
- [ ] appearance / audio
- [ ] memories
- [ ] workout / walk history

---

## 6. Event

Halloween / event code 変更時:

- [ ] previous progress が読める
- [ ] `memo.event.halloween2026.progress.v1` を再利用していない
- [ ] reward duplication が起きない
- [ ] exchange balance が reset されない
- [ ] run-game result persistence が維持される

---

## 7. Widget / Live Activity

- [ ] App Group ID 維持
- [ ] shared key 維持
- [ ] Widget kind 維持
- [ ] snapshot compatibility 維持
- [ ] Live Activity lifecycle 確認
- [ ] `MeMoWidgetExtension.entitlements` 変更は意図的
- [ ] ignored Widget Asset を必要に応じ local 確認

---

## 8. Apple Watch / Complication

- [ ] WatchConnectivity activation
- [ ] old/missing field tolerance
- [ ] phone → watch
- [ ] watch → phone
- [ ] application context / background path
- [ ] pet / step / care state 維持
- [ ] dynamic asset
- [ ] Watch Target Membership
- [ ] Complication Target
- [ ] ignored Watch Asset を local 確認

---

## 9. Codex Cloud verification

- [ ] `git diff`
- [ ] persistence literal / model diff
- [ ] relevant Xcode project metadata
- [ ] available tests / static checks
- [ ] usable Xcode toolchain がある場合のみ build
- [ ] build 未実行を build success と書いていない
- [ ] ignored Asset の local verification を列挙

---

## 10. Local Xcode

Affected scheme を確認:

- [ ] `MeMo`
- [ ] `MeMoWidgetExtension`
- [ ] `MeMoWatch Watch App`
- [ ] `MeMoWatchComplicationExtension`
- [ ] `MeMoWatchComplicationExtensionExtension`

必要に応じ:

- [ ] Debug build
- [ ] Release build
- [ ] Simulator / device
- [ ] Target Membership
- [ ] signing / capability
- [ ] ignored Asset reference

Project が parse できることだけを build success とみなさないこと。

---

## 11. Release gate

以下が unresolved の場合 release-ready としない。

- migration uncertainty
- previous payload decode failure
- accidental key change
- file path breakage
- Watch protocol incompatibility
- Widget shared-state incompatibility
- changed target の build 未確認
- Target Membership 不明
- required Asset 未確認
