# MeMo Architecture Guide

## Snapshot

This guide was prepared from GitHub `main` at commit `92563441704cf11712b17705b77b8b18f83c430f` on 2026-09-26.

It is a navigation document for Codex. It is not a substitute for reading the implementation before changing it.

---

## Application entry point

`Models/MeMoApp.swift`

Responsibilities visible in the current source:

- SwiftUI application entry
- global `BGMManager`
- AdMob startup
- iPad phone-canvas adaptation
- appearance preference via `@AppStorage`
- SwiftData model container registration

Current SwiftData registration:

```swift
.modelContainer(for: [
    AppState.self,
    TodayPhotoEntry.self,
    WorkoutSessionRecord.self
])
```

This list is a persistence contract for released users.

---

## Core persistent models

### `AppState`

`Models/AppState.swift`

Central application state, including:

- step currency / pending step state
- HealthKit sync timestamps
- fixed goal backing storage
- cached today values
- fullness state
- feed / bath / toilet scheduling state
- toilet-poop encoded state
- current pet and owned pet IDs
- notification preferences
- food inventory
- favorite/reveal state
- step-enjoy state and logs

Important: several backing property names intentionally preserve older terminology.

### `TodayPhotoEntry`

`Models/TodayPhotoEntry.swift`

Stores memory-photo metadata while the image itself is stored in `Documents/memories/`.

### `WorkoutSessionRecord`

`Models/StepModels.swift`

Stores walking/workout history and JSON-encoded route points.

---

## Feature-state extensions and stores

### AppState extensions

- `AppState+DesiredFood.swift`
- `AppState+Gacha.swift`
- `AppState+Happiness.swift`
- `AppState+LimitedHappinessRewardOnboarding.swift`
- `AppState+LiveActivity.swift`
- `AppState+MeMoWidget.swift`
- `AppState+Onboarding.swift`

A recurring design pattern is to place new feature state in UserDefaults rather than reshaping the released SwiftData model.

### Feature stores / policies

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

---

## Managers

`Managers/`

- `AdMobManager.swift` — ad loading/display state and temporary failure pause state
- `BGMManager.swift` — BGM / effect preferences and playback
- `LocationTrackingManager.swift` — location tracking
- `MeMoLiveActivityManager.swift` — ActivityKit lifecycle/settings
- `WalkWeatherManager.swift` — weather integration for walk flow
- `WorkoutRouteStore.swift` — persistence helper for workout routes

---

## ViewModels

`ViewModels/`

- `MemoOnboardingViewModel.swift`
- `MemoriesViewModel.swift`
- `RootViewModel.swift`
- `StepViewModel.swift`
- `ZukanViewModel.swift`

---

## Main UI areas

`Views/`

The repository currently contains views for:

- Home
- Settings
- Gacha
- Fishing
- Shop
- Zukan / character catalog
- Memories / daily photos
- Walk start, walk flow, result, route capture/map
- step activity dashboard
- sleep mode
- onboarding/tutorial
- character sprite/video rendering
- Live Activity settings/observation
- Halloween 2026 event, exchange, reward, and SpriteKit run game
- reusable event/media/memory/map components

`HomeView.swift`, `FishingView.swift`, `CameraStyleView.swift`, and `GachaView.swift` are comparatively large files. Prefer targeted edits instead of opportunistic refactoring.

---

## Widget / Live Activity

`MeMoWidget/`

- `MeMoWidget.swift`
- `MeMoWidgetBundle.swift`
- `MeMoWidgetLiveActivity.swift`
- target `Info.plist`

Shared app-to-widget state is also written from app-side bridge code.

Current code references App Group:

`group.com.shota.CalPet`

Treat the identifier, shared keys, and Widget kinds as compatibility contracts.

---

## Apple Watch

`MeMoWatch Watch App/`

### Models
- `MeMoWatchApp.swift`
- `MeMoWatchBridgeInstaller.swift`
- `MeMoWatchConnectivityBridge.swift`
- `MeMoWatchDynamicAssetSupport.swift`

### ViewModel
- `MeMoWatchHomeViewModel.swift`

### Views
- `MeMoWatchCharacterSpriteView.swift`
- `MeMoWatchHomeView.swift`

The Watch implementation contains a substantial WatchConnectivity bridge. Message/context keys must be treated like a versioned protocol.

---

## System frameworks / capabilities visible in source

- SwiftUI
- SwiftData
- UIKit
- SpriteKit
- ActivityKit / WidgetKit
- HealthKit
- WeatherKit
- CoreLocation / Map-related APIs
- WatchConnectivity
- AV/media playback
- Google Mobile Ads
- StoreKit-oriented subscription abstraction

The committed `MeMo.entitlements` currently declares:

- APNs environment (`development`)
- HealthKit
- WeatherKit

Do not alter signing/capabilities as a side effect of feature work.

---

## Resource layout

### Audio

`BGMs/` contains application BGM and effect MP3 files.

### Shaders

- `Models/CircularLiquidShaders.metal`
- `Models/PhotoPrintShaders.metal`

### Asset caveat

The GitHub snapshot does not include a complete asset/project representation. Watch and Widget asset catalogs are explicitly gitignored. Always inspect the local Xcode working copy before adding or renaming resources.
