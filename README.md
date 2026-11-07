# gitU.vim

A Vim plugin for Git operations, written in Vim9 script.

## Features

- **3-Pane Git Log Viewer (`:GitULog`)**: Interactive commit log graph, commit details/file list, and diff preview panes in a new tab page.
- **Interactive Git Status (`:GitUStatus` / `:GitU`)**: Fast overview of staged, unstaged, and untracked files.
  - `<<`: Stage file (`git add`)
  - `>>`: Unstage file (`git restore --staged`)
  - `dd`: View diff of the file under cursor
  - `pp`: 3-way vertical patch editor (`git add -p` / edit mode)
- **3-Way Vertical Patch Editor**: Splits the lower half of the status window into `HEAD`, `STAGE`, and `CURRENT` side-by-side in Vim diff mode. Directly updates the Git index on `:w`.
- **Asynchronous Execution**: Git commands run asynchronously without freezing the editor.
- **Dedicated Filetypes & Syntax**: Clean syntax highlighting and isolated buffer keymaps.

## Requirements

- Vim 9.0 or later (with `vim9script` and `job` support)
- `git` command

## Usage

```vim
" Open 3-pane interactive Git log viewer
:GitULog
:GitULog --all

" Open interactive Git status
:GitUStatus
:GitU
```

### Key Mappings

#### Within `:GitULog` panes:
- `q`: Close the GitU view and cancel background jobs
- `u`: Update / refresh the view
- `yy` (in log pane): Copy commit hash of the current line
- `go`: Open the commit on GitHub in the web browser
- `gp`: Open the pull request containing the commit on GitHub in the web browser
- `<Tab>` / `<S-Tab>`: Cycle focus across panes
- `<CR>` (in log pane): Inspect commit under cursor
- `<CR>` (in commit pane): Jump to diff of the selected file

#### Within `:GitUStatus` buffer:
- `<<` (Normal / Visual): Stage the file(s) under cursor or in visual selection (`git add`)
- `>>` (Normal / Visual): Unstage the file(s) under cursor or in visual selection (`git restore --staged`)
- `dd`: View diff of the file under cursor
- `pp`: Open 3-way vertical patch editor (`HEAD` | `STAGE` | `CURRENT`)
- `u`: Update / refresh the status view
- `q`: Close the status view

#### Within 3-Way Patch Editor (`pp`):
- `do` / `dp`: Pull or put diff changes across panels
- `:w` (in center STAGE panel): Write staged changes directly into the Git index
- `q`: Exit diff mode, close panels, and return to status view

## Configuration

```vim
" Height (in rows) of the top-right commit detail pane in :GitULog (default: 15)
let g:gitu_commit_height = 15

" Height (in rows) of the status window when split with diff / patch panels (default: 15)
let g:gitu_status_height = 15
```

## License

[MIT License](./LICENSE)
