# Rollback & Recovery Plan Template

**⚠️ This template must be filled out before every deployment to production or staging.**

---

## Pre-Deployment Checklist (AGENTS.md §20)

- [ ] Current production version is tagged in Git (e.g., `v1.0.0`)
- [ ] Database migrations are reversible (if applicable)
- [ ] Rollback procedure is documented below
- [ ] Smoke test plan is defined
- [ ] Monitoring and alerting are active and verified

---

## Release Information

**Release Version:** *[e.g., v1.0.0]*  
**Deployment Date:** *[YYYY-MM-DD]*  
**Deployment Time:** *[HH:MM timezone]*  
**Deployed By:** *[Name or identifier]*  
**Deployment Environment:** *[Production | Staging | Beta]*

---

## Rollback Trigger Conditions

**Rollback should be initiated if:**

- [ ] *[Define specific conditions, e.g., "App crashes on launch"]*
- [ ] *[e.g., "Prayer times are calculated incorrectly"]*
- [ ] *[e.g., "Location services fail for >50% of users"]*
- [ ] *[e.g., "Critical security vulnerability discovered"]*

---

## Rollback Procedure

### Step 1: Stop Traffic (if applicable)
*[Instructions for stopping new users from accessing the broken version]*

### Step 2: Revert Git Tag
```bash
# Example commands
git checkout tags/v[previous-version]
# or
git revert [commit-hash]
```

### Step 3: Reverse Database Migrations (if applicable)
```bash
# Example commands
# [List specific migration rollback commands]
```

### Step 4: Invalidate Caches (if applicable)
*[Instructions for clearing any caches]*

### Step 5: Verify Smoke Tests
*[Run smoke tests defined below]*

### Step 6: Notify Stakeholders
*[Who to notify and how]*

---

## Smoke Test Plan

**Minimum checks to verify deployment succeeded (or rollback succeeded):**

1. [ ] *[e.g., "App launches without crashing"]*
2. [ ] *[e.g., "Location permission request appears"]*
3. [ ] *[e.g., "Prayer times display correctly for known location"]*
4. [ ] *[e.g., "Time adjustments persist after app restart"]*
5. [ ] *[e.g., "Qiblah direction calculates correctly"]*

---

## Post-Rollback Actions

If rollback is executed:

1. **Log incident in `progress.md`** with:
   - Timeline of events
   - Root cause analysis
   - Resolution steps taken

2. **Open bugfix branch** to address root cause:
   - Branch name: `bugfix/BUG-XXXX-[short-description]`
   - Create BUG-XXXX entry in `docs/BUGS.md`

3. **Update `docs/LESSONS.md`** with hard-won lesson

4. **Schedule post-mortem** (if appropriate)

---

## Notes

- This file should be duplicated and customized for each release
- Archive completed rollback plans in `docs/rollback-archive/`
- Never proceed with deployment if you cannot complete this document

---

> **Rule:** Hope is not a recovery strategy. If you haven't tested the rollback, you don't have one.

---

**Last Updated:** 2026-03-12 (Template Created)
