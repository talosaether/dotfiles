#!/bin/sh
# Copy-only dotfiles installer (no Stow). Keeps legacy ~/.tmux.conf as a symlink to ~/.config/tmux/tmux.conf.

set -e

# -------------------------- Configuration -----------------------------------
NVIM_VERSION="${NVIM_VERSION:-0.10.0}"
NVIM_INSTALL_METHOD="${NVIM_INSTALL_METHOD:-appimage}"   # appimage | package
TMUX_INSTALL_TPM="${TMUX_INSTALL_TPM:-1}"
TARGET_USER="${TARGET_USER:-$(whoami)}"
TARGET_HOME="${TARGET_HOME:-$HOME}"
REPLACE_CONFIGS="${REPLACE_CONFIGS:-1}"  # 1=overwrite (with backup), 0=preserve

# -------------------------- Logging -----------------------------------------
log()     { echo "[INFO]  $(date +'%Y-%m-%d %H:%M:%S') $*"; }
warn()    { echo "[WARN]  $*"; }
error()   { echo "[ERROR] $*" >&2; }
success() { echo "[OK]    $*"; }

# -------------------------- OS Detection ------------------------------------
detect_os() {
  case "$(uname -s)" in
    Linux*)
      if command -v apt-get >/dev/null 2>&1; then echo "ubuntu"
      elif command -v pkg >/dev/null 2>&1; then echo "freebsd"
      else echo "linux"; fi
      ;;
    Darwin*)  echo "macos" ;;
    FreeBSD*) echo "freebsd" ;;
    *)        echo "unknown" ;;
  esac
}

# -------------------------- Utilities ---------------------------------------
ensure_dir() { [ -d "$1" ] || mkdir -p "$1"; }

version_compare() {
  a="$1"; b="$2"
  an=$(echo "$a" | sed 's/[^0-9.]/ /g' | awk -F. '{printf "%d%03d%03d", $1,$2,$3}')
  bn=$(echo "$b" | sed 's/[^0-9.]/ /g' | awk -F. '{printf "%d%03d%03d", $1,$2,$3}')
  [ "${an:-0}" -ge "${bn:-0}" ]
}

check_app_version() {
  app="$1"; min="$2"; cmd="$3"
  if ! command -v "$app" >/dev/null 2>&1; then return 1; fi
  cur=$(eval "$cmd" 2>/dev/null | head -n1)
  [ -z "$cur" ] && return 1
  version_compare "$cur" "$min" && return 0 || return 2
}

curl_retry() {
  max=3; n=1
  while [ $n -le $max ]; do
    if curl -fsSL "$@"; then return 0; fi
    warn "curl attempt $n failed, retrying..."
    n=$((n+1)); sleep 2
  done
  error "curl failed after $max attempts"; return 1
}

run_as() {
  if [ "$(whoami)" = "$TARGET_USER" ]; then sh -c "$*"
  else sudo -u "$TARGET_USER" sh -c "$*"; fi
}

safe_chown() {
  path="$1"
  user="${2:-$TARGET_USER}"

  # Get the user's primary group (macOS uses 'staff', Linux typically uses username)
  if [ "$(whoami)" = "$user" ]; then
    group="$(id -gn)"
  else
    group="$(id -gn "$user" 2>/dev/null || echo "$user")"
  fi

  # Try with sudo first, then without (macOS often doesn't need sudo for own files)
  sudo chown -R "$user:$group" "$path" 2>/dev/null || chown -R "$user:$group" "$path" 2>/dev/null || true
}

backup_existing_config() {
  p="$1"
  tsdir="$TARGET_HOME/.config/dotfiles-backup-$(date +%Y%m%d-%H%M%S)"
  if [ -e "$p" ] || [ -L "$p" ]; then
    log "Backing up $p"
    mkdir -p "$tsdir"
    rel="$(echo "$p" | sed "s|$TARGET_HOME/||")"
    (cd "$TARGET_HOME" && tar cpf "$tsdir/backup.tar" "$rel") 2>/dev/null || true
    success "Backed up to: $tsdir"
  fi
}

copy_tree() {
  src="$1"; dst="$2"
  if command -v rsync >/dev/null 2>&1; then
    rsync -a "$src"/ "$dst"/
  else
    (cd "$src" && tar cpf - .) | (cd "$dst" && tar xpf -)
  fi
}

cleanup_repo_symlinks() {
  script_dir="$(cd "$(dirname "$0")" && pwd)"
  log "Cleaning symlinks in $TARGET_HOME that point into $script_dir ..."
  if [ -d "$TARGET_HOME/.config" ]; then
    find "$TARGET_HOME/.config" -type l 2>/dev/null | while read -r lnk; do
      tgt="$(readlink "$lnk" || true)"
      case "$tgt" in "$script_dir"/*) rm -f "$lnk" ;; esac
    done
  fi
  for f in .vimrc .zshrc .bashrc .bash_profile .gitconfig; do
    p="$TARGET_HOME/$f"
    if [ -L "$p" ]; then
      tgt="$(readlink "$p" || true)"
      case "$tgt" in "$script_dir"/*) rm -f "$p" ;; esac
    fi
  done
  success "Repo symlink cleanup complete"
}

force_remove_path() {
  path="$1"
  if [ -e "$path" ] || [ -L "$path" ]; then
    if [ "$REPLACE_CONFIGS" -eq 1 ]; then
      [ ! -L "$path" ] && backup_existing_config "$path"
      rm -rf "$path"
    else
      warn "Conflict: $path exists; preserving (use --replace to overwrite)"
      return 1
    fi
  fi
  return 0
}

# -------------------------- Dev Tools ---------------------------------------
# Package manager wrappers - unified interface across OS types
apt_install() {
  pkg="$1"; log "Installing $pkg via apt...";
  sudo apt update && sudo apt install -y "$pkg"
}

brew_install() {
  pkg="$1"; log "Installing $pkg via Homebrew..."

  # Ensure Homebrew is installed first
  if ! command -v brew >/dev/null 2>&1; then
    log "Homebrew not found, installing..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Add Homebrew to PATH for this session (location varies by architecture)
    if [ -x "/opt/homebrew/bin/brew" ]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [ -x "/usr/local/bin/brew" ]; then
      eval "$(/usr/local/bin/brew shellenv)"
    fi
  fi

  brew install "$pkg"
}

pkg_install() {
  pkg="$1"; os="$2"

  # ===== FORK: OS-specific package installation =====
  case "$os" in
    ubuntu)  apt_install "$pkg" ;;
    macos)   brew_install "$pkg" ;;
    freebsd) log "Installing $pkg via pkg..."; sudo pkg install -y "$pkg" ;;
    *)       error "Unsupported OS: $os"; return 1 ;;
  esac
  # ===== END FORK =====
}

install_neovim() {
  log "Installing Neovim v${NVIM_VERSION} via ${NVIM_INSTALL_METHOD}..."
  if command -v nvim >/dev/null 2>&1; then
    if nvim --version | head -n1 | grep -q "NVIM v${NVIM_VERSION}"; then
      warn "Neovim v${NVIM_VERSION} already installed; skipping"; return 0
    fi
    warn "Different Neovim detected: $(nvim --version | head -n1)"
  fi

  os="$(detect_os)"

  # ===== FORK: macOS doesn't support AppImage =====
  if [ "${NVIM_INSTALL_METHOD}" = "appimage" ] && [ "$os" = "macos" ]; then
    warn "AppImage not supported on macOS; falling back to Homebrew"
    NVIM_INSTALL_METHOD="package"
  fi
  # ===== END FORK =====

  if [ "${NVIM_INSTALL_METHOD}" = "appimage" ]; then
    if [ "$(uname -m)" != "x86_64" ]; then
      error "AppImage method needs x86_64; falling back to package manager"
      pkg_install neovim "$os"
    else
      curl_retry -o /tmp/nvim.appimage \
        "https://github.com/neovim/neovim/releases/download/v${NVIM_VERSION}/nvim.appimage"
      chmod +x /tmp/nvim.appimage
      (cd /tmp && ./nvim.appimage --appimage-extract >/dev/null)
      sudo mv /tmp/squashfs-root "/opt/nvim-v${NVIM_VERSION}"
      sudo ln -sf "/opt/nvim-v${NVIM_VERSION}/usr/bin/nvim" /usr/local/bin/nvim
      rm -f /tmp/nvim.appimage
    fi
  else
    # ===== FORK: OS-specific package installation =====
    if [ "$os" = "ubuntu" ]; then
      apt_install neovim
      inst_ver="$(nvim --version | head -n1 | sed 's/.*v//')"
      if ! version_compare "$inst_ver" "$NVIM_VERSION"; then
        warn "neovim $inst_ver < required $NVIM_VERSION, trying PPA unstable"
        sudo add-apt-repository ppa:neovim-ppa/unstable -y
        sudo apt update && sudo apt install -y neovim
      fi
    else
      # macOS and FreeBSD use unified installer
      pkg_install neovim "$os"
    fi
    # ===== END FORK =====
  fi

  if nvim --version | head -n1 | grep -q "NVIM v${NVIM_VERSION}"; then
    success "Neovim v${NVIM_VERSION} installed"
  else
    warn "Neovim installed, but version differs: $(nvim --version | head -n1)"
  fi

  install -d -m 700 "$TARGET_HOME/.config"
  safe_chown "$TARGET_HOME/.config"
  log "Installing minimal Neovim config (safe fallback)"
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
  log "Ensuring tmux present + TPM (optional)"
  if ! command -v tmux >/dev/null 2>&1; then
    os="$(detect_os)"
    # Unified installation across all OS types
    pkg_install tmux "$os"
  fi

  install -d -m 700 "$TARGET_HOME/.config"
  safe_chown "$TARGET_HOME/.config"

  log "Installing minimal tmux config (safe fallback)"
  run_as "mkdir -p ~/.config/tmux"
  run_as "cat > ~/.config/tmux/tmux.conf" <<'TMUX'
set -g prefix C-s
unbind C-b
bind-key C-s send-prefix
set -g mouse on
set -g base-index 1
setw -g pane-base-index 1
bind r source-file ~/.config/tmux/tmux.conf \; display-message "Config reloaded!"
TMUX
  success "Minimal TMUX configuration installed"

  if [ "${TMUX_INSTALL_TPM}" -eq 1 ]; then
    tp="$TARGET_HOME/.tmux/plugins/tpm"
    run_as "mkdir -p '$TARGET_HOME/.tmux/plugins'"
    if [ ! -x "$tp/tpm" ]; then
      run_as "git clone --depth 1 https://github.com/tmux-plugins/tpm '$tp' || true"
      success "TPM installed"
    else
      warn "TPM already present; skipping"
    fi
  fi
}

create_tmux_symlink() {
  local tmux_config="$TARGET_HOME/.config/tmux/tmux.conf"
  local tmux_legacy="$TARGET_HOME/.tmux.conf"

  if [ -f "$tmux_config" ]; then
    log "Creating symlink: ~/.tmux.conf -> ~/.config/tmux/tmux.conf"
    if [ -e "$tmux_legacy" ] && [ ! -L "$tmux_legacy" ]; then
      backup_existing_config "$tmux_legacy"
      rm -f "$tmux_legacy"
    fi
    ln -sfn "$tmux_config" "$tmux_legacy"
    success "tmux legacy symlink created"
  else
    warn "tmux config not found at $tmux_config, skipping legacy symlink"
  fi
}

# -------------------------- Dotfiles Copy -----------------------------------
detect_packages() {
  for d in *; do
    [ -d "$d" ] || continue
    [ "$d" = ".git" ] && continue
    echo "$d"
  done
}

install_package() {
  package="$1"
  log "Installing package '$package' (copy mode, with smart mapping)..."

  # 1) If package contains a .config root, mirror it directly into ~/.config
  if [ -d "$package/.config" ]; then
    # Use ls instead of find -printf (not supported on macOS)
    subs=$(cd "$package/.config" && ls -1d */ 2>/dev/null | sed 's:/$::' || true)
    for sub in $subs; do
      target="$TARGET_HOME/.config/$sub"
      force_remove_path "$target" || true
    done
    ensure_dir "$TARGET_HOME/.config"
    copy_tree "$package/.config" "$TARGET_HOME/.config"
    safe_chown "$TARGET_HOME/.config"
    success "Installed $package into ~/.config"
    return 0
  fi

  # 2) Smart mapping for common layouts
  case "$package" in
    nvim)
      # a) repo_root/nvim/{init.lua,lua,...} -> ~/.config/nvim
      if [ -f "$package/init.lua" ] || [ -d "$package/lua" ]; then
        dest="$TARGET_HOME/.config/nvim"
        force_remove_path "$dest" || true
        ensure_dir "$dest"
        copy_tree "$package" "$dest"
        safe_chown "$dest"
        success "Installed $package into ~/.config/nvim"
        return 0
      fi
      # b) repo_root/nvim/nvim/* -> ~/.config/nvim
      if [ -d "$package/nvim" ]; then
        dest="$TARGET_HOME/.config/nvim"
        force_remove_path "$dest" || true
        ensure_dir "$dest"
        copy_tree "$package/nvim" "$dest"
        safe_chown "$dest"
        success "Installed $package/nvim into ~/.config/nvim"
        return 0
      fi
      ;;
    tmux)
      if [ -f "$package/tmux.conf" ]; then
        dest="$TARGET_HOME/.config/tmux"
        force_remove_path "$dest" || true
        ensure_dir "$dest"
        cp -f "$package/tmux.conf" "$dest/tmux.conf"
        safe_chown "$dest"
        success "Installed tmux.conf into ~/.config/tmux"
        return 0
      fi
      ;;
  esac

  # 3) Fallback: copy the package contents into $HOME
  if command -v find >/dev/null 2>&1; then
    for entry in $(find "$package" -mindepth 1 -maxdepth 1 2>/dev/null); do
      base="$(basename "$entry")"
      target="$TARGET_HOME/$base"
      force_remove_path "$target" || true
    done
  else
    for base in $(cd "$package" && ls -1A); do
      target="$TARGET_HOME/$base"
      force_remove_path "$target" || true
    done
  fi

  copy_tree "$package" "$TARGET_HOME"
  safe_chown "$TARGET_HOME"
  success "Installed $package into ~/"
}

setup_dotfiles() {
  script_dir="$(cd "$(dirname "$0")" && pwd)"
  cd "$script_dir" || exit 1

  log "Detecting packages..."
  packages="$(detect_packages)"
  if [ -z "$packages" ]; then warn "No packages found"; return 0; fi
  log "Found: $packages"

  failed=""
  for p in $packages; do
    if ! install_package "$p"; then
      failed="$failed $p"
    fi
  done

  echo
  if [ -z "$failed" ]; then
    success "All packages installed"
  else
    warn "Some packages failed:$failed"
  fi

  echo
  log "Post-install notes:"
  case " $packages " in *" nvim "*) log "- Neovim: run 'nvim' to trigger your plugin manager";; esac
  case " $packages " in *" tmux "*) log "- tmux: if TPM installed, press prefix (Ctrl-s) then I to install plugins";; esac
}

check_and_install_tools() {
  log "Checking dev tools..."

  # Neovim
  case $(check_app_version nvim "$NVIM_VERSION" "nvim --version | head -n1 | sed 's/.*v//'"; echo $?) in
    0) success "Neovim OK ($(nvim --version | head -n1))" ;;
    1) log "Neovim not found; installing..."; install_neovim ;;
    2) warn "Neovim below $NVIM_VERSION; upgrading..."; install_neovim ;;
  esac

  # tmux (+ TPM)
  case $(check_app_version tmux "3.0" "tmux -V | sed 's/tmux //'"; echo $?) in
    0) success "tmux OK ($(tmux -V))"; [ "${TMUX_INSTALL_TPM}" -eq 1 ] && install_tmux ;;
    1) log "tmux not found; installing..."; install_tmux ;;
    2) warn "tmux < 3.0; upgrading..."; install_tmux ;;
  esac

  # ripgrep
  if command -v rg >/dev/null 2>&1; then
    success "ripgrep present ($(rg --version | head -n1))"
  else
    log "ripgrep not found; installing..."
    os="$(detect_os)"
    # Unified installation across all OS types
    pkg_install ripgrep "$os" || warn "Failed to install ripgrep; install manually if needed."
  fi
}

# -------------------------- CLI ---------------------------------------------
show_help() {
  cat << 'EOF'
Usage: ./setup.sh [OPTIONS]

Options:
  --replace        Overwrite existing configs (default; backups taken)
  --no-replace     Preserve existing configs; skip conflicting entries
  --help, -h       Show help

Environment:
  REPLACE_CONFIGS     1 overwrite (default), 0 preserve
  NVIM_VERSION        default: 0.10.0
  NVIM_INSTALL_METHOD appimage (default) | package
  TMUX_INSTALL_TPM    1 install (default), 0 skip
  TARGET_USER         default: current user
  TARGET_HOME         default: $HOME
EOF
}

parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --replace) REPLACE_CONFIGS=1; shift ;;
      --no-replace) REPLACE_CONFIGS=0; shift ;;
      --help|-h) show_help; exit 0 ;;
      *) error "Unknown option: $1"; show_help; exit 1 ;;
    esac
  done
}

# -------------------------- Main --------------------------------------------
main() {
  parse_args "$@"

  log "Dotfiles setup (copy-mode; legacy tmux symlink)"
  if [ "$REPLACE_CONFIGS" -eq 1 ]; then
    log "Replacement: ENABLED (backups taken)"
  else
    log "Replacement: DISABLED (conflicts preserved)"
  fi

  # Optional: update repo if inside a git work tree
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    log "Updating repository..."
    if git remote get-url origin >/dev/null 2>&1; then
      branch="$(git symbolic-ref --short HEAD 2>/dev/null || echo main)"
      git pull --ff-only origin "$branch" || warn "git pull skipped/failed"
    else
      warn "No 'origin' remote; skipping update"
    fi
  fi

  cleanup_repo_symlinks
  check_and_install_tools
  setup_dotfiles
  create_tmux_symlink
  success "Done."
}

main "$@"

