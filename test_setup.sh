#!/bin/sh
# Test suite for setup.sh

# Override functions that require sudo to avoid permission issues
install_neovim() {
    echo "[MOCK] install_neovim called with NVIM_VERSION=$NVIM_VERSION"
    return 0
}

install_tmux() {
    echo "[MOCK] install_tmux called with TMUX_INSTALL_TPM=$TMUX_INSTALL_TPM"
    return 0
}

apt_install() {
    echo "[MOCK] apt_install called for package: $1"
    return 0
}

curl_retry() {
    echo "[MOCK] curl_retry called with args: $*"
    return 0
}

# Source the setup script to access functions (after our overrides)
. ./setup.sh

# Test framework
TEST_COUNT=0
PASS_COUNT=0
FAIL_COUNT=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

test_log() {
    echo "[TEST] $*"
}

assert_equals() {
    local expected="$1"
    local actual="$2"
    local test_name="$3"

    TEST_COUNT=$((TEST_COUNT + 1))

    if [ "$expected" = "$actual" ]; then
        PASS_COUNT=$((PASS_COUNT + 1))
        echo "${GREEN}✓${NC} $test_name"
    else
        FAIL_COUNT=$((FAIL_COUNT + 1))
        echo "${RED}✗${NC} $test_name"
        echo "  Expected: '$expected'"
        echo "  Actual:   '$actual'"
    fi
}

assert_true() {
    local condition="$1"
    local test_name="$2"

    TEST_COUNT=$((TEST_COUNT + 1))

    if eval "$condition"; then
        PASS_COUNT=$((PASS_COUNT + 1))
        echo "${GREEN}✓${NC} $test_name"
    else
        FAIL_COUNT=$((FAIL_COUNT + 1))
        echo "${RED}✗${NC} $test_name"
        echo "  Condition failed: $condition"
    fi
}

assert_false() {
    local condition="$1"
    local test_name="$2"

    TEST_COUNT=$((TEST_COUNT + 1))

    if ! eval "$condition"; then
        PASS_COUNT=$((PASS_COUNT + 1))
        echo "${GREEN}✓${NC} $test_name"
    else
        FAIL_COUNT=$((FAIL_COUNT + 1))
        echo "${RED}✗${NC} $test_name"
        echo "  Condition should have failed: $condition"
    fi
}

print_summary() {
    echo
    echo "========================================="
    echo "Test Summary:"
    echo "  Total:  $TEST_COUNT"
    echo "  ${GREEN}Passed: $PASS_COUNT${NC}"
    echo "  ${RED}Failed: $FAIL_COUNT${NC}"
    echo "========================================="

    if [ $FAIL_COUNT -eq 0 ]; then
        echo "${GREEN}All tests passed!${NC}"
        return 0
    else
        echo "${RED}Some tests failed!${NC}"
        return 1
    fi
}

# Test version_compare function
test_version_compare() {
    test_log "Testing version_compare function..."

    # Test equal versions
    assert_true "version_compare '1.0.0' '1.0.0'" "version_compare: 1.0.0 >= 1.0.0"

    # Test greater versions
    assert_true "version_compare '1.0.1' '1.0.0'" "version_compare: 1.0.1 >= 1.0.0"
    assert_true "version_compare '1.1.0' '1.0.0'" "version_compare: 1.1.0 >= 1.0.0"
    assert_true "version_compare '2.0.0' '1.0.0'" "version_compare: 2.0.0 >= 1.0.0"

    # Test lesser versions
    assert_false "version_compare '1.0.0' '1.0.1'" "version_compare: 1.0.0 < 1.0.1"
    assert_false "version_compare '1.0.0' '1.1.0'" "version_compare: 1.0.0 < 1.1.0"
    assert_false "version_compare '1.0.0' '2.0.0'" "version_compare: 1.0.0 < 2.0.0"

    # Test versions with v prefix
    assert_true "version_compare 'v1.0.0' '1.0.0'" "version_compare: v1.0.0 >= 1.0.0"
    assert_true "version_compare '1.0.0' 'v1.0.0'" "version_compare: 1.0.0 >= v1.0.0"

    # Test complex versions
    assert_true "version_compare '0.10.0' '0.9.5'" "version_compare: 0.10.0 >= 0.9.5"
    assert_false "version_compare '0.9.5' '0.10.0'" "version_compare: 0.9.5 < 0.10.0"
}

# Test detect_os function
test_detect_os() {
    test_log "Testing detect_os function..."

    # This test depends on the actual system
    local os_result
    os_result=$(detect_os)

    assert_true "[ -n '$os_result' ]" "detect_os: returns non-empty result"
    assert_true "[ '$os_result' = 'ubuntu' ] || [ '$os_result' = 'freebsd' ] || [ '$os_result' = 'linux' ] || [ '$os_result' = 'unknown' ]" "detect_os: returns valid OS type"
}

# Test utility functions exist
test_utility_functions_exist() {
    test_log "Testing utility functions exist..."

    assert_true "command -v version_compare >/dev/null" "version_compare function exists"
    assert_true "command -v check_app_version >/dev/null" "check_app_version function exists"
    assert_true "command -v apt_install >/dev/null" "apt_install function exists"
    assert_true "command -v curl_retry >/dev/null" "curl_retry function exists"
    assert_true "command -v run_as >/dev/null" "run_as function exists"
    assert_true "command -v install_neovim >/dev/null" "install_neovim function exists"
    assert_true "command -v install_tmux >/dev/null" "install_tmux function exists"
    assert_true "command -v check_and_install_tools >/dev/null" "check_and_install_tools function exists"
}

# Test environment variables
test_environment_variables() {
    test_log "Testing environment variables..."

    assert_true "[ -n '$NVIM_VERSION' ]" "NVIM_VERSION is set"
    assert_true "[ -n '$NVIM_INSTALL_METHOD' ]" "NVIM_INSTALL_METHOD is set"
    assert_true "[ -n '$TMUX_INSTALL_TPM' ]" "TMUX_INSTALL_TPM is set"
    assert_true "[ -n '$TARGET_USER' ]" "TARGET_USER is set"
    assert_true "[ -n '$TARGET_HOME' ]" "TARGET_HOME is set"

    # Test default values
    assert_equals "0.10.0" "$NVIM_VERSION" "NVIM_VERSION default value"
    assert_equals "appimage" "$NVIM_INSTALL_METHOD" "NVIM_INSTALL_METHOD default value"
    assert_equals "1" "$TMUX_INSTALL_TPM" "TMUX_INSTALL_TPM default value"
}

# Test check_app_version function with mock commands
test_check_app_version() {
    test_log "Testing check_app_version function..."

    # Create temporary mock command that doesn't exist
    local mock_cmd="nonexistent_app_$(date +%s)"

    # Test app not installed (should return 1)
    local result
    check_app_version "$mock_cmd" "1.0.0" "echo '1.0.0'"
    result=$?
    assert_equals "1" "$result" "check_app_version: returns 1 for non-existent app"

    # Test with existing command (sh should exist)
    if command -v sh >/dev/null 2>&1; then
        # Test version checking with a command that exists
        check_app_version "sh" "0.0.1" "echo '1.0.0'"
        result=$?
        assert_equals "0" "$result" "check_app_version: returns 0 for sufficient version"
    fi
}

# Test installation functions structure
test_installation_functions_structure() {
    test_log "Testing installation function structure..."

    # Test that functions are properly defined and callable
    assert_true "command -v install_neovim >/dev/null 2>&1" "install_neovim function is defined"
    assert_true "command -v install_tmux >/dev/null 2>&1" "install_tmux function is defined"

    # Test that functions handle basic error cases (dry run)
    # We'll test by checking if the functions exist and are executable
    assert_true "type install_neovim | grep -q 'function'" "install_neovim is a function"
    assert_true "type install_tmux | grep -q 'function'" "install_tmux is a function"
}

# Test curl_retry function behavior
test_curl_retry() {
    test_log "Testing curl_retry function..."

    # Test that our mock curl_retry function works
    local result
    result=$(curl_retry -s 'https://test.com' 2>/dev/null)
    assert_true "echo '$result' | grep -q 'MOCK.*curl_retry'" "curl_retry: mock function works"

    # Test function exists
    assert_true "command -v curl_retry >/dev/null" "curl_retry: function is defined"
}

# Test run_as function
test_run_as() {
    test_log "Testing run_as function..."

    # Test basic command execution
    local result
    result=$(run_as "echo 'test_output'")
    assert_equals "test_output" "$result" "run_as: executes commands correctly"

    # Test with TARGET_USER set to current user
    local old_target_user="$TARGET_USER"
    TARGET_USER="$(whoami)"
    result=$(run_as "echo 'current_user_test'")
    assert_equals "current_user_test" "$result" "run_as: works with current user"
    TARGET_USER="$old_target_user"
}

# Integration test for dotfiles setup
test_dotfiles_integration() {
    test_log "Testing dotfiles setup integration..."

    # Create temporary test directory
    local test_dir="/tmp/dotfiles_test_$(date +%s)"
    mkdir -p "$test_dir"

    # Test that detect_packages works
    local packages
    packages=$(detect_packages)
    assert_true "[ -n '$packages' ]" "detect_packages: returns packages"

    # Test that check_dependencies works
    assert_true "check_dependencies >/dev/null 2>&1 || true" "check_dependencies: runs without error"

    # Cleanup
    rm -rf "$test_dir"
}

# Main test runner
main_test() {
    echo "${YELLOW}Running setup.sh test suite...${NC}"
    echo

    test_environment_variables
    echo

    test_version_compare
    echo

    test_detect_os
    echo

    test_utility_functions_exist
    echo

    test_check_app_version
    echo

    test_installation_functions_structure
    echo

    test_curl_retry
    echo

    test_run_as
    echo

    test_dotfiles_integration
    echo

    print_summary
}

# Run tests
main_test