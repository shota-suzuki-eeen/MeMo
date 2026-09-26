# MeMo Codex 作業ルール

## 目的

このファイルは、MeMo リポジトリ全体に適用する Codex 向けの最上位ルールです。

- Repository: `shota-suzuki-eeen/MeMo`
- Branch: `main`
- 基準コミット: `448bb17895b60b4bcbd54690c327c8aa22bbadbe`
- 更新日: `2026-09-26`
- 状態: **すでにリリース済みのアプリ**

Codex はコード変更前に必ずこのファイルを読むこと。

---

# 1. 最優先ルール：既存ユーザーのデータを保護する

MeMo はすでにリリース済みです。

そのため、以下よりも **既存ユーザーの保存データ互換性を優先**してください。

- リファクタリングの綺麗さ
- 命名統一
- アーキテクチャ整理
- コード簡略化
- 不要そうに見える旧仕様の削除

既存の保存名やキーが古い名称に見えても、リリース済みデータとの互換性のために意図的に残している可能性があります。

永続化に関係する変更を行う前に、必ず現在の読み書き箇所と旧データ互換性を確認してください。

---

# 2. 現在のリポジトリ構成

Git リポジトリ直下には、現在 `MeMo.xcodeproj` も含まれています。

主要な管理対象:

- `MeMo.xcodeproj/`
- `MeMo/`
- `MeMoWatchComplication/`
- `MeMoWidgetExtension.entitlements`
- `AGENTS.md`
- `SwiftDataOperationPolicy.md`
- `docs/`

アプリ本体の主要ソース:

- `MeMo/Models/`
- `MeMo/Managers/`
- `MeMo/ViewModels/`
- `MeMo/Views/`
- `MeMo/MeMoWatch Watch App/`
- `MeMo/MeMoWidget/`
- `MeMo/BGMs/`
- `MeMo/Movie/`

旧構成の `Models/...` や `Views/...` を使用せず、現在の `MeMo/...` パスを使用してください。

---

# 3. 意図的に Git 管理外にしているもの

以下は意図的に Git 管理対象から外しています。

- `Assets.xcassets/`
- `MeMo_material/`
- `MeMo-Support/`
- `MeMo/MeMoWatch Watch App/WatchAssets.xcassets/`
- `MeMo/MeMoWidget/Assets.xcassets/`
- `xcuserdata`
- `*.xcuserstate`

Codex Cloud ではこれらが存在しない可能性があります。

その場合:

- 不足ファイルとして勝手に再作成しない
- ダミー Asset Catalog を作らない
- 既存 Asset 名を推測で変更しない
- Source / Xcode project 上の参照名を優先して確認する
- 実アセット確認が必要な場合は「ローカル Xcode で確認が必要」と明記する
- 大容量 Asset を勝手に Git 管理へ追加しない

---

# 4. 永続化に関する互換性ルール

## SwiftData

現在 `.modelContainer(for:)` に登録されているモデル:

- `AppState`
- `TodayPhotoEntry`
- `WorkoutSessionRecord`

明示的な移行設計なしに以下を変更しないこと。

- 既存 `@Model` 名
- 既存 `@Model` の削除
- `.modelContainer(for:)` からの既存モデル削除
- 既存保存プロパティ名
- 既存保存プロパティの型
- 既存保存プロパティの削除
- uniqueness の意味
- 既存保存値の意味

SwiftData を変更する場合は必ず `SwiftDataOperationPolicy.md` を読むこと。

## UserDefaults / @AppStorage

既存の literal key はリリース済みユーザーとの互換性識別子です。

以下を行わないこと。

- 既存 key の文字列変更
- 新 key を導入して旧 key の読み込みを停止
- 保存 payload を旧データが読めない形式へ変更
- 新機能追加時に既存 key を初期化
- 既存 key を別の意味に再利用

既存コードに fallback / dual-read / dual-write がある場合は維持してください。

## Documents

`TodayPhotoEntry` の画像データは以下に保存されています。

`Documents/memories/`

移行処理なしに以下を変更しないこと。

- `memories` ディレクトリ名
- fileName の命名ルール
- JPEG 前提
- `TodayPhotoEntry.fileName` と実ファイルの対応関係

## JSON / Data / Codable

既存保存データが decode できなくなる変更は禁止です。

必要に応じて以下を使用してください。

- Optional field の追加
- `decodeIfPresent`
- versioning
- old-format fallback
- 明示的な migration

## Cross-target identifier

以下は互換性契約として扱うこと。

- App Group: `group.com.shota.CalPet`
- Widget kind
- App Group UserDefaults key
- WatchConnectivity message/context key
- Live Activity identifier / state contract

整理目的で変更しないこと。

---

# 5. 永続化変更前の確認

保存状態に関係する機能を変更する前に、少なくとも以下を検索してください。

- `@Model`
- `.modelContainer`
- `UserDefaults`
- `@AppStorage`
- `forKey:`
- `suiteName:`
- `FileManager`
- `.documentDirectory`
- `JSONEncoder`
- `JSONDecoder`
- `Codable`
- `WCSession`
- `sendMessage`
- `updateApplicationContext`
- Widget kind
- App Group identifier

永続化に関係するタスクでは、最終報告に必ず「既存ユーザーデータへの影響」を含めてください。

---

# 6. 実装方針

既存アーキテクチャを優先してください。

- `MeMo/Models/` — 状態・永続化・Policy・Store
- `MeMo/Managers/` — OS / service coordination
- `MeMo/ViewModels/` — presentation / domain coordination
- `MeMo/Views/` — SwiftUI / SpriteKit UI
- `MeMo/MeMoWatch Watch App/` — Watch app / WatchConnectivity
- `MeMo/MeMoWidget/` — Widget / Live Activity
- `MeMoWatchComplication/` — Complication
- `MeMo/BGMs/` — audio
- `MeMo/Movie/` — Widget snapshot support

ルール:

- 既存 owner が存在する場合はそこへ追加する
- 同じ state のために新しい persistence system を並立させない
- unrelated refactor を行わない
- style 統一だけを目的とした rename を行わない
- legacy fallback を維持する
- 小さく review 可能な diff を優先する

---

# 7. Xcode project の扱い

`MeMo.xcodeproj` は Git 管理され、Codex Cloud から参照可能です。

Target / resource / package / capability / build setting に関係する変更では、必要に応じて以下を確認してください。

- `MeMo.xcodeproj/project.pbxproj`
- `MeMo.xcodeproj/xcshareddata/xcschemes/`
- `MeMo.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`
- relevant entitlements
- relevant `Info.plist`

Folder 名だけで Target Membership を推測しないでください。

この project は file-system-synchronized group を使用しています。
新規 Swift file を追加するたびに従来型の PBX file reference を手動追加する前提ではありません。

Source-only の変更で不要な場合は `project.pbxproj` を変更しないでください。

Git 管理外 Asset が project から参照されていても、Codex Cloud 上に存在しないことだけを理由に project broken と判断しないでください。

---

# 8. Codex Cloud での検証

実装後:

1. `git diff` を確認
2. 永続化 key / stored property に不要な変更がないか確認
3. Xcode project への影響を確認
4. Cloud 環境で利用可能な test / static check を実行
5. Xcode toolchain が実際に利用可能な場合のみ build
6. 実施できたこと / できなかったことを明確に分けて報告

Build を実行して成功していない限り、

- iOS app
- Widget
- Watch app
- Complication

が build 成功したと書かないでください。

Cloud で Xcode / Simulator / ignored Asset を確認できない場合は、ローカル Xcode で必要な確認内容を明記してください。

---

# 9. Codex の最終報告形式

## Changed files

変更・追加・削除した file を列挙。

## Implementation

実装内容を簡潔に説明。

## Persistence compatibility

以下のいずれかを明記。

- `No persistent-data contract changed.`
- `Persistent data changed additively; backward compatibility verified as follows: ...`
- `Migration required; implementation not safe to release until: ...`

## Xcode / target impact

- affected target(s)
- `MeMo.xcodeproj` 変更有無
- Target Membership / Build Settings / Capability 変更有無
- ignored/local Asset 依存有無

## Verification

- 実際に実行した command
- build result
- test / check result
- ローカルで必要な追加確認

## Remaining risks

特に以下を明記。

- SwiftData
- UserDefaults
- Documents
- Widget / App Group
- WatchConnectivity
- StoreKit / entitlements
- Target Membership
- ignored/local Assets
