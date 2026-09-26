# Codex Start Prompt

Use this as the standard opening instruction for implementation tasks.

```text
Read AGENTS.md, SwiftDataOperationPolicy.md, docs/PERSISTENCE_COMPATIBILITY.md,
docs/ARCHITECTURE.md, and the specified task file before editing.

MeMo is already released. Existing-user local data must not be lost or become
inaccessible. Treat SwiftData stored property names, UserDefaults/AppStorage
literal keys, Documents paths/file-name rules, persisted Codable payloads,
Widget/App Group identifiers, and WatchConnectivity protocol keys as
compatibility contracts.

Before changing code:
1. inspect the complete local Xcode project and target membership;
2. locate the current feature owner and all references;
3. identify every persistence read/write affected by the task;
4. state whether the task has no persistence impact, additive persistence,
   or requires migration.

Then implement the task described in:

docs/tasks/<TASK_FILE>.md

Keep the diff narrowly scoped. Do not perform unrelated refactors or rename
legacy persistence identifiers for cleanliness.

After implementation:
- inspect git diff;
- build every affected target;
- run relevant tests;
- verify compatibility with pre-existing user data when persistence is touched;
- report changed files, implementation, persistence compatibility, build/tests,
  and remaining risks.
```
