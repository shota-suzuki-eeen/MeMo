# MeMo Codex ドキュメント

Repository:

`shota-suzuki-eeen/MeMo`

基準コミット:

`448bb17895b60b4bcbd54690c327c8aa22bbadbe`

更新日:

`2026-09-26`

## ファイル構成

- `AGENTS.md` — Codex が常に守る最上位ルール
- `docs/ARCHITECTURE.md` — architecture / file navigation
- `docs/PERSISTENCE_COMPATIBILITY.md` — 既存ユーザーデータ保護ルール
- `docs/REPOSITORY_MAP.md` — repository map
- `docs/CODEX_WORKFLOW.md` — Codex Cloud 実装手順
- `docs/TESTING_RELEASE_CHECKLIST.md` — regression / release checklist
- `docs/CODEX_START_PROMPT.md` — Codex 開始時の共通 prompt
- `docs/tasks/TASK_TEMPLATE.md` — feature task template

既存 policy:

`SwiftDataOperationPolicy.md`

これは repository root に維持してください。

---

## 現在の Repository 構成

```text
AGENTS.md
SwiftDataOperationPolicy.md
docs/
MeMo.xcodeproj/
MeMo/
MeMoWatchComplication/
MeMoWidgetExtension.entitlements
```

Application source は `MeMo/` 配下です。

---

## Codex Cloud から見えるもの

Git 管理されているため確認可能:

- `MeMo.xcodeproj/project.pbxproj`
- shared scheme
- `Package.resolved`
- `MeMo/` source
- tracked Watch / Widget / Complication source
- tracked entitlements / plist

---

## Codex Cloud から見えない可能性があるもの

意図的に Git 管理外:

- `Assets.xcassets/`
- `MeMo_material/`
- `MeMo-Support/`
- `MeMo/MeMoWatch Watch App/WatchAssets.xcassets/`
- `MeMo/MeMoWidget/Assets.xcassets/`

これらを不足ファイルとして勝手に再作成しないでください。

---

## 基本運用

Codex Cloud:

- repository inspection
- implementation
- persistence compatibility review
- Xcode project metadata review
- diff review
- Cloud で利用可能な test / static check
- usable Xcode toolchain がある場合のみ build

Local Xcode:

- Simulator / device
- ignored Asset
- signing / capability
- target-specific build
- 最終リリース確認

Codex は確認できなかった内容を「成功」とみなさず、local verification required として報告してください。
