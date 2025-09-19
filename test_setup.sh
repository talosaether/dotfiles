#!/bin/bash
# Test script for setup.sh functionality
# Tests the force replace behavior of the dotfiles setup script

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test directory
TEST_HOME="/tmp/dotfiles_test_$(date +%s)"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

log() { echo -e "${BLUE}[TEST]${NC} $*"; }
success() { echo -e "${GREEN}[PASS]${NC} $*"; }
fail() { echo -e "${RED}[FAIL]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }

run_test() {
    local test_name="$1"
    local test_func="$2"

    TESTS_RUN=$((TESTS_RUN + 1))
    log "Running test: $test_name"

    if $test_func; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        success "$test_name"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        fail "$test_name"
    fi
    echo
}

setup_test_env() {
    log "Setting up test environment in $TEST_HOME"
    rm -rf "$TEST_HOME"
    mkdir -p "$TEST_HOME"

    # Create fake home directories
    mkdir -p "$TEST_HOME/.config"

    # Create a separate dotfiles directory for stow
    local dotfiles_dir="$TEST_HOME/dotfiles"
    mkdir -p "$dotfiles_dir"

    # Copy dotfiles to the dotfiles directory
    cp -r "$SCRIPT_DIR/nvim" "$dotfiles_dir/"
    cp -r "$SCRIPT_DIR/tmux" "$dotfiles_dir/"
    cp "$SCRIPT_DIR/setup.sh" "$dotfiles_dir/"

    cd "$dotfiles_dir"
}

cleanup_test_env() {
    log "Cleaning up test environment"
    rm -rf "$TEST_HOME"
}

# Test 1: Fresh installation (no existing configs)
test_fresh_install() {
    setup_test_env

    # Run setup
    if HOME="$TEST_HOME" ./setup.sh > /dev/null 2>&1; then
        # Check if symlinks were created
        if [ -L "$TEST_HOME/.config/nvim" ] && [ -L "$TEST_HOME/.config/tmux" ]; then
            return 0
        else
            fail "Symlinks not created properly"
            return 1
        fi
    else
        fail "Setup script failed"
        return 1
    fi
}

# Test 2: Replace existing regular directories
test_replace_directories() {
    setup_test_env

    # Create existing directories with content
    mkdir -p "$TEST_HOME/.config/nvim"
    echo "existing nvim config" > "$TEST_HOME/.config/nvim/init.lua"
    mkdir -p "$TEST_HOME/.config/tmux"
    echo "existing tmux config" > "$TEST_HOME/.config/tmux/tmux.conf"

    # Run setup
    if HOME="$TEST_HOME" ./setup.sh > /dev/null 2>&1; then
        # Check if old configs were backed up
        if ls "$TEST_HOME"/.config/dotfiles-backup-* > /dev/null 2>&1; then
            # Check if new symlinks were created
            if [ -L "$TEST_HOME/.config/nvim" ] && [ -L "$TEST_HOME/.config/tmux" ]; then
                return 0
            else
                fail "New symlinks not created"
                return 1
            fi
        else
            fail "Existing configs not backed up"
            return 1
        fi
    else
        fail "Setup script failed"
        return 1
    fi
}

# Test 3: Replace existing symlinks
test_replace_symlinks() {
    setup_test_env

    # Create existing symlinks pointing to wrong locations
    mkdir -p "$TEST_HOME/wrong_nvim"
    mkdir -p "$TEST_HOME/wrong_tmux"
    ln -s "$TEST_HOME/wrong_nvim" "$TEST_HOME/.config/nvim"
    ln -s "$TEST_HOME/wrong_tmux" "$TEST_HOME/.config/tmux"

    # Run setup
    if HOME="$TEST_HOME" ./setup.sh > /dev/null 2>&1; then
        # Check if symlinks point to correct locations
        local nvim_target=$(readlink "$TEST_HOME/.config/nvim")
        local tmux_target=$(readlink "$TEST_HOME/.config/tmux")

        if [[ "$nvim_target" == *"/nvim/.config/nvim" ]] && [[ "$tmux_target" == *"/tmux/.config/tmux" ]]; then
            return 0
        else
            fail "Symlinks not pointing to correct locations"
            fail "nvim target: $nvim_target"
            fail "tmux target: $tmux_target"
            return 1
        fi
    else
        fail "Setup script failed"
        return 1
    fi
}

# Test 4: Multiple runs (idempotency)
test_multiple_runs() {
    setup_test_env

    # Run setup twice
    if HOME="$TEST_HOME" ./setup.sh > /dev/null 2>&1 && HOME="$TEST_HOME" ./setup.sh > /dev/null 2>&1; then
        # Check if symlinks still exist and are correct
        if [ -L "$TEST_HOME/.config/nvim" ] && [ -L "$TEST_HOME/.config/tmux" ]; then
            local nvim_target=$(readlink "$TEST_HOME/.config/nvim")
            local tmux_target=$(readlink "$TEST_HOME/.config/tmux")

            if [[ "$nvim_target" == *"/nvim/.config/nvim" ]] && [[ "$tmux_target" == *"/tmux/.config/tmux" ]]; then
                return 0
            else
                fail "Symlinks corrupted after multiple runs"
                return 1
            fi
        else
            fail "Symlinks missing after multiple runs"
            return 1
        fi
    else
        fail "Multiple setup runs failed"
        return 1
    fi
}

# Test 5: tmux legacy symlink creation
test_tmux_legacy_symlink() {
    setup_test_env

    # Run setup
    if HOME="$TEST_HOME" ./setup.sh > /dev/null 2>&1; then
        # Check if legacy tmux symlink was created
        if [ -L "$TEST_HOME/.tmux.conf" ]; then
            local target=$(readlink "$TEST_HOME/.tmux.conf")
            if [[ "$target" == *"/.config/tmux/tmux.conf" ]]; then
                return 0
            else
                fail "Legacy tmux symlink pointing to wrong location: $target"
                return 1
            fi
        else
            fail "Legacy tmux symlink not created"
            return 1
        fi
    else
        fail "Setup script failed"
        return 1
    fi
}

# Test 6: Backup functionality
test_backup_functionality() {
    setup_test_env

    # Create existing config with unique content
    mkdir -p "$TEST_HOME/.config/nvim"
    echo "unique_test_content_$(date +%s)" > "$TEST_HOME/.config/nvim/test_file.lua"

    # Run setup
    if HOME="$TEST_HOME" ./setup.sh > /dev/null 2>&1; then
        # Check if backup was created and contains our content
        local backup_dir=$(ls -d "$TEST_HOME"/.config/dotfiles-backup-* 2>/dev/null | head -1)
        if [ -n "$backup_dir" ] && [ -f "$backup_dir/nvim/test_file.lua" ]; then
            if grep -q "unique_test_content" "$backup_dir/nvim/test_file.lua"; then
                return 0
            else
                fail "Backup doesn't contain expected content"
                return 1
            fi
        else
            fail "Backup not created or content missing"
            return 1
        fi
    else
        fail "Setup script failed"
        return 1
    fi
}

# Main test execution
main() {
    log "Starting dotfiles setup.sh tests"
    log "Test environment: $TEST_HOME"
    echo

    # Check if stow is available
    if ! command -v stow >/dev/null 2>&1; then
        fail "GNU Stow is required for testing but not installed"
        exit 1
    fi

    # Run all tests
    run_test "Fresh installation" test_fresh_install
    run_test "Replace existing directories" test_replace_directories
    run_test "Replace existing symlinks" test_replace_symlinks
    run_test "Multiple runs (idempotency)" test_multiple_runs
    run_test "tmux legacy symlink creation" test_tmux_legacy_symlink
    run_test "Backup functionality" test_backup_functionality

    # Cleanup
    cleanup_test_env

    # Summary
    echo "=========================================="
    log "Test Summary:"
    echo "  Total tests run: $TESTS_RUN"
    echo "  Tests passed: $TESTS_PASSED"
    echo "  Tests failed: $TESTS_FAILED"
    echo

    if [ $TESTS_FAILED -eq 0 ]; then
        success "All tests passed! ✅"
        exit 0
    else
        fail "Some tests failed! ❌"
        exit 1
    fi
}

# Trap to cleanup on exit
trap cleanup_test_env EXIT

main "$@"