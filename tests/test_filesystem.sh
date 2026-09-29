#!/bin/bash

filesystem="/"

disk_usage=$(df -P "$filesystem" | awk 'NR==2 {gsub("%",""); print $5}')

if [[ -z "$disk_usage" ]]; then
    echo "FAIL: Filesystem usage could not be collected"
    exit 1
fi

if (( disk_usage < 0 || disk_usage > 100 )); then
    echo "FAIL: Filesystem usage is invalid"
    exit 1
fi

echo "PASS: Filesystem usage is available"
echo "$filesystem Usage: ${disk_usage}%"
exit 0
