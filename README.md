# gitU.vim

A Vim plugin for Git operations, written in Vim9 script.

## Features

- **3-Pane Git Log Viewer (`:GitULog`)**: Interactive commit log graph, commit details/file list, and diff preview panes in a new tab page.
- **Asynchronous Execution**: Git commands run asynchronously without freezing the editor.
- **Dedicated Filetypes & Syntax**: Buffer-local keymaps and customized syntax highlighting for `gitu-log`, `gitu-commit`, and `gitu-diff`.

## Requirements

- Vim 9.0 or later (with `vim9script` support)
- `git` command

## Usage

```vim
" Open 3-pane interactive Git log viewer
:GitULog

" Pass git log arguments
:GitULog --all
```

### Key Mappings

Within `:GitULog` panes:
- `q`: Close the GitU view and cancel background jobs
- `r`: Refresh the log view
- `<Tab>` / `<S-Tab>`: Cycle focus across panes
- `<CR>` (in log pane): Inspect commit under cursor
- `<CR>` (in commit pane): Jump to diff of the selected file

## Configuration

```vim
" Height (in rows) of the top-right commit detail pane (default: 15)
let g:gitu_commit_height = 15
```

## License

[MIT License](./LICENSE)
