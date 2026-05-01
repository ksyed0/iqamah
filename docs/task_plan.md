# task_plan.md — Blueprint Phases & Checklist

Defines phases, goals, and checklists for the current project Blueprint. Updated as the project evolves.

---

## 🎯 Project Status

**Current Phase:** 🟡 **Phase 1-B — Blueprint (Discovery)**  
**Blueprint Status:** ⏸️ **AWAITING USER INPUT**  
**Blocker:** 5 Discovery Questions must be answered before coding begins

---

## Phase 1-B: Blueprint (Vision & Logic)

### ✅ **Completed**
- [x] Read AGENTS.md in full
- [x] Identify project type (macOS prayer times app)
- [x] Examine existing code files
- [x] Create PROJECT.md with initial schema
- [x] Create PROMPT_LOG.md
- [x] Create MEMORY.md
- [x] Create progress.md
- [x] Create MIGRATION_LOG.md
- [x] Create findings.md
- [x] Create task_plan.md (this file)

### 🟡 **In Progress**
- [ ] Create docs/ directory structure
- [ ] Create docs/ID_REGISTRY.md
- [ ] Create docs/RELEASE_PLAN.md
- [ ] Create docs/TEST_CASES.md
- [ ] Create docs/BUGS.md
- [ ] Create docs/LESSONS.md
- [ ] Create docs/ROLLBACK.md template
- [ ] Create .env.example
- [ ] Create .gitignore
- [ ] Create architecture/ directory
- [ ] Create architecture/ERROR_TAXONOMY.md
- [ ] Create tools/ directory
- [ ] Create tests/ directory

### ⏸️ **Blocked (Awaiting User Input)**

**5 Discovery Questions (AGENTS.md Phase 1-B):**

1. **North Star:** What is the singular desired outcome?
2. **Integrations:** Which external services are needed? Are credentials ready?
3. **Source of Truth:** Where does the primary data live?
4. **Delivery Payload:** How and where should the final result be delivered?
5. **Behavioral Rules:** How should the system act? (tone, logic constraints, "Do Not" rules)

**Additional Questions:**
- Confirm Data Schema in PROJECT.md (input/output shapes)
- Define minimum macOS version requirement
- Define distribution method (Mac App Store, direct download, both)
- Define user profile (technical comfort, mental model, usage context)
- Are notifications required?
- Is city selection/search needed, or is GPS-only sufficient?

---

## Phase 2-L: Link (Connectivity)

**Status:** 🔴 Not Started (blocked by Phase 1)

### **Checklist**
- [ ] Test CoreLocation authorization flow
- [ ] Verify prayer calculation accuracy
- [ ] Test settings persistence (load/save)
- [ ] Verify Qiblah calculation
- [ ] Test date/time formatting
- [ ] Test Hijri date conversion

---

## Phase 3-A: Architect (3-Layer Build)

**Status:** 🔴 Not Started (blocked by Phase 1)

### **Layer 1 — Architecture Documentation**
- [ ] Document LocationService SOP
- [ ] Document PrayerCalculator SOP
- [ ] Document SettingsManager SOP
- [ ] Document QiblahCalculator SOP (if separate)
- [ ] Define ERROR_TAXONOMY.md with app-specific error types

### **Layer 2 — Navigation (Decision Making)**
- [ ] Map data flow: Location → Prayer Calculation → Display
- [ ] Define error routing logic
- [ ] Define authorization state transitions

### **Layer 3 — Tools (Deterministic Scripts)**
- [ ] Review existing tools for compliance
- [ ] Create .env for any future API keys (if needed)
- [ ] Create .tmp/ for intermediate operations

---

## Phase 4-S: Stylize (Refinement & UI)

**Status:** 🔴 Not Started (blocked by Phase 1)

### **Checklist**
- [ ] Accessibility audit (WCAG 2.1 AA)
- [ ] VoiceOver support verification
- [ ] Dynamic Type support
- [ ] Keyboard navigation verification
- [ ] Color contrast ratio verification
- [ ] Dark mode support (if applicable)

---

## Phase 5-T: Trigger (Deployment)

**Status:** 🔴 Not Started (blocked by Phase 1)

### **Pre-Deployment Checklist (AGENTS.md §20)**
- [ ] Current version tagged in Git
- [ ] Rollback procedure documented in docs/ROLLBACK.md
- [ ] Smoke test plan defined
- [ ] Code signing configured
- [ ] Notarization completed (if distributing outside App Store)
- [ ] All tests passing (≥80% coverage)

---

## 🧪 Testing Requirements

**Current Coverage:** 0%  
**Target Coverage:** ≥80%  
**Framework:** Swift Testing (preferred) or XCTest

### **Critical Test Areas**
- [ ] Prayer time calculation accuracy
- [ ] Location service authorization flow
- [ ] Settings persistence and retrieval
- [ ] Date boundary transitions (midnight recalculation)
- [ ] Time zone handling
- [ ] Qiblah calculation accuracy
- [ ] UI state management (next prayer highlighting)
- [ ] Time adjustment persistence

---

## 📦 Release Planning

**Status:** 🔴 Not Started (blocked by Phase 1)

**Required:**
- [ ] Define MVP scope
- [ ] Define Release 1.x scope
- [ ] Create Epics with EPIC-XXXX IDs
- [ ] Create User Stories with US-XXXX IDs
- [ ] Create Tasks with TASK-XXXX IDs
- [ ] Define Acceptance Criteria with AC-XXXX IDs
- [ ] Update ID_REGISTRY.md as artefacts are created

---

## 🚦 Current Blockers

1. **🛑 Discovery Questions Unanswered** — Cannot define Blueprint until user provides answers
2. **🛑 Data Schema Unconfirmed** — Must confirm input/output shapes in PROJECT.md
3. **🛑 No Test Suite** — Violates AGENTS.md §8 (80% coverage requirement)
4. **🛑 Unknown Dependencies** — PrayerCalculator, SettingsManager, City model not examined
5. **🛑 No Release Plan** — Violates AGENTS.md §9 (release planning requirement)

---

## ✅ Next Immediate Actions

1. Finish creating required project files (docs/, architecture/, tests/)
2. Present 5 Discovery Questions to user
3. Wait for user input before proceeding to coding
4. Once answers received: Update PROJECT.md and create RELEASE_PLAN.md
5. Create initial test suite scaffolding
6. Examine unknown code files (PrayerCalculator, SettingsManager, etc.)

---

**Last Updated:** 2026-03-12 (Project Initialization)
