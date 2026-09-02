# CodeQuick

Quick project manager for macOS/Zsh that helps you manage and navigate between projects. Its core trick: project directories keep constant, randomized names while you rename the human-facing names freely — so IDE state that is keyed by directory path (like Cursor's chat history) survives renames.

## Features

- Create, copy, rename, and remove projects
- Rename projects without breaking IDE state (e.g. Cursor chat history)
- Quick project navigation with fuzzy finding, ordered by last use
- Pass a project name directly to skip the menu
- Open projects in your preferred app/editor
- Automatic window title management for VSCode-based editors
- Projects stored in a centralized location with clean symlinks
- Clipboard integration for project names
- macOS Trash integration and confirmation prompt for safe deletion

## How it Works

Projects are stored in `~/aa/code/_cq/` by default (override with the `CQ_ROOT` environment variable):

- `reals/` - Contains actual project directories with unique IDs (e.g., `cq-Ab3Xf9G2`)
- `links/` - Contains symlinks with human-readable names pointing to real directories

Link names are automatically sanitized to kebab-case (lowercase, hyphens only). Selection menus list projects by last use, newest first.

### Window Title Management

When you create, copy, or rename a project, CodeQuick automatically manages the `.vscode/settings.json` file to set the window title to your project's friendly name. This means Cursor IDE will display `my-project` in the window title instead of the internal directory ID like `cq-Ab3Xf9G2`.

This preserves Cursor's chat history (which is keyed by directory path) while giving you the flexibility to change project names at will.

## Installation

1. Ensure you have the required dependencies:
   - `zsh`, `pbcopy`, `trash` (standard on macOS)
   - `fzf` (install with `brew install fzf`)
   - `jq` (install with `brew install jq`)

2. Source the zsh wrapper in your `~/.zshrc`:

   ```bash
   source <path-to-codequick>/contrib/cq.zsh
   ```

3. Optionally, set `CQ_ROOT` in your `~/.zshrc` to change where projects are stored (defaults to `~/aa/code/_cq`):

   ```bash
   export CQ_ROOT="$HOME/somewhere/else"
   ```

## Usage

For `ls`, `lookup`, `cd`, and `open`, the optional `project-name` argument skips the fzf menu when it matches a project exactly; otherwise it prefills the fuzzy search (auto-selecting when only one project matches).

### Create a new project

```bash
cq mk my-project
```

Creates a new project with a unique real directory and a symlink named `my-project`, and prints the real directory's path (so you can e.g. `cd "$(cq mk my-project | tail -1)"`).

### Create a new project and cd into it

```bash
cq mkcd my-project
```

Creates a new project and changes your shell's working directory to it.
_Requires the zsh wrapper to be loaded._

### Copy an existing project

```bash
cq cp my-project backup
```

Creates a copy of `my-project` named `my-project__backup`.

> **Warning:** You might have problems if the project's tooling relies on the path staying the same. For example, Turbopack's dev cache (located in `dist/dev/cache/turbopack`) doesn't automatically refresh the cached paths and needs to be manually cleared on the new copy to be regenerated. Since CodeQuick is tool-agnostic, it's up to you to ensure your tooling can handle the path change and regenerate artifacts properly.

### Rename a project

```bash
cq rename my-project my-new-project
```

Renames the symlink (the real directory remains unchanged).

### List and select projects

```bash
cq ls [project-name]
```

Opens an interactive fzf menu. Press Enter to copy the selected project name to clipboard.

### Look up a project's real directory name

```bash
cq lookup [project-name]
```

Opens an interactive fzf menu showing an aligned mapping of real directory names to project names (e.g. `cq-a1b2c3d4		my-project`), ordered by last used. Press Enter to copy the selected real directory name to clipboard.

### Change directory to a project

```bash
cq cd [project-name]
```

Opens an interactive fzf menu and changes your shell's working directory to the selected project.
_Requires the zsh wrapper to be loaded._

### Open a project in an app/editor

```bash
cq open <agy|cur|fx|vsc|zed> [project-name]
```

Opens an interactive fzf menu and launches the selected project in the specified app/editor:

- `agy` - Antigravity
- `cur` - Cursor
- `fx` - Finder (macOS file explorer)
- `vsc` - Visual Studio Code
- `zed` - Zed

### Get project path

```bash
cq path my-project
```

Prints the absolute path of the real directory for `my-project`. Useful for integrating with other CLI tools.

### Remove a project

```bash
cq rm my-project
```

Asks for confirmation, then moves both the symlink and the real directory to the macOS Trash.

## Development

Run the smoke test before committing changes:

```bash
zsh test/smoke.zsh
```

It exercises the non-interactive command paths against a throwaway `CQ_ROOT`, with `pbcopy`/`trash`/`fzf` stubbed out. See `AGENTS.md` for architecture notes and conventions.

## Known Issues

- If the `.vscode/settings.json` file has comments in it (JSONC), `jq` cannot parse it, so the window title is not updated automatically. CodeQuick prints a warning and continues; update `window.title` manually if desired.
