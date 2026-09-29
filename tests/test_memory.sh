#!/bin/bash

mem_total=$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)
mem_available=$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)

if [[ -z "$mem_total" || -z "$mem_available" ]]; then
    echo "FAIL: Memory statistics are not available"
    exit 1
fi

if (( mem_total <= 0 || mem_available < 0 )); then
    echo "FAIL: Memory statistics contain invalid values"
    exit 1
fi

mem_used=$((mem_total - mem_available))
memory_usage=$((mem_used * 100 / mem_total))

if (( memory_usage < 0 || memory_usage > 100 )); then    
    echo "FAIL: Memory usage calculation is invalid"
    exit 1
fi

echo "PASS: Memory statistics are available"
echo "Memory usage: ${memory_usage}%"
exit 0
