# Fix Regression Test

A regression test is failing. Your job is to fix it.

## Failing Test

- **Test ID:** {{TEST_ID}}
- **Story:** {{STORY_ID}} - {{STORY_TITLE}}
- **Description:** {{TEST_DESCRIPTION}}
- **Command:** `{{TEST_COMMAND}}`

## Instructions

1. Run the failing test command to see the error
2. Investigate what broke (check git log for recent changes)
3. Fix the regression while preserving the intended new functionality
4. Verify the test passes
5. Commit with message: `fix: {{TEST_ID}} - {{TEST_DESCRIPTION}}`

Do NOT modify the test itself unless it's genuinely wrong.
The goal is to fix the code, not weaken the test.
