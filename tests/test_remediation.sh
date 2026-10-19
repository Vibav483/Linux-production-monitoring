
#!/bin/bash

set -u

# Test remediation behavior without restarting real system services.

test_dir=$(mktemp -d) || exit 1
trap 'rm -rf "$test_dir"' EXIT

export TEST_LOG="$test_dir/test.log"

REMEDIATION_RETRY_INTERVAL=2
REMEDIATION_MAX_ATTEMPTS=3

MOCK_RESTART_RESULT=0
MOCK_STATES=("inactive")
MOCK_STATE_FILE="$test_dir/state-index"

# Mock systemctl. State advances through a file so updates
# persist across Bash command substitutions.
systemctl() {
    case "$1" in
        restart)
            return "$MOCK_RESTART_RESULT"
            ;;
        is-active)
            local index=0

            if [[ -f "$MOCK_STATE_FILE" ]]; then
                index=$(<"$MOCK_STATE_FILE")
            fi

            echo "$((index + 1))" > "$MOCK_STATE_FILE"

            if (( index < ${#MOCK_STATES[@]} )); then
                echo "${MOCK_STATES[$index]}"
            else
                echo "${MOCK_STATES[${#MOCK_STATES[@]}-1]}"
            fi
            return 0
            ;;
        *)
            echo "Unexpected systemctl command: $*" >&2
            return 2
            ;;
    esac
}

# Do not actually sleep during tests.
sleep() {
    :
}

# Capture remediation events in a temporary log.
log_event() {
    echo "$*" >> "$TEST_LOG"
}

# Load the same remediation function used in production.
source "$(dirname "${BASH_SOURCE[0]}")/../scripts/remediation.sh"

# Test 1: restart command fails immediately.
: > "$TEST_LOG"
MOCK_RESTART_RESULT=1
MOCK_STATES=("inactive")
echo 0 > "$MOCK_STATE_FILE"

if remediate_service "test-service" >/dev/null 2>&1; then
    echo "FAIL: restart-command failure returned success"
    exit 1
fi

if ! grep -q 'restart_command_failed' "$TEST_LOG"; then
    echo "FAIL: restart-command failure was not logged"
    exit 1
fi

echo "PASS: restart-command failure is returned and logged"

# Test 2: service becomes active on the second verification attempt.
: > "$TEST_LOG"
MOCK_RESTART_RESULT=0
MOCK_STATES=("inactive" "active")
echo 0 > "$MOCK_STATE_FILE"

if ! remediate_service "test-service" >/dev/null 2>&1; then
    echo "FAIL: recovery on a later attempt returned failure"
    exit 1
fi

if ! grep -q 'SUCCESS.*status=active attempts=2' "$TEST_LOG"; then
    echo "FAIL: recovery on the second attempt was not logged"
    exit 1
fi

echo "PASS: service recovery on a later attempt is detected"

# Test 3: service remains inactive through all attempts.
: > "$TEST_LOG"
MOCK_STATES=("inactive")
echo 0 > "$MOCK_STATE_FILE"

if remediate_service "test-service" >/dev/null 2>&1; then
    echo "FAIL: persistent inactivity returned success"
    exit 1
fi

if ! grep -q 'FAILED.*status=inactive attempts=3' "$TEST_LOG"; then
    echo "FAIL: final timeout failure was not logged correctly"
    exit 1
fi

if [[ $(cat "$MOCK_STATE_FILE") -ne "$REMEDIATION_MAX_ATTEMPTS" ]]; then
    echo "FAIL: unexpected number of verification attempts"
    exit 1
fi

echo "PASS: persistent inactivity fails after the maximum attempts"

echo "All remediation tests passed."
exit 0

