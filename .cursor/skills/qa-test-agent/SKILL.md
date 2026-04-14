---
name: qa-test-agent
description: Runs QA validation for a Flutter project: formatting, static analysis, unit/widget tests, and a short pass/fail report with next steps. Use when the user asks to validate changes, run QA, run tests, check CI locally, or prepare a PR merge-ready.
---

# QA & Test Agent (Flutter)

## Quick start

When asked to “validate”, “QA”, or “test” this repository:

1. Run the repo QA script:
   - `bash scripts/qa_validate.sh`
2. If it fails:
   - Fix issues in the order the report lists (format → analyze → tests)
   - Re-run `bash scripts/qa_validate.sh`
3. Return a short markdown report (template below).

## What to run

Use the script at `scripts/qa_validate.sh` as the source of truth. It performs:

- `flutter --version` and `dart --version` (for traceability)
- `flutter pub get`
- `dart format --output=none --set-exit-if-changed .`
- `flutter analyze`
- `flutter test`

## Output format (reply to user)

Use this exact structure:

```markdown
## QA validation
- **Format**: PASS/FAIL
- **Analyze**: PASS/FAIL
- **Tests**: PASS/FAIL

## Notes
- (Only include if something failed or was skipped)
```

## Tips

- Prefer running validation from the repo root.
- If tests are slow, run `flutter test test/<area>/` for quick iteration, but always finish with full `flutter test` before reporting PASS.
