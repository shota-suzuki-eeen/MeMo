# Task: <短いタイトル>

## Status

`Draft | Ready for Codex | In progress | Verification | Done`

## Goal

ユーザーから見た最終的な結果を書く。

## Background

なぜ必要なのか、現在どのように動いているかを書く。

## Scope

### In scope

- ...

### Out of scope

- ...

## 最初に確認する既存実装

現在の path を使用する。

例:

- `MeMo/Models/...`
- `MeMo/Views/...`
- `MeMo/Managers/...`
- `MeMo/MeMoWatch Watch App/...`
- `MeMo/MeMoWidget/...`
- `MeMoWatchComplication/...`
- `MeMo.xcodeproj/project.pbxproj`

記載するもの:

- relevant source
- type / function
- persistence key
- asset
- Watch / Widget / Complication 関連

## Required assets

| Asset | Runtime name/path | Git 管理 | Notes |
|---|---|---|---|
| | | Yes / No | |

注意:

- main `Assets.xcassets` は Git 管理外
- Watch / Widget Asset Catalog も Git 管理外
- existing Asset name を理由なく変更しない
- Cloud で見えない Asset は local verification を明記

## Functional requirements

1. ...
2. ...
3. ...

## UI / interaction requirements

- ...

## Persistence requirements

いずれかを選択。

### No new persistence

保存状態は変更しない。

### Additive persistence

- name:
- type:
- default:
- namespace:
- backward behavior:

### Migration

Old format:

New format:

Migration algorithm:

Rollback / failure behavior:

## Existing-user compatibility

既存インストールユーザーが保持している可能性がある状態を書く。

例:

- SwiftData records
- gacha pity
- claimed rewards
- photos
- fishing points
- active walk / event state
- Watch / Widget shared snapshot

これらを維持すること。

## Xcode / target impact

- affected target(s):
- `MeMo.xcodeproj` 変更必要?:
- Target Membership change?:
- entitlements / capability change?:
- Swift Package change?:
- ignored/local Asset dependency?:

不明な場合は Codex が project を確認してから実装すること。

## 不要に変更してはいけない file

- ...

## Acceptance criteria

- [ ] ...
- [ ] existing user data が読める
- [ ] unrelated behavior が変わらない
- [ ] project file change が必要最小限
- [ ] ignored/local Asset requirement が明記されている
- [ ] Cloud で build できない場合、affected target を local Xcode で確認する

## Verification

### Codex Cloud

- command / check:
- test:
- static validation:
- usable Xcode toolchain がある場合のみ build:

### Local Xcode

- affected scheme:
- Simulator / device:
- Target Membership:
- Asset:
- signing / capability:

### Upgrade test

Existing data を使った update 後の確認方法を書く。

## Codex final report

Codex は以下を報告すること。

- changed files
- implementation summary
- persistence impact
- Xcode / target impact
- Cloud verification
- local Xcode verification required
- migration / upgrade verification
- remaining risks
