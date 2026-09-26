# Task: <short title>

## Status

`Draft | Ready for Codex | In progress | Verification | Done`

## Goal

Describe the user-visible result.

## Background

Explain why this change is needed and how the current behavior works.

## Scope

### In scope

- ...

### Out of scope

- ...

## Existing implementation to inspect first

- `path/to/file.swift`
- relevant types/functions
- related persistence keys
- related assets
- related Watch/Widget code if applicable

## Required assets

| Asset | Expected name/path | Notes |
|---|---|---|
| | | |

Do not rename existing assets unless explicitly required.

## Functional requirements

1. ...
2. ...
3. ...

## UI / interaction requirements

- ...

## Persistence requirements

Choose one:

### No new persistence

No stored state should change.

### Additive persistence

New key/model/field:

- name:
- type:
- default:
- namespace:
- backward behavior:

### Migration

Old format:

New format:

Migration algorithm:

Rollback/failure behavior:

## Existing-user compatibility

Explicitly describe what an existing installed user may already have.

Examples:

- existing SwiftData records
- non-zero gacha pity
- claimed rewards
- existing photos
- existing fishing points
- active walk/event state
- Watch/Widget shared snapshots

The implementation must preserve these values.

## Files that must not be changed unnecessarily

- ...

## Acceptance criteria

- [ ] ...
- [ ] existing user data remains readable
- [ ] relevant targets build
- [ ] no unrelated behavior changed

## Verification

### Build

- affected target(s):
- expected scheme(s), if known:

### Tests

- ...

### Manual checks

- ...

### Upgrade test

Describe how to verify behavior with pre-existing data.

## Codex final report requirements

Codex must report:

- changed files
- implementation summary
- persistence impact
- build result
- test result
- migration/upgrade verification
- remaining risks
