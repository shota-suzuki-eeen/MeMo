#!/bin/bash
set -euo pipefail
task_root="$(cd "$(dirname "$0")/.." && pwd)"
test_directory="$(mktemp -d "${TMPDIR:-/tmp}/memo-gacha-selection-tests.XXXXXX")"
trap 'rm -rf "$test_directory"' EXIT
xcrun swiftc -swift-version 5 -module-cache-path "$test_directory/module-cache" \
    "$task_root/tests/GachaSelectionTestSupport.swift" \
    "$task_root/MeMo/Models/GachaFreeAdSlot.swift" \
    "$task_root/MeMo/Models/GachaTicketPolicy.swift" \
    "$task_root/MeMo/Models/AppState+Gacha.swift" \
    "$task_root/tests/GachaSelectionTests.swift" \
    -o "$test_directory/GachaSelectionTests"
"$test_directory/GachaSelectionTests" "$test_directory"
