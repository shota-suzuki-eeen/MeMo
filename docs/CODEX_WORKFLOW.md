# Codex Implementation Workflow for MeMo

## Purpose

Use this workflow for each implementation task.

---

# Phase 1 — Read before editing

Codex must read:

1. `/AGENTS.md`
2. `/SwiftDataOperationPolicy.md`
3. `/docs/PERSISTENCE_COMPATIBILITY.md`
4. `/docs/ARCHITECTURE.md`
5. the task file under `/docs/tasks/`

Then inspect the local Xcode project, including files/resources not represented in GitHub.

---

# Phase 2 — Locate the feature owner

Before coding:

- find current feature types
- find all references
- find persistence reads/writes
- find target membership / resource usage
- identify adjacent features that must not change

Do not create a new manager/store if an existing owner already exists.

---

# Phase 3 — Persistence impact analysis

Classify the task:

## A. No persistence impact

Examples:

- visual layout
- animation
- rendering-only change
- non-persistent calculation

Report: `No persistent-data contract changed.`

## B. Additive persistence

Examples:

- new independent UserDefaults key
- new optional Codable field with safe fallback
- additive feature store

Requirements:

- namespaced key
- explicit default
- old app data remains readable
- no old keys reused

## C. Migration required

Examples:

- changing an existing SwiftData property
- changing a persisted Codable payload incompatibly
- moving Documents files
- replacing existing UserDefaults key names
- changing Watch/Widget shared protocol identifiers

Do not implement a destructive shortcut.

Prepare migration and tests first.

---

# Phase 4 — Implement narrowly

Rules:

- smallest practical diff
- no unrelated refactoring
- no opportunistic naming cleanup in persistence code
- preserve legacy fallback code
- preserve legacy keys
- reuse current patterns
- keep old-data decoding paths

---

# Phase 5 — Verify

At minimum:

- inspect `git diff`
- search diff for changed persistence key literals
- search diff for changed `@Model` properties
- build relevant targets
- run tests
- verify old/non-empty data scenario for persistence changes

When Widget is affected:

- verify app-to-widget shared state
- verify Widget reload behavior
- verify existing shared keys

When Watch is affected:

- verify reachable and background/application-context paths
- verify missing/new fields are tolerated

When memories are affected:

- verify an existing file in `Documents/memories/` still opens

---

# Phase 6 — Report

Codex must return:

```text
Changed files:
- ...

Implementation:
- ...

Persistence compatibility:
- ...

Build:
- ...

Tests:
- ...

Manual verification:
- ...

Remaining risks:
- ...
```

A successful compile is not sufficient evidence of persistence compatibility.
