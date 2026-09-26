# Task: 全キャラクター獲得済みガチャに「complete」表示を追加

## Status

`Ready for Codex`

## Goal

各ガチャマシーンについて、そのmachine専用の排出キャラクターをすべて獲得済みの場合、Asset名 `complete` を該当ガチャマシーンの中央・前面へ大きくoverlay表示する。

`complete` はcharacter ownershipから都度導出し、永続化しない。

## Background

基準 `main` commit: `5d23e42c55fd07e46498450603e9477cd543dd18`

現行 `GachaView.swift` では `GachaDefinition.emissionCharacters` によりmachineごとの排出character一覧を取得できる。

また既存ownershipは `AppState.ownedPetIDs()` で取得できる。

したがってcomplete判定は:

- machineの `emissionCharacters` が空でない
- その全character IDが `ownedPetIDs()` に含まれる

という共通ロジックで導出する。

TASK_001〜003適用後は以下を同じ共通判定で扱う。

- `always`
- `food`
- `moja`
- `streetAnimals`
- `cyberpunkRacers`
- `hyakkaryouran`

TASK_004適用後はlocked machine自体が `availableGachas` に含まれないため、complete overlayもvisible machineに対してのみ表示する。

## Scope

### In scope

- machine単位のcomplete判定
- Asset `complete` overlay
- existing / new machineへの共通適用
- ownership変化後のUI更新
- locked machine filterとの整合
- overlayによる既存interaction阻害防止

### Out of scope

- complete reward追加
- complete後のGacha draw禁止
- ownership書換
- machine unlock書換
- probability変更
- Asset `complete` の加工
- Asset CatalogのGit管理化

## 最初に確認する既存実装

- `MeMo/Views/GachaView.swift`
  - `GachaDefinition`
  - `emissionCharacters`
  - `GachaCatalog`
  - `availableGachas`
  - machine image rendering
  - current machine selection
- `MeMo/Models/AppState.swift`
  - `ownedPetIDs()`
- `MeMo/Models/PetMaster.swift`
- TASK_001〜003のdedicated pools
- TASK_004のunlock / visible filtering

## Required assets

| Asset | Runtime name/path | Git 管理 | Notes |
|---|---|---|---|
| Complete overlay | `complete` | No | local `Assets.xcassets` に追加済み |

## Functional requirements

1. Current machineの `emissionCharacters` からcharacter IDsを取得する。
2. `emissionCharacters` が空ならcompleteにしない。
3. 全character IDが `ownedPetIDs()` に含まれる時のみcomplete。
4. 1体でも未所持なら非表示。
5. food / special item等、character以外の排出物はcomplete条件に含めない。
6. machineごとに独立判定。
7. TASK_001〜003のnew machineも同一ロジック。
8. 新規completion flag / UserDefaults key / SwiftData propertyを追加しない。
9. 最後の1体を取得した後、existing ownership state更新に追従してoverlayが表示される。
10. complete後もdraw可否・pity・probabilityは既存仕様を維持。
11. locked machineはvisible listにいないためoverlay判定対象にも表示対象にもならない。

## UI / interaction requirements

- `complete` はmachine imageの中央・前面へ大きめにoverlay。
- machine visualの上に表示する。
- `allowsHitTesting(false)` 等を利用し、overlay自体がtapを奪わないこと。
- 左右 `＜` / `＞` navigationを隠さない・tap不能にしない。
- Gacha button / probability / emission list button等の既存interactionを阻害しない。
- Machine切替時にcomplete状態も即時切替。
- Existing layoutを大きく作り変えない。

## Persistence requirements

### No new persistence

Complete stateはexisting ownershipから導出する。

追加禁止:

- completion UserDefaults key
- completion SwiftData property
- machine別complete flag

書換禁止:

- ownedPetIDs
- machine unlock state
- pity / guaranteed
- special item counts

## Existing-user compatibility

Update時点ですでにあるmachineの全characterを所持しているexisting userは、追加操作なしで `complete` が表示されること。

既存データをmigrationしない。

## Xcode / target impact

- affected target(s): `MeMo`
- `MeMo.xcodeproj` 変更必要?: 原則不要
- Target Membership change?: 不要
- entitlements / capability change?: 不要
- Swift Package change?: 不要
- ignored/local Asset dependency?: Yes (`complete`)

## 不要に変更してはいけない file

- persistence model
- gacha storage keys
- Pet IDs
- machine unlock store
- Gacha probability
- unrelated Watch / Widget code
- `project.pbxproj`（不要なら変更しない）

## Acceptance criteria

- [ ] 全character所持machineに `complete` 表示
- [ ] 1体でも未所持なら非表示
- [ ] empty poolはcomplete扱いしない
- [ ] non-character itemは条件外
- [ ] machineごとに独立
- [ ] existing 3 machine + new 3 machineへ共通適用
- [ ] locked machineは対象外
- [ ] overlayは中央・前面・大きめ
- [ ] overlayがinteractionを奪わない
- [ ] complete後もdraw可
- [ ] new persistenceなし
- [ ] existing user data維持

## Verification

### Codex Cloud

- `emissionCharacters` とowned IDs比較logic確認
- empty pool handling
- new machine共通適用
- locked machineとの整合
- persistence差分なし確認
- `git diff`
- usable Xcode toolchainがある場合のみbuild

### Local Xcode

- affected scheme: `MeMo`
- Simulator / device:
  - 未complete
  - 最後の1体取得前
  - 最後の1体取得後
  - machine切替
  - complete後のdraw
  - overlay上でもbutton操作可能
- Asset: `complete`
- signing / capability: 変更なし

### Upgrade test

Existing user相当で、あるmachineの全characterを既に所持した状態からupdateし、追加migrationなしで `complete` が表示されることを確認する。

## Codex final report

- changed files
- implementation summary
- persistence impact
- Xcode / target impact
- Cloud verification
- local Xcode verification required
- migration / upgrade verification
- remaining risks
