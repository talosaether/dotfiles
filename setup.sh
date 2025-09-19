#!/bin/sh
# -------------------------- Configuration -----------------------------------
# Environment variables for version control and installation methods
NVIM_VERSION="${NVIM_VERSION:-0.10.0}"
NVIM_INSTALL_METHOD="${NVIM_INSTALL_METHOD:-appimage}"
TMUX_INSTALL_TPM="${TMUX_INSTALL_TPM:-1}"
TARGET_USER="${TARGET_USER:-$(whoami)}"
TARGET_HOME="${TARGET_HOME:-$HOME}"

# -------------------------- Logging -----------------------------------------
log()     { echo "[INFO]  $(date +'%Y-%m-%d %H:%M:%S') $*"; }
warn()    { echo "[WARN]  $*"; }
error()   { echo "[ERROR] $*" >&2; }
success() { echo "[OK]    $*"; }

# -------------------------- OS Detection ------------------------------------
detect_os() {
  case "$(uname -s)" in
    Linux*)
      if command -v apt-get >/dev/null 2>&1; then
        echo "ubuntu"
      elif command -v pkg >/dev/null 2>&1; then
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
version_compare() {
  # Compare two version strings (e.g., "1.2.3" vs "1.2.4")
  # Returns 0 if $1 >= $2, 1 otherwise
  local current="$1"
  local required="$2"

  # Convert versions to comparable format
  current_num=$(echo "$current" | sed 's/[^0-9.]//g' | awk -F. '{printf "%d%03d%03d", $1, $2, $3}')
  required_num=$(echo "$required" | sed 's/[^0-9.]//g' | awk -F. '{printf "%d%03d%03d", $1, $2, $3}')

  [ "$current_num" -ge "$required_num" ]
}

check_app_version() {
  local app="$1"
  local min_version="$2"
  local version_cmd="$3"

  if ! command -v "$app" >/dev/null 2>&1; then
    return 1  # App not installed
  fi

  local current_version
  current_version=$(eval "$version_cmd" 2>/dev/null | head -n1)

  if [ -z "$current_version" ]; then
    return 1  # Could not determine version
  fi

  if version_compare "$current_version" "$min_version"; then
    return 0  # Version is sufficient
  else
    return 2  # Version is too old
  fi
}

apt_install() {
  local package="$1"
  log "Installing $package via apt..."
  sudo apt update && sudo apt install -y "$package"
}

curl_retry() {
  local max_attempts=3
  local attempt=1

  while [ $attempt -le $max_attempts ]; do
    if curl -fsSL "$@"; then
      return 0
    fi
    warn "curl attempt $attempt failed, retrying..."
    attempt=$((attempt + 1))
    sleep 2
  done

  error "curl failed after $max_attempts attempts"
  return 1
}

run_as() {
  if [ "$(whoami)" = "$TARGET_USER" ]; then
    sh -c "$*"
  else
    sudo -u "$TARGET_USER" sh -c "$*"
  fi
}

check_dependencies() {
  if ! command -v stow >/dev/null 2>&1; then
    error "GNU Stow is required but not installed"
    os="$(detect_os)"
    case "$os" in
      ubuntu)
        log "Install with: sudo apt install stow"
        ;;
      freebsd)
        log "Install with: sudo pkg install stow"
        ;;
      *)
        log "Please install GNU Stow manually"
        ;;
    esac
    exit 1
  fi
  success "GNU Stow found"
}

# -------------------------- Development Tools -------------------------------
install_neovim() {
  log "Installing Neovim v${NVIM_VERSION} via ${NVIM_INSTALL_METHOD}..."

  # Check if already installed with correct version
  if command -v nvim >/dev/null 2>&1; then
    if nvim --version | head -n1 | grep -q "NVIM v${NVIM_VERSION}"; then
      warn "Neovim v${NVIM_VERSION} already installed; skipping"
      return 0
    else
      warn "Different Neovim version detected: $(nvim --version | head -n1)"
      log "Proceeding with v${NVIM_VERSION} installation"
    fi
  fi

  if [ "${NVIM_INSTALL_METHOD}" = "appimage" ]; then
    # Install via AppImage (x86_64 only)
    if [ "$(uname -m)" != "x86_64" ]; then
      error "AppImage method only supports x86_64 architecture. Current: $(uname -m)"
      warn "Falling back to package manager installation"
      apt_install neovim
      success "Neovim installed via package manager"
      return 0
    fi

    log "Downloading Neovim AppImage v${NVIM_VERSION}..."
    curl_retry -o /tmp/nvim.appimage \
      "https://github.com/neovim/neovim/releases/download/v${NVIM_VERSION}/nvim.appimage"

    chmod +x /tmp/nvim.appimage

    log "Extracting AppImage..."
    cd /tmp && /tmp/nvim.appimage --appimage-extract >/dev/null

    # Move to opt and create symlink
    sudo mv squashfs-root "/opt/nvim-v${NVIM_VERSION}"
    sudo ln -sf "/opt/nvim-v${NVIM_VERSION}/usr/bin/nvim" /usr/local/bin/nvim

    # Clean up
    rm -f /tmp/nvim.appimage

    # Verify installation
    if nvim --version | head -n1 | grep -q "NVIM v${NVIM_VERSION}"; then
      success "Neovim v${NVIM_VERSION} installed via AppImage"
    else
      error "Neovim installation verification failed"
      exit 1
    fi
  else
    error "Unsupported NVIM_INSTALL_METHOD: ${NVIM_INSTALL_METHOD}"
    warn "Falling back to package manager installation"
    apt_install neovim
    success "Neovim installed via package manager"
  fi

  # Install minimal config (will be overwritten by dotfiles if present)
  install -d -m 700 "$TARGET_HOME/.config"
  sudo chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.config"

  log "Installing minimal Neovim configuration"
  run_as "mkdir -p ~/.config/nvim"
  run_as "cat > ~/.config/nvim/init.lua" <<'NVIM'
vim.o.number = true
vim.o.relativenumber = true
vim.o.termguicolors = true
vim.o.expandtab = true
vim.o.shiftwidth = 2
vim.o.tabstop = 2
NVIM
  success "Minimal Neovim configuration installed"
}

install_tmux() {
  log "Setting up TMUX with TPM..."

  # Ensure tmux is installed (should be from build tools)
  if ! command -v tmux >/dev/null 2>&1; then
    warn "TMUX not found; installing via apt"
    apt_install tmux
  fi

  # Set up TMUX plugin manager path for target user
  local tmux_plugin_path="$TARGET_HOME/.tmux/plugins"

  if [ "${TMUX_INSTALL_TPM}" -eq 1 ]; then
    log "Installing TMUX Plugin Manager (TPM)..."
    run_as "mkdir -p '${tmux_plugin_path}'"

    if [ ! -x "${tmux_plugin_path}/tpm/tpm" ]; then
      run_as "git clone --depth 1 https://github.com/tmux-plugins/tpm '${tmux_plugin_path}/tpm'" || true
      success "TPM installed at ${tmux_plugin_path}/tpm"
    else
      warn "TPM already installed; skipping"
    fi
  fi

  # Install minimal config (will be overwritten by dotfiles if present)
  install -d -m 700 "$TARGET_HOME/.config"
  sudo chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.config"

  log "Installing minimal TMUX configuration"
  run_as "mkdir -p ~/.config/tmux"
  run_as "cat > ~/.config/tmux/tmux.conf" <<'TMUX'
# Basic tmux configuration
set -g prefix C-s
unbind C-b
bind-key C-s send-prefix

# Enable mouse mode
set -g mouse on

# Start windows and panes at 1, not 0
set -g base-index 1
setw -g pane-base-index 1

# Reload config
bind r source-file ~/.config/tmux/tmux.conf \; display-message "Config reloaded!"
TMUX
  success "Minimal TMUX configuration installed"
}

backup_existing_config() {
  local config_path="$1"
  local backup_dir="$HOME/.config/dotfiles-backup-$(date +%Y%m%d-%H%M%S)"

  if [ -e "$config_path" ]; then
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

  # Remove existing symlinks first to avoid conflicts
  stow --target="$HOME" --delete "$package" 2>/dev/null || true

  # Check for conflicts and remove/backup if necessary
  if [ "$package" = "nvim" ]; then
    if [ -e "$HOME/.config/nvim" ] && [ ! -L "$HOME/.config/nvim" ]; then
      backup_existing_config "$HOME/.config/nvim"
    elif [ -L "$HOME/.config/nvim" ]; then
      rm -f "$HOME/.config/nvim"
    fi
  elif [ "$package" = "tmux" ]; then
    if [ -e "$HOME/.config/tmux" ] && [ ! -L "$HOME/.config/tmux" ]; then
      backup_existing_config "$HOME/.config/tmux"
    elif [ -L "$HOME/.config/tmux" ]; then
      rm -f "$HOME/.config/tmux"
    fi
    if [ -e "$HOME/.tmux.conf" ] && [ ! -L "$HOME/.tmux.conf" ]; then
      backup_existing_config "$HOME/.tmux.conf"
    elif [ -L "$HOME/.tmux.conf" ]; then
      rm -f "$HOME/.tmux.conf"
    fi
  fi

  # Use stow to create symlinks, forcing replacement
  if stow --target="$HOME" --verbose --restow "$package"; then
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

update_repository() {
  log "Updating dotfiles repository from GitHub..."
  if git remote get-url origin >/dev/null 2>&1; then
    if git pull origin main; then
      success "Repository updated successfully"
    else
      error "Failed to pull latest changes"
      return 1
    fi
  else
    warn "No git remote origin found, skipping update"
  fi
}

create_tmux_symlink() {
  local tmux_config="$HOME/.config/tmux/tmux.conf"
  local tmux_legacy="$HOME/.tmux.conf"

  if [ -f "$tmux_config" ]; then
    log "Creating symlink: ~/.tmux.conf -> ~/.config/tmux/tmux.conf"
    if [ -e "$tmux_legacy" ] && [ ! -L "$tmux_legacy" ]; then
      backup_existing_config "$tmux_legacy"
    fi
    ln -sf "$tmux_config" "$tmux_legacy"
    success "tmux legacy symlink created"
  else
    warn "tmux config not found at $tmux_config, skipping legacy symlink"
  fi
}

check_and_install_tools() {
  log "Checking and installing development tools..."

  # Check Neovim
  case $(check_app_version nvim "$NVIM_VERSION" "nvim --version | head -n1 | sed 's/.*v//'"; echo $?) in
    0)
      success "Neovim v$(nvim --version | head -n1 | sed 's/.*v//') meets minimum requirement (v${NVIM_VERSION})"
      ;;
    1)
      log "Neovim not found, installing..."
      install_neovim
      ;;
    2)
      warn "Neovim v$(nvim --version | head -n1 | sed 's/.*v//') is below minimum requirement (v${NVIM_VERSION})"
      log "Upgrading Neovim..."
      install_neovim
      ;;
  esac

  # Check tmux
  case $(check_app_version tmux "3.0" "tmux -V | sed 's/tmux //'"; echo $?) in
    0)
      success "tmux v$(tmux -V | sed 's/tmux //') meets minimum requirement (v3.0)"
      if [ "${TMUX_INSTALL_TPM}" -eq 1 ]; then
        install_tmux  # Still run to ensure TPM is installed
      fi
      ;;
    1)
      log "tmux not found, installing..."
      install_tmux
      ;;
    2)
      warn "tmux v$(tmux -V | sed 's/tmux //') is below minimum requirement (v3.0)"
      log "Upgrading tmux..."
      install_tmux
      ;;
  esac
}

main() {
  log "Setting up dotfiles..."
  update_repository
  check_dependencies
  check_and_install_tools
  setup_dotfiles
  create_tmux_symlink
}

main "$@"

