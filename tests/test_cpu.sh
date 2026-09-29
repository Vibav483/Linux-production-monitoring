#!/bin/bash

cpu_stats=$(head -n 1 /proc/stat)

if [[ "$cpu_stats" == cpu* ]]; then

    echo "PASS: CPU statistics are available"
    exit 0
else
    echo "FAIL: CPU statistics are not available"
    exit 1
fi
