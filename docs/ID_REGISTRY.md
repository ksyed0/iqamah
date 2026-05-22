# ID Registry

Single source of truth for the next available ID in each artefact sequence. Update immediately whenever a new artefact is created.

---

## Current ID Sequences

| **Sequence** | **Next Available ID** | **Last Assigned** |
|--------------|-----------------------|-------------------|
| EPIC         | EPIC-0017             | EPIC-0016         |
| US           | US-0071               | US-0070           |
| TASK         | TASK-0001             | None              |
| AC           | AC-0357               | AC-0356           |
| TC           | TC-0093               | TC-0092           |
| BUG          | BUG-0069              | BUG-0068          |
| ENH          | ENH-025               | ENH-024           |

---

## Rules

- **Always consult this file** before creating any new artefact
- **Update immediately** after assigning a new ID
- **IDs are permanent** — never reused, even if artefact is retired
- **Retired artefacts** are marked `Status: Retired`, not deleted
- **Cross-references** must use full ID format (e.g., US-0003)

---

**Last Updated:** 2026-05-22 (EPIC-0015 TC backfill — TC-0044 through TC-0092 consumed, one TC per AC covering US-0064 smoke tests, US-0065 snapshot tests, US-0066–US-0068 XCUITest suites, and US-0069 nightly CI gate.)
