# Task: 新規ガチャ「ストリートアニマルズ」を追加

## Status

`Ready for Codex`

## Goal

ガチャ画面へ「ストリートアニマルズ」を追加し、専用machine・専用character pool・専用character theme BGMを既存multi-gacha構成へ統合する。

固定識別子:

- Gacha ID: `streetAnimals`
- Pet ID prefix: `street_`
- Machine Asset: `gatyaMachine_streetAnimals`
- Character theme BGM resource: `BGM_streetAnimals`
- `BGMManager.BackgroundTrack` case: `.streetAnimals`

これらはrelease後のcompatibility identifierになるため、実装後はrenameしない。

最終仕様ではLv45のV2 level rewardをclaimするまでmachineを表示しない。
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

**専用BGMの意味:** `BGM_streetAnimals` は「ストリートアニマルズから排出されたcharacterを現在お世話中にした時のHome theme BGM」とする。
Gacha画面自体は既存どおり共通 `.gacha` BGMを維持し、このTaskだけを理由にmachine別Gacha画面BGMへ変更しない。

## Scope

### In scope

- 新規GachaDefinition `streetAnimals`
- 専用character pool
- listed characterのPetMaster登録
- Stable Pet ID prefix `street_`
- `PetMaster.assetName(for:)` mapping
- `_wc` / blink Asset対応
- 新characterを「いつでもガチャ」から除外
- 新characterをfirst-run tutorial guaranteed character候補から除外
- Gacha画面の左右machine切替へ追加
- open時は引き続き「いつでもガチャ」
- tutorial / iPad初回無料10回のAlways-only制限を維持
- per-gacha pity / guaranteed stateへ統合
- `BGM_streetAnimals` をHome character themeとしてBGMManagerへ追加
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
| Gacha machine | `gatyaMachine_streetAnimals` | No | local `Assets.xcassets` に追加済み |
| Character theme BGM | `BGM_streetAnimals` | No/要確認 | BGMManagerはbundle fileまたはNSDataAssetを読める。Cloudで実体確認できなければlocal verification |
| Character assets | 下表 | No | local `Assets.xcassets` に追加済み |

### Character assets / stable Pet IDs

| 表示名 | Pet ID | Base | WC | Blink 1 | Blink 2 | Notes |
|---|---|---|---|---|---|---|
| アゲリーター | `street_ageriter` | `ageriter` | `ageriter_wc` | `ageriter_idle_blink_0001` | `ageriter_idle_blink_0002` |  |
| アラコ | `street_arako` | `arako` | `arako_wc` | `arako_idle_blink_0001` | `arako_idle_blink_0002` |  |
| ボーダーケニー | `street_borderkeniy` | `borderkeniy` | `borderkeniy_wc` | `borderkeniy_idle_blink_0001` | `borderkeniy_idle_blink_0002` |  |
| ファントス | `street_fantosu` | `fantosu` | `fantosu_wc` | `fantosu_idle_blink_0001` | `fantosu_idle_blink_0002` |  |
| ファックス | `street_fax` | `fax` | `fax_wc` | `fax_idle_blink_0001` | `fax_idle_blink_0002` |  |
| フライド | `street_fried` | `fried` | `fried_wc` | `fried_idle_blink_0001` | `fried_idle_blink_0002` |  |
| グイン | `street_guin` | `guin` | `guin_wc` | `guin_idle_blink_0001` | `guin_idle_blink_0002` |  |
| ハム・スター | `street_hamstar` | `hamstar` | `hamstar_wc` | `hamstar_idle_blink_0001` | `hamstar_idle_blink_0002` |  |
| ヘイン | `street_hayne` | `hayne` | `hayne_wc` | `hayne_idle_blink_0001` | `hayne_idle_blink_0002` |  |
| カバラピ | `street_kabarapi` | `kabarapi` | `kabarapi_wc` | `kabarapi_idle_blink_0001` | `kabarapi_idle_blink_0002` |  |
| クロ | `street_kuro` | `kuro` | `kuro_wc` | `kuro_idle_blink_0001` | `kuro_idle_blink_0002` |  |
| モンマス | `street_monmasu` | `monmasu` | `monmasu_wc` | `monmasu_idle_blink_0001` | `monmasu_idle_blink_0002` |  |
| ラビ | `street_rabi` | `rabi` | `rabi_wc` | `rabi_idle_blink_0001` | `rabi_idle_blink_0002` |  |
| ラックン | `street_raccun` | `raccun` | `raccun_wc` | `raccun_idle_blink_0001` | `raccun_idle_blink_0002` |  |
| ライアン | `street_raian` | `raian` | `raian_wc` | `raian_idle_blink_0001` | `raian_idle_blink_0002` |  |
| ラッチュ | `street_rattyu` | `rattyu` | `rattyu_wc` | `rattyu_idle_blink_0001` | `rattyu_idle_blink_0002` |  |
| ラウタン | `street_rautan` | `rautan` | `rautan_wc` | `rautan_idle_blink_0001` | `rautan_idle_blink_0002` |  |
| レイタ | `street_reita` | `reita` | `reita_wc` | `reita_idle_blink_0001` | `reita_idle_blink_0002` |  |
| リゴラ | `street_rigora` | `rigora` | `rigora_wc` | `rigora_idle_blink_0001` | `rigora_idle_blink_0002` |  |
| リッス | `street_rissu` | `rissu` | `rissu_wc` | `rissu_idle_blink_0001` | `rissu_idle_blink_0002` |  |
| サンクマ | `street_sankuma` | `sankuma` | `sankuma_wc` | `sankuma_idle_blink_0001` | `sankuma_idle_blink_0002` |  |
| スパイキー | `street_spiky` | `spiky` | `spiky_wc` | `spiky_idle_blink_0001` | `spiky_idle_blink_0002` |  |
| ヤーン | `street_yarn` | `yarn` | `yarn_wc` | `yarn_idle_blink_0001` | `yarn_idle_blink_0002` |  |
| ユーマ | `street_yuma` | `yuma` | `yuma_wc` | `yuma_idle_blink_0001` | `yuma_idle_blink_0002` |  |

Pet ID / Asset名は正確に使用し、見た目上のtypoを勝手に修正しない。

## Functional requirements

1. Gacha画面open時は「いつでもガチャ」を初期表示する。
2. Existing `＜` / `＞` で「ストリートアニマルズ」へ切替できる。
3. tutorial / iPad初回無料10回中は既存どおり「いつでもガチャ」のみ。
4. `ストリートアニマルズ` 選択時に `gatyaMachine_streetAnimals` を表示する。
5. Gacha IDは `streetAnimals`。
6. listed characterは `street_` prefixのstable Pet IDを使用する。
7. listed characterは「ストリートアニマルズ」専用SR character poolへ登録する。
8. listed characterを「いつでもガチャ」のSR candidateへ混入させない。
9. Existing `always` / `food` / `moja` のcandidate内容を壊さない。
10. current multi-gacha仕様に合わせ、N/Rは既存item pool、SRは当該machine専用characterとする。既存確率定義を再利用し、新確率を作らない。
11. pity / guaranteed stateは `streetAnimals` 単位でexisting mechanismを利用する。
12. Legacy `always` key fallback / dual-writeを変更しない。
13. `PetMaster.assetName(for:)` が各Pet IDを指定Base Assetへ解決する。
14. `PetMaster.wcAssetName(for:)` が各新Pet IDに対して `<base>_wc` を返す。
15. `PetMaster.idleBlinkAssetNames(for:)` が各新Pet IDに対して2枚のblink Assetを返す。
16. first-run tutorial gacha characterとしてこのgroupのPet IDを選ばない。
17. 取得後はexisting ownership / Zukan / Home / Watch経路で利用できる。
18. `BGMManager.BackgroundTrack` に `.streetAnimals` (`BGM_streetAnimals`) を追加する。
19. `defaultBackgroundTrack(for:)` で `street_` prefixのPetを `.streetAnimals` にmappingする。
20. このgroupのcharacterをお世話中にするとHome BGMが `BGM_streetAnimals` になる。
21. Gacha画面表示中はexisting共通 `.gacha` BGMを維持する。
22. TASK_004適用後はLv45 reward claim前にmachineを表示しない。

## UI / interaction requirements

- Existing machine navigation designを維持。
- title: 「ストリートアニマルズ」
- machine image: `gatyaMachine_streetAnimals`
- initial machine: `always`
- sizing / animationは既存machineに合わせる。
- locked machineはnavigation配列にも含めない。

## Persistence requirements

### Additive persistence

既存per-gacha storageを利用:

- `memo.gacha.pityCountersByGacha`
- `memo.gacha.guaranteedGoldNextByGacha`

dictionaryへ `streetAnimals` entry追加可。

Character ownershipはexisting `ownedPetIDs`を使用。

Machine unlockはTASK_004の共通storeを使用。

新Pet IDは以下をrelease compatibility contractとして固定:

- prefix `street_`
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

- [ ] 「ストリートアニマルズ」追加
- [ ] initial machineはalways
- [ ] tutorial/iPad初回制限維持
- [ ] 左右button切替
- [ ] `gatyaMachine_streetAnimals` 表示
- [ ] dedicated SR pool
- [ ] alwaysへ新character混入なし
- [ ] first-run tutorial characterへ新group混入なし
- [ ] `streetAnimals` pityが独立
- [ ] WC / blink対応
- [ ] ownership / Zukan / Home / Watch利用可能
- [ ] お世話中Home BGMが `BGM_streetAnimals`
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
- Asset: machine / Base / WC / blink / `BGM_streetAnimals`
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
