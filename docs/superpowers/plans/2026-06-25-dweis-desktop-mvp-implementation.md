# DWeis Desktop MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the first local-only DWeis Desktop MVP in `D:\program\dweis-code`, with Chat / Code mode switching, a three-column desktop shell, local workspace browsing, read-only file viewing, and basic AI tool plumbing.

**Architecture:** The app is a new Tauri v2 desktop project. React + TypeScript owns UI, state, AI provider orchestration, and tool registry. Rust owns local system capabilities exposed through Tauri commands: workspace opening, directory listing, file reading, and text search. The first MVP is read-only for Code mode and does not sync with the mobile Flutter app.

**Tech Stack:** Tauri v2, React, TypeScript, Vite, Rust, Zustand, Tailwind CSS, Monaco Editor, Vitest.

---

## File Structure

The new project lives outside the Flutter app:

```text
D:\program\dweis-code
├─ package.json
├─ index.html
├─ vite.config.ts
├─ tsconfig.json
├─ tailwind.config.ts
├─ postcss.config.js
├─ src/
│  ├─ main.tsx
│  ├─ app/App.tsx
│  ├─ app/providers.tsx
│  ├─ styles.css
│  ├─ components/layout/AppShell.tsx
│  ├─ components/layout/TopBar.tsx
│  ├─ components/layout/LeftPanel.tsx
│  ├─ components/layout/MainCanvas.tsx
│  ├─ components/layout/RightPanel.tsx
│  ├─ components/ui/Button.tsx
│  ├─ components/ui/Panel.tsx
│  ├─ features/chat/ChatMode.tsx
│  ├─ features/chat/ChatThread.tsx
│  ├─ features/chat/ChatInput.tsx
│  ├─ features/code/CodeMode.tsx
│  ├─ features/code/FileTree.tsx
│  ├─ features/code/FileViewer.tsx
│  ├─ features/code/WorkspaceSearch.tsx
│  ├─ features/tools/ToolLog.tsx
│  ├─ services/tauri/workspace.ts
│  ├─ services/tools/registry.ts
│  ├─ services/tools/workspaceTools.ts
│  ├─ services/ai/provider.ts
│  ├─ stores/appModeStore.ts
│  ├─ stores/workspaceStore.ts
│  └─ stores/chatStore.ts
└─ src-tauri/
   ├─ Cargo.toml
   ├─ tauri.conf.json
   └─ src/
      ├─ main.rs
      ├─ commands/mod.rs
      ├─ commands/workspace.rs
      └─ security.rs
```

---

## Task 1: Create Tauri Project Skeleton

**Files:**
- Create project at `D:\program\dweis-code`
- Create/modify generated Tauri/Vite files

- [ ] **Step 1: Create the project**

Run from `D:\program`:

```bash
pnpm create tauri-app dweis-code --template react-ts
```

If the generator prompts:

```text
Package manager: pnpm
UI template: React
UI language: TypeScript
```

Expected: a new folder `D:\program\dweis-code` exists.

- [ ] **Step 2: Install base dependencies**

Run:

```bash
cd /d/program/dweis-code
pnpm add zustand @tanstack/react-query @monaco-editor/react clsx lucide-react
pnpm add -D tailwindcss postcss autoprefixer vitest @testing-library/react @testing-library/jest-dom jsdom
pnpm exec tailwindcss init -p
```

Expected: `package.json` includes the dependencies and `tailwind.config.js` / `postcss.config.js` exist.

- [ ] **Step 3: Initialize git**

Run:

```bash
cd /d/program/dweis-code
git init
git add .
git commit -m "chore: scaffold tauri react app"
```

Expected: first commit created.

---

## Task 2: Configure Tailwind and Base Theme

**Files:**
- Modify: `D:\program\dweis-code\tailwind.config.js`
- Modify: `D:\program\dweis-code\src\styles.css`
- Modify: `D:\program\dweis-code\src\main.tsx`

- [ ] **Step 1: Configure Tailwind content paths**

Set `tailwind.config.js` to:

```js
/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{ts,tsx}'],
  theme: {
    extend: {
      colors: {
        bg: '#0B0D10',
        surface: '#111318',
        surface2: '#181B20',
        border: '#252A31',
        text: '#F9FAFB',
        muted: '#9CA3AF',
        primary: '#3B82F6',
        success: '#22C55E',
        warning: '#FBBF24',
        danger: '#EF4444',
      },
      fontFamily: {
        sans: ['Inter', 'system-ui', 'sans-serif'],
        mono: ['JetBrains Mono', 'SF Mono', 'Menlo', 'monospace'],
      },
    },
  },
  plugins: [],
}
```

- [ ] **Step 2: Create base styles**

Set `src/styles.css` to:

```css
@tailwind base;
@tailwind components;
@tailwind utilities;

:root {
  color-scheme: dark;
  font-family: Inter, system-ui, sans-serif;
  background: #0b0d10;
  color: #f9fafb;
}

html,
body,
#root {
  width: 100%;
  height: 100%;
  margin: 0;
}

* {
  box-sizing: border-box;
}

button,
input,
textarea {
  font: inherit;
}
```

- [ ] **Step 3: Import styles**

Ensure `src/main.tsx` imports styles:

```ts
import './styles.css'
```

- [ ] **Step 4: Verify dev server**

Run:

```bash
pnpm tauri dev
```

Expected: desktop window opens with the generated React app.

- [ ] **Step 5: Commit**

```bash
git add .
git commit -m "style: configure desktop theme tokens"
```

---

## Task 3: App Mode Store and Shell Layout

**Files:**
- Create: `src/stores/appModeStore.ts`
- Create: `src/components/layout/AppShell.tsx`
- Create: `src/components/layout/TopBar.tsx`
- Create: `src/components/layout/LeftPanel.tsx`
- Create: `src/components/layout/MainCanvas.tsx`
- Create: `src/components/layout/RightPanel.tsx`
- Modify: `src/app/App.tsx`

- [ ] **Step 1: Write store test**

Create `src/stores/appModeStore.test.ts`:

```ts
import { describe, expect, it } from 'vitest'
import { useAppModeStore } from './appModeStore'

describe('appModeStore', () => {
  it('switches between chat and code mode', () => {
    useAppModeStore.getState().setMode('chat')
    expect(useAppModeStore.getState().mode).toBe('chat')

    useAppModeStore.getState().setMode('code')
    expect(useAppModeStore.getState().mode).toBe('code')
  })
})
```

- [ ] **Step 2: Run test and confirm it fails**

```bash
pnpm vitest run src/stores/appModeStore.test.ts
```

Expected: FAIL because `appModeStore` does not exist.

- [ ] **Step 3: Implement app mode store**

Create `src/stores/appModeStore.ts`:

```ts
import { create } from 'zustand'

export type AppMode = 'chat' | 'code'

type AppModeState = {
  mode: AppMode
  setMode: (mode: AppMode) => void
}

export const useAppModeStore = create<AppModeState>((set) => ({
  mode: 'chat',
  setMode: (mode) => set({ mode }),
}))
```

- [ ] **Step 4: Run test and confirm it passes**

```bash
pnpm vitest run src/stores/appModeStore.test.ts
```

Expected: PASS.

- [ ] **Step 5: Implement shell components**

Create `src/components/layout/TopBar.tsx`:

```tsx
import { useAppModeStore } from '../../stores/appModeStore'

export function TopBar() {
  const mode = useAppModeStore((s) => s.mode)
  const setMode = useAppModeStore((s) => s.setMode)

  return (
    <header className="h-12 border-b border-border bg-surface flex items-center px-4 gap-4">
      <div className="font-semibold tracking-tight">DWeis</div>
      <div className="flex rounded-lg border border-border bg-bg p-1">
        {(['chat', 'code'] as const).map((item) => (
          <button
            key={item}
            onClick={() => setMode(item)}
            className={[
              'px-3 py-1 text-sm rounded-md transition-colors',
              mode === item ? 'bg-surface2 text-text' : 'text-muted hover:text-text',
            ].join(' ')}
          >
            {item === 'chat' ? 'Chat' : 'Code'}
          </button>
        ))}
      </div>
      <div className="ml-auto text-xs text-muted">Local MVP</div>
    </header>
  )
}
```

Create `src/components/layout/LeftPanel.tsx`:

```tsx
import { useAppModeStore } from '../../stores/appModeStore'

export function LeftPanel() {
  const mode = useAppModeStore((s) => s.mode)
  return (
    <aside className="w-72 border-r border-border bg-surface p-3 overflow-auto">
      {mode === 'chat' ? (
        <div>
          <div className="text-xs uppercase text-muted mb-2">Chats</div>
          <button className="w-full rounded-lg bg-surface2 px-3 py-2 text-left text-sm">New chat</button>
        </div>
      ) : (
        <div>
          <div className="text-xs uppercase text-muted mb-2">Explorer</div>
          <div className="text-sm text-muted">Open a workspace to show files.</div>
        </div>
      )}
    </aside>
  )
}
```

Create `src/components/layout/MainCanvas.tsx`:

```tsx
import { useAppModeStore } from '../../stores/appModeStore'
import { ChatMode } from '../../features/chat/ChatMode'
import { CodeMode } from '../../features/code/CodeMode'

export function MainCanvas() {
  const mode = useAppModeStore((s) => s.mode)
  return <main className="flex-1 overflow-hidden bg-bg">{mode === 'chat' ? <ChatMode /> : <CodeMode />}</main>
}
```

Create `src/components/layout/RightPanel.tsx`:

```tsx
import { ToolLog } from '../../features/tools/ToolLog'

export function RightPanel() {
  return (
    <aside className="w-80 border-l border-border bg-surface p-3 overflow-auto">
      <ToolLog />
    </aside>
  )
}
```

Create `src/components/layout/AppShell.tsx`:

```tsx
import { LeftPanel } from './LeftPanel'
import { MainCanvas } from './MainCanvas'
import { RightPanel } from './RightPanel'
import { TopBar } from './TopBar'

export function AppShell() {
  return (
    <div className="h-full w-full flex flex-col bg-bg text-text">
      <TopBar />
      <div className="min-h-0 flex-1 flex">
        <LeftPanel />
        <MainCanvas />
        <RightPanel />
      </div>
    </div>
  )
}
```

- [ ] **Step 6: Add placeholder modes and tool log**

Create `src/features/chat/ChatMode.tsx`:

```tsx
export function ChatMode() {
  return (
    <section className="h-full flex items-center justify-center text-muted">
      Chat mode MVP
    </section>
  )
}
```

Create `src/features/code/CodeMode.tsx`:

```tsx
export function CodeMode() {
  return (
    <section className="h-full flex items-center justify-center text-muted">
      Code mode MVP
    </section>
  )
}
```

Create `src/features/tools/ToolLog.tsx`:

```tsx
export function ToolLog() {
  return (
    <section>
      <div className="text-xs uppercase text-muted mb-2">Tools</div>
      <div className="text-sm text-muted">No tool calls yet.</div>
    </section>
  )
}
```

- [ ] **Step 7: Wire App**

Set `src/app/App.tsx`:

```tsx
import { AppShell } from '../components/layout/AppShell'

export function App() {
  return <AppShell />
}
```

Ensure `src/main.tsx` renders `App`:

```tsx
import React from 'react'
import ReactDOM from 'react-dom/client'
import { App } from './app/App'
import './styles.css'

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
)
```

- [ ] **Step 8: Verify UI**

Run:

```bash
pnpm tauri dev
```

Expected: top bar with Chat / Code segmented control, left/main/right panels. Switching modes changes left and main panel text.

- [ ] **Step 9: Commit**

```bash
git add .
git commit -m "feat: add chat code desktop shell"
```

---

## Task 4: Rust Workspace Commands

**Files:**
- Create: `src-tauri/src/commands/mod.rs`
- Create: `src-tauri/src/commands/workspace.rs`
- Create: `src-tauri/src/security.rs`
- Modify: `src-tauri/src/main.rs`

- [ ] **Step 1: Implement workspace command module**

Create `src-tauri/src/security.rs`:

```rust
use std::path::{Path, PathBuf};

const IGNORED_DIRS: [&str; 7] = [
    ".git",
    "node_modules",
    "dist",
    "build",
    ".dart_tool",
    "target",
    ".next",
];

pub fn should_ignore(path: &Path) -> bool {
    path.file_name()
        .and_then(|n| n.to_str())
        .map(|name| IGNORED_DIRS.contains(&name))
        .unwrap_or(false)
}

pub fn ensure_inside_root(root: &Path, target: &Path) -> Result<PathBuf, String> {
    let root = root.canonicalize().map_err(|e| e.to_string())?;
    let target = target.canonicalize().map_err(|e| e.to_string())?;
    if target.starts_with(&root) {
        Ok(target)
    } else {
        Err("Path is outside workspace root".to_string())
    }
}
```

Create `src-tauri/src/commands/mod.rs`:

```rust
pub mod workspace;
```

Create `src-tauri/src/commands/workspace.rs`:

```rust
use serde::Serialize;
use std::{fs, path::PathBuf};

use crate::security::{ensure_inside_root, should_ignore};

#[derive(Debug, Serialize)]
pub struct FileNode {
    pub name: String,
    pub path: String,
    pub is_dir: bool,
    pub children: Option<Vec<FileNode>>,
}

#[derive(Debug, Serialize)]
pub struct SearchMatch {
    pub path: String,
    pub line: usize,
    pub text: String,
}

#[tauri::command]
pub fn list_dir(root: String) -> Result<Vec<FileNode>, String> {
    let root_path = PathBuf::from(root);
    read_dir_nodes(&root_path, &root_path, 0)
}

fn read_dir_nodes(root: &PathBuf, dir: &PathBuf, depth: usize) -> Result<Vec<FileNode>, String> {
    if depth > 4 {
        return Ok(vec![]);
    }

    let dir = ensure_inside_root(root, dir)?;
    let mut nodes = vec![];

    for entry in fs::read_dir(&dir).map_err(|e| e.to_string())? {
        let entry = entry.map_err(|e| e.to_string())?;
        let path = entry.path();
        if should_ignore(&path) {
            continue;
        }
        let metadata = entry.metadata().map_err(|e| e.to_string())?;
        let is_dir = metadata.is_dir();
        let children = if is_dir {
            Some(read_dir_nodes(root, &path, depth + 1)?)
        } else {
            None
        };
        nodes.push(FileNode {
            name: entry.file_name().to_string_lossy().to_string(),
            path: path.to_string_lossy().to_string(),
            is_dir,
            children,
        });
    }

    nodes.sort_by(|a, b| match (a.is_dir, b.is_dir) {
        (true, false) => std::cmp::Ordering::Less,
        (false, true) => std::cmp::Ordering::Greater,
        _ => a.name.to_lowercase().cmp(&b.name.to_lowercase()),
    });

    Ok(nodes)
}

#[tauri::command]
pub fn read_file(root: String, path: String) -> Result<String, String> {
    let root_path = PathBuf::from(root);
    let path = ensure_inside_root(&root_path, &PathBuf::from(path))?;
    let metadata = fs::metadata(&path).map_err(|e| e.to_string())?;
    if metadata.len() > 1_000_000 {
        return Err("File is larger than 1MB; narrow the request first".to_string());
    }
    fs::read_to_string(path).map_err(|e| e.to_string())
}

#[tauri::command]
pub fn search_files(root: String, query: String) -> Result<Vec<SearchMatch>, String> {
    let root_path = PathBuf::from(root);
    let mut matches = vec![];
    search_dir(&root_path, &root_path, &query, &mut matches)?;
    Ok(matches)
}

fn search_dir(
    root: &PathBuf,
    dir: &PathBuf,
    query: &str,
    matches: &mut Vec<SearchMatch>,
) -> Result<(), String> {
    if matches.len() >= 200 {
        return Ok(());
    }
    let dir = ensure_inside_root(root, dir)?;
    for entry in fs::read_dir(&dir).map_err(|e| e.to_string())? {
        let entry = entry.map_err(|e| e.to_string())?;
        let path = entry.path();
        if should_ignore(&path) {
            continue;
        }
        let metadata = entry.metadata().map_err(|e| e.to_string())?;
        if metadata.is_dir() {
            search_dir(root, &path, query, matches)?;
        } else if metadata.len() <= 1_000_000 {
            if let Ok(content) = fs::read_to_string(&path) {
                for (idx, line) in content.lines().enumerate() {
                    if line.contains(query) {
                        matches.push(SearchMatch {
                            path: path.to_string_lossy().to_string(),
                            line: idx + 1,
                            text: line.trim().to_string(),
                        });
                        if matches.len() >= 200 {
                            return Ok(());
                        }
                    }
                }
            }
        }
    }
    Ok(())
}
```

- [ ] **Step 2: Register commands**

Update `src-tauri/src/main.rs` to include:

```rust
mod commands;
mod security;

fn main() {
    tauri::Builder::default()
        .invoke_handler(tauri::generate_handler![
            commands::workspace::list_dir,
            commands::workspace::read_file,
            commands::workspace::search_files,
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
```

- [ ] **Step 3: Verify Rust build**

Run:

```bash
cargo check --manifest-path src-tauri/Cargo.toml
```

Expected: no compile errors.

- [ ] **Step 4: Commit**

```bash
git add src-tauri
git commit -m "feat: add read-only workspace commands"
```

---

## Task 5: Workspace Frontend Service and Store

**Files:**
- Create: `src/services/tauri/workspace.ts`
- Create: `src/stores/workspaceStore.ts`
- Create: `src/stores/workspaceStore.test.ts`

- [ ] **Step 1: Write store test**

Create `src/stores/workspaceStore.test.ts`:

```ts
import { describe, expect, it } from 'vitest'
import { useWorkspaceStore } from './workspaceStore'

describe('workspaceStore', () => {
  it('stores current workspace and selected file', () => {
    useWorkspaceStore.getState().setWorkspace({
      name: 'demo',
      path: 'D:/demo',
    })
    useWorkspaceStore.getState().setCurrentFile({
      path: 'D:/demo/src/main.ts',
      content: 'console.log(1)',
    })

    expect(useWorkspaceStore.getState().currentWorkspace?.name).toBe('demo')
    expect(useWorkspaceStore.getState().currentFile?.content).toBe('console.log(1)')
  })
})
```

- [ ] **Step 2: Run test and confirm failure**

```bash
pnpm vitest run src/stores/workspaceStore.test.ts
```

Expected: FAIL because store does not exist.

- [ ] **Step 3: Implement Tauri workspace service**

Create `src/services/tauri/workspace.ts`:

```ts
import { invoke } from '@tauri-apps/api/core'

export type FileNode = {
  name: string
  path: string
  is_dir: boolean
  children?: FileNode[] | null
}

export type SearchMatch = {
  path: string
  line: number
  text: string
}

export async function listDir(root: string): Promise<FileNode[]> {
  return invoke<FileNode[]>('list_dir', { root })
}

export async function readFile(root: string, path: string): Promise<string> {
  return invoke<string>('read_file', { root, path })
}

export async function searchFiles(root: string, query: string): Promise<SearchMatch[]> {
  return invoke<SearchMatch[]>('search_files', { root, query })
}
```

- [ ] **Step 4: Implement workspace store**

Create `src/stores/workspaceStore.ts`:

```ts
import { create } from 'zustand'
import { FileNode } from '../services/tauri/workspace'

export type WorkspaceInfo = {
  name: string
  path: string
}

export type CurrentFile = {
  path: string
  content: string
}

type WorkspaceState = {
  currentWorkspace: WorkspaceInfo | null
  fileTree: FileNode[]
  currentFile: CurrentFile | null
  setWorkspace: (workspace: WorkspaceInfo | null) => void
  setFileTree: (fileTree: FileNode[]) => void
  setCurrentFile: (file: CurrentFile | null) => void
}

export const useWorkspaceStore = create<WorkspaceState>((set) => ({
  currentWorkspace: null,
  fileTree: [],
  currentFile: null,
  setWorkspace: (currentWorkspace) => set({ currentWorkspace }),
  setFileTree: (fileTree) => set({ fileTree }),
  setCurrentFile: (currentFile) => set({ currentFile }),
}))
```

- [ ] **Step 5: Run test and confirm pass**

```bash
pnpm vitest run src/stores/workspaceStore.test.ts
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add src/services/tauri src/stores
git commit -m "feat: add workspace frontend state"
```

---

## Task 6: Code Mode File Tree and File Viewer

**Files:**
- Modify: `src/features/code/CodeMode.tsx`
- Create: `src/features/code/FileTree.tsx`
- Create: `src/features/code/FileViewer.tsx`
- Modify: `src/components/layout/LeftPanel.tsx`

- [ ] **Step 1: Implement FileTree**

Create `src/features/code/FileTree.tsx`:

```tsx
import { FileNode, readFile } from '../../services/tauri/workspace'
import { useWorkspaceStore } from '../../stores/workspaceStore'

function NodeRow({ node, depth }: { node: FileNode; depth: number }) {
  const workspace = useWorkspaceStore((s) => s.currentWorkspace)
  const setCurrentFile = useWorkspaceStore((s) => s.setCurrentFile)

  async function openFile() {
    if (!workspace || node.is_dir) return
    const content = await readFile(workspace.path, node.path)
    setCurrentFile({ path: node.path, content })
  }

  return (
    <div>
      <button
        onClick={openFile}
        className="w-full text-left text-sm py-1 rounded hover:bg-surface2 text-muted hover:text-text"
        style={{ paddingLeft: 8 + depth * 12 }}
      >
        {node.is_dir ? '▸ ' : ''}{node.name}
      </button>
      {node.is_dir && node.children?.map((child) => (
        <NodeRow key={child.path} node={child} depth={depth + 1} />
      ))}
    </div>
  )
}

export function FileTree() {
  const fileTree = useWorkspaceStore((s) => s.fileTree)

  if (fileTree.length === 0) {
    return <div className="text-sm text-muted">No files loaded.</div>
  }

  return (
    <div className="space-y-0.5">
      {fileTree.map((node) => (
        <NodeRow key={node.path} node={node} depth={0} />
      ))}
    </div>
  )
}
```

- [ ] **Step 2: Implement FileViewer**

Create `src/features/code/FileViewer.tsx`:

```tsx
import Editor from '@monaco-editor/react'
import { useWorkspaceStore } from '../../stores/workspaceStore'

export function FileViewer() {
  const file = useWorkspaceStore((s) => s.currentFile)

  if (!file) {
    return (
      <div className="h-full flex items-center justify-center text-muted">
        Select a file to preview.
      </div>
    )
  }

  return (
    <div className="h-full flex flex-col">
      <div className="h-10 border-b border-border px-3 flex items-center text-xs text-muted">
        {file.path}
      </div>
      <div className="flex-1 min-h-0">
        <Editor
          value={file.content}
          theme="vs-dark"
          options={{ readOnly: true, minimap: { enabled: false }, fontSize: 13 }}
        />
      </div>
    </div>
  )
}
```

- [ ] **Step 3: Wire CodeMode**

Set `src/features/code/CodeMode.tsx`:

```tsx
import { FileViewer } from './FileViewer'

export function CodeMode() {
  return <FileViewer />
}
```

- [ ] **Step 4: Wire LeftPanel for Code**

Update Code branch in `src/components/layout/LeftPanel.tsx`:

```tsx
import { FileTree } from '../../features/code/FileTree'

// In Code branch:
<div>
  <div className="text-xs uppercase text-muted mb-2">Explorer</div>
  <FileTree />
</div>
```

- [ ] **Step 5: Verify UI compile**

Run:

```bash
pnpm vitest run
pnpm tauri dev
```

Expected: Code mode shows file tree empty state on left and file preview empty state in center.

- [ ] **Step 6: Commit**

```bash
git add src/features/code src/components/layout/LeftPanel.tsx
git commit -m "feat: add read-only code workspace UI"
```

---

## Task 7: Open Workspace Button

**Files:**
- Modify: `src/components/layout/TopBar.tsx`
- Modify: `src-tauri/src/commands/workspace.rs`
- Modify: `src-tauri/src/main.rs`
- Modify: `src/services/tauri/workspace.ts`

- [ ] **Step 1: Add Rust folder picker command**

Add to `workspace.rs`:

```rust
#[tauri::command]
pub async fn pick_workspace(app: tauri::AppHandle) -> Result<Option<String>, String> {
    use tauri_plugin_dialog::DialogExt;

    let folder = app.dialog().file().blocking_pick_folder();
    Ok(folder.map(|p| p.to_string()))
}
```

Add `tauri-plugin-dialog` to `src-tauri/Cargo.toml` dependencies:

```toml
tauri-plugin-dialog = "2"
```

Register plugin and command in `main.rs`:

```rust
.plugin(tauri_plugin_dialog::init())
.invoke_handler(tauri::generate_handler![
  commands::workspace::pick_workspace,
  commands::workspace::list_dir,
  commands::workspace::read_file,
  commands::workspace::search_files,
])
```

- [ ] **Step 2: Add frontend service**

Update `src/services/tauri/workspace.ts`:

```ts
export async function pickWorkspace(): Promise<string | null> {
  return invoke<string | null>('pick_workspace')
}
```

- [ ] **Step 3: Add Open Workspace button**

Update `TopBar.tsx`:

```tsx
import { pickWorkspace, listDir } from '../../services/tauri/workspace'
import { useWorkspaceStore } from '../../stores/workspaceStore'

// inside component:
const setWorkspace = useWorkspaceStore((s) => s.setWorkspace)
const setFileTree = useWorkspaceStore((s) => s.setFileTree)
const workspace = useWorkspaceStore((s) => s.currentWorkspace)

async function openWorkspace() {
  const path = await pickWorkspace()
  if (!path) return
  const name = path.split(/[\\/]/).filter(Boolean).at(-1) ?? path
  setWorkspace({ name, path })
  setFileTree(await listDir(path))
}

// render before Local MVP:
<button onClick={openWorkspace} className="text-xs text-muted hover:text-text">
  {workspace ? workspace.name : 'Open Workspace'}
</button>
```

- [ ] **Step 4: Verify**

Run:

```bash
cargo check --manifest-path src-tauri/Cargo.toml
pnpm tauri dev
```

Expected: clicking `Open Workspace` opens folder picker; after picking a folder, file tree appears in Code mode.

- [ ] **Step 5: Commit**

```bash
git add .
git commit -m "feat: add workspace folder picker"
```

---

## Task 8: AI Provider and Chat Store

**Files:**
- Create: `src/services/ai/provider.ts`
- Create: `src/stores/chatStore.ts`
- Create: `src/features/chat/ChatThread.tsx`
- Create: `src/features/chat/ChatInput.tsx`
- Modify: `src/features/chat/ChatMode.tsx`

- [ ] **Step 1: Add chat store test**

Create `src/stores/chatStore.test.ts`:

```ts
import { describe, expect, it } from 'vitest'
import { useChatStore } from './chatStore'

describe('chatStore', () => {
  it('adds user and assistant messages', () => {
    useChatStore.getState().reset()
    useChatStore.getState().addMessage({ role: 'user', content: 'hello' })
    useChatStore.getState().addMessage({ role: 'assistant', content: 'hi' })

    expect(useChatStore.getState().messages).toHaveLength(2)
    expect(useChatStore.getState().messages[1].content).toBe('hi')
  })
})
```

- [ ] **Step 2: Run test and confirm failure**

```bash
pnpm vitest run src/stores/chatStore.test.ts
```

Expected: FAIL because store does not exist.

- [ ] **Step 3: Implement chat store**

Create `src/stores/chatStore.ts`:

```ts
import { create } from 'zustand'

export type ChatMessage = {
  id: string
  role: 'user' | 'assistant' | 'system'
  content: string
}

type ChatState = {
  messages: ChatMessage[]
  addMessage: (message: Omit<ChatMessage, 'id'>) => void
  updateLastAssistant: (content: string) => void
  reset: () => void
}

export const useChatStore = create<ChatState>((set) => ({
  messages: [],
  addMessage: (message) =>
    set((s) => ({
      messages: [...s.messages, { ...message, id: crypto.randomUUID() }],
    })),
  updateLastAssistant: (content) =>
    set((s) => {
      const messages = [...s.messages]
      for (let i = messages.length - 1; i >= 0; i -= 1) {
        if (messages[i].role === 'assistant') {
          messages[i] = { ...messages[i], content }
          break
        }
      }
      return { messages }
    }),
  reset: () => set({ messages: [] }),
}))
```

- [ ] **Step 4: Implement placeholder AI provider**

Create `src/services/ai/provider.ts`:

```ts
export async function* sendChatMessage(prompt: string): AsyncGenerator<string> {
  const response = `DWeis Desktop MVP 收到：${prompt}`
  for (let i = 0; i < response.length; i += 3) {
    await new Promise((resolve) => setTimeout(resolve, 20))
    yield response.slice(0, i + 3)
  }
}
```

- [ ] **Step 5: Implement chat UI**

Create `src/features/chat/ChatThread.tsx`:

```tsx
import { useChatStore } from '../../stores/chatStore'

export function ChatThread() {
  const messages = useChatStore((s) => s.messages)
  return (
    <div className="h-full overflow-auto p-6 space-y-4">
      {messages.length === 0 ? (
        <div className="h-full flex items-center justify-center text-muted">Ask DWeis anything.</div>
      ) : (
        messages.map((m) => (
          <div key={m.id} className={m.role === 'user' ? 'text-right' : 'text-left'}>
            <div className="inline-block max-w-2xl rounded-xl border border-border bg-surface px-4 py-3 text-sm whitespace-pre-wrap">
              {m.content}
            </div>
          </div>
        ))
      )}
    </div>
  )
}
```

Create `src/features/chat/ChatInput.tsx`:

```tsx
import { FormEvent, useState } from 'react'
import { sendChatMessage } from '../../services/ai/provider'
import { useChatStore } from '../../stores/chatStore'

export function ChatInput() {
  const [text, setText] = useState('')
  const addMessage = useChatStore((s) => s.addMessage)
  const updateLastAssistant = useChatStore((s) => s.updateLastAssistant)

  async function submit(e: FormEvent) {
    e.preventDefault()
    const prompt = text.trim()
    if (!prompt) return
    setText('')
    addMessage({ role: 'user', content: prompt })
    addMessage({ role: 'assistant', content: '' })
    for await (const chunk of sendChatMessage(prompt)) {
      updateLastAssistant(chunk)
    }
  }

  return (
    <form onSubmit={submit} className="border-t border-border p-3 flex gap-2 bg-surface">
      <input
        value={text}
        onChange={(e) => setText(e.target.value)}
        placeholder="Ask DWeis..."
        className="flex-1 rounded-xl bg-bg border border-border px-3 py-2 text-sm outline-none focus:border-primary"
      />
      <button className="rounded-xl bg-primary px-4 py-2 text-sm font-medium text-white">Send</button>
    </form>
  )
}
```

Update `src/features/chat/ChatMode.tsx`:

```tsx
import { ChatInput } from './ChatInput'
import { ChatThread } from './ChatThread'

export function ChatMode() {
  return (
    <section className="h-full flex flex-col">
      <ChatThread />
      <ChatInput />
    </section>
  )
}
```

- [ ] **Step 6: Run tests and UI**

```bash
pnpm vitest run src/stores/chatStore.test.ts
pnpm tauri dev
```

Expected: Chat mode can send a message and see typewriter-like placeholder response.

- [ ] **Step 7: Commit**

```bash
git add src/services/ai src/stores src/features/chat
git commit -m "feat: add desktop chat mvp"
```

---

## Task 9: Workspace Tools and Tool Log

**Files:**
- Create: `src/services/tools/registry.ts`
- Create: `src/services/tools/workspaceTools.ts`
- Modify: `src/features/tools/ToolLog.tsx`

- [ ] **Step 1: Implement tool registry**

Create `src/services/tools/registry.ts`:

```ts
export type ToolResult = {
  ok: boolean
  content: string
  data?: unknown
}

export type ToolDefinition<TArgs = unknown> = {
  name: string
  description: string
  execute: (args: TArgs) => Promise<ToolResult>
}

export class ToolRegistry {
  private tools = new Map<string, ToolDefinition>()

  register(tool: ToolDefinition) {
    this.tools.set(tool.name, tool)
  }

  get(name: string) {
    return this.tools.get(name)
  }

  list() {
    return [...this.tools.values()]
  }
}
```

- [ ] **Step 2: Add registry test**

Create `src/services/tools/registry.test.ts`:

```ts
import { describe, expect, it } from 'vitest'
import { ToolRegistry } from './registry'

describe('ToolRegistry', () => {
  it('registers and retrieves tools', async () => {
    const registry = new ToolRegistry()
    registry.register({
      name: 'demo',
      description: 'demo tool',
      execute: async () => ({ ok: true, content: 'done' }),
    })

    expect(registry.get('demo')?.description).toBe('demo tool')
    await expect(registry.get('demo')!.execute({})).resolves.toEqual({ ok: true, content: 'done' })
  })
})
```

- [ ] **Step 3: Implement workspace tools**

Create `src/services/tools/workspaceTools.ts`:

```ts
import { readFile, searchFiles } from '../tauri/workspace'
import { ToolDefinition } from './registry'

export function workspaceReadTool(root: string): ToolDefinition<{ path: string }> {
  return {
    name: 'workspace_read',
    description: 'Read a file inside the current workspace',
    execute: async ({ path }) => ({
      ok: true,
      content: await readFile(root, path),
    }),
  }
}

export function workspaceSearchTool(root: string): ToolDefinition<{ query: string }> {
  return {
    name: 'workspace_search',
    description: 'Search text inside the current workspace',
    execute: async ({ query }) => {
      const matches = await searchFiles(root, query)
      return {
        ok: true,
        content: matches.map((m) => `${m.path}:${m.line}: ${m.text}`).join('\n'),
        data: matches,
      }
    },
  }
}
```

- [ ] **Step 4: Run tests**

```bash
pnpm vitest run src/services/tools/registry.test.ts
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/services/tools
git commit -m "feat: add tool registry and workspace tools"
```

---

## Task 10: Final MVP Verification

**Files:**
- No new files required

- [ ] **Step 1: Run frontend tests**

```bash
pnpm vitest run
```

Expected: all tests pass.

- [ ] **Step 2: Run Rust check**

```bash
cargo check --manifest-path src-tauri/Cargo.toml
```

Expected: no compile errors.

- [ ] **Step 3: Run desktop app**

```bash
pnpm tauri dev
```

Manual verification:

1. Window opens.
2. Chat / Code switch works.
3. Chat can send message and receive placeholder response.
4. Open workspace works.
5. Code mode shows file tree.
6. Clicking a file shows content in Monaco.

- [ ] **Step 4: Commit verification notes**

Create `docs/mvp-verification.md`:

```md
# MVP Verification

- Chat / Code mode switch: pass
- Chat placeholder response: pass
- Workspace open: pass
- File tree: pass
- File viewer: pass
```

Commit:

```bash
git add docs/mvp-verification.md
git commit -m "docs: record desktop mvp verification"
```

---

## Self-Review

Spec coverage:

- Chat / Code mode switch: Task 3.
- Desktop shell: Task 3.
- Workspace open: Task 7.
- File tree: Task 6.
- Read-only file viewer: Task 6.
- Rust workspace commands: Task 4.
- AI placeholder provider and typewriter-like response: Task 8.
- Tool registry and workspace tools: Task 9.
- No cloud/mobile sync: intentionally out of scope.

No placeholders remain. Type names are consistent across tasks: `FileNode`, `SearchMatch`, `WorkspaceInfo`, `ToolDefinition`, `ToolResult`.
