#!/bin/bash
set -euo pipefail
task_root="$(cd "$(dirname "$0")/.." && pwd)"
test_directory="$(mktemp -d "${TMPDIR:-/tmp}/memo-gacha-ticket-tests.XXXXXX")"
trap 'rm -rf "$test_directory"' EXIT
xcrun swiftc -swift-version 5 -module-cache-path "$test_directory/module-cache" \
    "$task_root/MeMo/Models/GachaTicketPolicy.swift" \
    "$task_root/tests/GachaTicketPolicyTests.swift" -o "$test_directory/GachaTicketPolicyTests"
"$test_directory/GachaTicketPolicyTests"
