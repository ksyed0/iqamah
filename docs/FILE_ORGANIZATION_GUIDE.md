# File Organization Guide

**IMPORTANT:** Some files were created with "Docs" as a filename prefix instead of in a Docs folder. Follow this guide to reorganize them properly in your Xcode project.

---

## 📁 Correct Project Structure

```
iqamah/
├── docs/
│   ├── ID_REGISTRY.md
│   ├── RELEASE_PLAN.md
│   ├── TEST_CASES.md
│   ├── BUGS.md
│   ├── LESSONS.md
│   ├── ROLLBACK.md
│   ├── DEPLOYMENT_READINESS.md
│   ├── FINAL_SESSION_SUMMARY.md
│   ├── MANUAL_TEST_CHECKLIST.md
│   ├── XCODE_SETUP_GUIDE.md
│   ├── ACCESSIBILITY_AUDIT_GUIDE.md
│   └── MVP_COMPLETION_SUMMARY.md
├── architecture/
│   └── ERROR_TAXONOMY.md
├── Models/
├── Views/
├── Tests/
├── Resources/
├── PROJECT.md
├── MEMORY.md
├── progress.md
├── findings.md
├── task_plan.md
├── PROMPT_LOG.md
├── MIGRATION_LOG.md
├── .env.example
├── .gitignore
└── AGENTS.md
```

---

## 🔧 How to Reorganize in Xcode

### **Step 1: Create Docs Folder**

1. In Xcode Project Navigator (left sidebar)
2. Right-click on your project root
3. Select **New Group**
4. Name it **"Docs"**

### **Step 2: Move Files with "Docs" Prefix**

**Files to Move and Rename:**

| **Current Filename** | **Move to Folder** | **Rename to** |
|---------------------|-------------------|---------------|
| `DocsID_REGISTRY.md` | docs/ | `ID_REGISTRY.md` |
| `DocsRELEASE_PLAN.md` | docs/ | `RELEASE_PLAN.md` |
| `DocsTEST_CASES.md` | docs/ | `TEST_CASES.md` |
| `DocsBUGS 2.md` | docs/ | `BUGS.md` |
| `DocsLESSONS.md` | docs/ | `LESSONS.md` |
| `DocsROLLBACK.md` | docs/ | `ROLLBACK.md` |
| `DocsDEPLOYMENT_READINESS.md` | docs/ | `DEPLOYMENT_READINESS.md` |
| `DocsFINAL_SESSION_SUMMARY.md` | docs/ | `FINAL_SESSION_SUMMARY.md` |
| `DocsMANUAL_TEST_CHECKLIST.md` | docs/ | `MANUAL_TEST_CHECKLIST.md` |
| `DocsXCODE_SETUP_GUIDE.md` | docs/ | `XCODE_SETUP_GUIDE.md` |
| `DocsACCESSIBILITY_AUDIT_GUIDE.md` | docs/ | `ACCESSIBILITY_AUDIT_GUIDE.md` |
| `DocsMVP_COMPLETION_SUMMARY.md` | docs/ | `MVP_COMPLETION_SUMMARY.md` |

**For Each File:**
1. Drag file into Docs folder in Xcode
2. Right-click file → **Rename**
3. Remove "Docs" prefix from filename

---

### **Step 3: Move Files with Other Prefixes**

**architecture/ folder:**

| **Current** | **Move to** | **Rename to** |
|------------|------------|---------------|
| `architectureERROR_TAXONOMY.md` | architecture/ | `ERROR_TAXONOMY.md` |

1. Create "architecture" group
2. Move and rename file

**Tests/ folder:**

| **Current** | **Move to** | **Rename to** |
|------------|------------|---------------|
| `TestsPrayerCalculatorTests.swift` | Tests/ | `PrayerCalculatorTests.swift` |
| `TestsAdditionalTests.swift` | Tests/ | `AdditionalTests.swift` |
| `TestsIntegrationAndEdgeCaseTests.swift` | Tests/ | `IntegrationAndEdgeCaseTests.swift` |

**Models/ folder:**

| **Current** | **Move to** | **Rename to** |
|------------|------------|---------------|
| `ModelsIqamahError.swift` | Models/ | `IqamahError.swift` |

**Views/ folder:**

| **Current** | **Move to** | **Rename to** |
|------------|------------|---------------|
| `ViewsSplashScreenView.swift` | Views/ | `SplashScreenView.swift` |
| `ViewsLocationSetupView.swift` | Views/ | `LocationSetupView.swift` |
| `ViewsCalculationMethodView.swift` | Views/ | `CalculationMethodView.swift` |

**Resources/ folder:**

| **Current** | **Move to** | **Rename to** |
|------------|------------|---------------|
| `Resourcescities.json` | Resources/ | `cities.json` |

---

## ✅ Verification Checklist

After reorganizing:

- [ ] docs/ folder contains 12 markdown files (no "Docs" prefix)
- [ ] architecture/ folder contains ERROR_TAXONOMY.md
- [ ] Tests/ folder contains 3 test files (in test target)
- [ ] Models/ folder contains IqamahError.swift
- [ ] Views/ folder contains 3 new view files
- [ ] Resources/ folder contains cities.json
- [ ] All files renamed (no folder name in filename)
- [ ] Project still builds (Cmd+B)
- [ ] Tests still run (Cmd+U)

---

## 🔄 Alternative: Use Finder

If Xcode is being difficult:

1. **Close Xcode**
2. **In Finder:**
   - Create `Docs` folder in project directory
   - Move all files with "Docs" prefix into folder
   - Rename files to remove prefix
   - Repeat for architecture, Tests, Models, Views, Resources
3. **Reopen Xcode**
4. **Remove old file references** (red files in navigator)
5. **Add files from new locations** (right-click project → Add Files)

---

## 📝 Quick Terminal Commands

From your project root directory:

```bash
# Create folders
mkdir -p Docs architecture Models Views Tests Resources

# Move and rename Docs files
mv DocsID_REGISTRY.md docs/ID_REGISTRY.md
mv DocsRELEASE_PLAN.md docs/RELEASE_PLAN.md
mv DocsTEST_CASES.md docs/TEST_CASES.md
mv "DocsBUGS 2.md" docs/BUGS.md
mv DocsLESSONS.md docs/LESSONS.md
mv DocsROLLBACK.md docs/ROLLBACK.md
mv DocsDEPLOYMENT_READINESS.md docs/DEPLOYMENT_READINESS.md
mv DocsFINAL_SESSION_SUMMARY.md docs/FINAL_SESSION_SUMMARY.md
mv DocsMANUAL_TEST_CHECKLIST.md docs/MANUAL_TEST_CHECKLIST.md
mv DocsXCODE_SETUP_GUIDE.md docs/XCODE_SETUP_GUIDE.md
mv DocsACCESSIBILITY_AUDIT_GUIDE.md docs/ACCESSIBILITY_AUDIT_GUIDE.md
mv DocsMVP_COMPLETION_SUMMARY.md docs/MVP_COMPLETION_SUMMARY.md

# Move and rename architecture file
mv architectureERROR_TAXONOMY.md architecture/ERROR_TAXONOMY.md

# Move and rename Test files
mv TestsPrayerCalculatorTests.swift Tests/PrayerCalculatorTests.swift
mv TestsAdditionalTests.swift Tests/AdditionalTests.swift
mv TestsIntegrationAndEdgeCaseTests.swift Tests/IntegrationAndEdgeCaseTests.swift

# Move and rename Models file
mv ModelsIqamahError.swift Models/IqamahError.swift

# Move and rename Views files
mv ViewsSplashScreenView.swift Views/SplashScreenView.swift
mv ViewsLocationSetupView.swift Views/LocationSetupView.swift
mv ViewsCalculationMethodView.swift Views/CalculationMethodView.swift

# Move and rename Resources file
mv Resourcescities.json Resources/cities.json

# Verify
ls -la docs/
ls -la architecture/
ls -la Tests/
ls -la Models/
ls -la Views/
ls -la Resources/
```

After running these commands, **add the folders back to Xcode:**
1. Right-click project → **Add Files to [Project]**
2. Select each folder (Docs, architecture, Models, Views, Tests, Resources)
3. Check **"Create folder references"** (important!)
4. Select appropriate targets

---

## 🎯 Expected Final State

```
Your Project/
├── 📁 docs/              (12 files, folder reference)
├── 📁 architecture/      (1 file, folder reference)
├── 📁 Models/            (IqamahError.swift + existing)
├── 📁 Views/             (3 new views + existing)
├── 📁 Tests/             (3 test suites, test target)
├── 📁 Resources/         (cities.json, bundle resource)
├── 📄 PROJECT.md
├── 📄 MEMORY.md
├── 📄 progress.md
├── 📄 findings.md
├── 📄 task_plan.md
├── 📄 PROMPT_LOG.md
├── 📄 MIGRATION_LOG.md
├── 📄 .env.example
├── 📄 .gitignore
└── 📄 AGENTS.md
```

---

## ⚠️ Important Notes

1. **Use "Create folder references"** not "Create groups" when adding folders
2. **Verify targets** — Test files go to test target, others to app target
3. **cities.json** must be in Copy Bundle Resources phase
4. **Clean build** after reorganizing (Cmd+Shift+K)

---

**After reorganization, your project structure will be clean and professional!**

Follow `docs/XCODE_SETUP_GUIDE.md` for next steps (it will reference the correct paths).
