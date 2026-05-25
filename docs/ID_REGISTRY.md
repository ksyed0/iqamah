# ID Registry

Single source of truth for the next available ID in each artefact sequence. Update immediately whenever a new artefact is created.

---

## Current ID Sequences

| **Sequence** | **Next Available ID** | **Last Assigned** |
|--------------|-----------------------|-------------------|
| EPIC         | EPIC-0018             | EPIC-0017         |
| US           | US-0076               | US-0075           |
| TASK         | TASK-0001             | None              |
| AC           | AC-0383               | AC-0382           |
| TC           | TC-0123               | TC-0122           |
| BUG          | BUG-0071              | BUG-0070          |
| ENH          | ENH-0030               | ENH-0029           |

---

## Rules

- **Always consult this file** before creating any new artefact
- **Update immediately** after assigning a new ID
- **IDs are permanent** — never reused, even if artefact is retired
- **Retired artefacts** are marked `Status: Retired`, not deleted
- **Cross-references** must use full ID format (e.g., US-0003)

---

**Last Updated:** 2026-05-25 (TC-0074 through TC-0122 backfilled for EPIC-0015 Test Automation — cherry-picked from orphan PR #131 with renumbering to avoid collision with EPIC-0017 Fasting Mode TCs at TC-0044–0073.)
