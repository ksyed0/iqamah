# ID Registry

Single source of truth for the next available ID in each artefact sequence. Update immediately whenever a new artefact is created.

---

## Current ID Sequences

| **Sequence** | **Next Available ID** | **Last Assigned** |
|--------------|-----------------------|-------------------|
| EPIC         | EPIC-0016             | EPIC-0015         |
| US           | US-0070               | US-0069           |
| TASK         | TASK-0001             | None              |
| AC           | AC-0349               | AC-0348           |
| TC           | TC-0036               | TC-0035           |
| BUG          | BUG-0056              | BUG-0055          |
| ENH          | ENH-023               | ENH-022           |

---

## Rules

- **Always consult this file** before creating any new artefact
- **Update immediately** after assigning a new ID
- **IDs are permanent** — never reused, even if artefact is retired
- **Retired artefacts** are marked `Status: Retired`, not deleted
- **Cross-references** must use full ID format (e.g., US-0003)

---

**Last Updated:** 2026-05-24 (ENH-022 logged — Cross-Ecosystem Expansion to Windows/Linux/Android via Rust+UniFFI shared core. ENH audit pass against codebase: ENH-001 and ENH-004 reconciled as shipped; ENH-010 marked partial.)
