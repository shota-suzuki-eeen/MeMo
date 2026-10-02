#!/bin/bash
set -euo pipefail
task_root="$(cd "$(dirname "$0")/.." && pwd)"
test_directory="$(mktemp -d "${TMPDIR:-/tmp}/memo-halloween-tests.XXXXXX")"
trap 'rm -rf "$test_directory"' EXIT
xcrun swiftc -swift-version 5 -module-cache-path "$test_directory/module-cache" \
    "$task_root/MeMo/Models/EventManager.swift" \
    "$task_root/MeMo/Models/Halloween2026Configuration.swift" \
    "$task_root/MeMo/Models/HalloweenStageAttempt.swift" \
    "$task_root/MeMo/Models/HalloweenRunDifficulty.swift" \
    "$task_root/MeMo/Models/HalloweenRunInterruption.swift" \
    "$task_root/MeMo/Models/HalloweenObstaclePlanner.swift" \
    "$task_root/MeMo/Models/WallpaperCatalog.swift" \
    "$task_root/MeMo/Models/FoodCatalog.swift" \
    "$task_root/MeMo/Models/Halloween2026EventModels.swift" \
    "$task_root/MeMo/Models/Halloween2026EventStore.swift" \
    "$task_root/tests/HalloweenEventStoreTests.swift" \
    "$task_root/tests/HalloweenRunMechanicsTests.swift" \
    -o "$test_directory/HalloweenEventStoreTests"
"$test_directory/HalloweenEventStoreTests"
