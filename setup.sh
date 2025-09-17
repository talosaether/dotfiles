#!/bin/sh
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
  packages=""
  for dir in */; do
    dir="${dir%/}"
    if [ -d "$dir" ] && [ "$dir" != ".git" ]; then
      if [ -z "$packages" ]; then
        packages="$dir"
      else
        packages="$packages $dir"
      fi
    fi
  done
  echo "$packages"
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
  if stow --target="$HOME" --verbose "$package"; then
    success "Successfully installed $package"
  else
    error "Failed to install $package"
    return 1
  fi
}

setup_dotfiles() {
  script_dir="$(cd "$(dirname "$0")" && pwd)"
  cd "$script_dir" || exit 1

  log "Detecting available packages..."
  packages="$(detect_packages)"

  if [ -z "$packages" ]; then
    warn "No dotfile packages found"
    return 0
  fi

  log "Found packages: $packages"

  # Install each package
  failed_packages=""
  for package in $packages; do
    if ! install_package "$package"; then
      if [ -z "$failed_packages" ]; then
        failed_packages="$package"
      else
        failed_packages="$failed_packages $package"
      fi
    fi
  done

  # Summary
  echo
  if [ -z "$failed_packages" ]; then
    success "All packages installed successfully!"
    log "Installed: $packages"
  else
    warn "Some packages failed to install: $failed_packages"
    # Build successful packages list
    successful=""
    for package in $packages; do
      case " $failed_packages " in
        *" $package "*) ;;
        *)
          if [ -z "$successful" ]; then
            successful="$package"
          else
            successful="$successful $package"
          fi
          ;;
      esac
    done
    log "Successfully installed: $successful"
  fi

  # Post-installation notes
  echo
  log "Post-installation notes:"
  case " $packages " in
    *" nvim "*)
      log "- Neovim: Run 'nvim' to trigger lazy.nvim plugin installation"
      ;;
  esac
  case " $packages " in
    *" tmux "*)
      log "- tmux: Install TPM with: git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm"
      log "- tmux: Press prefix + I (Ctrl-s + I) to install plugins"
      ;;
  esac
}

main() {
  log "Setting up dotfiles..."
  check_dependencies
  setup_dotfiles
}

main "$@"

