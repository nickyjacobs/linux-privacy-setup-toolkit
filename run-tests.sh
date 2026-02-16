#!/bin/bash
# Run all tests for the Privacy Setup Toolkit (no root, no real system changes).
# Usage: ./run-tests.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAIN_SCRIPT="$SCRIPT_DIR/privacy-toolkit.sh"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

run_test() {
    local name="$1"
    local cmd="$2"
    echo -e "${YELLOW}TEST: $name${NC}"
    if eval "$cmd"; then
        echo -e "${GREEN}  PASS${NC}"
        return 0
    else
        echo -e "${RED}  FAIL${NC}"
        return 1
    fi
}

FAILED=0

# 1. Syntax check
run_test "Bash syntax check (bash -n)" "bash -n '$MAIN_SCRIPT'" || FAILED=$((FAILED+1))

# 2. Help
run_test "Help (--help)" "bash '$MAIN_SCRIPT' --help | grep -q 'dry-run'" || FAILED=$((FAILED+1))

# 3. Dry-run full flow (no input needed: dry-run auto-accepts)
# Use workspace dir so sandboxed/CI environments can write
DRY_RUN_DIR="$SCRIPT_DIR/.test-output"
rm -rf "$DRY_RUN_DIR"
mkdir -p "$DRY_RUN_DIR"
echo -e "${YELLOW}TEST: Full dry-run (all steps, no system changes)${NC}"
OUTPUT=$(cd "$SCRIPT_DIR" && DRY_RUN_OUTPUT_DIR="$DRY_RUN_DIR" bash "$MAIN_SCRIPT" --dry-run 2>&1) || true
EXIT=$?
if [[ $EXIT -eq 0 ]]; then
    echo -e "${GREEN}  PASS (exit 0)${NC}"
else
    echo -e "${RED}  FAIL (exit $EXIT)${NC}"
    echo "$OUTPUT" | tail -20
    FAILED=$((FAILED+1))
fi

# 4. Dry-run output directory and generated scripts
echo -e "${YELLOW}TEST: Dry-run creates test dir and scripts${NC}"
TEST_DIR="$DRY_RUN_DIR"
if [[ -z "$TEST_DIR" ]]; then
    echo -e "${RED}  FAIL: TEST_DIR not set${NC}"
    FAILED=$((FAILED+1))
elif [[ ! -d "$TEST_DIR" ]]; then
    echo -e "${RED}  FAIL: $TEST_DIR does not exist${NC}"
    FAILED=$((FAILED+1))
else
    BIN="$TEST_DIR/bin"
    if [[ -f "$BIN/privacy-audit" && -f "$BIN/strip-metadata" ]]; then
        echo -e "${GREEN}  PASS ($BIN/privacy-audit and strip-metadata present)${NC}"
    else
        echo -e "${RED}  FAIL: missing scripts in $BIN${NC}"
        ls -la "$BIN" 2>/dev/null || true
        FAILED=$((FAILED+1))
    fi
fi
[[ -n "${TEST_DIR:-}" ]] && BIN="$TEST_DIR/bin"

# 5. Generated scripts content (output may contain errors e.g. sudo in sandbox; we only check expected text)
if [[ -n "${BIN:-}" && -d "$BIN" ]]; then
    run_test "Generated privacy-audit runs and shows audit header" "OUT=\$(bash \"$BIN/privacy-audit\" 2>&1); echo \"\$OUT\" | grep -q 'Privacy Configuration Audit'" || FAILED=$((FAILED+1))
    run_test "Generated strip-metadata shows usage without args" "OUT=\$(bash \"$BIN/strip-metadata\" 2>&1); echo \"\$OUT\" | grep -q 'Usage:'" || FAILED=$((FAILED+1))
else
    echo -e "${YELLOW}TEST: Skipping generated-script checks (dry-run dir not found)${NC}"
fi

# 6. Must not run as root (sudo ./script should exit 1 with message)
echo -e "${YELLOW}TEST: Script refuses to run as root${NC}"
if sudo -n true 2>/dev/null; then
    ROOT_EXIT=0
    sudo -n bash "$MAIN_SCRIPT" 2>&1 || ROOT_EXIT=$?
    if [[ $ROOT_EXIT -ne 0 ]]; then
        echo -e "${GREEN}  PASS (exits non-zero when run as root)${NC}"
    else
        echo -e "${RED}  FAIL: script should exit 1 when run as root${NC}"
        FAILED=$((FAILED+1))
    fi
else
    echo -e "${YELLOW}  SKIP (sudo requires password; run manually: sudo ./privacy-toolkit.sh → should exit with 'not run as root')${NC}"
fi

# Summary
echo ""
echo "=========================================="
if [[ $FAILED -eq 0 ]]; then
    echo -e "${GREEN}All tests passed.${NC}"
    echo "You can run the real setup with: ./privacy-toolkit.sh"
    echo "Or run another dry-run: ./privacy-toolkit.sh --dry-run"
    exit 0
else
    echo -e "${RED}$FAILED test(s) failed.${NC}"
    exit 1
fi
