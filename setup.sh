# -------------------------- Logging -----------------------------------------
log()     { echo "[INFO]  $(date +'%Y-%m-%d %H:%M:%S') $*"; }
warn()    { echo "[WARN]  $*"; }
error()   { echo "[ERROR] $*" >&2; }
success() { echo "[OK]    $*"; }

# -------------------------- Utilities ---------------------------------------
check_dependencies() {
  if ! command -v stow &> /dev/null; then
    error "GNU Stow is required but not installed"
    log "Install with: sudo apt install stow (Debian/Ubuntu) or brew install stow (macOS)"
    exit 1
  fi
  success "GNU Stow found"
}

backup_existing_config() {
  local config_path="$1"
  local backup_dir="$HOME/.config/dotfiles-backup-$(date +%Y%m%d-%H%M%S)"

  if [[ -e "$config_path" ]]; then
    log "Backing up existing config: $config_path"
    mkdir -p "$backup_dir"
    mv "$config_path" "$backup_dir/"
    success "Backed up to: $backup_dir"
  fi
}

detect_packages() {
  local packages=()
  for dir in */; do
    dir="${dir%/}"
    if [[ -d "$dir" && "$dir" != ".git" ]]; then
      packages+=("$dir")
    fi
  done
  echo "${packages[@]}"
}

install_package() {
  local package="$1"
  log "Installing $package configuration..."

  # Check for conflicts and backup if necessary
  if [[ "$package" == "nvim" ]]; then
    backup_existing_config "$HOME/.config/nvim"
  elif [[ "$package" == "tmux" ]]; then
    backup_existing_config "$HOME/.config/tmux"
    backup_existing_config "$HOME/.tmux.conf"
  fi

  # Use stow to create symlinks
  if stow --target="$HOME" --verbose "$package" 2>&1; then
    success "Successfully installed $package"
  else
    error "Failed to install $package"
    return 1
  fi
}

setup_dotfiles() {
  local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  cd "$script_dir" || exit 1

  log "Detecting available packages..."
  local packages
  packages=($(detect_packages))

  if [[ ${#packages[@]} -eq 0 ]]; then
    warn "No dotfile packages found"
    return 0
  fi

  log "Found packages: ${packages[*]}"

  # Install each package
  local failed_packages=()
  for package in "${packages[@]}"; do
    if ! install_package "$package"; then
      failed_packages+=("$package")
    fi
  done

  # Summary
  echo
  if [[ ${#failed_packages[@]} -eq 0 ]]; then
    success "All packages installed successfully!"
    log "Installed: ${packages[*]}"
  else
    warn "Some packages failed to install: ${failed_packages[*]}"
    log "Successfully installed: $(printf '%s ' "${packages[@]}" | sed "s/$(printf '%s\|' "${failed_packages[@]}" | sed 's/|$//')//g")"
  fi

  # Post-installation notes
  echo
  log "Post-installation notes:"
  if [[ " ${packages[*]} " =~ " nvim " ]]; then
    log "- Neovim: Run 'nvim' to trigger lazy.nvim plugin installation"
  fi
  if [[ " ${packages[*]} " =~ " tmux " ]]; then
    log "- tmux: Install TPM with: git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm"
    log "- tmux: Press prefix + I (Ctrl-s + I) to install plugins"
  fi
}

main() {
  log "Setting up dotfiles..."
  check_dependencies
  setup_dotfiles
}

main "$@"

