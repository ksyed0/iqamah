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
| TC           | TC-0074               | TC-0073           |
| BUG          | BUG-0070              | BUG-0069          |
| ENH          | ENH-0028               | ENH-0027           |

---

## Rules

- **Always consult this file** before creating any new artefact
- **Update immediately** after assigning a new ID
- **IDs are permanent** — never reused, even if artefact is retired
- **Retired artefacts** are marked `Status: Retired`, not deleted
- **Cross-references** must use full ID format (e.g., US-0003)

---

**Last Updated:** 2026-05-24 (ENH-0027 logged — Cross-Ecosystem Expansion to Windows/Linux/Android via Rust+UniFFI shared core, golden test-vector contract, and per-platform Claude Code subagents.)
