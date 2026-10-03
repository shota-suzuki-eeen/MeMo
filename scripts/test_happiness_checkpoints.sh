#!/bin/bash
set -euo pipefail
task_root="$(cd "$(dirname "$0")/.." && pwd)"
test_directory="$(mktemp -d "${TMPDIR:-/tmp}/memo-happiness-tests.XXXXXX")"
trap 'rm -rf "$test_directory"' EXIT
xcrun swiftc -swift-version 5 -module-cache-path "$test_directory/module-cache" \
    "$task_root/tests/HappinessCheckpointTestSupport.swift" \
    "$task_root/MeMo/Models/GachaFreeAdSlot.swift" \
    "$task_root/MeMo/Models/GachaTicketPolicy.swift" \
    "$task_root/MeMo/Models/EventManager.swift" \
    "$task_root/MeMo/Models/Halloween2026Configuration.swift" \
    "$task_root/MeMo/Models/FoodCatalog.swift" \
    "$task_root/MeMo/Models/HalloweenGachaModels.swift" \
    "$task_root/MeMo/Models/PetMaster.swift" \
    "$task_root/MeMo/Models/AppState+Gacha.swift" \
    "$task_root/MeMo/Models/AppState+Happiness.swift" \
    "$task_root/tests/HappinessCheckpointTests.swift" \
    -o "$test_directory/HappinessCheckpointTests"
"$test_directory/HappinessCheckpointTests" "$test_directory"
