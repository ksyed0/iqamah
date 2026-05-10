# ID Registry

Single source of truth for the next available ID in each artefact sequence. Update immediately whenever a new artefact is created.

---

## Current ID Sequences

| **Sequence** | **Next Available ID** | **Last Assigned** |
|--------------|-----------------------|-------------------|
| EPIC         | EPIC-0012             | EPIC-0011         |
| US           | US-0053               | US-0052           |
| TASK         | TASK-0001             | None              |
| AC           | AC-0249               | AC-0248           |
| TC           | TC-0001               | None              |
| BUG          | BUG-0056              | BUG-0055          |
| ENH          | ENH-019               | ENH-018           |

> **Cross-branch reservations (in flight, not yet on `develop`):**
> - `claude/explore-ios-conversion-Su3MF` (PR #54) — EPIC-0010, US-0040 – US-0045, AC-0169 – AC-0203, TC-0001 – TC-0035
> - `feat/ENH-018-hilal-watch-spec` (this branch) — EPIC-0011, US-0046 – US-0052, AC-0204 – AC-0248
>
> The "Next Available" values above assume PR #54 lands first. If the explore branch lands second instead, Hilal Watch's IDs must be renumbered down to EPIC-0010 / US-0040+ / AC-0169+ at merge time. The registry rows for EPIC/US/AC reflect develop's actual highest assigned IDs (0009 / 0039 / 0168) plus both branches' reservations.

---

## Rules

- **Always consult this file** before creating any new artefact
- **Update immediately** after assigning a new ID
- **IDs are permanent** — never reused, even if artefact is retired
- **Retired artefacts** are marked `Status: Retired`, not deleted
- **Cross-references** must use full ID format (e.g., US-0003)

---

**Last Updated:** 2026-05-10 (ENH-018 promoted to EPIC-0011 Hilal Watch — added US-0046 – US-0052 / AC-0204 – AC-0248; cross-branch reservation note added covering both `feat/ENH-018-hilal-watch-spec` and `claude/explore-ios-conversion-Su3MF` PR #54).
