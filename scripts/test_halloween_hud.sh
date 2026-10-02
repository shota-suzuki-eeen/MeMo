#!/bin/bash
set -euo pipefail
task_root="$(cd "$(dirname "$0")/.." && pwd)"
test_directory="$(mktemp -d "${TMPDIR:-/tmp}/memo-halloween-hud.XXXXXX")"
trap 'rm -rf "$test_directory"' EXIT
xcrun swiftc -swift-version 5 -module-cache-path "$test_directory/module-cache" \
    "$task_root/MeMo/Models/Halloween2026Configuration.swift" \
    "$task_root/MeMo/Models/HalloweenRunHUDLayout.swift" \
    "$task_root/tests/HalloweenRunHUDLayoutTests.swift" -o "$test_directory/HalloweenHUDTests"
"$test_directory/HalloweenHUDTests"
