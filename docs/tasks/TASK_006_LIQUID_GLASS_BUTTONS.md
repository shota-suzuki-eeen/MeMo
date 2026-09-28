# Task: 標準ボタン群の Liquid Glass 化

## Status

`Ready for Codex`

## Goal

アセット画像そのものを見た目として使用していない MeMo の標準ボタン群を、iOS 26 のネイティブ Liquid Glass 表現へ統一する。

既存ボタンが持つ色・強調度・disabled/loading・サイズ・操作意味を維持しつつ、特にリワード広告視聴を伴う操作は「広告ボタン」であることが一目で分かる赤系の Liquid Glass とする。

## Background

MeMo の iOS Deployment Target は現在 `26.0` であり、iOS 26 の Liquid Glass API を前提にできる。

現状は画面ごとに以下のようなボタン表現が混在している。

- `.buttonStyle(.plain)`
- `.buttonStyle(.bordered)`
- `.buttonStyle(.borderedProminent)`
- `RoundedRectangle` / `Capsule` + `background` を使った独自標準ボタン
- 色付きの標準ボタン
- リワード広告導線の赤系ボタン
- Asset Image 自体をタップ対象にしたゲーム固有ボタン

今回の対象は「標準UIとして描画されているボタン」であり、Assetそのものがボタン外観になっているものや、透明なhit area、ゲーム固有の画像操作UIを機械的に Glass 化してはいけない。

## Scope

### In scope

- `MeMo` target の SwiftUI 画面にある、Asset非依存の標準ボタンを洗い出す。
- Text / Label / SF Symbol / Shape背景などで構成される標準ボタンを Liquid Glass 化する。
- 既存の色味が意味を持つ場合、その意味色を Glass の tint として引き継ぐ。
- 既存の primary / prominent 相当の強調度を Liquid Glass 側でも維持する。
- リワード広告を実際に視聴する操作は、明確な赤系 tint の prominent Glass とする。
- disabled / loading / progress / accessibility / tap area / animation / haptics / SE を維持する。
- ライトモード / ダークモード双方で文字・アイコンの可読性を確保する。
- iPhone / 現在の iPad phone-canvas 表示でレイアウトを維持する。
- 必要であれば重複を減らすための小さな共通 ViewModifier / ButtonStyle helper を追加する。

### Out of scope

- Asset Image 自体を見た目として使用しているボタンの差し替え。
- キャラクター、ガチャマシーン、釣り、イベント等のゲームアセット変更。
- Liquid Glass 化を理由とした画面レイアウトの全面変更。
- Navigation構造の変更。
- 広告ロジック、課金ロジック、ガチャ確率、報酬ロジックの変更。
- 保存データ・UserDefaults・SwiftDataの変更。
- iOS 25以前向けfallback UIの新規実装。
- Asset Catalogへの新規素材追加。

## 最初に確認する既存実装

現在の `main` を使用する。

最低限以下を確認すること。

- `MeMo.xcodeproj/project.pbxproj`
  - `IPHONEOS_DEPLOYMENT_TARGET = 26.0`
- `MeMo/Views/`
  - `HomeView.swift`
  - `GachaView.swift`
  - `FishingView.swift`
  - `SettingsView.swift`
  - `SleepModePopupView.swift`
  - `WalkStartPopupView.swift`
  - `WalkResultOverlayView.swift`
  - `WalkView.swift`
  - `ZukanView.swift`
  - `ShopView.swift`
  - `RootView.swift`
  - Halloween / event系View
  - `Components/` 配下
- `MeMo/Managers/AdMobManager.swift`
- `MeMo/Models/MonetizationPolicy.swift`

実装前に `Button(`、`.buttonStyle(`、`.background(`、`.tint(`、`RoundedRectangle`、`Capsule`、rewarded ad呼び出し箇所を検索して対象一覧を作ること。

### 対象判定ルール

以下は原則として対象。

- Text / Label / SF Symbol が主表示のButton
- `.bordered` / `.borderedProminent`
- 標準操作のために Shape + Color で独自描画しているButton
- 既存の色が状態・意味を表す標準Button

以下は原則として対象外。

- `Image("...")` のAsset自体がボタン外観を構成するもの
- キャラクターやアイテムAssetへのtap gesture
- invisible / transparent hit target
- close領域等で `.plain` を使っているだけのもの
- SpriteKit / game scene 内の操作UI
- 独自ビジュアルを維持すること自体が仕様のイベント・ゲームUI

`.plain` であることだけを理由に一括変換しないこと。

## Required assets

| Asset | Runtime name/path | Git 管理 | Notes |
|---|---|---|---|
| なし | - | - | 新規Assetを追加しない |

注意:

- main `Assets.xcassets` は Git 管理外。
- 今回は Asset Catalog を変更しない。
- 既存Assetボタンは対象外とする。
- ignored/local Asset を理由に既存UIを推測で置換しない。

## Functional requirements

1. iOS 26 のネイティブ SwiftUI Liquid Glass APIを使用する。
2. Liquid Glassを独自の `.thinMaterial` / blur / opacity の組み合わせで擬似再現しない。
3. 標準ボタンは原則 `.glass` 相当を使用する。
4. 既存の prominent / primary action は `.glassProminent` 相当を優先する。
5. 既存で色指定がある標準ボタンは、その意味色を `.tint(...)` 等で引き継ぐ。
6. 色指定が単なる旧デザイン上の偶然か、意味色かを既存UI・処理から確認して判断する。
7. リワード広告視聴を実際に開始するボタンは赤系 tint を維持し、通常ボタンと視覚的に明確に区別する。
8. リワード広告ボタンは原則 prominent Glass + red tint とする。
9. 広告一時停止モード、tutorial、developer mode等で実際には広告を視聴しない状態では、既存の状態別意味を壊さない。広告を見ない操作まで誤って「広告視聴」を示す表現へ固定しないこと。
10. `AdMobManager` / `MonetizationPolicy` の判定ロジック自体は変更しない。
11. 既存Button actionの処理内容を変更しない。
12. 既存の `.disabled(...)` 条件を維持する。
13. 既存のローディングスピナーや「読み込み中」表示を維持する。
14. 既存のSE / haptic呼び出しを維持する。
15. 既存Buttonのframe / padding / corner placementを必要以上に変更しない。
16. Liquid Glass化によりtap targetが小さくならないこと。
17. ライトモード・ダークモードでText / Symbolのコントラストを確認する。
18. tintを付けたButtonでもLiquid Glassの透明感が失われない実装にする。
19. 同一用途の標準ボタンに同じGlass方針を適用する。
20. ただし、共通化のための大規模refactorは行わない。
21. Asset Imageを使用する既存ボタンは変更しない。
22. `MeMo.xcodeproj` を不要に変更しない。
23. UserDefaults / SwiftData / Documents / App Group / WatchConnectivityには一切変更を加えない。

## UI / interaction requirements

- 通常操作:
  - standard Liquid Glass
- 強調された主要操作:
  - prominent Liquid Glass
- リワード広告視聴操作:
  - prominent Liquid Glass
  - 赤系 tint
  - Text / icon が十分読めること
- 既存で青・緑・オレンジ等の意味色を持つButton:
  - Liquid Glass化後も意味色を維持する
- disabled:
  - 操作不能であることが明確
  - tintが強すぎてenabledに見えないようにする
- loading:
  - 現在のspinner / title切替を維持
- Asset button:
  - 見た目・サイズ・位置を変更しない

## Persistence requirements

### No new persistence

保存状態は変更しない。

以下を追加・変更しないこと。

- SwiftData schema
- UserDefaults / `@AppStorage` key
- Documents
- App Group shared defaults
- WatchConnectivity payload
- StoreKit state
- Gacha / Fishing / Happiness state

## Existing-user compatibility

UI表示のみの変更とする。

既存ユーザーが保持している以下を変更しないこと。

- `AppState`
- gacha ownership / pity / guaranteed / unlocked machine
- happiness reward state
- fishing state
- photos
- walk state
- onboarding state
- appearance setting
- AdMob temporary-pause state
- Widget / Watch shared state

## Xcode / target impact

- affected target(s):
  - `MeMo`
- `MeMo.xcodeproj` 変更必要?:
  - 原則不要
- Target Membership change?:
  - 原則不要
- entitlements / capability change?:
  - なし
- Swift Package change?:
  - なし
- ignored/local Asset dependency?:
  - 新規なし
  - 既存Assetボタンは変更対象外

新規helper fileを追加する場合、file-system-synchronized groupの現在構成を確認し、不要な `project.pbxproj` 編集をしないこと。

## 不要に変更してはいけない file

- `MeMo/Models/AppState.swift`
- `MeMo/Models/AppState+Gacha.swift`
- `MeMo/Models/AppState+Happiness.swift`
- `MeMo/Views/FishingView.swift` 内のFishingStore persistence仕様
- Widget / Watch / Complication関連
- entitlements
- StoreKit / monetization policyの意味
- Asset Catalog

View fileは対象Buttonの表示変更に必要な範囲のみ変更する。

## Acceptance criteria

- [ ] Asset非依存の標準ボタン群がiOS 26 native Liquid Glassで表示される
- [ ] Asset Imageを外観に使うボタンは変更されていない
- [ ] `.plain` を機械的に全置換していない
- [ ] 既存の意味色が維持されている
- [ ] リワード広告視聴ボタンが明確な赤系Glassで識別できる
- [ ] 広告を伴わない状態を誤って広告ボタンとして表示しない
- [ ] primary actionの強調度が維持される
- [ ] disabled / loading / SE / haptic / actionが維持される
- [ ] ライト / ダーク双方で可読性がある
- [ ] iPhone / iPad phone-canvasで主要Buttonのlayoutが崩れない
- [ ] new persistenceがない
- [ ] unrelated behaviorが変わらない
- [ ] project file changeが必要最小限
- [ ] ignored/local Asset requirementが明記されている
- [ ] Cloudでbuildできない場合、`MeMo` schemeをlocal Xcodeで確認する

## Verification

### Codex Cloud

- `rg -n 'Button\(|buttonStyle|tint\(|RoundedRectangle|Capsule' MeMo/Views`
- rewarded-ad導線を `AdMobManager` / `MonetizationPolicy` 参照と照合する
- 変更対象Buttonと対象外Buttonの一覧を最終報告に含める
- `git diff --check`
- persistence関連差分がないことを確認
- `git diff -- MeMo.xcodeproj/project.pbxproj`
- usable Xcode toolchain がある場合のみ `MeMo` scheme build

### Local Xcode

- affected scheme:
  - `MeMo`
- Simulator / device:
  - iPhone 17 Pro Simulator
  - iPhone 15 実機
  - iPad Air 11 (M3) Simulator の phone-canvas
- 確認:
  - Home
  - Gacha
  - Fishing
  - Sleep
  - Walk
  - Settings
  - Zukan
  - Shop
  - event系画面
- Light / Dark
- rewarded ad ready / loading / unavailable / temporary-pause状態
- disabled state
- tap area
- Asset buttonが変わっていないこと

### Upgrade test

既存ユーザーデータを保持した状態でアップデートし、画面表示だけがLiquid Glass化され、保存状態・操作結果が変わらないことを確認する。

## Codex final report

Codex は以下を報告すること。

- changed files
- implementation summary
- Liquid Glass対象Button一覧
- 対象外としたButtonと理由
- rewarded-ad button styling
- preserved tint / semantic colors
- persistence impact
- Xcode / target impact
- Cloud verification
- local Xcode verification required
- migration / upgrade verification
- remaining risks
