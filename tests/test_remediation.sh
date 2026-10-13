
#!/bin/bash

set -u

# Test remediation logic without restarting real system services.

test_dir=$(mktemp -d) || exit 1
trap 'rm -rf "$test_dir"' EXIT

export TEST_LOG="$test_dir/test.log"
export MOCK_RESTART_RESULT=0
export MOCK_SERVICE_STATE="active"

# Mock systemctl so no real services are touched.
systemctl() {
    case "$1" in
        restart)
            return "$MOCK_RESTART_RESULT"
            ;;
        is-active)
            echo "$MOCK_SERVICE_STATE"
            return 0
            ;;
        *)
            echo "Unexpected systemctl command: $*" >&2
            return 2
            ;;
    esac
}

# Minimal log_event replacement for this isolated test.
log_event() {
    echo "$*" >> "$TEST_LOG"
}

# Function under test: keep this aligned with system_health.sh.
remediate_service() {
    local service="$1"

    echo "Attempting remediation for: $service"

    if systemctl restart "$service"; then
        echo "$service restart command succeeded"
    else
        echo "$service restart command failed"
        log_event "REMEDIATION" "$service" "FAILED" "restart_command_failed"
        return 1
    fi

    sleep 1

    local service_state
    service_state=$(systemctl is-active "$service")

    if [[ "$service_state" == "active" ]]; then
        echo "$service: REMEDIATION SUCCESS"
        log_event "REMEDIATION" "$service" "SUCCESS" "status=$service_state"
    else
        echo "$service: REMEDIATION FAILED"
        log_event "REMEDIATION" "$service" "FAILED" "status=$service_state"
        return 1
    fi
}

# Test 1: restart command fails.
MOCK_RESTART_RESULT=1
MOCK_SERVICE_STATE="inactive"

if remediate_service "test-service" >/dev/null 2>&1; then
    echo "FAIL: restart-command failure returned success"
    exit 1
fi

if ! grep -q 'restart_command_failed' "$TEST_LOG"; then
    echo "FAIL: restart-command failure was not logged"
    exit 1
fi

echo "PASS: restart-command failure is returned and logged"

# Test 2: restart succeeds, but service remains inactive.
: > "$TEST_LOG"
MOCK_RESTART_RESULT=0
MOCK_SERVICE_STATE="inactive"

if remediate_service "test-service" >/dev/null 2>&1; then
    echo "FAIL: inactive service returned success"
    exit 1
fi

if ! grep -q 'FAILED.*status=inactive' "$TEST_LOG"; then
    echo "FAIL: inactive service failure was not logged"
    exit 1
fi

echo "PASS: inactive service failure is returned and logged"

# Test 3: restart succeeds and service becomes active.
: > "$TEST_LOG"
MOCK_RESTART_RESULT=0
MOCK_SERVICE_STATE="active"

if ! remediate_service "test-service" >/dev/null 2>&1; then
    echo "FAIL: successful remediation returned failure"
    exit 1
fi

if ! grep -q 'SUCCESS.*status=active' "$TEST_LOG"; then
    echo "FAIL: successful remediation was not logged"
    exit 1
fi

echo "PASS: successful remediation is returned and logged"
exit 0

