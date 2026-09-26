# Task: 新規ガチャ「サイバーパンクレーサーズ」を追加

## Status

`Ready for Codex`

## Goal

ガチャ画面へ「サイバーパンクレーサーズ」を追加し、専用machine・専用character pool・専用character theme BGMを既存multi-gacha構成へ統合する。

固定識別子:

- Gacha ID: `cyberpunkRacers`
- Pet ID prefix: `cyberpunk_`
- Machine Asset: `gatyaMachine_cyberpunkRacers`
- Character theme BGM resource: `BGM_cyberpunkRacers`
- `BGMManager.BackgroundTrack` case: `.cyberpunkRacers`

これらはrelease後のcompatibility identifierになるため、実装後はrenameしない。

最終仕様ではLv60のV2 level rewardをclaimするまでmachineを表示しない。
Machine unlock persistenceは `TASK_004_LEVEL_REWARD_V2.md` の共通実装を使用し、このTaskで別のunlock storeを作らない。

## Background

基準 `main` commit: `5d23e42c55fd07e46498450603e9477cd543dd18`

現行実装では:

- `GachaView.swift` のmachineは `always` / `food` / `moja`
- `selectedGachaIndex` の初期値は0
- tutorial / iPad初回無料10回中は `isAlwaysGachaOnlyMode` により「いつでもガチャ」のみに制限
- `availableGachas` は通常時 `GachaCatalog.gachas`
- `AppState+Gacha.swift` は `GachaDefinition.id` ごとにpity / guaranteed stateを保持
- `GachaView` 表示中のBGMは共通 `.gacha`
- `BGMManager` は現在お世話中のPet ID prefixに応じてHome側のdefault BGMを切り替え、現在は `food_` / `moja_` を専用themeとして扱う
- `PetMaster.wcAssetName` / `idleBlinkAssetNames` も現在は `food_` / `reward_` / `moja_` prefixを特別扱いする
- first-run tutorial character選定は `PetMaster.all` から候補を作るため、新規専用ガチャcharacterを単純追加するとtutorial側へ混入する可能性がある

したがって新規groupは、Gacha poolだけでなくPetMaster / Home BGM / WC / blink / onboarding候補まで一貫してgroup識別できるようにする。

**専用BGMの意味:** `BGM_cyberpunkRacers` は「サイバーパンクレーサーズから排出されたcharacterを現在お世話中にした時のHome theme BGM」とする。
Gacha画面自体は既存どおり共通 `.gacha` BGMを維持し、このTaskだけを理由にmachine別Gacha画面BGMへ変更しない。

## Scope

### In scope

- 新規GachaDefinition `cyberpunkRacers`
- 専用character pool
- listed characterのPetMaster登録
- Stable Pet ID prefix `cyberpunk_`
- `PetMaster.assetName(for:)` mapping
- `_wc` / blink Asset対応
- 新characterを「いつでもガチャ」から除外
- 新characterをfirst-run tutorial guaranteed character候補から除外
- Gacha画面の左右machine切替へ追加
- open時は引き続き「いつでもガチャ」
- tutorial / iPad初回無料10回のAlways-only制限を維持
- per-gacha pity / guaranteed stateへ統合
- `BGM_cyberpunkRacers` をHome character themeとしてBGMManagerへ追加
- ownedPetIDs / Zukan / Home / Watch character renderingとの整合
- TASK_004実装済みなら共通unlock filterへ統合

### Out of scope

- Gacha画面BGMをmachine別に変更
- Gacha全体UI redesign
- existing machine ID変更
- existing pity key変更
- 独自machine unlock persistence追加
- Asset CatalogのGit管理化
- ユーザー未指定の新排出率
- existing food / moja onboarding挙動の整理

## 最初に確認する既存実装

- `MeMo/Views/GachaView.swift`
  - `GachaRarity`
  - `GachaRewardPool`
  - `GachaDefinition`
  - `GachaCatalog.gachas`
  - `isGachaCharacter`
  - `emissionCharacters`
  - remaining character判定
  - `availableGachas`
  - `isAlwaysGachaOnlyMode`
  - machine navigation
  - `.onAppear { bgmManager.switchBackground(to: .gacha) }`
- `MeMo/Models/AppState+Gacha.swift`
  - per-gacha pity
  - legacy always fallback / dual-write
- `MeMo/Models/PetMaster.swift`
  - `all`
  - `assetName(for:)`
  - `wcAssetName(for:)`
  - `idleBlinkAssetNames(for:)`
- `MeMo/Managers/BGMManager.swift`
  - `BackgroundTrack`
  - `defaultBackgroundTrack(for:)`
- `MeMo/Models/AppState+Onboarding.swift`
  - `memoTutorialGachaCharacterPetID`
- `MeMo/Views/ZukanView.swift`
- `MeMo/ViewModels/ZukanViewModel.swift`
- `MeMo/Views/CharacterSpriteView.swift`
- `MeMo/MeMoWatch Watch App/Models/MeMoWatchConnectivityBridge.swift`
- `MeMo/MeMoWatch Watch App/Views/MeMoWatchCharacterSpriteView.swift`
- TASK_004適用済みならmachine unlock implementation

## Required assets

| Asset | Runtime name/path | Git 管理 | Notes |
|---|---|---|---|
| Gacha machine | `gatyaMachine_cyberpunkRacers` | No | local `Assets.xcassets` に追加済み |
| Character theme BGM | `BGM_cyberpunkRacers` | No/要確認 | BGMManagerはbundle fileまたはNSDataAssetを読める。Cloudで実体確認できなければlocal verification |
| Character assets | 下表 | No | local `Assets.xcassets` に追加済み |

### Character assets / stable Pet IDs

| 表示名 | Pet ID | Base | WC | Blink 1 | Blink 2 | Notes |
|---|---|---|---|---|---|---|
| ブラン | `cyberpunk_blanc` | `blanc` | `blanc_wc` | `blanc_idle_blink_0001` | `blanc_idle_blink_0002` |  |
| ブリッツ | `cyberpunk_blitz` | `blitz` | `blitz_wc` | `blitz_idle_blink_0001` | `blitz_idle_blink_0002` |  |
| チェルシー | `cyberpunk_chelsea` | `chelsea` | `chelsea_wc` | `chelsea_idle_blink_0001` | `chelsea_idle_blink_0002` |  |
| ハザード | `cyberpunk_hazard` | `hazard` | `hazard_wc` | `hazard_idle_blink_0001` | `hazard_idle_blink_0002` |  |
| ネオン | `cyberpunk_neon` | `neon` | `neon_wc` | `neon_idle_blink_0001` | `neon_idle_blink_0002` |  |
| ノア | `cyberpunk_noa` | `noa` | `noa_wc` | `noa_idle_blink_0001` | `noa_idle_blink_0002` |  |
| ラピッド | `cyberpunk_rapid` | `rapid` | `rapid_wc` | `rapid_idle_blink_0001` | `rapid_idle_blink_0002` |  |
| リブ | `cyberpunk_reb` | `reb` | `reb_wc` | `reb_idle_blink_0001` | `reb_idle_blink_0002` |  |
| レイ | `cyberpunk_rey` | `rey` | `rey_wc` | `rey_idle_blink_0001` | `rey_idle_blink_0002` |  |
| ジーク | `cyberpunk_sieg` | `sieg` | `sieg_wc` | `sieg_idle_blink_0001` | `sieg_idle_blink_0002` |  |
| ヴィク | `cyberpunk_vic` | `vic` | `vic_wc` | `vic_idle_blink_0001` | `vic_idle_blink_0002` |  |
| ボルト | `cyberpunk_volt` | `volt` | `volt_wc` | `volt_idle_blink_0001` | `volt_idle_blink_0002` |  |
| ヤシャ | `cyberpunk_yasha` | `yasha` | `yasha_wc` | `yasha_idle_blink_0001` | `yasha_idle_blink_0002` |  |

Pet ID / Asset名は正確に使用し、見た目上のtypoを勝手に修正しない。

## Functional requirements

1. Gacha画面open時は「いつでもガチャ」を初期表示する。
2. Existing `＜` / `＞` で「サイバーパンクレーサーズ」へ切替できる。
3. tutorial / iPad初回無料10回中は既存どおり「いつでもガチャ」のみ。
4. `サイバーパンクレーサーズ` 選択時に `gatyaMachine_cyberpunkRacers` を表示する。
5. Gacha IDは `cyberpunkRacers`。
6. listed characterは `cyberpunk_` prefixのstable Pet IDを使用する。
7. listed characterは「サイバーパンクレーサーズ」専用SR character poolへ登録する。
8. listed characterを「いつでもガチャ」のSR candidateへ混入させない。
9. Existing `always` / `food` / `moja` のcandidate内容を壊さない。
10. current multi-gacha仕様に合わせ、N/Rは既存item pool、SRは当該machine専用characterとする。既存確率定義を再利用し、新確率を作らない。
11. pity / guaranteed stateは `cyberpunkRacers` 単位でexisting mechanismを利用する。
12. Legacy `always` key fallback / dual-writeを変更しない。
13. `PetMaster.assetName(for:)` が各Pet IDを指定Base Assetへ解決する。
14. `PetMaster.wcAssetName(for:)` が各新Pet IDに対して `<base>_wc` を返す。
15. `PetMaster.idleBlinkAssetNames(for:)` が各新Pet IDに対して2枚のblink Assetを返す。
16. first-run tutorial gacha characterとしてこのgroupのPet IDを選ばない。
17. 取得後はexisting ownership / Zukan / Home / Watch経路で利用できる。
18. `BGMManager.BackgroundTrack` に `.cyberpunkRacers` (`BGM_cyberpunkRacers`) を追加する。
19. `defaultBackgroundTrack(for:)` で `cyberpunk_` prefixのPetを `.cyberpunkRacers` にmappingする。
20. このgroupのcharacterをお世話中にするとHome BGMが `BGM_cyberpunkRacers` になる。
21. Gacha画面表示中はexisting共通 `.gacha` BGMを維持する。
22. TASK_004適用後はLv60 reward claim前にmachineを表示しない。

## UI / interaction requirements

- Existing machine navigation designを維持。
- title: 「サイバーパンクレーサーズ」
- machine image: `gatyaMachine_cyberpunkRacers`
- initial machine: `always`
- sizing / animationは既存machineに合わせる。
- locked machineはnavigation配列にも含めない。

## Persistence requirements

### Additive persistence

既存per-gacha storageを利用:

- `memo.gacha.pityCountersByGacha`
- `memo.gacha.guaranteedGoldNextByGacha`

dictionaryへ `cyberpunkRacers` entry追加可。

Character ownershipはexisting `ownedPetIDs`を使用。

Machine unlockはTASK_004の共通storeを使用。

新Pet IDは以下をrelease compatibility contractとして固定:

- prefix `cyberpunk_`
- 上表の各Pet ID

## Existing-user compatibility

維持必須:

- existing `always` pity / guaranteed
- `food` / `moja` pity
- existing owned characters
- legacy `memo.gacha.pityCounter`
- legacy `memo.gacha.guaranteedGoldNext`
- existing Pet IDs
- existing tutorial状態

新character追加だけで既存「いつでもガチャ」の排出candidateを変更しない。

## Xcode / target impact

- affected target(s): `MeMo`; character Asset transfer確認のため `MeMoWatch Watch App` も影響確認
- `MeMo.xcodeproj` 変更必要?: Source-onlyなら原則不要
- Target Membership change?: 新規source file追加時のみ
- entitlements / capability change?: 不要
- Swift Package change?: 不要
- ignored/local Asset dependency?: Yes

## 不要に変更してはいけない file

- SwiftData schema
- existing gacha key literals
- existing machine IDs
- existing Pet IDs
- tutorial/iPad Always-only制限
- Gacha画面共通BGM仕様
- `project.pbxproj`（不要なら変更しない）

## Acceptance criteria

- [ ] 「サイバーパンクレーサーズ」追加
- [ ] initial machineはalways
- [ ] tutorial/iPad初回制限維持
- [ ] 左右button切替
- [ ] `gatyaMachine_cyberpunkRacers` 表示
- [ ] dedicated SR pool
- [ ] alwaysへ新character混入なし
- [ ] first-run tutorial characterへ新group混入なし
- [ ] `cyberpunkRacers` pityが独立
- [ ] WC / blink対応
- [ ] ownership / Zukan / Home / Watch利用可能
- [ ] お世話中Home BGMが `BGM_cyberpunkRacers`
- [ ] Gacha画面BGMは `.gacha` のまま
- [ ] TASK_004適用後unlock前非表示
- [ ] existing data維持

## Verification

### Codex Cloud

- GachaDefinition / RewardPool / Catalog差分
- PetMaster ID / Asset / WC / blink mapping
- always candidate除外
- onboarding tutorial candidate除外
- BGMManager BackgroundTrack / prefix mapping
- existing storage key / machine ID差分
- Watch asset transfer経路確認
- `git diff`
- usable Xcode toolchainがある場合のみbuild

### Local Xcode

- affected scheme: `MeMo`, 必要に応じ `MeMoWatch Watch App`
- Simulator/device:
  - initial always
  - machine navigation
  - N/R/SR排出
  - ownership / Zukan
  - WC / blink
  - character選択後Home theme BGM
  - Gacha画面共通BGM
- Asset: machine / Base / WC / blink / `BGM_cyberpunkRacers`
- Watch: 新characterの画像転送・表示
- signing / capability: 変更なし

### Upgrade test

Existing pity / ownership / onboarding stateを保持したdataでupdateし、既存stateが変化しないことを確認する。

## Codex final report

- changed files
- implementation summary
- persistence impact
- Xcode / target impact
- Cloud verification
- local Xcode verification required
- migration / upgrade verification
- remaining risks
