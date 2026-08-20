#!/bin/bash

echo "=============================================="
echo "        LINUX SERVICE & PORT MONITOR"
echo "=============================================="

printf "%-25s %-10s %-10s %-10s\n" "SERVICE" "STATUS" "PORT" "PROTOCOL"
echo "------------------------------------------------------------"

systemctl list-units --type=service --state=running --no-legend | while read -r line
do
    service=$(echo "$line" | awk '{print $1}')

    # Get process/service PID
    pid=$(systemctl show "$service" -p MainPID --value)

    if [ "$pid" = "0" ]; then
        continue
    fi

    # Find ports used by this PID
    ports=$(sudo ss -tulpn | grep "pid=$pid,")

    if [ -z "$ports" ]; then
        printf "%-25s %-10s %-10s %-10s\n" \
            "$service" "ACTIVE" "-" "-"
    else
        echo "$ports" | while read -r socket
        do
            protocol=$(echo "$socket" | awk '{print $1}')

            local_address=$(echo "$socket" | awk '{print $5}')

            port="${local_address##*:}"

            printf "%-25s %-10s %-10s %-10s\n" \
                "$service" "ACTIVE" "$port" "$protocol"
        done
    fi

done

echo "=============================================="