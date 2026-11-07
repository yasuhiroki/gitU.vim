# AGENTS.md

This document outlines the architecture and development guidelines for AI agents working on the `gitU.vim` repository.

## Project Overview

`gitU.vim` is a Vim plugin that provides Git operations within Vim.

## Implementation & Architecture Guidelines

1. **Written in Vim9 script**
   - Every script file must start with `vim9script` and follow Vim9 script syntax, type annotations, and scoping rules.
   - Do not use legacy Vim script syntax.

2. **UI and Buffer Control via Dedicated `filetype`**
   - Control UI rendering, buffer behavior, and key mappings using dedicated `gitU` filetypes (e.g., `gitu` or specific subtypes).
   - Organize buffer-specific settings and `<buffer>` key mappings in `ftplugin/` and related `autoload/` modules so they do not affect other buffers.

3. **Directory Structure (Standard Vim Plugin Layout)**
   - `plugin/`: Entry points (command definitions and minimal initial setup)
   - `autoload/`: Core logic, Git command execution, and UI control
   - `ftplugin/`: Buffer settings and key mappings for `gitU` filetypes
   - `syntax/`: Syntax highlighting definitions for `gitU` buffers
   - `doc/`: Help documentation
