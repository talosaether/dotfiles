# dotfiles

Personal development environment configuration files for Neovim and tmux.

## Structure

```
dotfiles/
├── nvim/.config/nvim/          # Neovim configuration
│   ├── init.lua               # Entry point, loads lazy.nvim
│   ├── lua/config/            # Core configuration modules
│   └── lua/plugins/          # Plugin configurations
├── tmux/.config/tmux/         # tmux configuration
│   └── tmux.conf             # Main tmux config with Catppuccin theme
└── setup.sh                  # Installation script
```

## Installation

```bash
./setup.sh
```

## Features

### Neovim
- **Plugin Manager**: lazy.nvim
- **Theme**: melange colorscheme
- **LSP**: Language server support via nvim-lspconfig
- **File Navigation**: nvim-tree, telescope, fzf-lua
- **UI**: lualine, bufferline, whichkey

### tmux
- **Prefix**: `Ctrl-s` (changed from default `Ctrl-b`)
- **Theme**: Catppuccin mocha with rounded status
- **Navigation**: Vim-aware pane navigation (`Ctrl-h/j/k/l`)
- **Plugins**: TPM (Tmux Plugin Manager) integration

## Integration

Seamless navigation between tmux panes and Neovim splits using nvim-tmux-navigator.
