# -------------------------- Logging -----------------------------------------
log()     { echo "[INFO]  $(date +'%Y-%m-%d %H:%M:%S') $*"; }
warn()    { echo "[WARN]  $*"; }
error()   { echo "[ERROR] $*" >&2; }
success() { echo "[OK]    $*"; }

# -------------------------- OS Detection ------------------------------------
detect_os() {
  case "$(uname -s)" in
    Linux*)
      if command -v apt-get &> /dev/null; then
        echo "ubuntu"
      elif command -v pkg &> /dev/null; then
        echo "freebsd"
      else
        echo "linux"
      fi
      ;;
    FreeBSD*)
      echo "freebsd"
      ;;
    *)
      echo "unknown"
      ;;
  esac
}

install_stow() {
  local os="$1"
  case "$os" in
    ubuntu)
      log "Installing GNU Stow on Ubuntu..."
      sudo apt update && sudo apt install -y stow
      ;;
    freebsd)
      log "Installing GNU Stow on FreeBSD..."
      sudo pkg install -y stow
      ;;
    *)
      error "Unsupported operating system: $os"
      error "Please install GNU Stow manually"
      return 1
      ;;
  esac
}

# -------------------------- Utilities ---------------------------------------
check_dependencies() {
  local os
  os="$(detect_os)"

  if ! command -v stow &> /dev/null; then
    warn "GNU Stow is not installed"
    case "$os" in
      ubuntu)
        log "Attempting to install GNU Stow via apt..."
        if install_stow "$os"; then
          success "GNU Stow installed successfully"
        else
          error "Failed to install GNU Stow"
          exit 1
        fi
        ;;
      freebsd)
        log "Attempting to install GNU Stow via pkg..."
        if install_stow "$os"; then
          success "GNU Stow installed successfully"
        else
          error "Failed to install GNU Stow"
          exit 1
        fi
        ;;
      *)
        error "GNU Stow is required but not installed"
        error "Unsupported OS: $os. Please install GNU Stow manually"
        exit 1
        ;;
    esac
  else
    success "GNU Stow found"
  fi
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

