
#!/bin/bash

# Linux Production Monitoring
# CPU utilization check

echo "Linux Production Monitoring"
echo "==========================="

echo
echo "HOST INFORMATION"
echo "-----------------"
echo "Hostname: $(hostname)"

echo
echo "CPU"
echo "---"

read_cpu_stats() {
    read -r _ user nice system idle iowait irq softirq steal _ _ < /proc/stat
    echo "$user $nice $system $idle $iowait $irq $softirq $steal"
}

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

CPU_WARNING=70
CPU_CRITICAL=90

if (( cpu_usage >= CPU_CRITICAL )); then
    cpu_status="CRITICAL"
elif (( cpu_usage >= CPU_WARNING )); then
    cpu_status="WARNING"
else
    cpu_status="OK"
fi

echo "Usage: ${cpu_usage}%"
echo "Status: ${cpu_status}"	 
