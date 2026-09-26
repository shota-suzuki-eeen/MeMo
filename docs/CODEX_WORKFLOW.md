# MeMo Codex 実装ワークフロー

## 目的

Codex Cloud で各実装タスクを進める際の標準手順です。

---

# Phase 1 — 実装前に読む

必須:

1. `/AGENTS.md`
2. `/SwiftDataOperationPolicy.md`
3. `/docs/PERSISTENCE_COMPATIBILITY.md`
4. `/docs/ARCHITECTURE.md`
5. `/docs/CODEX_WORKFLOW.md`
6. `/docs/tasks/` 配下の対象タスク

必要に応じて:

- `/MeMo.xcodeproj/project.pbxproj`
- `/MeMo.xcodeproj/xcshareddata/xcschemes/`
- `/MeMo.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`

Git 管理外 Asset Catalog が Cloud に存在すると仮定しないこと。

---

# Phase 2 — Feature owner を特定

コード変更前に確認:

- current feature type
- 全参照箇所
- persistence read/write
- relevant Target Membership
- resource name
- adjacent feature

既存 owner が存在する場合、新しい Manager / Store を並立させないこと。

現在の path 例:

- `MeMo/Models/...`
- `MeMo/Views/...`
- `MeMo/Managers/...`
- `MeMo/MeMoWatch Watch App/...`
- `MeMo/MeMoWidget/...`
- `MeMoWatchComplication/...`

---

# Phase 3 — Persistence impact を分類

## A. No persistence impact

例:

- layout
- animation
- rendering
- non-persistent calculation

報告:

`No persistent-data contract changed.`

## B. Additive persistence

例:

- 新規 UserDefaults key
- optional Codable field
- additive feature store

条件:

- namespaced key
- safe default
- 旧データ読み込み可能
- existing key を別用途に使わない

## C. Migration required

例:

- SwiftData stored property 変更
- incompatible Codable change
- Documents path 移動
- UserDefaults literal key 置換
- Widget / Watch shared protocol identifier 変更

破壊的 shortcut を実装せず、migration と test を先に設計すること。

---

# Phase 4 — Xcode / Resource impact を確認

確認項目:

- Target Membership
- `project.pbxproj`
- shared scheme
- Swift Package
- entitlements
- capability
- `Info.plist`
- bundle resource
- ignored/local Asset

ルール:

- project metadata を触る前に現在の project を確認
- source-only 変更で不要なら `project.pbxproj` を変更しない
- file-system-synchronized group を考慮
- ignored Asset Catalog を再作成しない
- physical Asset が Cloud にない場合は local verification を明記

---

# Phase 5 — 実装

- diff は最小限
- unrelated refactor 禁止
- persistence naming cleanup 禁止
- legacy fallback / key を維持
- old-data decoding path を維持
- project file churn を避ける

---

# Phase 6 — Codex Cloud で検証

最低限:

- `git diff`
- persistence literal / `@Model` 差分確認
- Xcode project impact 確認
- 利用可能な test / static check
- usable Xcode toolchain がある場合のみ build
- 確認できなかった ignored Asset を列挙

Widget 変更時:

- shared state contract
- App Group key
- Widget Target configuration

Watch 変更時:

- old/missing field tolerance
- Watch Target configuration
- WatchConnectivity compatibility

Memories 変更時:

- `Documents/memories/` の維持
- existing file を使った upgrade test 要否

---

# Phase 7 — ローカル Xcode で最終確認

Cloud で確認できない場合、リリース前にローカルで確認:

- `MeMo` scheme build/run
- affected Widget / Watch / Complication scheme
- Target Membership
- entitlements / capability
- ignored Asset name resolution
- Simulator / device behavior
- existing non-empty data を使った upgrade behavior

Cloud で Xcode が使えないこと自体は失敗ではありません。
ただし「未確認」として明示してください。

---

# Phase 8 — 最終報告

```text
Changed files:
- ...

Implementation:
- ...

Persistence compatibility:
- ...

Xcode / target impact:
- ...

Cloud verification:
- ...

Local Xcode verification required:
- ...

Remaining risks:
- ...
```

Compile 成功だけでは persistence compatibility の証明にはなりません。
