# MeMo Codex Documentation Pack

Prepared from GitHub repository `shota-suzuki-eeen/MeMo`.

Audited snapshot:

`92563441704cf11712b17705b77b8b18f83c430f` (`main`, 2026-09-26)

## Contents

- `AGENTS.md` — repository-wide instructions for Codex
- `docs/ARCHITECTURE.md` — project architecture/navigation
- `docs/PERSISTENCE_COMPATIBILITY.md` — released-user data compatibility contract
- `docs/REPOSITORY_MAP.md` — audited GitHub source tree map
- `docs/CODEX_WORKFLOW.md` — implementation workflow
- `docs/TESTING_RELEASE_CHECKLIST.md` — regression/release checklist
- `docs/CODEX_START_PROMPT.md` — reusable first instruction for Codex
- `docs/tasks/TASK_TEMPLATE.md` — template for individual implementation tasks

<!--AGENTS.md = 常時ルール-->
<!--ARCHITECTURE.md = 設計理解-->
<!--REPOSITORY_MAP.md = ファイル探索-->
<!--PERSISTENCE_COMPATIBILITY.md = データ保護-->
<!--CODEX_WORKFLOW.md = 実装手順-->
<!--TESTING_RELEASE_CHECKLIST.md = 検証-->
<!--CODEX_START_PROMPT.md = Codex開始指示-->
<!--TASK_TEMPLATE.md = 個別作業仕様-->

## Existing repository document

The repository already contains:

`SwiftDataOperationPolicy.md`

Keep it at the repository root. `AGENTS.md` intentionally requires Codex to read it.

## How to install

Copy `AGENTS.md` and the `docs/` directory into the repository root.

Do not delete or replace existing persistence-policy files.

## Important snapshot limitation

The audited GitHub tree does not show a complete Xcode project/workspace or main
application asset catalog. Watch and Widget asset catalogs are gitignored.

Codex must inspect the local Xcode working copy before changing target membership,
assets, signing, capabilities, or build settings.
