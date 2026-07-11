# AGENTS.md

This file provides context for AI coding agents working on this project.

## Project Overview

CodeQuick (`cq`) is a quick project manager for macOS/Zsh that helps manage and navigate between projects. It uses a two-tier directory structure with unique IDs for actual directories and human-readable symlinks.

### Core Problem Being Solved

The main motivation is enabling **project renaming without breaking IDE state**. Cursor IDE keys chat history by directory path, so changing the directory path results in lost chat history. CodeQuick solves this by keeping the real directory name constant (random ID) while allowing the user-facing name (symlink) to change freely.

Secondary benefits:

- Quick copies for comparisons, experimental refactors, and evaluating AI coding agents
- Fuzzy-searchable project navigation (since random directory names defeat tools like Autojump)

## Architecture

### Directory Structure

```
$CQ_ROOT/            # Defaults to ~/aa/code/_cq
├── reals/           # Actual project directories with unique IDs (e.g., cq-Ab3Xf9G2)
└── links/           # Symlinks with human-readable names pointing to reals/
```

Symlinks use **relative paths** (`../reals/<id>`) to keep the structure portable.

### Key Design Decisions

1. **Separation of Identity and Name**: Real directories use unique IDs (`cq-XXXXXXXX`) while symlinks provide human-readable names. This allows renaming projects without breaking IDE workspace associations (like Cursor's chat history).

2. **Window Title Management**: When creating, copying, or renaming projects, the `.vscode/settings.json` file is automatically updated with `window.title` set to the friendly name. This ensures Cursor IDE displays the human-readable name instead of the internal ID.

3. **Symlink-based Navigation**: Commands like `ls`, `cd`, `open` work through the links directory. The `open` command resolves to the real path for proper file watching.

4. **Kebab-case Sanitization**: All project names are automatically sanitized to lowercase kebab-case (hyphens only, no spaces or special characters). Duplicate link names (including after sanitization) are rejected.

5. **Recent Access Ordering**: `get_sorted_links` returns links sorted by modification time (`ls -1t`), and `record_access` touches the symlink (using `touch -h` to touch the link itself, not the target) to update its timestamp when accessed.

6. **Copy Strategy**: Uses `cp -a -c` which preserves attributes (`-a`) and uses copy-on-write/cloning when possible (`-c`). Includes dotfiles and `.git`.

7. **Safe Deletion**: Uses macOS `trash` command instead of `rm` for recovery.

## File Structure

| File             | Purpose                                             |
| ---------------- | --------------------------------------------------- |
| `bin/cq`         | Main executable (Zsh script)                        |
| `contrib/cq.zsh` | Zsh wrapper for shell integration (enables `cq cd`) |
| `test/smoke.zsh` | Smoke test (sandboxed CQ_ROOT, stubbed deps)        |
| `README.md`      | User documentation                                  |

## Key Implementation Details

### Direct Selection vs. fzf

The selection commands (`ls`, `lookup`, `cd`, `open`) accept an optional project name, handled by the shared `select_link` helper: an exact match skips fzf entirely; otherwise the name prefills fzf's query with `--select-1` (auto-select when only one project matches).

### Why the Zsh Wrapper Exists

The `cq cd` and `cq mkcd` commands need to change the **calling shell's** working directory. Since a subprocess cannot change its parent's working directory, the wrapper function intercepts them, calls the internal `cq _cd`/`cq _mkcd` command to get the path, then uses `builtin cd` to change directories within the same shell process.

### Unique Directory Names

Created with `mktemp -d "$REALS_DIR/cq-XXXXXXXX"` which generates 8 random alphanumeric characters prefixed with `cq-`.

### Dependencies

- **zsh**: Shell interpreter (primary target; Bash compatibility is nice-to-have but not guaranteed)
- **fzf**: Fuzzy finder for interactive selection
- **jq**: JSON manipulation for `.vscode/settings.json`
- **pbcopy**: Clipboard access (macOS)
- **trash**: Safe deletion to macOS Trash

### Error Handling

- Script uses `set -e` to exit on first error
- Errors are printed in red to stderr via `print_err`
- Exit code 1: Operational errors (e.g., link not found, real dir missing) and cancelled fzf selection (silent)
- Exit code 2: Usage errors (e.g., missing arguments, empty sanitized name) — always via `print_err` + `exit 2`
- An empty fzf selection prints "Nothing selected" and returns 0 (not an error)
- Prefer explicit `if` blocks over `[[ ... ]] && ... && ...` chains, which behave surprisingly under `set -e`
- `cq rm` should error clearly if either the link or real dir is missing or out of sync

### Command Reference

| Command  | Internal Function       | Description                                                                       |
| -------- | ----------------------- | --------------------------------------------------------------------------------- |
| `ls`     | `cmd_ls`                | Interactive fzf selection, copies name to clipboard                               |
| `lookup` | `cmd_lookup`            | Interactive fzf selection, copies real dir name to clipboard                      |
| `cd`     | `cmd__cd` (via wrapper) | Interactive fzf selection, changes directory                                      |
| `open`   | `cmd_open`              | Interactive fzf selection, opens in specified app/editor (fx\|vsc\|cur\|agy\|zed) |
| `mk`     | `cmd_mk`                | Creates new project, prints its real path                                        |
| `mkcd`   | `cmd__mkcd` (via wrapper) | Creates new project, changes directory into it                                 |
| `cp`     | `cmd_cp`                | Copies project with suffix (creates `<name>__<suffix>`)                           |
| `rename` | `cmd_rename`            | Renames symlink only, updates window title                                        |
| `path`   | `cmd_path`              | Outputs real path for a project                                                   |
| `rm`     | `cmd_rm`                | Moves project and symlink to Trash                                                |

## Development Notes

### Adding New Commands

1. Create a new function `cmd_<name>()` in `bin/cq`
2. Add the command to the `case` statement in `main()`
3. Add help text to the heredoc in the help case
4. If the command needs shell integration (like `cd`), update `contrib/cq.zsh`

To support a new app/editor in `cq open`, add a single entry to the `OPEN_APPS` table at the top of `bin/cq` — usage, help, and error messages derive from it (also document the alias in README).

### Testing Changes

Don't test changes against the user's real projects. Run `zsh test/smoke.zsh` — it exercises the non-interactive command paths against a throwaway `CQ_ROOT` with `pbcopy`/`trash`/`fzf` stubbed out. For ad-hoc testing, set `CQ_ROOT` to a temporary directory yourself. Interactive fzf flows still need manual testing by the user — never invoke fzf paths from automation (they hang waiting for the terminal).

### Code Style

- Functions are prefixed with `cmd_` for commands
- Helper functions are lowercase with underscores
- Use `require_arg` for argument validation
- Use `link_exists` before operations that need an existing link
- Fail early on missing args with concise error messages

### Side Effects to Remember

- Creating a new project puts it at the top of the list (newest modification time)
- Renaming a project bumps it to the top since `mv` updates modification time
- The `open` command uses the real path (not symlink) for proper file watching behavior
