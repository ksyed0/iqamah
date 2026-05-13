# ID Registry

Single source of truth for the next available ID in each artefact sequence. Update immediately whenever a new artefact is created.

---

## Current ID Sequences

| **Sequence** | **Next Available ID** | **Last Assigned** |
|--------------|-----------------------|-------------------|
| EPIC         | EPIC-0015             | EPIC-0014         |
| US           | US-0064               | US-0063           |
| TASK         | TASK-0001             | None              |
| AC           | AC-0300               | AC-0299           |
| TC           | TC-0036               | TC-0035           |
| BUG          | BUG-0056              | BUG-0055          |
| ENH          | ENH-020               | ENH-019           |

---

## Rules

- **Always consult this file** before creating any new artefact
- **Update immediately** after assigning a new ID
- **IDs are permanent** — never reused, even if artefact is retired
- **Retired artefacts** are marked `Status: Retired`, not deleted
- **Cross-references** must use full ID format (e.g., US-0003)

---

**Last Updated:** 2026-05-13 (EPIC-0013 Widget Platform consumed US-0058–US-0060, AC-0276–AC-0275 range was reserved; EPIC-0014 Adaptive Layout added — US-0061–US-0063, AC-0276–AC-0299.)
