# Hard-Won Lessons & Permanent Rules

Encodes bug fixes and hard-won lessons as permanent rules. Every AI mistake should only happen once.

---

## Format

> **"[Never/Always] [specific behaviour]."** *Learned when [brief description of failure].*

---

## Lessons by Category

### **Location Services**

*[No lessons recorded yet]*

### **Prayer Time Calculations**

*[No lessons recorded yet]*

### **UI/UX**

*[No lessons recorded yet]*

### **Settings & Persistence**

*[No lessons recorded yet]*

### **Date & Time Handling**

*[No lessons recorded yet]*

### **Thread Safety**

*[No lessons recorded yet]*

### **Error Handling**

*[No lessons recorded yet]*

### **Testing**

*[No lessons recorded yet]*

---

## Self-Annealing Loop (AGENTS.md §7)

When a bug is resolved after significant debugging:

1. **Analyze** — Read the stack trace. Do not guess.
2. **Patch** — Fix the script in `tools/` using Swift.
3. **Test** — Verify the fix works.
4. **Update Architecture** — Record the learning in the relevant `architecture/` SOP so the error never repeats.

---

## Notes

- This file should grow over time as bugs are discovered and fixed
- Every lesson here must be referenced in the related BUG-XXXX entry
- Lessons should be actionable and specific, not vague principles
- Review this file before starting work on related areas

---

**Last Updated:** 2026-03-12 (Project Initialization — No lessons yet)
