# MeMo アーキテクチャガイド

## 基準

- Repository: `shota-suzuki-eeen/MeMo`
- Branch: `main`
- 基準コミット: `448bb17895b60b4bcbd54690c327c8aa22bbadbe`
- 更新日: `2026-09-26`

このファイルは Codex が実装場所を把握するためのナビゲーション用です。
実際に変更する前には必ず現在の source を確認してください。

---

## Repository root

```text
AGENTS.md
SwiftDataOperationPolicy.md
docs/
MeMo.xcodeproj/
MeMo/
MeMoWatchComplication/
MeMoWidgetExtension.entitlements
```

現在は `MeMo.xcodeproj` も Git 管理されています。

Application source は `MeMo/` 配下です。

例:

- 旧: `Models/AppState.swift`
- 現在: `MeMo/Models/AppState.swift`

---

## Xcode project

`MeMo.xcodeproj`

管理対象:

- `project.pbxproj`
- shared schemes
- `Package.resolved`

現在確認済みの Target:

- `MeMo`
- `MeMoWatch Watch App`
- `MeMoWidgetExtension`
- `MeMoWatchComplicationExtension`
- `MeMoWatchComplicationExtensionExtension`

Target Membership や Build Settings は folder 構成だけで判断せず、`project.pbxproj` を確認してください。

---

## App entry point

`MeMo/Models/MeMoApp.swift`

主な責務:

- SwiftUI app entry
- global manager setup
- AdMob startup
- appearance preference
- SwiftData model container

現在の SwiftData registration:

```swift
.modelContainer(for: [
    AppState.self,
    TodayPhotoEntry.self,
    WorkoutSessionRecord.self
])
```

これはリリース済みユーザーとの永続化契約です。

---

## Core persistent model

### `AppState`

`MeMo/Models/AppState.swift`

主な内容:

- step currency
- HealthKit sync state
- cached today values
- fullness / care scheduling
- current / owned pets
- food inventory
- notification preference
- step-enjoy state

古い名称の backing property が意図的に残っている場合があります。

### `TodayPhotoEntry`

`MeMo/Models/TodayPhotoEntry.swift`

Metadata は SwiftData、画像本体は `Documents/memories/` に保存。

### `WorkoutSessionRecord`

`MeMo/Models/StepModels.swift`

Walking / workout history と routeData を保持。

---

## Feature state

`MeMo/Models/` 配下:

- `AppState+DesiredFood.swift`
- `AppState+Gacha.swift`
- `AppState+Happiness.swift`
- `AppState+LimitedHappinessRewardOnboarding.swift`
- `AppState+LiveActivity.swift`
- `AppState+MeMoWidget.swift`
- `AppState+Onboarding.swift`
- `EventManager.swift`
- `Halloween2026EventModels.swift`
- `Halloween2026EventStore.swift`
- `Halloween2026RewardGranting.swift`
- `WalkChallengeStore.swift`
- `FoodCatalog.swift`
- `WallpaperCatalog.swift`
- `StepRewardPolicy.swift`
- `MonetizationPolicy.swift`
- `SubscriptionAccessManager.swift`
- `PetMaster.swift`

リリース済み SwiftData schema を変えず、UserDefaults 側へ feature state を追加している実装が複数あります。

---

## Managers

`MeMo/Managers/`

- `AdMobManager.swift`
- `BGMManager.swift`
- `LocationTrackingManager.swift`
- `MeMoLiveActivityManager.swift`
- `WalkWeatherManager.swift`
- `WorkoutRouteStore.swift`

---

## ViewModels

`MeMo/ViewModels/`

- `MemoOnboardingViewModel.swift`
- `MemoriesViewModel.swift`
- `RootViewModel.swift`
- `StepViewModel.swift`
- `ZukanViewModel.swift`

---

## Main UI

`MeMo/Views/`

主な画面:

- Home
- Settings
- Gacha
- Fishing
- Shop
- Zukan
- Memories
- Walk
- Onboarding
- Live Activity
- Halloween event / run game

大きな View file に対して unrelated refactor を行わないでください。

---

## Widget / Live Activity

`MeMo/MeMoWidget/`

- `MeMoWidget.swift`
- `MeMoWidgetBundle.swift`
- `MeMoWidgetLiveActivity.swift`
- `Info.plist`

Widget entitlements:

`MeMoWidgetExtension.entitlements`

App Group:

`group.com.shota.CalPet`

Widget kind / shared key / App Group ID は互換性契約として扱ってください。

---

## Apple Watch

`MeMo/MeMoWatch Watch App/`

- `Models/`
- `ViewModels/`
- `Views/`

WatchConnectivity bridge が存在します。

Message / context key は versioned protocol として扱ってください。

---

## Complication

`MeMoWatchComplication/`

Complication source と `Info.plist` を含みます。

Target / Embed relationship を変更する場合は Xcode project を確認してください。

---

## Entitlements

Main app:

`MeMo/MeMo.entitlements`

Widget:

`MeMoWidgetExtension.entitlements`

Unrelated feature 変更で capability / signing を変更しないでください。

---

## Resource

Audio:

`MeMo/BGMs/`

Shader:

- `MeMo/Models/CircularLiquidShaders.metal`
- `MeMo/Models/PhotoPrintShaders.metal`

---

## Git 管理外 Asset

- `Assets.xcassets/`
- `MeMo/MeMoWatch Watch App/WatchAssets.xcassets/`
- `MeMo/MeMoWidget/Assets.xcassets/`
- `MeMo_material/`

Codex Cloud では実体が見えない可能性があります。

Asset task では source / project 上の参照名を維持し、実 Asset の確認が必要な場合はローカル Xcode 確認を要求してください。
