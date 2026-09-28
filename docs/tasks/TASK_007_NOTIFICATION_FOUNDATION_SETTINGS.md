# Task: Local Notification 基盤・通知設定・通知タップ遷移

## Status

`Ready for Codex`

## Goal

MeMo にローカル通知の共通基盤を追加し、ユーザーが通知を全体・個別に設定できるようにする。

通知許可は mandatory onboarding 完了後に初めてHomeへ到達したタイミングで、iOS側が `.notDetermined` の場合のみ一度要求する。

通知をタップした場合は通知種別に応じて Home / Gacha / Fishing へ遷移できるようにする。

このTaskでは通知の「6種類の発火タイミングそのもの」は実装せず、TASK_008で利用する安全な基盤・設定・route contractを作る。

## Background

現在の `AppState` には旧MVP由来の以下SwiftData保存プロパティが残っている。

- `notifyFeed`
- `notifyBath`
- `notifyToilet`

現行コードでは新しい通知システムの設定として使用しない。

MeMoはすでにリリース済みであり、`AppState` は `@Model` であるため、この3プロパティを削除・rename・型変更するとSwiftData schema互換性に影響する可能性がある。

したがって以下3プロパティは「Legacy / runtime未使用」であることをコメントと永続化ドキュメントに明記したうえで、そのまま残す。

新しい通知設定はSwiftDataへ追加せず、additiveなUserDefaultsで管理する。

Local Notificationを使用するため、Remote Push / APNs backend / Push Notifications capabilityは導入しない。

## Scope

### In scope

- `UserNotifications` を使ったLocal Notification共通Manager / Coordinator。
- 通知カテゴリ定義。
- 通知route定義。
- 通知設定UserDefaults。
- Settings画面の通知設定UI。
- 全体ON/OFF。
- 6種類の個別ON/OFF。
- デフォルトは全設定ON。
- OS通知authorization statusの表示。
- iOS通知設定がOFFの場合の「端末設定を開く」導線。
- onboarding完了後、初Home到達時のpermission request。
- notification response tapから Home / Gacha / Fishing へのroute。
- foreground notification presentation方針。
- `notifyFeed / notifyBath / notifyToilet` のLegacy明記。
- `docs/PERSISTENCE_COMPATIBILITY.md` 更新。
- TASK_008がschedule/cancel/reconcileを呼び出せるAPI。

### Out of scope

- 満腹度0等の実イベントから通知をscheduleする処理。
- 釣りカゴ満杯日時の予測。
- Gacha時刻通知のschedule。
- Remote Push / APNs。
- backend / DB。
- Push Notifications capability。
- notification service extension。
- badge count管理。
- Watch通知独自実装。
- Widget通知。
- `notifyFeed / notifyBath / notifyToilet` の削除・migration・再利用。

## 最初に確認する既存実装

現在の `main` を使用する。

- `AGENTS.md`
- `SwiftDataOperationPolicy.md`
- `docs/PERSISTENCE_COMPATIBILITY.md`
- `MeMo/Models/AppState.swift`
  - `@Model`
  - `notifyFeed`
  - `notifyBath`
  - `notifyToilet`
- `MeMo/Models/MeMoApp.swift`
  - app root
  - environment object
  - scene lifecycle
- `MeMo/Views/RootView.swift`
  - onboarding / root flow
- `MeMo/Views/HomeView.swift`
  - Home表示
  - `showGachaView`
  - `showFishingView`
  - existing `.fullScreenCover`
- `MeMo/Views/SettingsView.swift`
- `MeMo/Views/MemoOnboardingHomeHooks.swift`
- `MeMo/Models/AppState+Onboarding.swift`
- `MeMo/Models/MemoOnboardingNotifications.swift`
- `MeMo.xcodeproj/project.pbxproj`
- relevant `Info.plist` / entitlements

実装前にmandatory onboarding完了判定の現在の正規API / 保存keyを確認し、新しい重複状態を作らないこと。

## Required assets

| Asset | Runtime name/path | Git 管理 | Notes |
|---|---|---|---|
| なし | - | - | 通知設定に新規画像Assetを要求しない |

## Functional requirements

1. `UNUserNotificationCenter` を使用したLocal Notification基盤を実装する。
2. Remote Pushは使用しない。
3. APNs device token登録を実装しない。
4. Push Notifications capabilityを追加しない。
5. notification permissionは `.alert` と `.sound` を基本とし、badgeは今回使用しない。
6. mandatory onboarding完了後、Homeへ到達したタイミングでauthorization statusを確認する。
7. authorization statusが `.notDetermined` の場合のみ `requestAuthorization` を実行する。
8. OSがすでに `.authorized` / `.provisional` / `.denied` 等の場合、不要な再要求をしない。
9. 「一度だけ」の判定は可能な限りOSのauthorization statusを正とし、不要な独自prompt済みflagを追加しない。
10. permission拒否でもアプリ内の通知個別設定値は変更しない。
11. permission拒否時も全通知設定のデフォルトONを維持する。
12. Settings画面でOS authorization statusを表示できるようにする。
13. OS側通知が無効の場合、「端末設定を開く」操作を提供する。
14. `UIApplication.openSettingsURLString` 等、現在のiOSで適切な設定導線を使用する。
15. アプリがforegroundのときにMeMo通知が発火した場合、設定が有効ならsystem banner/list/soundとして認識できるよう `UNUserNotificationCenterDelegate` を構成する。
16. 通知タップを受け取るdelegateを構成する。
17. cold launch時のnotification tap routeをUI準備完了まで失わないこと。
18. notification tap routeは以下とする。
    - `fullnessZero` -> Home
    - `toilet` -> Home
    - `sleepEnded` -> Home
    - `gachaFreeTen` -> Gacha
    - `fishingTimeBoostEnded` -> Fishing
    - `fishingBasketFull` -> Fishing
19. Gacha / Fishing routeは既存Homeのpresentation構造を再利用する。
20. 現在の `HomeView` にある `showGachaView` / `showFishingView` と `.fullScreenCover` の意味を壊さない。
21. routingのためだけに別のGacha / Fishing画面インスタンス管理方式を並立させない。
22. mandatory onboarding未完了中にrouteでtutorialを破壊しない。
23. notification payload `userInfo` に安定したroute / kind識別子を持たせる。
24. route識別子はコード内で一元定義し、magic stringを各画面に散在させない。
25. notification request identifierもTASK_008から参照できる形で一元定義する。
26. manager APIはcategory単位で `schedule / cancel / cancelAll / authorization refresh` が可能な構造にする。
27. TASK_008が既存状態からreconcileできるAPIを用意する。
28. notification managerがSwiftData `AppState` を新しい保存先として使わないこと。

## Notification categories

以下6種類を固定カテゴリとして扱う。

| Kind | Settings表示名 | Route |
|---|---|---|
| `fullnessZero` | 満腹度が0 | Home |
| `toilet` | トイレ | Home |
| `sleepEnded` | おやすみ終了 | Home |
| `gachaFreeTen` | 無料10回ガチャ | Gacha |
| `fishingTimeBoostEnded` | タイムブースト終了 | Fishing |
| `fishingBasketFull` | 釣りカゴ満杯 | Fishing |

## UI / interaction requirements

Settingsに独立した「通知」sectionを追加する。

推奨構成:

- 端末側の通知状態
  - 許可済み / OFF / 未選択 等
  - OFF時: 「端末設定を開く」
- `すべての通知`
- お世話
  - `満腹度が0`
  - `トイレ`
  - `おやすみ終了`
- ガチャ
  - `無料10回ガチャ`
- 釣り
  - `タイムブースト終了`
  - `釣りカゴ満杯`

要件:

- master OFFでも個別値そのものは消さない。
- master ONへ戻したとき、以前の個別設定へ戻る。
- master OFF中は個別Toggleをdisabled表示にしてよいが、保存値は変更しない。
- OS通知OFFとアプリ内master OFFを混同しない。
- OS通知OFFでもアプリ内設定値を勝手にOFFへ書き換えない。
- Settings再表示 / app foregroundでOS authorization statusをrefreshする。
- VoiceOverでToggleの意味が分かるlabelを付ける。

## Persistence requirements

### Additive persistence

新規UserDefaults:

| name | type | default | namespace | backward behavior |
|---|---|---:|---|---|
| `memo.notifications.enabled` | Bool | `true` | standard UserDefaults | key未存在はON扱い |
| `memo.notifications.fullnessZero.enabled` | Bool | `true` | standard UserDefaults | key未存在はON扱い |
| `memo.notifications.toilet.enabled` | Bool | `true` | standard UserDefaults | key未存在はON扱い |
| `memo.notifications.sleepEnded.enabled` | Bool | `true` | standard UserDefaults | key未存在はON扱い |
| `memo.notifications.gachaFreeTen.enabled` | Bool | `true` | standard UserDefaults | key未存在はON扱い |
| `memo.notifications.fishingTimeBoostEnded.enabled` | Bool | `true` | standard UserDefaults | key未存在はON扱い |
| `memo.notifications.fishingBasketFull.enabled` | Bool | `true` | standard UserDefaults | key未存在はON扱い |

実装上の注意:

- `UserDefaults.bool(forKey:)` は未登録keyをfalseとして返すため、key未存在をtrueとして扱うhelperまたは `register(defaults:)` を使用する。
- 既存UserDefaults keyを再利用しない。
- notification設定をSwiftDataへ追加しない。
- OS authorization statusはUserDefaultsへ複製して正としない。OS stateを正とする。

### Legacy SwiftData properties

以下は既存SwiftData schema互換性のため削除しない。

- `AppState.notifyFeed`
- `AppState.notifyBath`
- `AppState.notifyToilet`

この3つについて:

- runtimeの新通知設定には使用しない
- new UserDefaultsへmigrationしない
- new UserDefaultsの初期値決定にも使用しない
- renameしない
- 型変更しない
- 削除しない
- initializerから削除しない

`AppState.swift` の該当箇所へ、以下の意味のコメントを追加すること。

> Legacy notification settings. Current notification system does not use these values. Kept only for released-app SwiftData schema compatibility. Do not delete / rename / change type. New notification preferences use `memo.notifications.*`.

`docs/PERSISTENCE_COMPATIBILITY.md` にも同内容を明記する。

## Existing-user compatibility

既存ユーザーについて:

- 既存SwiftData Storeをそのまま読み込めること。
- `notifyFeed / notifyBath / notifyToilet` の値は保持する。
- ただし新通知設定へ意味を引き継がない。
- 新通知設定は全てONで開始する。
- iOS notification authorizationが既に設定済みならOS状態を尊重する。
- onboarding完了済みexisting userでOS authorizationが`.notDetermined`なら、update後の初Homeでpermission request対象となる。
- permission denied userにsystem promptを繰り返さない。
- gacha / fishing / ownership / happiness / photos / walk / Watch / Widget stateを変更しない。

## Xcode / target impact

- affected target(s):
  - `MeMo`
- `MeMo.xcodeproj` 変更必要?:
  - 新規Swift file追加時もfile-system-synchronized groupを確認
  - source-onlyなら不要なproject編集をしない
- Target Membership change?:
  - 新規Manager / model helperが `MeMo` targetでcompileされることを確認
- entitlements / capability change?:
  - **Push Notifications capabilityは追加しない**
  - Local Notificationのための不要なentitlementを追加しない
- Swift Package change?:
  - なし
- ignored/local Asset dependency?:
  - なし
- system framework:
  - `UserNotifications`

## 不要に変更してはいけない file

- SwiftData model propertyの削除・rename・型変更
- `.modelContainer(for:)`
- Gacha persistence
- Fishing persistence
- Happiness persistence
- Documents
- Widget / App Group
- WatchConnectivity
- StoreKit
- AdMob
- entitlements（Local Notificationに不要な変更禁止）

必要なroute integrationのための `MeMoApp.swift` / `HomeView.swift` / `RootView.swift` 変更は最小限にする。

## Acceptance criteria

- [ ] Local Notification基盤がある
- [ ] Remote Push / APNsを導入していない
- [ ] Push Notifications capabilityを追加していない
- [ ] 6カテゴリが一元定義されている
- [ ] master設定がある
- [ ] 6個別設定がある
- [ ] 全設定のdefaultがON
- [ ] master OFFで個別値が失われない
- [ ] OS authorization statusを表示できる
- [ ] denied時に端末設定を開ける
- [ ] onboarding完了後の初Homeで`.notDetermined`の場合のみpermission requestする
- [ ] denied後にsystem promptを繰り返さない
- [ ] foreground notificationを表示できるdelegate構成になっている
- [ ] tap routeがHome / Gacha / Fishingへ正しく分かれる
- [ ] cold launch routeを失わない
- [ ] existing HomeのGacha / Fishing presentationを再利用する
- [ ] `notifyFeed / notifyBath / notifyToilet` を削除していない
- [ ] 3 Legacy propertyを新通知設定へ再利用していない
- [ ] Legacy理由がsource commentとpersistence docへ記載されている
- [ ] existing user data が読める
- [ ] unrelated behavior が変わらない
- [ ] project file change が必要最小限
- [ ] Cloudでbuildできない場合、affected targetをlocal Xcodeで確認する

## Verification

### Codex Cloud

- `rg -n 'notifyFeed|notifyBath|notifyToilet' MeMo docs`
- `rg -n 'UNUserNotificationCenter|UserNotifications|memo\.notifications' MeMo`
- new keyがすべてdefault true semanticsになっていることをstatic確認
- existing `@Model` stored property diffを確認
- `git diff --check`
- `git diff -- MeMo.xcodeproj/project.pbxproj`
- entitlements差分確認
- Push Notifications capability / `aps-environment` が追加されていないことを確認
- usable Xcode toolchainがある場合のみ `MeMo` scheme build

### Local Xcode

- affected scheme:
  - `MeMo`
- Simulator / device:
  - iPhone 17 Pro Simulator
  - iPhone 15 実機
- 新規install相当:
  - onboarding中にpermissionを出さない
  - onboarding完了後の初Homeでprompt
- 許可:
  - Settingsが許可済み表示
- 拒否:
  - app toggleはON維持
  - SettingsにOFF表示
  - 「端末設定を開く」が動作
  - Home再表示でsystem promptが再出現しない
- master toggle:
  - OFFで通知基盤が停止
  - 個別値維持
  - ONで元の個別状態へ戻る
- route:
  - Home notification tap
  - Gacha notification tap
  - Fishing notification tap
  - foreground
  - background
  - cold launch

### Upgrade test

既存リリースデータを使用する。

確認:

- `AppState` が正常にloadできる。
- `notifyFeed / notifyBath / notifyToilet` の旧値が保持される。
- 新しい `memo.notifications.*` は全てdefault ON。
- 旧3値が新通知設定を上書きしない。
- existing onboarding-completed userのpermission flowが正しい。
- Gacha / Fishing / Happiness / Watch / Widget stateが維持される。

## Codex final report

Codex は以下を報告すること。

- changed files
- implementation summary
- notification architecture
- notification kinds / route contract
- permission-request timing
- Settings UI
- UserDefaults keys and default semantics
- Legacy `notifyFeed / notifyBath / notifyToilet` handling
- persistence impact
- existing-user compatibility
- Xcode / target impact
- entitlement / capability impact
- Cloud verification
- local Xcode verification required
- migration / upgrade verification
- remaining risks
