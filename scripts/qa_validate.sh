#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

has() { command -v "$1" >/dev/null 2>&1; }

if ! has flutter; then
  echo "ERROR: flutter not found in PATH" >&2
  exit 127
fi

if ! has dart; then
  echo "ERROR: dart not found in PATH (expected with Flutter SDK)" >&2
  exit 127
fi

echo "== Environment =="
flutter --version || true
dart --version || true
echo

echo "== Pub get =="
flutter pub get
echo

FORMAT_STATUS="PASS"
ANALYZE_STATUS="PASS"
TEST_STATUS="PASS"

echo "== Format check =="
if dart format --output=none --set-exit-if-changed .; then
  echo "Format: PASS"
else
  FORMAT_STATUS="FAIL"
  echo "Format: FAIL"
fi
echo

echo "== Analyze =="
if flutter analyze; then
  echo "Analyze: PASS"
else
  ANALYZE_STATUS="FAIL"
  echo "Analyze: FAIL"
fi
echo

echo "== Tests =="
if flutter test; then
  echo "Tests: PASS"
else
  TEST_STATUS="FAIL"
  echo "Tests: FAIL"
fi
echo

echo "== QA validation (summary) =="
echo "## QA validation"
echo "- **Format**: ${FORMAT_STATUS}"
echo "- **Analyze**: ${ANALYZE_STATUS}"
echo "- **Tests**: ${TEST_STATUS}"

if [[ "$FORMAT_STATUS" == "FAIL" || "$ANALYZE_STATUS" == "FAIL" || "$TEST_STATUS" == "FAIL" ]]; then
  echo
  echo "## Notes"
  echo "- Fix failures in order: format → analyze → tests, then re-run \`bash scripts/qa_validate.sh\`."
  exit 1
fi
