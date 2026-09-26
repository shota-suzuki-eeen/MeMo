# Task: 幸せ度レベル上限を40から75へ解放

## Status

`Ready for Codex`

## Goal

現在の幸せ度レベル上限 `40` を `75` へ変更し、レベル41〜75まで正常に進行・保存・表示できるようにする。

レベル数値Assetは既存規則どおり、レベル `41` → Asset名 `41` のように対応する。
`41`〜`75` はローカルの `Assets.xcassets` に追加済み。

## Background

基準 `main` commit: `5d23e42c55fd07e46498450603e9477cd543dd18`

現行 `MeMo/Models/AppState+Happiness.swift` では:

- `happinessMaxPointsPerLevel = 100`
- `happinessMaxLevel = 40`
- `happinessLevel` のread/writeが `happinessMaxLevel` でclampされる
- レベル上限到達時のpoint処理も `happinessMaxLevel` に依存する

`HappinessStomachGauge` はレベル番号を文字列化してAsset名として利用する。
Watch側にもlevel-number Assetの前提・dynamic transfer処理があるため、40固定の前提がないか確認する。

今回の変更は保存形式のmigrationではなく、既存UserDefaults形式を維持した上限拡張とする。

## Scope

### In scope

- `AppState.happinessMaxLevel` を75へ変更
- 40→41、74→75、75上限の進行確認
- level表示Asset `41`〜`75` の参照確認
- iPhone / Watch / Widget / Live Activity / notification判定で上限40前提がないか確認
- 幸せ度文脈のhard-coded `40` を検索し、「最大レベル40」を意味する箇所のみ修正
- コメント・説明で `0...40` 等の旧上限を固定記載している箇所が実装仕様を誤解させる場合は更新

### Out of scope

- 1レベルあたり必要point変更
- 幸せ度の増減速度変更
- レベルアップ報酬内容変更（`TASK_004_LEVEL_REWARD_V2.md`）
- 既存UserDefaults key rename
- 既存character ID変更
- Asset CatalogのGit管理化

## 最初に確認する既存実装

- `MeMo/Models/AppState+Happiness.swift`
  - `happinessMaxLevel`
  - `happinessLevel`
  - `increaseHappinessOnePoint`
  - level / point clamp
- `MeMo/Models/HappinessStomachGauge.swift`
  - level number Asset名生成
- `MeMo/Views/HomeView.swift`
- `MeMo/Managers/AdMobManager.swift`
  - claimable reward判定でのmax level参照
- `MeMo/MeMoWatch Watch App/Views/MeMoWatchHomeView.swift`
  - level badge Asset前提
- `MeMo/MeMoWatch Watch App/Models/MeMoWatchDynamicAssetSupport.swift`
- `MeMo/MeMoWatch Watch App/Models/MeMoWatchConnectivityBridge.swift`
  - level-number image transfer
- `MeMo/Models/AppState+MeMoWidget.swift`
- `MeMo/Models/AppState+LiveActivity.swift`
- repository全体の幸せ度文脈におけるhard-coded `40`

## Required assets

| Asset | Runtime name/path | Git 管理 | Notes |
|---|---|---|---|
| レベル41〜75数値画像 | `41`〜`75` | No | main `Assets.xcassets` に追加済み |
| Watchで必要になるlevel画像 | 既存dynamic asset仕様 | 一部No | iPhone→Watch転送経路を確認 |

注意:

- main `Assets.xcassets` はGit管理外
- Codex Cloudで実Assetが見えない場合もplaceholderを作らない
- Asset名は `"41"`〜`"75"` をそのまま使用

## Functional requirements

1. レベル40から41へ正常に上がる。
2. 最大75まで上がる。
3. 75到達後は既存の「最大レベル時」の処理を75に対して適用する。
4. 既存レベル0〜40の保存値と挙動を維持する。
5. レベル41〜75の表示はAsset名 `"41"`〜`"75"` を利用する。
6. レベル40で保存済みのユーザーをresetせず、そのまま41以降へ進める。
7. 上限値と無関係な数値 `40` は変更しない。
8. Watchへlevel-number imageを動的転送する既存仕様が41〜75でも動作すること。

## UI / interaction requirements

- Homeの幸せ度表示が41〜75で既存designのまま表示される。
- Watchのlevel表示も既存designを維持する。
- Layout / gauge / animationのredesignは行わない。

## Persistence requirements

### No new persistence

既存の保存形式を維持する。

変更禁止:

- `memo.happiness.level`
- `memo.happiness.point`
- その他existing `memo.happiness.*` key

上限変更だけを理由に新SwiftData property / migration keyを追加しない。

## Existing-user compatibility

維持する可能性があるstate:

- happiness level 0〜40
- level40時のpoint
- existing claimed reward levels
- reward-character別のhappiness storage context
- sleep mode state

既存値を補正目的でresetしない。

## Xcode / target impact

- affected target(s): `MeMo`, `MeMoWatch Watch App`; Widget / Live Activityは参照がある場合
- `MeMo.xcodeproj` 変更必要?: 原則不要
- Target Membership change?: 不要
- entitlements / capability change?: 不要
- Swift Package change?: 不要
- ignored/local Asset dependency?: Yes

## 不要に変更してはいけない file

- SwiftData schema
- Gacha reward定義
- character ID / Asset mapping
- `project.pbxproj`（不要なら変更しない）
- Asset Catalog構造

## Acceptance criteria

- [ ] max levelが75
- [ ] 40→41成功
- [ ] 74→75成功
- [ ] 75を超えない
- [ ] 41〜75のlevel Assetが既存規則で解決される
- [ ] Watch側のlevel表示/転送が75まで対応
- [ ] existing `memo.happiness.*` key変更なし
- [ ] existing user data維持
- [ ] unrelated behavior変更なし

## Verification

### Codex Cloud

- `happinessMaxLevel` 全参照検索
- hard-coded `40` の幸せ度文脈検索
- Watch dynamic asset / connectivityのlevel image処理確認
- UserDefaults key差分確認
- `git diff`
- usable Xcode toolchainがある場合のみbuild

### Local Xcode

- affected scheme: `MeMo`, `MeMoWatch Watch App`
- Simulator / device: 40→41、74→75、75上限
- Asset: `41`〜`75`
- Watch: 41以上のlevel-number表示
- signing / capability: 変更なし

### Upgrade test

既存 `memo.happiness.level = 40` と既存pointを保持した状態からupdateし、データを失わず41へ進めることを確認する。

## Codex final report

- changed files
- implementation summary
- persistence impact
- Xcode / target impact
- Cloud verification
- local Xcode verification required
- migration / upgrade verification
- remaining risks
