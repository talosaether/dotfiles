# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a personal dotfiles repository containing configuration files for Neovim and tmux. The repository follows a modular structure using GNU Stow for symlink management.

## Repository Structure

```
dotfiles/
├── nvim/.config/nvim/          # Neovim configuration
│   ├── init.lua               # Entry point, loads lazy.nvim
│   ├── lua/config/            # Core configuration modules
│   │   ├── lazy.lua          # Plugin manager bootstrap
│   │   ├── options.lua       # Vim options
│   │   ├── keymaps.lua       # Key bindings
│   │   ├── globals.lua       # Global variables
│   │   └── autocmds.lua      # Auto commands
│   └── lua/plugins/          # Plugin configurations (12 files)
├── tmux/.config/tmux/         # tmux configuration
│   └── tmux.conf             # Main tmux config with Catppuccin theme
└── setup.sh                  # Installation script (basic skeleton)
```

## Setup and Installation

Run the setup script to install dotfiles:
```bash
./setup.sh
```

The setup script currently contains only logging functions and a placeholder `setup_dotfiles()` function.

## Configuration Architecture

### Neovim Configuration
- **Plugin Manager**: Uses lazy.nvim for plugin management
- **Configuration Structure**: Modular Lua configuration split across multiple files
- **Theme**: Uses "melange" colorscheme as default during plugin installation
- **Key Features**:
  - Disabled netrw in favor of nvim-tree
  - Automatic plugin updates checking enabled
  - 12 plugin configurations including LSP, Telescope, Treesitter, FZF

### tmux Configuration
- **Prefix Key**: Changed from `Ctrl-b` to `Ctrl-s`
- **Theme**: Catppuccin mocha flavor with rounded window status
- **Key Features**:
  - Vim-aware pane navigation (Ctrl-h/j/k/l)
  - Mouse support enabled
  - TPM (Tmux Plugin Manager) integration
  - Custom status bar configuration

## Key Plugin Configurations

Notable Neovim plugins configured:
- **LSP**: nvim-lspconfig for language server support
- **File Navigation**: nvim-tree, telescope, fzf-lua
- **UI**: lualine, bufferline, whichkey
- **Editing**: treesitter for syntax highlighting
- **Integration**: nvim-tmux-navigator for seamless tmux/vim navigation

## Development Notes

- The nvim README indicates pending LSP, autocomplete, and suggestions setup
- tmux configuration includes error handling for missing TPM installation
- Both configurations use consistent theming (Catppuccin/melange)
- Vim and tmux are integrated for seamless pane navigation