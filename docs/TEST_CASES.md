# Test Cases

Human-readable test cases (TC-XXXX) linked to user stories and acceptance criteria. Distinct from unit tests — used for verification and QA.

---

## Test Case Registry

**Total Test Cases:** 0  
**Status:** 🔴 No test cases defined yet (awaiting User Stories and Acceptance Criteria)

---

## Test Case Format

```
TC-[XXXX]: [Short descriptive title]
Related Story: US-[XXXX]
Related Task: TASK-[XXXX]
Related AC: AC-[XXXX]
Type: [Functional | Regression | Edge Case | Negative | Accessibility | Performance]
Preconditions: [System state required before the test is run]
Steps:
  1. [Action]
  2. [Action]
  3. [Action]
Expected Result: [What should happen if the system is working correctly]
Actual Result: [Filled in during test execution — leave blank until executed]
Status: [ ] Not Run / [ ] Pass / [ ] Fail
Defect Raised: [BUG-XXXX or "None"]
Notes: [Any observations, edge cases, or defects found]
```

---

## Test Cases by Epic

*[Test cases will be organized by Epic once User Stories are defined]*

---

## Test Cases by Type

### Functional Tests
*[To be created]*

### Regression Tests
*[To be created]*

### Edge Case Tests
*[To be created]*

### Negative Tests
*[To be created]*

### Accessibility Tests
*[To be created]*

### Performance Tests
*[To be created]*

---

## Rules (AGENTS.md §10)

- Every user story must have at least one test case covering its primary acceptance criterion
- Every acceptance criterion (AC-XXXX) must have a corresponding test case (TC-XXXX)
- Edge cases and negative paths must have their own uniquely identified test cases
- Test cases must be reviewed and updated whenever acceptance criteria change
- Failed test cases must raise a BUG-XXXX entry and be logged in `progress.md`
- Test case IDs are permanent — never reuse or renumber a TC-XXXX, even if deleted
- Mark deleted cases as `Status: Retired`

---

**Last Updated:** 2026-03-12 (Project Initialization — Awaiting User Stories)
