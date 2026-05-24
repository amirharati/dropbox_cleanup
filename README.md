# dropbox_cleanup

Keep dev projects in Dropbox without syncing regenerable junk (`node_modules/`, builds, caches, logs, etc.).

## Two layers (use both)

| Layer | Mechanism | Scope | When |
|-------|-----------|--------|------|
| **Phase 1 — `sync-rules`** | `~/Dropbox/rules.dropboxignore` read by the **Dropbox app** | **Global** — entire Dropbox folder | Ongoing; new matching paths don’t upload |
| **Phase 2 — `apply` / `apply-git`** | macOS `xattr com.dropbox.ignored` → Dropbox app stops syncing | **Only** paths under your `scan_root`s (or `--root`) | One-time cleanup + occasional re-runs |

**Why both?**

- **Rules** = autopilot for the **future** (`npm install`, new projects). No script after every install.
- **Apply** = fix **past** junk already on dropbox.com. Dropbox does not retroactively apply rules to folders that were already syncing.

Rules do **not** call the Dropbox API. `apply` only sets a **local flag**; the desktop app changes sync behavior.

## Quick start

```bash
cd ~/Dropbox/CodingProjects/personal_tools/dropbox_cleanup

# Phase 1 — future uploads (once, re-run when rules change)
./dropbox-cleanup.sh sync-rules

# Preview Phase 2 (summary only; progress on stderr)
./dropbox-cleanup.sh scan

# Phase 2 — prefer git-aware first, then pattern-based
./dropbox-cleanup.sh apply-git --dry-run   # needs dbx-ignore for full .gitignore
./dropbox-cleanup.sh apply-git
./dropbox-cleanup.sh apply --dry-run
./dropbox-cleanup.sh apply
```

## Config

Copy `config.example` → `config.local` (gitignored) or edit `config`:

```text
dropbox_root=~/Dropbox
scan_root=~/Dropbox/CodingProjects
scan_root=~/Dropbox/OtherProjects
scan_top=15
```

- **`~` works** — use `~/Dropbox`, not `$HOME/~/Dropbox`.
- **Full paths** are fine too.
- **Priority:** `config.local` → `config` → env (`DROPBOX_ROOT`, `SCAN_ROOT`).

## Scoping: one folder vs everything

Scripts walk **`scan_root`** entries (and subfolders). Rules at Dropbox root still apply **globally**.

| Method | Use when |
|--------|----------|
| **Config** `scan_root=...` | Default trees you always scan/apply |
| **One-off env** | `SCAN_ROOT=~/path/to/project ./dropbox-cleanup.sh apply` |
| **`--root`** | Same as env, no file edit: |

```bash
./dropbox-cleanup.sh scan --root ~/Dropbox/CodingProjects/personal_tools/workbench_agent
./dropbox-cleanup.sh apply-git --root ~/path/to/project --dry-run
./dropbox-cleanup.sh apply --root ~/path/to/project
```

Repeat `--root` for multiple paths in one run.

## Commands

| Command | Description |
|---------|-------------|
| `sync-rules` | Copy `rules/rules.dropboxignore` → `~/Dropbox/rules.dropboxignore` |
| `scan [--root <path>] [-v]` | Summary by pattern / root + top N largest (`-v` = every directory) |
| `apply [--root <path>] [--dry-run] [-v]` | Mark dirs matching **rules** name patterns (+ scoped paths in rules file). Full-tree run is **slow** (many `find` passes); use `--root` to preview one project. Progress prints on **stderr**. |
| `apply-git [--root <path>] [--dry-run]` | Mark paths from each repo’s **`.gitignore`** (safer in git trees) |
| `unignore <path> ...` | Remove ignore marker from a path |

### `apply` vs `apply-git`

Same result (local `com.dropbox.ignored` → Dropbox stops cloud sync). Different **source of truth**:

| | `apply` | `apply-git` |
|--|---------|-------------|
| **Decides paths from** | `rules/rules.dropboxignore` (e.g. `node_modules/`, `dist/`) | `.gitignore` per repo |
| **Repos** | Any folder under scan root | Git repos only |
| **Safer for source code?** | Broader (any folder named `build/`, etc.) | Yes — only git-ignored paths |

Recommended: **`apply-git` first**, then **`apply`** for non-git trees or rules-only paths (e.g. scoped `runs/`).

**`dbx-ignore` is not bundled** — run once before `apply-git` (macOS + Linux x86_64):

```bash
./scripts/install-dbx-ignore.sh
# installs to ~/.local/bin/dbx-ignore — add that dir to PATH if needed
```

Verify: `command -v dbx-ignore`

Upstream `install.sh` must be run with **`bash`**, not `sh` (`| bash`). Our installer downloads the GitHub release binary directly and avoids that issue.

Without it, `apply-git` only marks **top-level** `.gitignore` directory lines (~dozens of paths, not `node_modules/` everywhere). Use **`apply`** for pattern-based cleanup, or install `dbx-ignore` for full gitignore coverage.

## Ongoing practice

You do **not** need to run `apply` on a schedule if Phase 1 rules are active.

Run Phase 2 again when:

- A new large project still uploads junk that was created **before** rules existed
- Something was cloned outside your usual `scan_root`
- You add new patterns to `rules/` and want existing trees updated

Typical habit for **one project**:

```bash
./dropbox-cleanup.sh apply-git --root ~/Dropbox/CodingProjects/my-app --dry-run
./dropbox-cleanup.sh apply-git --root ~/Dropbox/CodingProjects/my-app
```

## What `apply` does technically

```bash
xattr -w com.dropbox.ignored 1 '<path>'
```

- **Local only** from the script — no Dropbox API.
- Dropbox desktop app must be running for cloud quota/sync to update.
- **Files stay on disk**; they drop off dropbox.com and other devices over time.

## Updating rules

1. Edit `rules/rules.dropboxignore` in this repo.
2. `./dropbox-cleanup.sh sync-rules`
3. Re-run `apply` / `apply-git` if you need existing folders marked (rules alone may not fix old syncs).


## Safety

- Does **not** delete local files or change source code.
- Worst case with wrong path: folder **stops cloud backup** until `unignore` — disk copy remains.
- `.env` ignored = good for secrets; back them up elsewhere (1Password, etc.).
- `.git/` is **not** in default rules (unpushed work can still sync via Dropbox unless you add it).

## License

MIT — personal tooling.
