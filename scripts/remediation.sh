remediate_service() {
    local service="$1"
    local service_state=""
    local attempt

    echo "Attempting remediation for: $service"

    if systemctl restart "$service"; then
        echo "$service restart command succeeded"
    else
        echo "$service restart command failed"
        log_event "REMEDIATION" "$service" "FAILED" "restart_command_failed"
        return 1
    fi

    for ((attempt = 1; attempt <= REMEDIATION_MAX_ATTEMPTS; attempt++))
    do
        sleep "$REMEDIATION_RETRY_INTERVAL"
        service_state=$(systemctl is-active "$service" 2>/dev/null) || true

        if [[ "$service_state" == "active" ]]; then
            echo "$service: REMEDIATION SUCCESS"
            log_event "REMEDIATION" "$service" "SUCCESS" \
                "status=$service_state attempts=$attempt"
            return 0
        fi

        echo "$service: verification attempt $attempt/$REMEDIATION_MAX_ATTEMPTS - status=$service_state"
    done

    echo "$service: REMEDIATION FAILED"
    log_event "REMEDIATION" "$service" "FAILED" \
        "status=$service_state attempts=$REMEDIATION_MAX_ATTEMPTS"
    return 1
}
