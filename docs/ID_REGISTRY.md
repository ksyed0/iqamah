# ID Registry

Single source of truth for the next available ID in each artefact sequence. Update immediately whenever a new artefact is created.

---

## Current ID Sequences

| **Sequence** | **Next Available ID** | **Last Assigned** |
|--------------|-----------------------|-------------------|
| EPIC         | EPIC-0011             | EPIC-0010         |
| US           | US-0046               | US-0045           |
| TASK         | TASK-0001             | None              |
| AC           | AC-0204               | AC-0203           |
| TC           | TC-0001               | None              |
| BUG          | BUG-0056              | BUG-0055          |

---

## Rules

- **Always consult this file** before creating any new artefact
- **Update immediately** after assigning a new ID
- **IDs are permanent** — never reused, even if artefact is retired
- **Retired artefacts** are marked `Status: Retired`, not deleted
- **Cross-references** must use full ID format (e.g., US-0003)

---

**Last Updated:** 2026-05-09 (EPIC-0010 added — iOS universal app conversion: US-0040–US-0045, AC-0169–AC-0203). Registry was previously stale; refreshed to reflect actual highest IDs in RELEASE_PLAN.md (EPIC-0009, US-0039, AC-0168) and BUGS.md (BUG-0055).
