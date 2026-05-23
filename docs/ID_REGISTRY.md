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
| TC           | TC-0044               | TC-0043           |
| BUG          | BUG-0069              | BUG-0068          |
| ENH          | ENH-026               | ENH-025           |

---

## Rules

- **Always consult this file** before creating any new artefact
- **Update immediately** after assigning a new ID
- **IDs are permanent** — never reused, even if artefact is retired
- **Retired artefacts** are marked `Status: Retired`, not deleted
- **Cross-references** must use full ID format (e.g., US-0003)

---

**Last Updated:** 2026-05-23 (ENH-025 logged — per-day alert scheduling backlog item from user request.)
