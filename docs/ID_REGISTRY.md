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
| ENH          | ENH-019               | ENH-018           |

---

## Rules

- **Always consult this file** before creating any new artefact
- **Update immediately** after assigning a new ID
- **IDs are permanent** — never reused, even if artefact is retired
- **Retired artefacts** are marked `Status: Retired`, not deleted
- **Cross-references** must use full ID format (e.g., US-0003)

---

**Last Updated:** 2026-05-09 (ENH-018 added — Hilal Watch global crescent sighting map; ENH row added to the registry — was previously missing despite ENH being a tracked sequence). Other rows (EPIC/US/AC/TC/BUG) reflect develop's current state and are known to be stale relative to in-flight planning work on other branches.
