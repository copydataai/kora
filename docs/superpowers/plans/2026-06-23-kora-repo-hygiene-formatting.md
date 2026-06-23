# Kora Repo Hygiene And Formatting Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stop local Xcode state and generated files from leaking into git, and define minimal formatting expectations.

**Architecture:** Keep hygiene lightweight: update `.gitignore`, untrack user-specific Xcode metadata, add `.editorconfig`, and document that formatting is conventional until a formatter is intentionally adopted.

**Tech Stack:** Git, Xcode project files, EditorConfig.

---

## Files

- Modify: `.gitignore`
- Create: `.editorconfig`
- Remove from git index: `kora.xcodeproj/xcuserdata/josesanchez.xcuserdatad/xcschemes/xcschememanagement.plist`
- Modify: `README.md`

### Task 1: Expand Xcode-Safe Ignore Rules

- [ ] **Step 1: Replace `.gitignore`**

Use this complete `.gitignore`:

```gitignore
.DS_Store

# Codex/local agent state
.agents/
.superpowers/

# Xcode local state
xcuserdata/
*.xcuserstate
DerivedData/
build/
Build/
*.xcarchive
*.dSYM

# SwiftPM/Xcode generated files
.build/
Package.resolved

# Logs
*.log
```

- [ ] **Step 2: Untrack existing user-specific Xcode metadata**

```bash
git rm --cached kora.xcodeproj/xcuserdata/josesanchez.xcuserdatad/xcschemes/xcschememanagement.plist
```

Expected: file is removed from the git index but remains locally if it exists on disk.

- [ ] **Step 3: Verify ignored local state**

```bash
git status --short --ignored | sed -n '1,120p'
```

Expected: `kora.xcodeproj/xcuserdata/` appears as ignored or absent, and `xcschememanagement.plist` is staged as deleted.

### Task 2: Add Minimal Formatting Policy

- [ ] **Step 1: Create `.editorconfig`**

```editorconfig
root = true

[*]
charset = utf-8
end_of_line = lf
insert_final_newline = true
trim_trailing_whitespace = true

[*.swift]
indent_style = space
indent_size = 4

[*.{yml,yaml,md}]
indent_style = space
indent_size = 2
trim_trailing_whitespace = false

[*.pbxproj]
indent_style = tab
indent_size = 4
```

- [ ] **Step 2: Document formatting stance**

In `README.md`, add a short `## Development` section:

```markdown
## Development

This repo uses `.editorconfig` for baseline whitespace rules. There is no SwiftFormat or SwiftLint requirement yet; add one only when the project is ready to enforce it in CI.
```

### Task 3: Verify And Commit

- [ ] **Step 1: Verify no ignored Xcode state is tracked**

```bash
git ls-files | rg '(^|/)xcuserdata/|\\.xcuserstate$'
```

Expected: no output.

- [ ] **Step 2: Verify expected staged changes**

```bash
git status --short
```

Expected includes `.editorconfig`, `.gitignore`, README changes, and a deleted tracked `xcschememanagement.plist`.

- [ ] **Step 3: Commit**

```bash
git add .gitignore .editorconfig README.md
git add -u kora.xcodeproj/xcuserdata
git commit -m "chore: clean Xcode repo hygiene"
```

