---
name: desktop-packaging
description: Package Tauri/Electron desktop apps into exe installers — analyze project type, configure build, handle platform-specific packaging steps.
---

# Desktop App Packaging Workflow

Package a desktop application project (Tauri, Electron, or similar) into an executable installer. This handles the common cycle of: identify project type → install dependencies → configure build → package → locate output.

## When To Use

- User asks to "打包" (package) a desktop project into exe
- User asks to "打包成exe" or "打包exe"
- Project is a Tauri, Electron, or similar desktop framework

## Workflow

### Step 1: Identify Project Type

```bash
# List project root
ls -la "<project_path>"

# Check for Tauri
Glob: **/tauri.conf.json in <project_path>
Glob: src-tauri/** in <project_path>

# Check for Electron
Glob: package.json in <project_path>
# Look for "electron" in dependencies

# Check for other frameworks
Glob: **/*.spec in <project_path>  # PyInstaller
```

**Project type detection from package.json:**
- `"tauri"` in dependencies → Tauri project
- `"electron"` in dependencies → Electron project
- `"electron-builder"` in devDependencies → Electron with builder

### Step 2: Read Build Configuration

For **Tauri:**
- `src-tauri/tauri.conf.json` — app name, bundle identifier, build config
- `src-tauri/Cargo.toml` — Rust dependencies
- `package.json` — frontend build scripts

For **Electron:**
- `package.json` — build config, scripts
- `electron-builder.yml` or `electron-builder.json` — packaging config

### Step 3: Install Dependencies

```bash
# Node.js projects
cmd /c "cd /d <path> && npm install"

# If using pnpm
cmd /c "cd /d <path> && pnpm install"

# Tauri Rust dependencies (usually automatic)
```

### Step 4: Build Frontend (if applicable)

```bash
# Check package.json scripts for build command
# Common patterns:
cmd /c "cd /d <path> && npm run build"
cmd /c "cd /d <path> && pnpm build"
```

### Step 5: Package Desktop App

**Tauri:**
```bash
cmd /c "cd /d <path> && npm run tauri build"
# Or with pnpm:
cmd /c "cd /d <path> && pnpm tauri build"
```

**Electron:**
```bash
cmd /c "cd /d <path> && npm run build"
# Or:
cmd /c "cd /d <path> && npx electron-builder --win"
```

**Timeout:** Set to 600000ms (10 minutes) for builds.

### Step 6: Locate Output

**Tauri output:**
```bash
ls -la <project_path>/src-tauri/target/release/bundle/
# NSIS installer: src-tauri/target/release/bundle/nsis/
# MSI installer: src-tauri/target/release/bundle/msi/
```

**Electron output:**
```bash
ls -la <project_path>/dist/
# Or: <project_path>/release/
```

### Step 7: Report

- Installer file path and size
- Build time
- Any warnings or issues encountered

## Common Pitfalls

1. **Rust not installed** (Tauri) — Need rustup + cargo in PATH
2. **WebView2 not available** — Tauri needs WebView2 on Windows (usually pre-installed on Win 10/11)
3. **Node modules missing** — Always run `npm install` / `pnpm install` first
4. **Build cache issues** — Try `cargo clean` (Tauri) or `rm -rf dist` (Electron)
5. **Code signing** — Unsigned executables may trigger Windows SmartScreen

## Quick Detection Script

```bash
# Auto-detect project type
if [ -f "<path>/src-tauri/tauri.conf.json" ]; then
  echo "Tauri project detected"
elif grep -q '"electron"' "<path>/package.json" 2>/dev/null; then
  echo "Electron project detected"
else
  echo "Unknown desktop framework"
fi
```
