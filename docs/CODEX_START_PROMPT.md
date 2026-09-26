# Codex 開始プロンプト

Codex Cloud で実装を開始するときに使用する共通プロンプトです。

```text
実装前に以下を読んでください。

- AGENTS.md
- SwiftDataOperationPolicy.md
- docs/PERSISTENCE_COMPATIBILITY.md
- docs/ARCHITECTURE.md
- docs/CODEX_WORKFLOW.md
- 指定された docs/tasks/<TASK_FILE>.md

MeMo はすでにリリース済みです。
既存ユーザーの保存データが失われたり、読み込めなくなったりしないことを最優先してください。

以下は互換性契約として扱ってください。

- SwiftData の既存 stored property
- UserDefaults / @AppStorage の literal key
- Documents の path / fileName rule
- 保存済み Codable payload
- Widget / App Group identifier
- WatchConnectivity message/context key

Repository 構成:

- MeMo.xcodeproj は repository root にあり Git 管理されています
- app source は MeMo/ 配下です
- complication source は MeMoWatchComplication/ 配下です
- main Assets.xcassets と Watch/Widget Asset Catalog の一部は意図的に gitignore されています

コード変更前に:

1. Target / package / resource / capability / build setting に影響する場合は
   MeMo.xcodeproj/project.pbxproj と relevant scheme を確認する
2. current feature owner と参照箇所を MeMo/ 配下から確認する
3. 永続化 read/write への影響を確認する
4. persistence impact を
   - none
   - additive
   - migration required
   のいずれかに分類する
5. Git 管理外 Asset への依存有無を確認する

指定タスク:
docs/tasks/<TASK_FILE>.md

実装ルール:

- diff は必要最小限
- unrelated refactor 禁止
- legacy persistence identifier の整理目的 rename 禁止
- source-only 変更で不要なら project.pbxproj を変更しない

実装後:

- git diff を確認
- Cloud で実行可能な validation を実施
- usable Xcode toolchain がある場合のみ Xcode build を実行
- 実際に build 成功していない target を build success と報告しない
- Cloud で確認できない Xcode / Simulator / ignored Asset は
  ローカル確認事項として明示する

最終報告には以下を含めてください。

- changed files
- implementation summary
- persistence compatibility
- Xcode / target impact
- Cloud verification
- local Xcode verification required
- remaining risks
```
