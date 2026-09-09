#!/bin/bash

# Configuration
CONFIG_FILE="$(dirname "$0")/../config/monitoring.conf"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "ERROR: Configuration file not found: $CONFIG_FILE"
    exit 1
fi

source "$CONFIG_FILE"

# Linux Production Monitoring

# ============================================================
# CPU MONITORING
# ============================================================

read_cpu_stats() {
    read -r _ user nice system idle iowait irq softirq steal _ _ < /proc/stat
    echo "$user $nice $system $idle $iowait $irq $softirq $steal"
}

check_cpu() {

    echo
    echo "CPU"
    echo "---"

    cpu_before=$(read_cpu_stats)

    if [[ -z "$cpu_before" ]]; then
        echo "ERROR: Failed to collect initial CPU statistics"
        exit 1
    fi

    sleep 1

    cpu_after=$(read_cpu_stats)

    if [[ -z "$cpu_after" ]]; then
        echo "ERROR: Failed to collect second CPU statistics"
        exit 1
    fi

    read -r user_before nice_before system_before idle_before iowait_before irq_before softirq_before steal_before <<< "$cpu_before"

    read -r user_after nice_after system_after idle_after iowait_after irq_after softirq_after steal_after <<< "$cpu_after"

    total_before=$((user_before + nice_before + system_before + idle_before + iowait_before + irq_before + softirq_before + steal_before))

    total_after=$((user_after + nice_after + system_after + idle_after + iowait_after + irq_after + softirq_after + steal_after))

    total_delta=$((total_after - total_before))
    idle_delta=$((idle_after - idle_before))

    cpu_usage=$(( (total_delta - idle_delta) * 100 / total_delta ))


    if (( cpu_usage >= CPU_CRITICAL )); then
        cpu_status="CRITICAL"
    elif (( cpu_usage >= CPU_WARNING )); then
        cpu_status="WARNING"
    else
        cpu_status="OK"
    fi

    echo "Usage: ${cpu_usage}%"
    echo "Status: ${cpu_status}"
}


# ============================================================
# MEMORY MONITORING
# ============================================================

check_memory() {

    echo
    echo "MEMORY"
    echo "------"

    mem_total=$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)
    mem_available=$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)

    if [[ -z "$mem_total" || -z "$mem_available" ]]; then
        echo "ERROR: Failed to collect memory statistics"
        exit 1
    fi

    mem_used=$((mem_total - mem_available))
    memory_usage=$((mem_used * 100 / mem_total))

    if (( memory_usage >= MEMORY_CRITICAL )); then
        memory_status="CRITICAL"
    elif (( memory_usage >= MEMORY_WARNING )); then
        memory_status="WARNING"
    else
        memory_status="OK"
    fi

    echo "Usage: ${memory_usage}%"
    echo "Status: ${memory_status}"
}


# ============================================================
# FILESYSTEM MONITORING
# ============================================================

check_filesystem() {

    echo
    echo "FILESYSTEM"
    echo "----------"

    filesystem="/"

    disk_usage=$(df -P "$filesystem" | awk 'NR==2 {gsub("%",""); print $5}')

    if [[ -z "$disk_usage" ]]; then
        echo "ERROR: Failed to collect filesystem statistics"
        exit 1
    fi


    if (( disk_usage >= DISK_CRITICAL )); then
        disk_status="CRITICAL"
    elif (( disk_usage >= DISK_WARNING )); then
        disk_status="WARNING"
    else
        disk_status="OK"
    fi

    echo "$filesystem Usage: ${disk_usage}%"
    echo "Status: ${disk_status}"
}


# ============================================================
# INODE MONITORING
# ============================================================

check_inodes() {

    echo
    echo "INODES"
    echo "------"

    filesystem="/"

    inode_usage=$(df -Pi "$filesystem" | awk 'NR==2 {gsub("%",""); print $5}')

    if [[ -z "$inode_usage" ]]; then
        echo "ERROR: Failed to collect inode statistics"
        exit 1
    fi


    if (( inode_usage >= INODE_CRITICAL )); then
        inode_status="CRITICAL"
    elif (( inode_usage >= INODE_WARNING )); then
        inode_status="WARNING"
    else
        inode_status="OK"
    fi

    echo "$filesystem Usage: ${inode_usage}%"
    echo "Status: ${inode_status}"
}


# ============================================================
# MAIN
# ============================================================

echo "Linux Production Monitoring"
echo "==========================="

echo
echo "HOST INFORMATION"
echo "-----------------"
echo "Hostname: $(hostname)"

check_cpu
check_memory
check_filesystem
check_inodes
