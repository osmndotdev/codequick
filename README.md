# CodeQuick

Quick project manager for macOS/Zsh that helps you manage and navigate between projects.

## Features

- Create, copy, rename, and remove projects
- Quick project navigation with fuzzy finding
- Open projects in your preferred app/editor
- Automatic window title management for VSCode-based editors
- Projects stored in a centralized location with clean symlinks
- Clipboard integration for project names
- macOS Trash integration for safe deletion

## How it Works

Projects are stored in `/Users/osman/aa/code/_cq/`:

- `reals/` - Contains actual project directories with unique IDs (e.g., `cq-Ab3Xf9G2`)
- `links/` - Contains symlinks with human-readable names pointing to real directories

Link names are automatically sanitized to kebab-case (lowercase, hyphens only).

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
   source /Users/osman/aa/code/shell/codequick/contrib/cq.zsh
   ```

## Usage

### Create a new project

```bash
cq mk my-project
```

Creates a new project with a unique real directory and a symlink named `my-project`.

### Copy an existing project

```bash
cq cp my-project backup
```

Creates a copy of `my-project` named `my-project__backup`.

### Rename a project

```bash
cq rename my-project my-new-project
```

Renames the symlink (the real directory remains unchanged).

### List and select projects

```bash
cq ls
```

Opens an interactive fzf menu. Press Enter to copy the selected project name to clipboard.

### Change directory to a project

```bash
cq cd
```

Opens an interactive fzf menu and changes your shell's working directory to the selected project.
_Requires the zsh wrapper to be loaded._

### Open a project in an app/editor

```bash
cq open <fx|vsc|cur|agy|zed>
```

Opens an interactive fzf menu and launches the selected project in the specified app/editor:

- `fx` - Finder (macOS file explorer)
- `vsc` - Visual Studio Code
- `cur` - Cursor
- `agy` - Antigravity
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

Moves both the symlink and the real directory to the macOS Trash.

## Known Issues

- When renaming a project, if the `.vscode/settings.json` file has comments in it, the `jq` command will fail to parse the file and the file will not be updated. If you see the error, you can manually update the window title and delete the empty `.vscode/settings.json.tmp` file.
