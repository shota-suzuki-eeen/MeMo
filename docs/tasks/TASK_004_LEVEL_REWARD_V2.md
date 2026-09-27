# Task: レベルアップ報酬をガチャ中心のV2仕様へ変更

## Status

`Done`

## Goal

standard happiness level rewardを、Legacy character直接付与から以下中心のV2仕様へ変更する。

- ガチャチケット
- キャラ確定ガチャチケット
- ガチャマシーン解放

既存ユーザーが過去に取得したLegacy character、ownership、gacha progress、その他local dataは削除・回収・置換しない。

既存ユーザーが旧standard rewardをclaim済みでも、現在levelが条件を満たす場合はV2 rewardを追加で各1回claimできること。

## Background

基準 `main` commit: `5d23e42c55fd07e46498450603e9477cd543dd18`

現行 `AppState+Happiness.swift` では:

- standard rewardはLv5〜40で `reward_000`〜`reward_007` を直接付与
- standard rewardのclaimed stateは `memo.happiness.claimedRewardLevels`
- reward characterを現在お世話中にした場合は、`happinessRewardDefinitionsByCarePetID` による別のLv10 casual rewardが存在
- claimedRewardLevelsはhappiness storage contextごとにsuffix付きkeyとして利用される場合がある
- `HappinessRewardDefinition` / `HappinessRewardClaimResult` は現状character付与前提のshape

したがってV2化では、**standard rewardだけを新仕様へ切替し、reward character別の既存casual reward systemを壊さないこと**が重要。

旧 `memo.happiness.claimedRewardLevels` をV2 standard rewardの受取済み判定へ流用すると、旧standard reward claim済みユーザーがV2 rewardを受け取れないため、V2 standard reward専用のadditive/versioned claim stateを持つこと。

現行 `GachaView.swift` では `food` / `moja` は通常時常に `GachaCatalog.gachas` に含まれる。
V2ではmachine unlock stateでvisible listをfilterする。

## Scope

### In scope

- standard happiness rewardをV2定義へ変更
- Legacy standard characterの新規配布終了
- Legacy character ownership / ID / Asset維持
- reward character別Lv10 casual reward systemの維持
- V2 standard reward claim stateの追加
- 既存到達ユーザーへのV2 reward補填
- `gachaTicket_nomal` / `gachaTicket_special` 付与
- Gacha machine unlock state追加
- visible gacha listをunlock stateでfilter
- Home reward UI / claim flow更新
- AdMob claimable happiness reward判定更新
- existing onboarding / limited reward関連への影響確認
- duplicate grant防止
- existing dataを壊さないadditive migration

### Out of scope

- Legacy character削除・rename
- Legacy Asset削除
- Legacy ownershipのticketへの交換
- reward character別casual reward廃止
- destructive SwiftData migration
- Ticketの未指定な消費UI/消費ルールを推測して追加
- Gacha排出率変更
- new character pool追加（TASK_001〜003）

## 最初に確認する既存実装

- `MeMo/Models/AppState+Happiness.swift`
  - `standardHappinessRewardDefinitions`
  - `happinessRewardDefinitionsByCarePetID`
  - `currentHappinessRewardDefinitions`
  - `claimedHappinessRewardLevels`
  - `setClaimedHappinessRewardLevels`
  - `claimHappinessReward`
  - `HappinessRewardDefinition`
  - `HappinessRewardClaimResult`
- `MeMo/Views/HomeView.swift`
  - reward list / claim UI
  - `claimHappinessReward(level:)`
- `MeMo/Managers/AdMobManager.swift`
  - `hasClaimableHappinessReward`
- `MeMo/Models/AppState+LimitedHappinessRewardOnboarding.swift`
- `MeMo/Views/MemoLimitedHappinessRewardIntroOverlay.swift`
- `MeMo/Models/AppState+Gacha.swift`
  - `gachaSpecialItemCounts`
  - `gachaAddSpecialItem`
  - `gachaConsumeSpecialItem`
  - per-gacha pity
- `MeMo/Views/GachaView.swift`
  - `GachaCatalog.gachas`
  - `availableGachas`
  - `isAlwaysGachaOnlyMode`
- `MeMo/Models/PetMaster.swift`
  - Legacy reward IDs / ownership
- stable gacha IDs:
  - `always`
  - `food`
  - `moja`
  - `streetAnimals`
  - `cyberpunkRacers`
  - `hyakkaryouran`

## Required assets

| Asset | Runtime name/path | Git 管理 | Notes |
|---|---|---|---|
| 通常ガチャチケット | `gachaTicket_nomal` | No | `nomal` は仕様上のAsset名。勝手に `normal` へ変更しない |
| キャラ確定ガチャチケット | `gachaTicket_special` | No | local Asset |
| 各machine Asset | 各Gacha Task参照 | No | local Asset |

## Functional requirements

### V2 standard reward list

| Level | Reward |
|---:|---|
| 5 | ガチャチケット ×10 |
| 10 | キャラ確定ガチャチケット ×1 |
| 15 | フードガチャ解放 |
| 20 | ガチャチケット ×10 |
| 25 | キャラ確定ガチャチケット ×1 |
| 30 | もじゃガチャ解放 |
| 35 | ガチャチケット ×10 |
| 40 | キャラ確定ガチャチケット ×1 |
| 45 | ストリートアニマルズ解放 |
| 50 | ガチャチケット ×10 |
| 55 | キャラ確定ガチャチケット ×1 |
| 60 | サイバーパンクレーサーズ解放 |
| 65 | ガチャチケット ×10 |
| 70 | キャラ確定ガチャチケット ×1 |
| 75 | 百花繚乱解放 |

### Standard rewardとLegacy casual rewardの分離

1. Standard meter contextではV2 reward listを使用する。
2. `reward_000`〜`reward_007` 等のreward characterをお世話中にした時のexisting Lv10 casual rewardは現行仕様を維持する。
3. `happinessRewardDefinitionsByCarePetID` とそのclaim状態をV2 standard rewardへ置換しない。
4. Existing `memo.happiness.claimedRewardLevels` はLegacy / existing context互換のため削除・renameしない。
5. V2 standard claim stateは別のnamespaced/versioned keyで管理する。

### Ticket

6. 通常ticket item ID / Assetは `gachaTicket_nomal`。
7. special ticket item ID / Assetは `gachaTicket_special`。
8. 可能ならexisting `gachaSpecialItemCounts` / `gachaAddSpecialItem` を再利用し、ticket count専用の重複storeを作らない。
9. 同一V2 level rewardを再claimしてticketを重複付与できない。
10. Current sourceにticket消費仕様が存在しないため、本Taskではユーザー未指定の「何回分のガチャに使えるか」「どのmachineで使えるか」等を推測しない。必要なら別Taskとして切り出す。

### Legacy characters

11. `reward_000`〜`reward_007` とcasual IDsを削除しない。
12. Existing owned characterを回収しない。
13. Pet ID / Asset mappingを変更しない。
14. New userへのstandard reward直接配布のみ終了する。
15. Machine lock状態とLegacy character利用可否を関連付けない。

### V2 claim / compensation

16. 旧standard reward claim済みでも、現在levelが条件を満たせばV2 rewardを各1回claim可能。
17. Legacy characterを保持したままV2 rewardを追加付与する。
18. app restart後も二重付与しない。
19. Update再実行相当でも二重付与しない。
20. Existing dataを削除・置換せず、追加のみ。
21. Background automatic exchangeは行わず、Home reward UIからユーザーがclaimする。
22. `AdMobManager` のclaimable判定もV2 standard rewardに追従させる一方、care-pet contextの既存挙動を壊さない。

### Machine unlock

23. `always` は常時表示・利用可能。
24. `food` はLv15 V2 reward claimまでhidden。
25. `moja` はLv30 V2 reward claimまでhidden。
26. `streetAnimals` はLv45 V2 reward claimまでhidden。
27. `cyberpunkRacers` はLv60 V2 reward claimまでhidden。
28. `hyakkaryouran` はLv75 V2 reward claimまでhidden。
29. machine unlock stateとcharacter ownershipを別dataで管理。
30. Machine lockでexisting owned characterを削除しない。
31. Machine lock/unlockでpity / guaranteed stateをresetしない。
32. Machine lock/unlockでspecial item countsをresetしない。
33. `availableGachas` は通常時「unlocked machineのみ」を返す。
34. `isAlwaysGachaOnlyMode` がtrueのtutorial / iPad初回無料10回では、unlock状態に関係なくexisting仕様どおり `[always]` のみ。
35. Unlock後、`always` を先頭に保ったまま既存machine orderへ追加する。

### Existing users

36. 過去にfood / mojaを利用済みでも、V2 unlock未claimならupdate後はmachineをhiddenにする。
37. その場合でもfood / moja character ownershipは維持する。
38. Lv15/Lv30到達済みならHomeからunlockをclaim可能。
39. Lv45/Lv60/Lv75到達済みなら各new machine unlockをclaim可能。
40. 旧 `memo.happiness.claimedRewardLevels` の値によってV2 rewardがclaim済み扱いにならない。

## UI / interaction requirements

- Standard Home reward UIはV2 reward typeに応じてticket / machine unlockを表示する。
- Ticketは指定Assetを表示。
- Machine unlock rewardは対象machine名が分かること。
- Locked machineはGacha画面の左右navigation対象にも含めない。
- `always` は常に先頭。
- Reward character別casual reward UIは現行挙動を維持。
- Legacy reward onboarding/overlayは参照関係を調査し、不要そうに見えてもLegacy pathを壊す削除をしない。

## Persistence requirements

### Additive persistence

必須:

- `memo.happiness.claimedRewardLevels` を変更しない
- V2 standard claim専用keyを追加
- Machine unlock専用keyを追加
- Ticket countはexisting generic gacha special-item storageの再利用を優先
- Existing gacha pity keyを変更しない

推奨設計例:

- V2 claimed levels: versioned Set<Int> / encoded array
- unlocked machine IDs: versioned Set<String> / encoded array
- default unlocked machine: `always` のみ

ただし実装前に現行architectureとkey namespaceを確認し、既存key衝突がない名称を選ぶこと。

Machine unlock storeはownership storeと絶対に共有しない。

## Existing-user compatibility

維持必須:

- Legacy reward character ownership
- casual reward ownership
- existing standard claimed reward state
- care-pet context claimed state
- existing gacha pity / guaranteed
- existing food / moja ownership
- existing special item counts
- other local data

## Xcode / target impact

- affected target(s): `MeMo`
- `MeMo.xcodeproj` 変更必要?: Source-onlyなら原則不要
- Target Membership change?: 新規source file追加時のみ確認
- entitlements / capability change?: 不要
- Swift Package change?: 不要
- ignored/local Asset dependency?: Yes

## 不要に変更してはいけない file

- `MeMo/Models/AppState.swift` SwiftData schema
- Legacy Pet ID / Asset mapping
- existing UserDefaults literal keys
- care-pet casual reward behavior
- Documents storage
- Watch / Widget protocol
- `project.pbxproj`（不要なら変更しない）

## Acceptance criteria

- [ ] Standard reward Lv5〜75がV2 listになる
- [ ] Legacy standard characterの新規直接配布終了
- [ ] Existing Legacy character維持
- [ ] Reward character別Lv10 casual reward維持
- [ ] Old claimed stateとV2 claimed stateが分離
- [ ] Existing到達ユーザーがV2 rewardを追加で1回claim可能
- [ ] Ticket二重付与なし
- [ ] Machine unlockとownershipが別state
- [ ] `always` 常時表示
- [ ] Locked machine hidden
- [ ] tutorial / iPad初回Always-only制限維持
- [ ] unlock後machine表示
- [ ] lock/unlockでownership / pity / itemsをresetしない
- [ ] destructive migrationなし

## Verification

### Codex Cloud

- `AppState+Happiness` standard / care-pet reward path比較
- old/new claim key差分
- Home reward UI / claim flow
- AdMob claimable判定
- Gacha visible list / Always-only mode
- machine unlockとownership分離
- duplicate grant防止
- existing key literal差分
- `git diff`
- usable Xcode toolchainがある場合のみbuild

### Local Xcode

- affected scheme: `MeMo`
- Test cases:
  1. 新規user: Lv5〜75 V2 reward
  2. 旧Lv40 user: old standard rewards全claim済み → V2 Lv5〜40を各1回claim
  3. Legacy reward characterお世話中 → existing Lv10 casual rewardが従来どおり
  4. food / moja owned characterあり・unlock未claim → machine hidden、character利用可能
  5. Lv15/Lv30 claim → food / moja表示
  6. Lv45/60/75 claim → new machines表示
  7. restart後二重付与なし
  8. tutorial / iPad初回無料中はalwaysのみ
- Asset: `gachaTicket_nomal`, `gachaTicket_special`
- signing / capability: 変更なし

### Upgrade test

既存データを保持したまま以下を確認:

- old claimed levelsを保持
- Legacy ownership保持
- V2 claimを追加で受取
- Machine unlock claim前後でownership不変
- restart後重複なし

## Codex final report

- changed files
- implementation summary
- persistence impact
- Xcode / target impact
- Cloud verification
- local Xcode verification required
- migration / upgrade verification
- remaining risks
