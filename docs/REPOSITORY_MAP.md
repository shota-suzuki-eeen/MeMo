# Repository Map

Audited repository: `shota-suzuki-eeen/MeMo`  
Branch: `main`  
Snapshot: `92563441704cf11712b17705b77b8b18f83c430f`  
Date: `2026-09-26`

The GitHub recursive tree was inspected as the source-of-truth for this map.

---

## Root

```text
.gitignore
BGMs/
Info.plist
Managers/
MeMo.entitlements
MeMoWatch Watch App/
MeMoWidget/
Models/
Movie/
SwiftDataOperationPolicy.md
ViewModels/
Views/
```

No `.xcodeproj` / `.xcworkspace` is present in the audited GitHub tree.

No main application asset catalog is present in the audited GitHub tree.

`.gitignore` explicitly excludes Watch and Widget asset catalogs, so the local Xcode working copy must be inspected before resource work.

---

## Managers

```text
Managers/
├── AdMobManager.swift
├── BGMManager.swift
├── LocationTrackingManager.swift
├── MeMoLiveActivityManager.swift
├── WalkWeatherManager.swift
└── WorkoutRouteStore.swift
```

---

## Models

```text
Models/
├── AdBannerView.swift
├── AppState+DesiredFood.swift
├── AppState+Gacha.swift
├── AppState+Happiness.swift
├── AppState+LimitedHappinessRewardOnboarding.swift
├── AppState+LiveActivity.swift
├── AppState+MeMoWidget.swift
├── AppState+Onboarding.swift
├── AppState.swift
├── CaptureLocationManager.swift
├── CircularLiquidShaders.metal
├── EventManager.swift
├── FoodCatalog.swift
├── Halloween2026EventModels.swift
├── Halloween2026EventStore.swift
├── Halloween2026RewardGranting.swift
├── HappinessStomachGauge.swift
├── Haptics.swift
├── HealthKitManager.swift
├── MeMoApp.swift
├── MeMoCareActivityAttributes.swift
├── MemoOnboardingNotifications.swift
├── MemoOnboardingScreen.swift
├── MonetizationPolicy.swift
├── Notifications.swift
├── PetMaster.swift
├── PhotoPrintShaders.metal
├── StepModels.swift
├── StepRewardPolicy.swift
├── SubscriptionAccessManager.swift
├── TodayPhotoEntry.swift
├── WalkChallengeStore.swift
├── WallpaperCatalog.swift
└── WidgetPetSnapshot.swift
```

---

## ViewModels

```text
ViewModels/
├── MemoOnboardingViewModel.swift
├── MemoriesViewModel.swift
├── RootViewModel.swift
├── StepViewModel.swift
└── ZukanViewModel.swift
```

---

## Views

```text
Views/
├── CameraStyleView.swift
├── CharacterSpriteView.swift
├── Components/
│   ├── CharacterVideoPlayerView.swift
│   ├── EventUIComponents.swift
│   ├── LoopingVideoPlayer.swift
│   ├── MemoryPhotoCardView.swift
│   └── WorkoutRouteMapView.swift
├── DayPhotosView.swift
├── DesiredFoodThoughtButton.swift
├── FishingView.swift
├── GachaView.swift
├── Halloween2026EventView.swift
├── Halloween2026ExchangeView.swift
├── Halloween2026RewardView.swift
├── HalloweenRunGameScene.swift
├── HalloweenRunGameView.swift
├── HomeView.swift
├── MeMoLiveActivitySettingsSection.swift
├── MeMoLiveActivityStateObserver.swift
├── MemoIPadPresentedPhoneCanvas.swift
├── MemoLimitedHappinessRewardIntroOverlay.swift
├── MemoOnboardingHomeHooks.swift
├── MemoOnboardingIntegrationNotes.swift
├── MemoOnboardingRootModifier.swift
├── MemoTeacherOnboardingView.swift
├── MemoTutorialGachaView.swift
├── MemoTutorialZukanSwitchView.swift
├── MemoriesView.swift
├── MetalCircularLiquidLayer.swift
├── RootView.swift
├── RouteCameraCaptureView.swift
├── SettingsView.swift
├── ShopView.swift
├── SleepModePopupView.swift
├── StepActivityDashboardView.swift
├── StepGainPopupView.swift
├── WalkResultOverlayView.swift
├── WalkStartPopupView.swift
├── WalkView.swift
├── WorkoutRouteLineOverlayView.swift
└── ZukanView.swift
```

---

## Apple Watch

```text
MeMoWatch Watch App/
├── Models/
│   ├── MeMoWatchApp.swift
│   ├── MeMoWatchBridgeInstaller.swift
│   ├── MeMoWatchConnectivityBridge.swift
│   └── MeMoWatchDynamicAssetSupport.swift
├── ViewModels/
│   └── MeMoWatchHomeViewModel.swift
└── Views/
    ├── MeMoWatchCharacterSpriteView.swift
    └── MeMoWatchHomeView.swift
```

---

## Widget / Live Activity

```text
MeMoWidget/
├── Info.plist
├── MeMoWidget.swift
├── MeMoWidgetBundle.swift
└── MeMoWidgetLiveActivity.swift
```

---

## Movie

```text
Movie/
└── WidgetPetSnapshotPublisher.swift
```

---

## Audio

Verified audio names in `BGMs/` include:

```text
BGM_cyberpunk.mp3
BGM_fishing.mp3
BGM_food.mp3
BGM_gacha.mp3
BGM_main.mp3
BGM_moja.mp3
BGM_street.mp3
BGM_zukan.mp3
effect_button.mp3
effect_food.mp3
effect_gacha.mp3
effect_gacha_do.mp3
effect_touch.mp3
effect_wc.mp3
```

---

## Navigation notes for Codex

When implementing a task, start from the feature owner rather than `HomeView.swift` by default.

Examples:

- gacha persistence/logic → `Models/AppState+Gacha.swift`
- gacha presentation → `Views/GachaView.swift`
- happiness → `Models/AppState+Happiness.swift`
- walk-session persistence → `Models/WalkChallengeStore.swift`, `Models/StepModels.swift`
- route save → `Managers/WorkoutRouteStore.swift`
- fishing → `Views/FishingView.swift`
- Halloween event state → `Models/Halloween2026EventStore.swift`
- Halloween run game → `Views/HalloweenRunGameScene.swift`, `Views/HalloweenRunGameView.swift`
- memories → `Models/TodayPhotoEntry.swift`, `ViewModels/MemoriesViewModel.swift`, memory views
- Watch → `MeMoWatch Watch App/`
- Widget/Live Activity → `MeMoWidget/` plus app-side bridge files

Before editing, search references to the relevant type/key/resource across the whole local Xcode project.
