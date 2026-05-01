# ID Registry

Single source of truth for the next available ID in each artefact sequence. Update immediately whenever a new artefact is created.

---

## Current ID Sequences

| **Sequence** | **Next Available ID** | **Last Assigned** |
|--------------|-----------------------|-------------------|
| EPIC         | EPIC-0007             | EPIC-0006         |
| US           | US-0032               | US-0031           |
| TASK         | TASK-0001             | None              |
| AC           | AC-0142               | AC-0141           |
| TC           | TC-0001               | None              |
| BUG          | BUG-0031              | BUG-0030          |

---

## Rules

- **Always consult this file** before creating any new artefact
- **Update immediately** after assigning a new ID
- **IDs are permanent** — never reused, even if artefact is retired
- **Retired artefacts** are marked `Status: Retired`, not deleted
- **Cross-references** must use full ID format (e.g., US-0003)

---

**Last Updated:** 2026-04-30 (Live UI review: BUG-0022–BUG-0030 added — Qiblah compass and general screen feedback)
